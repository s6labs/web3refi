import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_item.dart';

/// Calculator utilities for invoices
class InvoiceCalculator {
  /// Calculate invoice totals from items
  static InvoiceTotals calculateTotals({
    required List<InvoiceItem> items,
    double? taxRate,
    BigInt? discount,
    double? discountPercentage,
    BigInt? shippingCost,
  }) {
    // Calculate subtotal
    BigInt subtotal = BigInt.zero;
    for (final item in items) {
      subtotal += item.total;
    }

    // Apply discount
    BigInt discountAmount = BigInt.zero;
    if (discount != null) {
      discountAmount = discount;
    } else if (discountPercentage != null) {
      discountAmount = BigInt.from((subtotal.toDouble() * discountPercentage / 100.0).round());
    }

    final subtotalAfterDiscount = subtotal - discountAmount;

    // Calculate tax
    BigInt taxAmount = BigInt.zero;
    if (taxRate != null && taxRate > 0) {
      taxAmount = BigInt.from((subtotalAfterDiscount.toDouble() * taxRate / 100.0).round());
    }

    // Add shipping
    final shipping = shippingCost ?? BigInt.zero;

    // Calculate total
    final total = subtotalAfterDiscount + taxAmount + shipping;

    return InvoiceTotals(
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      shippingCost: shipping,
      total: total > BigInt.zero ? total : BigInt.zero,
    );
  }

  /// Calculate remaining amount
  static BigInt calculateRemainingAmount({
    required BigInt total,
    required BigInt paidAmount,
  }) {
    final remaining = total - paidAmount;
    return remaining > BigInt.zero ? remaining : BigInt.zero;
  }

  /// Calculate late fee
  static BigInt calculateLateFee({
    required BigInt total,
    required DateTime dueDate,
    double? lateFeePercentage,
    BigInt? lateFeeAmount,
    int gracePeriod = 0,
  }) {
    final now = DateTime.now();
    final daysOverdue = now.difference(dueDate).inDays;

    // Not overdue or within grace period
    if (daysOverdue <= gracePeriod) {
      return BigInt.zero;
    }

    // Fixed late fee
    if (lateFeeAmount != null) {
      return lateFeeAmount;
    }

    // Percentage-based late fee
    if (lateFeePercentage != null) {
      return BigInt.from((total.toDouble() * lateFeePercentage / 100.0).round());
    }

    return BigInt.zero;
  }

  /// Calculate payment progress (0.0 to 1.0)
  static double calculatePaymentProgress({
    required BigInt total,
    required BigInt paidAmount,
  }) {
    if (total == BigInt.zero) return 0.0;
    final progress = paidAmount.toDouble() / total.toDouble();
    return progress.clamp(0.0, 1.0);
  }

  /// Format amount to human-readable string
  static String formatAmount(BigInt amount, {int decimals = 2, String? symbol}) {
    final divisor = BigInt.from(10).pow(decimals);
    final whole = amount ~/ divisor;
    final fraction = amount.remainder(divisor);

    final fractionStr = fraction.toString().padLeft(decimals, '0');
    final result = '$whole.$fractionStr';

    return symbol != null ? '$result $symbol' : result;
  }

  /// Parse amount string to BigInt
  static BigInt parseAmount(String amount, {int decimals = 2}) {
    // Remove any spaces
    amount = amount.trim();

    // Handle decimal point
    if (amount.contains('.')) {
      final parts = amount.split('.');
      final whole = BigInt.parse(parts[0]);
      final fractionStr = parts.length > 1 ? parts[1] : '0';
      final paddedFraction = fractionStr.padRight(decimals, '0').substring(0, decimals);
      final fraction = BigInt.parse(paddedFraction);

      return (whole * BigInt.from(10).pow(decimals)) + fraction;
    } else {
      return BigInt.parse(amount) * BigInt.from(10).pow(decimals);
    }
  }

  /// Convert amount between different decimal precisions
  static BigInt convertDecimals({
    required BigInt amount,
    required int fromDecimals,
    required int toDecimals,
  }) {
    if (fromDecimals == toDecimals) return amount;

    if (fromDecimals < toDecimals) {
      // Scale up
      final multiplier = BigInt.from(10).pow(toDecimals - fromDecimals);
      return amount * multiplier;
    } else {
      // Scale down
      final divisor = BigInt.from(10).pow(fromDecimals - toDecimals);
      return amount ~/ divisor;
    }
  }

  /// Calculate factor price for invoice
  static BigInt calculateFactorPrice({
    required BigInt invoiceTotal,
    required double discountRate,
    BigInt? minPrice,
  }) {
    final discounted = invoiceTotal.toDouble() * (1.0 - discountRate / 100.0);
    final price = BigInt.from(discounted.round());

    if (minPrice != null && price < minPrice) {
      return minPrice;
    }

    return price;
  }

  /// Calculate platform fee for factoring
  static BigInt calculatePlatformFee({
    required BigInt factorPrice,
    required double platformFeePercentage,
  }) {
    return BigInt.from((factorPrice.toDouble() * platformFeePercentage / 100.0).round());
  }

  /// Distribute total amount across payment splits
  static Map<String, BigInt> distributePaymentSplits({
    required BigInt total,
    required List<PaymentSplit> splits,
  }) {
    final distribution = <String, BigInt>{};
    BigInt allocated = BigInt.zero;

    // First pass: calculate amounts for all splits
    for (int i = 0; i < splits.length; i++) {
      final split = splits[i];
      BigInt amount;

      if (split.fixedAmount != null) {
        amount = split.fixedAmount!;
      } else {
        amount = BigInt.from((total.toDouble() * split.percentage / 100.0).round());
      }

      distribution[split.address] = amount;
      allocated += amount;
    }

    // Handle rounding errors: add/subtract from primary recipient
    if (allocated != total) {
      final diff = total - allocated;
      final primarySplit = splits.firstWhere(
        (s) => s.isPrimary,
        orElse: () => splits.first,
      );

      distribution[primarySplit.address] = distribution[primarySplit.address]! + diff;
    }

    return distribution;
  }
}

/// Invoice totals calculation result
class InvoiceTotals {
  final BigInt subtotal;
  final BigInt discountAmount;
  final BigInt taxAmount;
  final BigInt shippingCost;
  final BigInt total;

  const InvoiceTotals({
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.shippingCost,
    required this.total,
  });
}
