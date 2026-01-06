import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_item.dart';
import 'package:web3refi/src/invoice/core/payment_info.dart';

/// Validator for invoice data
class InvoiceValidator {
  /// Validate invoice before creation/update
  static ValidationResult validateInvoice(Invoice invoice) {
    final errors = <String>[];

    // Validate parties
    if (invoice.from.isEmpty) {
      errors.add('Sender address is required');
    }

    if (invoice.to.isEmpty) {
      errors.add('Recipient address is required');
    }

    if (invoice.from == invoice.to) {
      errors.add('Sender and recipient cannot be the same');
    }

    // Validate title
    if (invoice.title.isEmpty) {
      errors.add('Invoice title is required');
    }

    // Validate items
    if (invoice.items.isEmpty) {
      errors.add('At least one invoice item is required');
    }

    for (final item in invoice.items) {
      final itemValidation = validateInvoiceItem(item);
      if (!itemValidation.isValid) {
        errors.addAll(itemValidation.errors);
      }
    }

    // Validate amounts
    if (invoice.total <= BigInt.zero) {
      errors.add('Invoice total must be greater than zero');
    }

    if (invoice.paidAmount < BigInt.zero) {
      errors.add('Paid amount cannot be negative');
    }

    if (invoice.paidAmount > invoice.total) {
      errors.add('Paid amount cannot exceed total');
    }

    // Validate dates
    if (invoice.createdAt.isAfter(invoice.updatedAt)) {
      errors.add('Created date cannot be after updated date');
    }

    if (invoice.dueDate.isBefore(invoice.createdAt)) {
      errors.add('Due date cannot be before created date');
    }

    // Validate payment terms
    if (invoice.acceptedTokens.isEmpty) {
      errors.add('At least one accepted token is required');
    }

    if (invoice.acceptedChains.isEmpty) {
      errors.add('At least one accepted chain is required');
    }

    // Validate split payments
    if (invoice.hasSplitPayment) {
      final splitValidation = validatePaymentSplits(invoice.paymentSplits ?? []);
      if (!splitValidation.isValid) {
        errors.addAll(splitValidation.errors);
      }
    }

    // Validate recurring config
    if (invoice.isRecurring && invoice.recurringConfig == null) {
      errors.add('Recurring config is required for recurring invoices');
    }

    if (invoice.recurringConfig != null) {
      final recurringValidation = validateRecurringConfig(invoice.recurringConfig!);
      if (!recurringValidation.isValid) {
        errors.addAll(recurringValidation.errors);
      }
    }

    // Validate factoring config
    if (invoice.isFactored && invoice.factoringConfig == null) {
      errors.add('Factoring config is required for factored invoices');
    }

    if (invoice.factoringConfig != null) {
      final factoringValidation = validateFactoringConfig(invoice.factoringConfig!);
      if (!factoringValidation.isValid) {
        errors.addAll(factoringValidation.errors);
      }
    }

    // Validate escrow
    if (invoice.useEscrow && invoice.escrowAddress == null) {
      errors.add('Escrow address is required when using escrow');
    }

    return ValidationResult(errors);
  }

  /// Validate invoice item
  static ValidationResult validateInvoiceItem(InvoiceItem item) {
    final errors = <String>[];

    if (item.description.isEmpty) {
      errors.add('Item description is required');
    }

    if (item.quantity <= 0) {
      errors.add('Item quantity must be greater than zero');
    }

    if (item.unitPrice < BigInt.zero) {
      errors.add('Item unit price cannot be negative');
    }

    if (item.total < BigInt.zero) {
      errors.add('Item total cannot be negative');
    }

    if (item.taxRate != null && (item.taxRate! < 0 || item.taxRate! > 100)) {
      errors.add('Tax rate must be between 0 and 100');
    }

    if (item.discountPercentage != null && (item.discountPercentage! < 0 || item.discountPercentage! > 100)) {
      errors.add('Discount percentage must be between 0 and 100');
    }

    return ValidationResult(errors);
  }

