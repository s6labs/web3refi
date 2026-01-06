import 'invoice_status.dart';

/// Configuration for invoice system
class InvoiceConfig {
  /// Default storage backend
  final InvoiceStorageBackend defaultStorageBackend;

  /// IPFS gateway URL (if using IPFS)
  final String? ipfsGateway;

  /// IPFS API URL
  final String? ipfsApiUrl;

  /// Arweave gateway URL (if using Arweave)
  final String? arweaveGateway;

  /// Arweave API URL
  final String? arweaveApiUrl;

  /// Arweave wallet key (JSON string)
  final String? arweaveWalletKey;

  /// Default delivery method
  final InvoiceDeliveryMethod defaultDeliveryMethod;

  /// Enable auto-send for invoices
  final bool autoSend;

  /// Enable payment reminders
  final bool enableReminders;

  /// Days before due date to send reminder
  final int reminderDaysBefore;

  /// Days after overdue to send reminder
  final List<int> overdueReminderDays;

  /// Default tax rate (percentage)
  final double? defaultTaxRate;

  /// Default payment terms
  final String defaultPaymentTerms;

  /// Default due days (days from creation)
  final int defaultDueDays;

  /// Enable invoice numbering
  final bool enableInvoiceNumbering;

  /// Invoice number prefix
  final String invoiceNumberPrefix;

  /// Starting invoice number
  final int startingInvoiceNumber;

  /// Enable late fees
  final bool enableLateFees;

  /// Default late fee percentage
  final double? defaultLateFeePercentage;

  /// Grace period before late fees apply (days)
  final int lateFeeGracePeriod;

  /// Enable escrow by default
  final bool defaultUseEscrow;

  /// Escrow factory contract address
  final String? escrowFactoryAddress;

  /// Invoice registry contract address
  final String? registryAddress;

  /// Enable factoring
  final bool enableFactoring;

  /// Default factoring discount rate
  final double? defaultFactoringRate;

  /// Platform fee for factoring (percentage)
  final double? factoringPlatformFee;

  /// Brand logo URL
  final String? defaultLogoUrl;

  /// Brand color
  final String? defaultBrandColor;

  /// Footer text for invoices
  final String? defaultFooterText;

  const InvoiceConfig({
    this.defaultStorageBackend = InvoiceStorageBackend.ipfsWithLocal,
    this.ipfsGateway = 'https://ipfs.io/ipfs/',
    this.ipfsApiUrl = 'https://ipfs.infura.io:5001/api/v0',
    this.arweaveGateway = 'https://arweave.net/',
    this.arweaveApiUrl = 'https://arweave.net',
    this.arweaveWalletKey,
    this.defaultDeliveryMethod = InvoiceDeliveryMethod.both,
    this.autoSend = false,
    this.enableReminders = true,
    this.reminderDaysBefore = 3,
    this.overdueReminderDays = const [1, 7, 14, 30],
    this.defaultTaxRate,
    this.defaultPaymentTerms = 'Net 30',
    this.defaultDueDays = 30,
    this.enableInvoiceNumbering = true,
    this.invoiceNumberPrefix = 'INV',
    this.startingInvoiceNumber = 1,
    this.enableLateFees = false,
    this.defaultLateFeePercentage,
    this.lateFeeGracePeriod = 0,
    this.defaultUseEscrow = false,
    this.escrowFactoryAddress,
    this.registryAddress,
    this.enableFactoring = false,
    this.defaultFactoringRate,
    this.factoringPlatformFee,
    this.defaultLogoUrl,
    this.defaultBrandColor,
    this.defaultFooterText,
  });

  InvoiceConfig copyWith({
    InvoiceStorageBackend? defaultStorageBackend,
    String? ipfsGateway,
    String? ipfsApiUrl,
    String? arweaveGateway,
    String? arweaveApiUrl,
    String? arweaveWalletKey,
    InvoiceDeliveryMethod? defaultDeliveryMethod,
    bool? autoSend,
    bool? enableReminders,
    int? reminderDaysBefore,
    List<int>? overdueReminderDays,
    double? defaultTaxRate,
    String? defaultPaymentTerms,
    int? defaultDueDays,
    bool? enableInvoiceNumbering,
    String? invoiceNumberPrefix,
    int? startingInvoiceNumber,
    bool? enableLateFees,
    double? defaultLateFeePercentage,
    int? lateFeeGracePeriod,
    bool? defaultUseEscrow,
    String? escrowFactoryAddress,
    String? registryAddress,
    bool? enableFactoring,
    double? defaultFactoringRate,
    double? factoringPlatformFee,
    String? defaultLogoUrl,
    String? defaultBrandColor,
    String? defaultFooterText,
  }) {
    return InvoiceConfig(
      defaultStorageBackend: defaultStorageBackend ?? this.defaultStorageBackend,
      ipfsGateway: ipfsGateway ?? this.ipfsGateway,
      ipfsApiUrl: ipfsApiUrl ?? this.ipfsApiUrl,
      arweaveGateway: arweaveGateway ?? this.arweaveGateway,
      arweaveApiUrl: arweaveApiUrl ?? this.arweaveApiUrl,
      arweaveWalletKey: arweaveWalletKey ?? this.arweaveWalletKey,
      defaultDeliveryMethod: defaultDeliveryMethod ?? this.defaultDeliveryMethod,
      autoSend: autoSend ?? this.autoSend,
      enableReminders: enableReminders ?? this.enableReminders,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      overdueReminderDays: overdueReminderDays ?? this.overdueReminderDays,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      defaultDueDays: defaultDueDays ?? this.defaultDueDays,
      enableInvoiceNumbering: enableInvoiceNumbering ?? this.enableInvoiceNumbering,
      invoiceNumberPrefix: invoiceNumberPrefix ?? this.invoiceNumberPrefix,
      startingInvoiceNumber: startingInvoiceNumber ?? this.startingInvoiceNumber,
      enableLateFees: enableLateFees ?? this.enableLateFees,
      defaultLateFeePercentage: defaultLateFeePercentage ?? this.defaultLateFeePercentage,
      lateFeeGracePeriod: lateFeeGracePeriod ?? this.lateFeeGracePeriod,
      defaultUseEscrow: defaultUseEscrow ?? this.defaultUseEscrow,
      escrowFactoryAddress: escrowFactoryAddress ?? this.escrowFactoryAddress,
      registryAddress: registryAddress ?? this.registryAddress,
      enableFactoring: enableFactoring ?? this.enableFactoring,
      defaultFactoringRate: defaultFactoringRate ?? this.defaultFactoringRate,
      factoringPlatformFee: factoringPlatformFee ?? this.factoringPlatformFee,
      defaultLogoUrl: defaultLogoUrl ?? this.defaultLogoUrl,
      defaultBrandColor: defaultBrandColor ?? this.defaultBrandColor,
      defaultFooterText: defaultFooterText ?? this.defaultFooterText,
    );
  }
}
