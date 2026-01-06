import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';
import 'package:web3refi/src/invoice/manager/invoice_manager.dart';
import 'package:web3refi/src/invoice/payment/invoice_payment_handler.dart';

/// Manages invoice factoring (selling invoices to investors)
class InvoiceFactoringManager extends ChangeNotifier {
  final InvoiceManager invoiceManager;
  final InvoicePaymentHandler? paymentHandler;

  /// Active factoring listings
  final Map<String, FactoringListing> _listings = {};

  /// Completed factoring transactions
  final List<FactoringTransaction> _transactions = [];

  /// Platform fee (0.5% = 0.005)
  final double platformFee;

  InvoiceFactoringManager({
    required this.invoiceManager,
    this.paymentHandler,
    this.platformFee = 0.005,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // LIST INVOICE FOR FACTORING
  // ═══════════════════════════════════════════════════════════════════════

  /// List invoice for factoring (selling to investors)
  Future<FactoringListing> listInvoiceForFactoring({
    required String invoiceId,
    required double discountRate,
    BigInt? minPrice,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final invoice = await invoiceManager.getInvoice(invoiceId);
    if (invoice == null) {
      throw FactoringException('Invoice not found: $invoiceId');
    }

    // Validate invoice state
    _validateInvoiceForFactoring(invoice);

    // Validate discount rate
    if (discountRate <= 0 || discountRate >= 1.0) {
      throw FactoringException('Discount rate must be between 0 and 1.0');
    }

    // Calculate factor price
    final factorPrice = _calculateFactorPrice(
      invoiceTotal: invoice.remainingAmount,
      discountRate: discountRate,
    );

    // Check minimum price
    if (minPrice != null && factorPrice < minPrice) {
      throw FactoringException(
        'Calculated factor price is below minimum price',
      );
    }

    // Create listing
    final listing = FactoringListing(
      id: _generateListingId(),
      invoiceId: invoiceId,
      invoiceNumber: invoice.number,
      seller: invoice.from,
      invoiceTotal: invoice.total,
      remainingAmount: invoice.remainingAmount,
      discountRate: discountRate,
      factorPrice: factorPrice,
      minPrice: minPrice,
      currency: invoice.currency,
      dueDate: invoice.dueDate,
      listedAt: DateTime.now(),
      expiresAt: expiresAt,
      status: FactoringListingStatus.active,
      notes: notes,
    );

    // Save listing
    _listings[listing.id] = listing;

    // Mark invoice as being factored
    final updatedInvoice = invoice.copyWith(
      isFactored: true,
      factoringConfig: FactoringConfig(
        discountRate: discountRate,
        minPrice: minPrice ?? BigInt.zero,
        listingId: listing.id,
        listedAt: listing.listedAt,
      ),
    );

    await invoiceManager.updateInvoice(updatedInvoice);

    _log('Invoice listed for factoring: ${invoice.number} at ${(discountRate * 100).toStringAsFixed(1)}% discount');

    notifyListeners();

    return listing;
  }

  /// Update factoring listing
  Future<FactoringListing> updateListing({
    required String listingId,
    double? discountRate,
    BigInt? minPrice,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final listing = _listings[listingId];
    if (listing == null) {
      throw FactoringException('Listing not found: $listingId');
    }

    if (listing.status != FactoringListingStatus.active) {
      throw FactoringException('Cannot update inactive listing');
    }

    // Recalculate factor price if discount changed
    BigInt? newFactorPrice;
    if (discountRate != null) {
      newFactorPrice = _calculateFactorPrice(
        invoiceTotal: listing.remainingAmount,
        discountRate: discountRate,
      );
    }

    final updated = listing.copyWith(
      discountRate: discountRate,
      factorPrice: newFactorPrice,
      minPrice: minPrice,
      expiresAt: expiresAt,
      notes: notes,
    );

    _listings[listingId] = updated;

    notifyListeners();

    return updated;
  }

  /// Cancel factoring listing
  Future<void> cancelListing(String listingId) async {
    final listing = _listings[listingId];
    if (listing == null) {
      throw FactoringException('Listing not found: $listingId');
    }

    // Update listing status
    _listings[listingId] = listing.copyWith(
      status: FactoringListingStatus.cancelled,
    );

    // Update invoice
    final invoice = await invoiceManager.getInvoice(listing.invoiceId);
    if (invoice != null) {
      final updated = invoice.copyWith(
        isFactored: false,
        factoringConfig: null,
      );
      await invoiceManager.updateInvoice(updated);
    }

    _log('Listing cancelled: $listingId');

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUY FACTORED INVOICE
  // ═══════════════════════════════════════════════════════════════════════

  /// Buy factored invoice
  Future<FactoringTransaction> buyFactoredInvoice({
    required String listingId,
    required String buyerAddress,
    required String txHash,
    required int chainId,
  }) async {
    final listing = _listings[listingId];
    if (listing == null) {
      throw FactoringException('Listing not found: $listingId');
    }

    if (listing.status != FactoringListingStatus.active) {
      throw FactoringException('Listing is not active');
    }

    if (listing.isExpired) {
      throw FactoringException('Listing has expired');
    }

    // Get invoice
    final invoice = await invoiceManager.getInvoice(listing.invoiceId);
    if (invoice == null) {
      throw FactoringException('Invoice not found: ${listing.invoiceId}');
    }

    // Calculate platform fee
    final platformFeeAmount = _calculatePlatformFee(listing.factorPrice);
    final sellerReceives = listing.factorPrice - platformFeeAmount;

    // Create transaction
    final transaction = FactoringTransaction(
      id: _generateTransactionId(),
      listingId: listingId,
      invoiceId: listing.invoiceId,
      seller: listing.seller,
      buyer: buyerAddress,
      factorPrice: listing.factorPrice,
      platformFee: platformFeeAmount,
      sellerReceives: sellerReceives,
      currency: listing.currency,
      txHash: txHash,
      chainId: chainId,
      executedAt: DateTime.now(),
    );

    // Save transaction
    _transactions.add(transaction);

    // Update listing
    _listings[listingId] = listing.copyWith(
      status: FactoringListingStatus.sold,
      buyer: buyerAddress,
      soldAt: transaction.executedAt,
    );

    // Update invoice - transfer ownership to buyer
    final updatedInvoice = invoice.copyWith(
      from: buyerAddress, // Buyer now owns the invoice
      factoringConfig: invoice.factoringConfig?.copyWith(
        buyer: buyerAddress,
        soldAt: transaction.executedAt,
        factorPrice: listing.factorPrice,
      ),
    );

    await invoiceManager.updateInvoice(updatedInvoice);

    _log('Invoice factored: ${invoice.number} sold to $buyerAddress for ${listing.factorPrice}');

    notifyListeners();

    return transaction;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUERIES AND STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get all active listings
  List<FactoringListing> getActiveListings() {
    return _listings.values
        .where((listing) => listing.status == FactoringListingStatus.active && !listing.isExpired)
        .toList()
      ..sort((a, b) => b.listedAt.compareTo(a.listedAt));
  }

  /// Get listings by seller
  List<FactoringListing> getListingsBySeller(String sellerAddress) {
    return _listings.values
        .where((listing) => listing.seller.toLowerCase() == sellerAddress.toLowerCase())
        .toList()
      ..sort((a, b) => b.listedAt.compareTo(a.listedAt));
  }

  /// Get purchases by buyer
  List<FactoringTransaction> getPurchasesByBuyer(String buyerAddress) {
    return _transactions
        .where((tx) => tx.buyer.toLowerCase() == buyerAddress.toLowerCase())
        .toList()
      ..sort((a, b) => b.executedAt.compareTo(a.executedAt));
  }

  /// Get factoring statistics
  FactoringStatistics getStatistics() {
    final activeListings = getActiveListings();
    final soldListings = _listings.values
        .where((l) => l.status == FactoringListingStatus.sold)
        .toList();

    BigInt totalActiveValue = BigInt.zero;
    BigInt totalSoldValue = BigInt.zero;
    BigInt totalPlatformFees = BigInt.zero;

    for (final listing in activeListings) {
      totalActiveValue += listing.factorPrice;
    }

    for (final tx in _transactions) {
      totalSoldValue += tx.factorPrice;
      totalPlatformFees += tx.platformFee;
    }

    double avgDiscount = 0.0;
    if (_listings.isNotEmpty) {
      avgDiscount = _listings.values
              .map((l) => l.discountRate)
              .reduce((a, b) => a + b) /
          _listings.length;
    }

    return FactoringStatistics(
      totalListings: _listings.length,
      activeListings: activeListings.length,
      soldListings: soldListings.length,
      totalActiveValue: totalActiveValue,
      totalSoldValue: totalSoldValue,
      totalPlatformFees: totalPlatformFees,
      averageDiscount: avgDiscount,
    );
  }

  /// Get listing by ID
  FactoringListing? getListing(String listingId) {
    return _listings[listingId];
  }

  /// Get transaction by ID
  FactoringTransaction? getTransaction(String transactionId) {
    return _transactions.firstWhere(
      (tx) => tx.id == transactionId,
      orElse: () => throw FactoringException('Transaction not found'),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Validate invoice can be factored
  void _validateInvoiceForFactoring(Invoice invoice) {
    if (invoice.isPaid) {
      throw FactoringException('Cannot factor paid invoice');
    }

    if (invoice.status == InvoiceStatus.cancelled) {
      throw FactoringException('Cannot factor cancelled invoice');
    }

    if (invoice.status == InvoiceStatus.disputed) {
      throw FactoringException('Cannot factor disputed invoice');
    }

    if (invoice.isFactored) {
      throw FactoringException('Invoice is already being factored');
    }

    if (invoice.remainingAmount == BigInt.zero) {
      throw FactoringException('Invoice has no remaining amount');
    }
  }

  /// Calculate factor price
  BigInt _calculateFactorPrice({
    required BigInt invoiceTotal,
    required double discountRate,
  }) {
    final discountAmount = BigInt.from(
      invoiceTotal.toDouble() * discountRate,
    );
    return invoiceTotal - discountAmount;
  }

  /// Calculate platform fee
  BigInt _calculatePlatformFee(BigInt factorPrice) {
    return BigInt.from(factorPrice.toDouble() * platformFee);
  }

  /// Generate listing ID
  String _generateListingId() {
    return 'listing_${DateTime.now().millisecondsSinceEpoch}_${_listings.length}';
  }

  /// Generate transaction ID
  String _generateTransactionId() {
    return 'factoring_tx_${DateTime.now().millisecondsSinceEpoch}_${_transactions.length}';
  }

  void _log(String message) {
    debugPrint('[InvoiceFactoringManager] $message');
  }

  /// Clear all data (for testing)
  void clear() {
    _listings.clear();
    _transactions.clear();
    notifyListeners();
  }
}

/// Factoring listing
class FactoringListing {
  final String id;
  final String invoiceId;
  final String invoiceNumber;
  final String seller;
  final BigInt invoiceTotal;
  final BigInt remainingAmount;
  final double discountRate;
  final BigInt factorPrice;
  final BigInt? minPrice;
  final String currency;
  final DateTime dueDate;
  final DateTime listedAt;
  final DateTime? expiresAt;
  final FactoringListingStatus status;
  final String? buyer;
  final DateTime? soldAt;
  final String? notes;

  FactoringListing({
    required this.id,
    required this.invoiceId,
    required this.invoiceNumber,
    required this.seller,
    required this.invoiceTotal,
    required this.remainingAmount,
    required this.discountRate,
    required this.factorPrice,
    required this.currency, required this.dueDate, required this.listedAt, required this.status, this.minPrice,
    this.expiresAt,
    this.buyer,
    this.soldAt,
    this.notes,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  int get daysUntilDue {
    return dueDate.difference(DateTime.now()).inDays;
  }

  double get roi {
    if (factorPrice == BigInt.zero) return 0.0;
    final profit = remainingAmount - factorPrice;
    return profit.toDouble() / factorPrice.toDouble();
  }

  FactoringListing copyWith({
    FactoringListingStatus? status,
    double? discountRate,
    BigInt? factorPrice,
    BigInt? minPrice,
    DateTime? expiresAt,
    String? buyer,
    DateTime? soldAt,
    String? notes,
  }) {
    return FactoringListing(
      id: id,
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      seller: seller,
      invoiceTotal: invoiceTotal,
      remainingAmount: remainingAmount,
      discountRate: discountRate ?? this.discountRate,
      factorPrice: factorPrice ?? this.factorPrice,
      minPrice: minPrice ?? this.minPrice,
      currency: currency,
      dueDate: dueDate,
      listedAt: listedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
      buyer: buyer ?? this.buyer,
      soldAt: soldAt ?? this.soldAt,
      notes: notes ?? this.notes,
    );
  }
}

/// Factoring transaction
class FactoringTransaction {
  final String id;
  final String listingId;
  final String invoiceId;
  final String seller;
  final String buyer;
  final BigInt factorPrice;
  final BigInt platformFee;
  final BigInt sellerReceives;
  final String currency;
  final String txHash;
  final int chainId;
  final DateTime executedAt;

  FactoringTransaction({
    required this.id,
    required this.listingId,
    required this.invoiceId,
    required this.seller,
    required this.buyer,
    required this.factorPrice,
    required this.platformFee,
    required this.sellerReceives,
    required this.currency,
    required this.txHash,
    required this.chainId,
    required this.executedAt,
  });
}

/// Factoring statistics
class FactoringStatistics {
  final int totalListings;
  final int activeListings;
  final int soldListings;
  final BigInt totalActiveValue;
  final BigInt totalSoldValue;
  final BigInt totalPlatformFees;
  final double averageDiscount;

  FactoringStatistics({
    required this.totalListings,
    required this.activeListings,
    required this.soldListings,
    required this.totalActiveValue,
    required this.totalSoldValue,
    required this.totalPlatformFees,
    required this.averageDiscount,
  });
}

/// Factoring listing status
enum FactoringListingStatus {
  active,
  sold,
  cancelled,
  expired,
}

/// Factoring exception
class FactoringException implements Exception {
  final String message;

  FactoringException(this.message);

  @override
  String toString() => 'FactoringException: $message';
}

/// Extension on FactoringConfig for copying
extension FactoringConfigCopyWith on FactoringConfig {
  FactoringConfig copyWith({
    double? discountRate,
    BigInt? minPrice,
    bool? enabled,
    List<String>? allowedBuyers,
    double? platformFeePercentage,
    DateTime? enabledAt,
    String? listingId,
    DateTime? listedAt,
    String? buyer,
    DateTime? soldAt,
    BigInt? factorPrice,
  }) {
    return FactoringConfig(
      discountRate: discountRate ?? this.discountRate,
      minPrice: minPrice ?? this.minPrice,
      enabled: enabled ?? this.enabled,
      allowedBuyers: allowedBuyers ?? this.allowedBuyers,
      platformFeePercentage: platformFeePercentage ?? this.platformFeePercentage,
      enabledAt: enabledAt ?? this.enabledAt,
      listingId: listingId ?? this.listingId,
      listedAt: listedAt ?? this.listedAt,
      buyer: buyer ?? this.buyer,
      soldAt: soldAt ?? this.soldAt,
      factorPrice: factorPrice ?? this.factorPrice,
    );
  }
}