  /// Validate payment
  static ValidationResult validatePayment(Payment payment) {
    final errors = <String>[];

    if (payment.txHash.isEmpty) {
      errors.add('Transaction hash is required');
    }

    if (payment.from.isEmpty) {
      errors.add('Payer address is required');
    }

    if (payment.to.isEmpty) {
      errors.add('Recipient address is required');
    }

    if (payment.amount <= BigInt.zero) {
      errors.add('Payment amount must be greater than zero');
    }

    if (payment.token.isEmpty) {
      errors.add('Token address is required');
    }

    if (payment.chainId <= 0) {
      errors.add('Invalid chain ID');
    }

    return ValidationResult(errors);
  }

  /// Validate payment splits
  static ValidationResult validatePaymentSplits(List<PaymentSplit> splits) {
    final errors = <String>[];

    if (splits.isEmpty) {
      errors.add('At least one payment split is required');
    }

    // Check total percentage
    double totalPercentage = 0;
    int primaryCount = 0;

    for (final split in splits) {
      if (split.address.isEmpty) {
        errors.add('Split address is required');
      }

      if (split.fixedAmount == null) {
        if (split.percentage <= 0 || split.percentage > 100) {
          errors.add('Split percentage must be between 0 and 100');
        }
        totalPercentage += split.percentage;
      }

      if (split.isPrimary) {
        primaryCount++;
      }
    }

    // If using percentages, total should be 100
    if (totalPercentage > 0 && (totalPercentage < 99.9 || totalPercentage > 100.1)) {
      errors.add('Total split percentage must equal 100% (got ${totalPercentage.toStringAsFixed(1)}%)');
    }

    // Should have exactly one primary recipient
    if (primaryCount != 1) {
      errors.add('Exactly one payment split must be marked as primary');
    }

    return ValidationResult(errors);
  }

  /// Validate recurring config
  static ValidationResult validateRecurringConfig(RecurringConfig config) {
    final errors = <String>[];

    if (config.endDate != null && config.endDate!.isBefore(config.startDate)) {
      errors.add('Recurring end date cannot be before start date');
    }

    if (config.maxOccurrences != null && config.maxOccurrences! <= 0) {
      errors.add('Max occurrences must be greater than zero');
    }

    if (config.currentOccurrence < 0) {
      errors.add('Current occurrence cannot be negative');
    }

    if (config.daysBeforeDue < 0) {
      errors.add('Days before due cannot be negative');
    }

    return ValidationResult(errors);
  }

  /// Validate factoring config
  static ValidationResult validateFactoringConfig(FactoringConfig config) {
    final errors = <String>[];

    if (config.discountRate < 0 || config.discountRate > 100) {
      errors.add('Discount rate must be between 0 and 100');
    }

    if (config.minPrice < BigInt.zero) {
      errors.add('Minimum price cannot be negative');
    }

    if (config.platformFeePercentage != null &&
        (config.platformFeePercentage! < 0 || config.platformFeePercentage! > 100)) {
      errors.add('Platform fee percentage must be between 0 and 100');
    }

    return ValidationResult(errors);
  }

  /// Validate address format
  static bool isValidAddress(String address) {
    // Basic Ethereum address validation
    final ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return ethAddressRegex.hasMatch(address);
  }

  /// Validate transaction hash
  static bool isValidTxHash(String txHash) {
    // Basic transaction hash validation
    final txHashRegex = RegExp(r'^0x[a-fA-F0-9]{64}$');
    return txHashRegex.hasMatch(txHash);
  }

  /// Validate IPFS CID
  static bool isValidIPFSCid(String cid) {
    // Basic IPFS CID validation (v0 and v1)
    if (cid.startsWith('Qm') && cid.length == 46) {
      return true; // CIDv0
    }
    if (cid.startsWith('bafy') || cid.startsWith('bafk')) {
      return true; // CIDv1
    }
    return false;
  }

  /// Validate Arweave transaction ID
  static bool isValidArweaveTxId(String txId) {
    // Arweave transaction IDs are 43 characters, alphanumeric + - and _
    final arweaveRegex = RegExp(r'^[a-zA-Z0-9_-]{43}$');
    return arweaveRegex.hasMatch(txId);
  }
}

/// Validation result
class ValidationResult {
  final List<String> errors;

  ValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String get errorMessage => errors.join(', ');

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $errorMessage';
}
