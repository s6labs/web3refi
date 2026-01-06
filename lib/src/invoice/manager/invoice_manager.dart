import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/invoice.dart';
import '../core/invoice_item.dart';
import '../core/invoice_status.dart';
import '../core/invoice_config.dart';
import '../core/payment_info.dart';
import '../storage/invoice_storage.dart';
import '../storage/ipfs_storage.dart';
import '../storage/arweave_storage.dart';
import 'invoice_calculator.dart';
import 'invoice_validator.dart';
import '../../names/universal_name_service.dart';
import '../../wallet/wallet_manager.dart';

/// Main invoice manager - orchestrates all invoice operations
class InvoiceManager extends ChangeNotifier {
  final InvoiceConfig config;
  final InvoiceStorage storage;
  final IPFSStorage? ipfsStorage;
  final ArweaveStorage? arweaveStorage;
  final UniversalNameService? nameService;
  final WalletManager? walletManager;

  /// Active invoices cache
  final Map<String, Invoice> _invoiceCache = {};

  /// Stream controller for invoice updates
  final StreamController<InvoiceEvent> _eventController = StreamController<InvoiceEvent>.broadcast();

  InvoiceManager({
    required this.config,
    required this.storage,
    this.ipfsStorage,
    this.arweaveStorage,
    this.nameService,
    this.walletManager,
  });

