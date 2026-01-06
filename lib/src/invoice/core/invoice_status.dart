/// Invoice status states
enum InvoiceStatus {
  /// Invoice created but not sent
  draft,

  /// Invoice sent to recipient
  sent,

  /// Recipient has viewed the invoice
  viewed,

  /// Awaiting payment (sent but not paid)
  pending,

  /// Partial payment received
  partiallyPaid,

  /// Fully paid
  paid,

  /// Past due date without payment
  overdue,

  /// Cancelled by sender
  cancelled,

  /// Under dispute
  disputed,

  /// Payment refunded
  refunded,

  /// Recurring invoice template
  template,
}

extension InvoiceStatusExtension on InvoiceStatus {
  /// Display name for UI
  String get displayName {
    switch (this) {
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.viewed:
        return 'Viewed';
      case InvoiceStatus.pending:
        return 'Pending';
      case InvoiceStatus.partiallyPaid:
        return 'Partially Paid';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.disputed:
        return 'Disputed';
      case InvoiceStatus.refunded:
        return 'Refunded';
      case InvoiceStatus.template:
        return 'Template';
    }
  }

  /// Whether invoice is payable
  bool get isPayable {
    return this == InvoiceStatus.sent ||
        this == InvoiceStatus.viewed ||
        this == InvoiceStatus.pending ||
        this == InvoiceStatus.partiallyPaid ||
        this == InvoiceStatus.overdue;
  }

  /// Whether invoice is finalized
  bool get isFinalized {
    return this == InvoiceStatus.paid ||
        this == InvoiceStatus.cancelled ||
        this == InvoiceStatus.refunded;
  }

  /// Whether invoice needs attention
  bool get needsAttention {
    return this == InvoiceStatus.overdue || this == InvoiceStatus.disputed;
  }
}

/// Payment status
enum PaymentStatus {
  /// Payment initiated
  pending,

  /// Payment confirmed on-chain
  confirmed,

  /// Payment failed
  failed,

  /// Payment refunded
  refunded,
}

/// Delivery method for invoices
enum InvoiceDeliveryMethod {
  /// Send via XMTP only
  xmtp,

  /// Send via Mailchain only
  mailchain,

  /// Send via both XMTP and Mailchain
  both,

  /// Store locally only (no delivery)
  local,
}

/// Storage backend for invoice data
enum InvoiceStorageBackend {
  /// Store on IPFS
  ipfs,

  /// Store on Arweave
  arweave,

  /// Store locally only
  local,

  /// Store on IPFS + local backup
  ipfsWithLocal,

  /// Store on Arweave + local backup
  arweaveWithLocal,
}

/// Recurring invoice frequency
enum RecurringFrequency {
  /// Every day
  daily,

  /// Every week
  weekly,

  /// Every 2 weeks
  biweekly,

  /// Every month
  monthly,

  /// Every quarter (3 months)
  quarterly,

  /// Every 6 months
  semiannually,

  /// Every year
  annually,

  /// Custom interval
  custom,
}

extension RecurringFrequencyExtension on RecurringFrequency {
  /// Get duration for frequency
  Duration get duration {
    switch (this) {
      case RecurringFrequency.daily:
        return const Duration(days: 1);
      case RecurringFrequency.weekly:
        return const Duration(days: 7);
      case RecurringFrequency.biweekly:
        return const Duration(days: 14);
      case RecurringFrequency.monthly:
        return const Duration(days: 30);
      case RecurringFrequency.quarterly:
        return const Duration(days: 90);
      case RecurringFrequency.semiannually:
        return const Duration(days: 180);
      case RecurringFrequency.annually:
        return const Duration(days: 365);
      case RecurringFrequency.custom:
        return Duration.zero; // Must be specified
    }
  }

  String get displayName {
    switch (this) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Bi-weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.semiannually:
        return 'Semi-annually';
      case RecurringFrequency.annually:
        return 'Annually';
      case RecurringFrequency.custom:
        return 'Custom';
    }
  }
}