  /// Stream of invoice events
  Stream<InvoiceEvent> get events => _eventController.stream;

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE CREATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Create a new invoice
  Future<Invoice> createInvoice({
    required String to,
    required String title,
    required List<InvoiceItem> items,
    required String currency,
    required String tokenAddress,
    required int chainId,
    String? description,
    DateTime? dueDate,
    String? paymentTerms,
    List<String>? acceptedTokens,
    List<int>? acceptedChains,
    double? taxRate,
    BigInt? discount,
    double? discountPercentage,
    BigInt? shippingCost,
    List<PaymentSplit>? paymentSplits,
    bool? useEscrow,
    RecurringConfig? recurringConfig,
    FactoringConfig? factoringConfig,
    Map<String, dynamic>? metadata,
    String? logoUrl,
    String? brandColor,
    String? footerText,
  }) async {
    // Get current user address
    final from = walletManager?.address ?? '';
    if (from.isEmpty) {
      throw InvoiceException('Wallet not connected');
    }

    // Resolve recipient name if needed
    String? toName;
    String resolvedTo = to;
    if (nameService != null && !InvoiceValidator.isValidAddress(to)) {
      final resolved = await nameService!.resolve(to);
      if (resolved == null) {
        throw InvoiceException('Could not resolve recipient: $to');
      }
      toName = to;
      resolvedTo = resolved;
    }

    // Calculate totals
    final totals = InvoiceCalculator.calculateTotals(
      items: items,
      taxRate: taxRate ?? config.defaultTaxRate,
      discount: discount,
      discountPercentage: discountPercentage,
      shippingCost: shippingCost,
    );

    // Generate invoice number
    final number = await storage.generateInvoiceNumber(
      prefix: config.invoiceNumberPrefix,
      startingNumber: config.startingInvoiceNumber,
    );

    // Generate unique ID
    final id = _generateInvoiceId();

    // Create invoice
    final now = DateTime.now();
    final invoice = Invoice(
      id: id,
      number: number,
      createdAt: now,
      updatedAt: now,
      from: from,
      to: resolvedTo,
      toName: toName,
      title: title,
      description: description,
      items: items,
      currency: currency,
      tokenAddress: tokenAddress,
      chainId: chainId,
      subtotal: totals.subtotal,
      taxAmount: totals.taxAmount,
      taxRate: taxRate ?? config.defaultTaxRate,
      discount: totals.discountAmount,
      discountPercentage: discountPercentage,
      shippingCost: shippingCost,
      total: totals.total,
      dueDate: dueDate ?? now.add(Duration(days: config.defaultDueDays)),
      paymentTerms: paymentTerms ?? config.defaultPaymentTerms,
      acceptedTokens: acceptedTokens ?? [currency],
      acceptedChains: acceptedChains ?? [chainId],
      status: InvoiceStatus.draft,
      paidAmount: BigInt.zero,
      remainingAmount: totals.total,
      storageBackend: config.defaultStorageBackend,
      hasSplitPayment: paymentSplits != null && paymentSplits.isNotEmpty,
      paymentSplits: paymentSplits,
      useEscrow: useEscrow ?? config.defaultUseEscrow,
      isRecurring: recurringConfig != null,
      recurringConfig: recurringConfig,
      isFactored: factoringConfig != null,
      factoringConfig: factoringConfig,
      metadata: metadata,
      logoUrl: logoUrl ?? config.defaultLogoUrl,
      brandColor: brandColor ?? config.defaultBrandColor,
      footerText: footerText ?? config.defaultFooterText,
    );

    // Validate
    final validation = InvoiceValidator.validateInvoice(invoice);
    if (!validation.isValid) {
      throw InvoiceException('Invalid invoice: ${validation.errorMessage}');
    }

    // Save to storage
    await storage.saveInvoice(invoice);

    // Update cache
    _invoiceCache[invoice.id] = invoice;

    // Emit event
    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.created,
      invoice: invoice,
    ));

    notifyListeners();

    _log('Invoice created: ${invoice.number} (${invoice.id})');

    return invoice;
  }

  /// Create invoice from template
  Future<Invoice> createFromTemplate({
    required Invoice template,
    required String to,
    DateTime? dueDate,
    Map<String, dynamic>? overrides,
  }) async {
    return createInvoice(
      to: to,
      title: overrides?['title'] ?? template.title,
      description: overrides?['description'] ?? template.description,
      items: overrides?['items'] ?? template.items,
      currency: overrides?['currency'] ?? template.currency,
      tokenAddress: overrides?['tokenAddress'] ?? template.tokenAddress,
      chainId: overrides?['chainId'] ?? template.chainId,
      dueDate: dueDate,
      paymentTerms: template.paymentTerms,
      acceptedTokens: template.acceptedTokens,
      acceptedChains: template.acceptedChains,
      taxRate: template.taxRate,
      useEscrow: template.useEscrow,
      logoUrl: template.logoUrl,
      brandColor: template.brandColor,
      footerText: template.footerText,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE RETRIEVAL
  // ═══════════════════════════════════════════════════════════════════════

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String id) async {
    // Check cache first
    if (_invoiceCache.containsKey(id)) {
      return _invoiceCache[id];
    }

    // Load from storage
    final invoice = await storage.getInvoice(id);
    if (invoice != null) {
      _invoiceCache[id] = invoice;
    }

    return invoice;
  }

  /// Get invoice by number
  Future<Invoice?> getInvoiceByNumber(String number) async {
    return await storage.getInvoiceByNumber(number);
  }

  /// Get all invoices
  Future<List<Invoice>> getAllInvoices() async {
    return await storage.getAllInvoices();
  }

  /// Get invoices by status
  Future<List<Invoice>> getInvoicesByStatus(InvoiceStatus status) async {
    return await storage.getInvoicesByStatus(status);
  }

  /// Get invoices sent by user
  Future<List<Invoice>> getSentInvoices() async {
    final address = walletManager?.address;
    if (address == null) return [];
    return await storage.getInvoicesBySender(address);
  }

  /// Get invoices received by user
  Future<List<Invoice>> getReceivedInvoices() async {
    final address = walletManager?.address;
    if (address == null) return [];
    return await storage.getInvoicesByRecipient(address);
  }

  /// Get overdue invoices
  Future<List<Invoice>> getOverdueInvoices() async {
    return await storage.getOverdueInvoices();
  }

  /// Search invoices
  Future<List<Invoice>> searchInvoices(String query) async {
    return await storage.searchInvoices(query);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE UPDATE
  // ═══════════════════════════════════════════════════════════════════════

  /// Update invoice
  Future<Invoice> updateInvoice(Invoice invoice) async {
    // Validate
    final validation = InvoiceValidator.validateInvoice(invoice);
    if (!validation.isValid) {
      throw InvoiceException('Invalid invoice: ${validation.errorMessage}');
    }

    // Update timestamp
    final updated = invoice.copyWith(updatedAt: DateTime.now());

    // Save
    await storage.saveInvoice(updated);

    // Update cache
    _invoiceCache[updated.id] = updated;

    // Emit event
    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.updated,
      invoice: updated,
    ));

    notifyListeners();

    return updated;
  }

  /// Mark invoice as sent
  Future<Invoice> markAsSent(String invoiceId) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    final updated = invoice.copyWith(
      status: InvoiceStatus.sent,
      sentAt: DateTime.now(),
    );

    return await updateInvoice(updated);
  }

  /// Mark invoice as viewed
  Future<Invoice> markAsViewed(String invoiceId) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    if (invoice.viewedAt != null) {
      return invoice; // Already viewed
    }

    final updated = invoice.copyWith(
      status: InvoiceStatus.viewed,
      viewedAt: DateTime.now(),
    );

    return await updateInvoice(updated);
  }

  /// Cancel invoice
  Future<Invoice> cancelInvoice(String invoiceId, {String? reason}) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    if (invoice.status.isFinalized) {
      throw InvoiceException('Cannot cancel finalized invoice');
    }

    final updated = invoice.copyWith(
      status: InvoiceStatus.cancelled,
      notes: reason != null ? '${invoice.notes ?? ''}\nCancelled: $reason' : invoice.notes,
    );

    return await updateInvoice(updated);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT PROCESSING
  // ═══════════════════════════════════════════════════════════════════════

  /// Record payment for invoice
  Future<Invoice> recordPayment({
    required String invoiceId,
    required String txHash,
    required String from,
    required BigInt amount,
    required String token,
    required String tokenSymbol,
    required int chainId,
    String? notes,
  }) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    // Validate payment
    if (amount <= BigInt.zero) {
      throw InvoiceException('Payment amount must be greater than zero');
    }

    if (invoice.paidAmount + amount > invoice.total) {
      throw InvoiceException('Payment exceeds invoice total');
    }

    // Create payment record
    final payment = Payment(
      id: _generatePaymentId(),
      invoiceId: invoiceId,
      txHash: txHash,
      from: from,
      to: invoice.to,
      amount: amount,
      token: token,
      tokenSymbol: tokenSymbol,
      chainId: chainId,
      createdAt: DateTime.now(),
      status: PaymentStatus.pending,
      notes: notes,
    );

    // Validate payment
    final validation = InvoiceValidator.validatePayment(payment);
    if (!validation.isValid) {
      throw InvoiceException('Invalid payment: ${validation.errorMessage}');
    }

    // Update invoice
    final newPaidAmount = invoice.paidAmount + amount;
    final newRemainingAmount = invoice.total - newPaidAmount;

    InvoiceStatus newStatus;
    if (newRemainingAmount == BigInt.zero) {
      newStatus = InvoiceStatus.paid;
    } else if (newPaidAmount > BigInt.zero) {
      newStatus = InvoiceStatus.partiallyPaid;
    } else {
      newStatus = invoice.status;
    }

    final updatedPayments = [...invoice.payments, payment];

    final updated = invoice.copyWith(
      payments: updatedPayments,
      paidAmount: newPaidAmount,
      remainingAmount: newRemainingAmount,
      status: newStatus,
      paidAt: newStatus == InvoiceStatus.paid ? DateTime.now() : null,
    );

    // Save
    await updateInvoice(updated);

    // Emit event
    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.paymentReceived,
      invoice: updated,
      payment: payment,
    ));

    _log('Payment recorded: ${payment.txHash} for invoice ${invoice.number}');

    return updated;
  }

  /// Confirm payment (update from pending to confirmed)
  Future<Invoice> confirmPayment({
    required String invoiceId,
    required String paymentId,
    int? blockNumber,
    int confirmations = 12,
  }) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    final paymentIndex = invoice.payments.indexWhere((p) => p.id == paymentId);
    if (paymentIndex == -1) {
      throw InvoiceException('Payment not found: $paymentId');
    }

    final payment = invoice.payments[paymentIndex];
    final confirmedPayment = payment.copyWith(
      status: PaymentStatus.confirmed,
      confirmedAt: DateTime.now(),
      blockNumber: blockNumber,
      confirmations: confirmations,
    );

    final updatedPayments = List<Payment>.from(invoice.payments);
    updatedPayments[paymentIndex] = confirmedPayment;

    final updated = invoice.copyWith(payments: updatedPayments);

    return await updateInvoice(updated);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STORAGE OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Upload invoice to IPFS
  Future<String> uploadToIPFS(String invoiceId) async {
    if (ipfsStorage == null) {
      throw InvoiceException('IPFS storage not configured');
    }

    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    _log('Uploading invoice to IPFS: ${invoice.number}');

    final cid = await ipfsStorage!.uploadInvoice(invoice);

    _log('Invoice uploaded to IPFS: $cid');

    // Update invoice with IPFS CID
    final updated = invoice.copyWith(
      ipfsCid: cid,
      storageBackend: InvoiceStorageBackend.ipfsWithLocal,
    );

    await updateInvoice(updated);

    // Pin to ensure persistence
    await ipfsStorage!.pin(cid);

    return cid;
  }

  /// Download invoice from IPFS
  Future<Invoice> downloadFromIPFS(String cid) async {
    if (ipfsStorage == null) {
      throw InvoiceException('IPFS storage not configured');
    }

    _log('Downloading invoice from IPFS: $cid');

    final invoice = await ipfsStorage!.downloadInvoice(cid);

    // Save to local storage
    await storage.saveInvoice(invoice);

    _log('Invoice downloaded from IPFS: ${invoice.number}');

    return invoice;
  }

  /// Upload invoice to Arweave (permanent storage)
  Future<String> uploadToArweave(String invoiceId) async {
    if (arweaveStorage == null) {
      throw InvoiceException('Arweave storage not configured');
    }

    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    _log('Uploading invoice to Arweave: ${invoice.number}');

    final txId = await arweaveStorage!.uploadInvoice(invoice);

    _log('Invoice uploaded to Arweave: $txId');

    // Update invoice with Arweave transaction ID
    final updated = invoice.copyWith(
      arweaveTxId: txId,
      storageBackend: InvoiceStorageBackend.arweaveWithLocal,
    );

    await updateInvoice(updated);

    return txId;
  }

  /// Download invoice from Arweave
  Future<Invoice> downloadFromArweave(String txId) async {
    if (arweaveStorage == null) {
      throw InvoiceException('Arweave storage not configured');
    }

    _log('Downloading invoice from Arweave: $txId');

    final invoice = await arweaveStorage!.downloadInvoice(txId);

    // Save to local storage
    await storage.saveInvoice(invoice);

    _log('Invoice downloaded from Arweave: ${invoice.number}');

    return invoice;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DISPUTE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Raise dispute for invoice
  Future<Invoice> raiseDispute({
    required String invoiceId,
    required String reason,
  }) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    final address = walletManager?.address ?? '';

    final updated = invoice.copyWith(
      isDisputed: true,
      status: InvoiceStatus.disputed,
      disputeReason: reason,
      disputedBy: address,
      disputedAt: DateTime.now(),
    );

    await updateInvoice(updated);

    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.disputed,
      invoice: updated,
    ));

    return updated;
  }

  /// Resolve dispute
  Future<Invoice> resolveDispute({
    required String invoiceId,
    required String resolution,
    InvoiceStatus? newStatus,
  }) async {
    final invoice = await getInvoice(invoiceId);
    if (invoice == null) {
      throw InvoiceException('Invoice not found: $invoiceId');
    }

    if (!invoice.isDisputed) {
      throw InvoiceException('Invoice is not under dispute');
    }

    final updated = invoice.copyWith(
      isDisputed: false,
      disputeResolution: resolution,
      status: newStatus ?? InvoiceStatus.pending,
    );

    await updateInvoice(updated);

    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.disputeResolved,
      invoice: updated,
    ));

    return updated;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get invoice statistics
  Future<InvoiceStatistics> getStatistics() async {
    return await storage.getStatistics();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Delete invoice
  Future<void> deleteInvoice(String id) async {
    await storage.deleteInvoice(id);
    _invoiceCache.remove(id);

    _eventController.add(InvoiceEvent(
      type: InvoiceEventType.deleted,
      invoiceId: id,
    ));

    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _invoiceCache.clear();
    notifyListeners();
  }

  /// Generate unique invoice ID
  String _generateInvoiceId() {
    return 'inv_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  /// Generate unique payment ID
  String _generatePaymentId() {
    return 'pay_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(8)}';
  }

  /// Generate random string
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    return List.generate(length, (i) => chars[(random + i) % chars.length]).join();
  }

  /// Log message
  void _log(String message) {
    debugPrint('[InvoiceManager] $message');
  }

  /// Watch invoice status updates
  Stream<Invoice> watchInvoice(String invoiceId) {
    return events
        .where((event) => event.invoice?.id == invoiceId)
        .map((event) => event.invoice!)
        .distinct((a, b) => a.status == b.status);
  }

  @override
  void dispose() {
    _eventController.close();
    super.dispose();
  }
}

/// Invoice event types
enum InvoiceEventType {
  created,
  updated,
  deleted,
  sent,
  viewed,
  paymentReceived,
  disputed,
  disputeResolved,
  factored,
  recurring,
}

/// Invoice event
class InvoiceEvent {
  final InvoiceEventType type;
  final Invoice? invoice;
  final Payment? payment;
  final String? invoiceId;

  InvoiceEvent({
    required this.type,
    this.invoice,
    this.payment,
    this.invoiceId,
  });
}

/// Invoice exception
class InvoiceException implements Exception {
  final String message;

  InvoiceException(this.message);

  @override
  String toString() => 'InvoiceException: $message';
}

/// Static factory for creating InvoiceManager
class InvoiceManagerFactory {
  static Future<InvoiceManager> create({
    InvoiceConfig? config,
    UniversalNameService? nameService,
    WalletManager? walletManager,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final storage = InvoiceStorage(prefs: prefs);

    final invoiceConfig = config ?? const InvoiceConfig();

    IPFSStorage? ipfsStorage;
    if (invoiceConfig.ipfsApiUrl != null) {
      ipfsStorage = IPFSStorage(
        apiUrl: invoiceConfig.ipfsApiUrl!,
        gateway: invoiceConfig.ipfsGateway ?? 'https://ipfs.io/ipfs/',
      );
    }

    ArweaveStorage? arweaveStorage;
    if (invoiceConfig.arweaveApiUrl != null) {
      arweaveStorage = ArweaveStorage(
        apiUrl: invoiceConfig.arweaveApiUrl!,
        gateway: invoiceConfig.arweaveGateway ?? 'https://arweave.net/',
      );
    }

    return InvoiceManager(
      config: invoiceConfig,
      storage: storage,
      ipfsStorage: ipfsStorage,
      arweaveStorage: arweaveStorage,
      nameService: nameService,
      walletManager: walletManager,
    );
  }
}
