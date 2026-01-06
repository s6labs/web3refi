import 'package:equatable/equatable.dart';
import 'package:web3refi/src/invoice/core/invoice_item.dart';
import 'package:web3refi/src/invoice/core/payment_info.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';

/// Complete invoice model with all features
class Invoice extends Equatable {
  // ═══════════════════════════════════════════════════════════════════════
  // IDENTITY
  // ═══════════════════════════════════════════════════════════════════════

  /// Unique invoice identifier (UUID)
  final String id;

  /// Human-readable invoice number (INV-2026-001)
  final String number;

  /// When invoice was created
  final DateTime createdAt;

  /// When invoice was last updated
  final DateTime updatedAt;

  // ═══════════════════════════════════════════════════════════════════════
  // PARTIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Sender/seller wallet address
  final String from;

  /// Sender name (resolved via UNS or manually set)
  final String? fromName;

  /// Sender company/business name
  final String? fromCompany;

  /// Sender email
  final String? fromEmail;

  /// Recipient/buyer wallet address
  final String to;

  /// Recipient name (resolved via UNS or manually set)
  final String? toName;

  /// Recipient company/business name
  final String? toCompany;

  /// Recipient email
  final String? toEmail;

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE DETAILS
  // ═══════════════════════════════════════════════════════════════════════

  /// Invoice title/subject
  final String title;

  /// Optional description
  final String? description;

  /// Line items
  final List<InvoiceItem> items;

  /// Currency/token for payment (symbol: USDC, ETH, DAI, etc.)
  final String currency;

  /// Token contract address (or 'ETH' for native token)
  final String tokenAddress;

  /// Chain ID for payment
  final int chainId;

  // ═══════════════════════════════════════════════════════════════════════
  // AMOUNTS
  // ═══════════════════════════════════════════════════════════════════════

  /// Subtotal (before tax and discounts)
  final BigInt subtotal;

  /// Tax amount
  final BigInt taxAmount;

  /// Tax rate (percentage)
  final double? taxRate;

  /// Discount amount
  final BigInt? discount;

  /// Discount percentage
  final double? discountPercentage;

  /// Shipping/delivery cost
  final BigInt? shippingCost;

  /// Final total amount due
  final BigInt total;

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT TERMS
  // ═══════════════════════════════════════════════════════════════════════

  /// When payment is due
  final DateTime dueDate;

  /// Payment terms (Net 30, Due on receipt, etc.)
  final String? paymentTerms;

  /// Accepted tokens for payment
  final List<String> acceptedTokens;

  /// Accepted chains for payment
  final List<int> acceptedChains;

  /// Late fee percentage (if overdue)
  final double? lateFeePercentage;

  /// Late fee amount
  final BigInt? lateFeeAmount;

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS & PAYMENTS
  // ═══════════════════════════════════════════════════════════════════════

  /// Current invoice status
  final InvoiceStatus status;

  /// Payment history
  final List<Payment> payments;

  /// Total amount paid so far
  final BigInt paidAmount;

  /// Remaining amount owed
  final BigInt remainingAmount;

  /// When invoice was sent
  final DateTime? sentAt;

  /// When invoice was first viewed
  final DateTime? viewedAt;

  /// When invoice was fully paid
  final DateTime? paidAt;

  // ═══════════════════════════════════════════════════════════════════════
  // STORAGE & DELIVERY
  // ═══════════════════════════════════════════════════════════════════════

  /// Storage backend used
  final InvoiceStorageBackend storageBackend;

  /// IPFS CID (if stored on IPFS)
  final String? ipfsCid;

  /// Arweave transaction ID (if stored on Arweave)
  final String? arweaveTxId;

  /// How invoice was delivered
  final InvoiceDeliveryMethod? deliveryMethod;

  /// XMTP message ID (if sent via XMTP)
  final String? xmtpMessageId;

  /// Mailchain message ID (if sent via Mailchain)
  final String? mailchainMessageId;

  // ═══════════════════════════════════════════════════════════════════════
  // SPLIT PAYMENTS (Multi-Recipient)
  // ═══════════════════════════════════════════════════════════════════════

  /// Whether this invoice has split payments
  final bool hasSplitPayment;

  /// Payment split configuration
  final List<PaymentSplit>? paymentSplits;

  // ═══════════════════════════════════════════════════════════════════════
  // SMART CONTRACT ESCROW
  // ═══════════════════════════════════════════════════════════════════════

  /// Whether to use smart contract escrow
  final bool useEscrow;

  /// Escrow contract address (if using escrow)
  final String? escrowAddress;

  /// Whether escrow funds have been released
  final bool escrowReleased;

  /// On-chain invoice ID (if registered on-chain)
  final String? onChainId;

  // ═══════════════════════════════════════════════════════════════════════
  // RECURRING INVOICES (Subscriptions)
  // ═══════════════════════════════════════════════════════════════════════

  /// Whether this is a recurring invoice
  final bool isRecurring;

  /// Recurring configuration
  final RecurringConfig? recurringConfig;

  /// Parent recurring template ID (if generated from template)
  final String? recurringTemplateId;

  /// Next occurrence date (for recurring invoices)
  final DateTime? nextOccurrence;

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE FACTORING
  // ═══════════════════════════════════════════════════════════════════════

  /// Whether invoice is factored (sold to investor)
  final bool isFactored;

  /// Factoring configuration
  final FactoringConfig? factoringConfig;

  /// Current factor owner (if factored)
  final String? factorOwner;

  /// Factoring price paid
  final BigInt? factoringPrice;

  // ═══════════════════════════════════════════════════════════════════════
  // DISPUTES
  // ═══════════════════════════════════════════════════════════════════════

  /// Whether invoice is under dispute
  final bool isDisputed;

  /// Dispute reason
  final String? disputeReason;

  /// Who raised the dispute
  final String? disputedBy;

  /// When dispute was raised
  final DateTime? disputedAt;

  /// Dispute resolution notes
  final String? disputeResolution;

  // ═══════════════════════════════════════════════════════════════════════
  // ATTACHMENTS & METADATA
  // ═══════════════════════════════════════════════════════════════════════

  /// Additional notes
  final String? notes;

  /// Attached files (URLs or IPFS CIDs)
  final List<String>? attachments;

  /// Purchase order number
  final String? poNumber;

  /// Reference/order number
  final String? referenceNumber;

  /// Custom metadata
  final Map<String, dynamic>? metadata;

  // ═══════════════════════════════════════════════════════════════════════
  // BRANDING
  // ═══════════════════════════════════════════════════════════════════════

  /// Logo URL or IPFS CID
  final String? logoUrl;

  /// Brand color
  final String? brandColor;

  /// Custom footer text
  final String? footerText;

  const Invoice({
    required this.id,
    required this.number,
    required this.createdAt,
    required this.updatedAt,
    required this.from,
    required this.to, required this.title, required this.items, required this.currency, required this.tokenAddress, required this.chainId, required this.subtotal, required this.taxAmount, required this.total, required this.dueDate, required this.acceptedTokens, required this.acceptedChains, required this.status, required this.paidAmount, required this.remainingAmount, this.fromName,
    this.fromCompany,
    this.fromEmail,
    this.toName,
    this.toCompany,
    this.toEmail,
    this.description,
    this.taxRate,
    this.discount,
    this.discountPercentage,
    this.shippingCost,
    this.paymentTerms,
    this.lateFeePercentage,
    this.lateFeeAmount,
    this.payments = const [],
    this.sentAt,
    this.viewedAt,
    this.paidAt,
    this.storageBackend = InvoiceStorageBackend.local,
    this.ipfsCid,
    this.arweaveTxId,
    this.deliveryMethod,
    this.xmtpMessageId,
    this.mailchainMessageId,
    this.hasSplitPayment = false,
    this.paymentSplits,
    this.useEscrow = false,
    this.escrowAddress,
    this.escrowReleased = false,
    this.onChainId,
    this.isRecurring = false,
    this.recurringConfig,
    this.recurringTemplateId,
    this.nextOccurrence,
    this.isFactored = false,
    this.factoringConfig,
    this.factorOwner,
    this.factoringPrice,
    this.isDisputed = false,
    this.disputeReason,
    this.disputedBy,
    this.disputedAt,
    this.disputeResolution,
    this.notes,
    this.attachments,
    this.poNumber,
    this.referenceNumber,
    this.metadata,
    this.logoUrl,
    this.brandColor,
    this.footerText,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Issue date (alias for createdAt for compatibility)
  DateTime get issueDate => createdAt;

  /// Whether invoice is fully paid
  bool get isPaid => status == InvoiceStatus.paid;

  /// Whether invoice is overdue
  bool get isOverdue => status == InvoiceStatus.overdue || (DateTime.now().isAfter(dueDate) && !isPaid);

  /// Whether invoice can be paid
  bool get isPayable => status.isPayable && remainingAmount > BigInt.zero;

  /// Whether invoice is a draft
  bool get isDraft => status == InvoiceStatus.draft;

  /// Days until due (negative if overdue)
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;

  /// Days overdue (0 if not overdue)
  int get daysOverdue => isOverdue ? DateTime.now().difference(dueDate).inDays : 0;

  /// Payment progress (0.0 to 1.0)
  double get paymentProgress {
    if (total == BigInt.zero) return 0.0;
    return paidAmount.toDouble() / total.toDouble();
  }

  /// Whether invoice has any payments
  bool get hasPayments => payments.isNotEmpty;

  /// Latest payment
  Payment? get latestPayment => payments.isEmpty ? null : payments.last;

  /// Total with late fee (if applicable)
  BigInt get totalWithLateFee {
    if (!isOverdue || (lateFeePercentage == null && lateFeeAmount == null)) {
      return total;
    }

    if (lateFeeAmount != null) {
      return total + lateFeeAmount!;
    }

    if (lateFeePercentage != null) {
      final fee = (total.toDouble() * lateFeePercentage! / 100.0).round();
      return total + BigInt.from(fee);
    }

    return total;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // METHODS
  // ═══════════════════════════════════════════════════════════════════════

  /// Copy with modifications
  Invoice copyWith({
    String? id,
    String? number,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? from,
    String? fromName,
    String? fromCompany,
    String? fromEmail,
    String? to,
    String? toName,
    String? toCompany,
    String? toEmail,
    String? title,
    String? description,
    List<InvoiceItem>? items,
    String? currency,
    String? tokenAddress,
    int? chainId,
    BigInt? subtotal,
    BigInt? taxAmount,
    double? taxRate,
    BigInt? discount,
    double? discountPercentage,
    BigInt? shippingCost,
    BigInt? total,
    DateTime? dueDate,
    String? paymentTerms,
    List<String>? acceptedTokens,
    List<int>? acceptedChains,
    double? lateFeePercentage,
    BigInt? lateFeeAmount,
    InvoiceStatus? status,
    List<Payment>? payments,
    BigInt? paidAmount,
    BigInt? remainingAmount,
    DateTime? sentAt,
    DateTime? viewedAt,
    DateTime? paidAt,
    InvoiceStorageBackend? storageBackend,
    String? ipfsCid,
    String? arweaveTxId,
    InvoiceDeliveryMethod? deliveryMethod,
    String? xmtpMessageId,
    String? mailchainMessageId,
    bool? hasSplitPayment,
    List<PaymentSplit>? paymentSplits,
    bool? useEscrow,
    String? escrowAddress,
    bool? escrowReleased,
    String? onChainId,
    bool? isRecurring,
    RecurringConfig? recurringConfig,
    String? recurringTemplateId,
    DateTime? nextOccurrence,
    bool? isFactored,
    FactoringConfig? factoringConfig,
    String? factorOwner,
    BigInt? factoringPrice,
    bool? isDisputed,
    String? disputeReason,
    String? disputedBy,
    DateTime? disputedAt,
    String? disputeResolution,
    String? notes,
    List<String>? attachments,
    String? poNumber,
    String? referenceNumber,
    Map<String, dynamic>? metadata,
    String? logoUrl,
    String? brandColor,
    String? footerText,
  }) {
    return Invoice(
      id: id ?? this.id,
      number: number ?? this.number,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      from: from ?? this.from,
      fromName: fromName ?? this.fromName,
      fromCompany: fromCompany ?? this.fromCompany,
      fromEmail: fromEmail ?? this.fromEmail,
      to: to ?? this.to,
      toName: toName ?? this.toName,
      toCompany: toCompany ?? this.toCompany,
      toEmail: toEmail ?? this.toEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      items: items ?? this.items,
      currency: currency ?? this.currency,
      tokenAddress: tokenAddress ?? this.tokenAddress,
      chainId: chainId ?? this.chainId,
      subtotal: subtotal ?? this.subtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      taxRate: taxRate ?? this.taxRate,
      discount: discount ?? this.discount,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      shippingCost: shippingCost ?? this.shippingCost,
      total: total ?? this.total,
      dueDate: dueDate ?? this.dueDate,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      acceptedTokens: acceptedTokens ?? this.acceptedTokens,
      acceptedChains: acceptedChains ?? this.acceptedChains,
      lateFeePercentage: lateFeePercentage ?? this.lateFeePercentage,
      lateFeeAmount: lateFeeAmount ?? this.lateFeeAmount,
      status: status ?? this.status,
      payments: payments ?? this.payments,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      sentAt: sentAt ?? this.sentAt,
      viewedAt: viewedAt ?? this.viewedAt,
      paidAt: paidAt ?? this.paidAt,
      storageBackend: storageBackend ?? this.storageBackend,
      ipfsCid: ipfsCid ?? this.ipfsCid,
      arweaveTxId: arweaveTxId ?? this.arweaveTxId,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      xmtpMessageId: xmtpMessageId ?? this.xmtpMessageId,
      mailchainMessageId: mailchainMessageId ?? this.mailchainMessageId,
      hasSplitPayment: hasSplitPayment ?? this.hasSplitPayment,
      paymentSplits: paymentSplits ?? this.paymentSplits,
      useEscrow: useEscrow ?? this.useEscrow,
      escrowAddress: escrowAddress ?? this.escrowAddress,
      escrowReleased: escrowReleased ?? this.escrowReleased,
      onChainId: onChainId ?? this.onChainId,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringConfig: recurringConfig ?? this.recurringConfig,
      recurringTemplateId: recurringTemplateId ?? this.recurringTemplateId,
      nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      isFactored: isFactored ?? this.isFactored,
      factoringConfig: factoringConfig ?? this.factoringConfig,
      factorOwner: factorOwner ?? this.factorOwner,
      factoringPrice: factoringPrice ?? this.factoringPrice,
      isDisputed: isDisputed ?? this.isDisputed,
      disputeReason: disputeReason ?? this.disputeReason,
      disputedBy: disputedBy ?? this.disputedBy,
      disputedAt: disputedAt ?? this.disputedAt,
      disputeResolution: disputeResolution ?? this.disputeResolution,
      notes: notes ?? this.notes,
      attachments: attachments ?? this.attachments,
      poNumber: poNumber ?? this.poNumber,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      metadata: metadata ?? this.metadata,
      logoUrl: logoUrl ?? this.logoUrl,
      brandColor: brandColor ?? this.brandColor,
      footerText: footerText ?? this.footerText,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'from': from,
      if (fromName != null) 'fromName': fromName,
      if (fromCompany != null) 'fromCompany': fromCompany,
      if (fromEmail != null) 'fromEmail': fromEmail,
      'to': to,
      if (toName != null) 'toName': toName,
      if (toCompany != null) 'toCompany': toCompany,
      if (toEmail != null) 'toEmail': toEmail,
      'title': title,
      if (description != null) 'description': description,
      'items': items.map((item) => item.toJson()).toList(),
      'currency': currency,
      'tokenAddress': tokenAddress,
      'chainId': chainId,
      'subtotal': subtotal.toString(),
      'taxAmount': taxAmount.toString(),
      if (taxRate != null) 'taxRate': taxRate,
      if (discount != null) 'discount': discount.toString(),
      if (discountPercentage != null) 'discountPercentage': discountPercentage,
      if (shippingCost != null) 'shippingCost': shippingCost.toString(),
      'total': total.toString(),
      'dueDate': dueDate.toIso8601String(),
      if (paymentTerms != null) 'paymentTerms': paymentTerms,
      'acceptedTokens': acceptedTokens,
      'acceptedChains': acceptedChains,
      if (lateFeePercentage != null) 'lateFeePercentage': lateFeePercentage,
      if (lateFeeAmount != null) 'lateFeeAmount': lateFeeAmount.toString(),
      'status': status.name,
      'payments': payments.map((p) => p.toJson()).toList(),
      'paidAmount': paidAmount.toString(),
      'remainingAmount': remainingAmount.toString(),
      if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
      if (viewedAt != null) 'viewedAt': viewedAt!.toIso8601String(),
      if (paidAt != null) 'paidAt': paidAt!.toIso8601String(),
      'storageBackend': storageBackend.name,
      if (ipfsCid != null) 'ipfsCid': ipfsCid,
      if (arweaveTxId != null) 'arweaveTxId': arweaveTxId,
      if (deliveryMethod != null) 'deliveryMethod': deliveryMethod!.name,
      if (xmtpMessageId != null) 'xmtpMessageId': xmtpMessageId,
      if (mailchainMessageId != null) 'mailchainMessageId': mailchainMessageId,
      'hasSplitPayment': hasSplitPayment,
      if (paymentSplits != null) 'paymentSplits': paymentSplits!.map((s) => s.toJson()).toList(),
      'useEscrow': useEscrow,
      if (escrowAddress != null) 'escrowAddress': escrowAddress,
      'escrowReleased': escrowReleased,
      if (onChainId != null) 'onChainId': onChainId,
      'isRecurring': isRecurring,
      if (recurringConfig != null) 'recurringConfig': recurringConfig!.toJson(),
      if (recurringTemplateId != null) 'recurringTemplateId': recurringTemplateId,
      if (nextOccurrence != null) 'nextOccurrence': nextOccurrence!.toIso8601String(),
      'isFactored': isFactored,
      if (factoringConfig != null) 'factoringConfig': factoringConfig!.toJson(),
      if (factorOwner != null) 'factorOwner': factorOwner,
      if (factoringPrice != null) 'factoringPrice': factoringPrice.toString(),
      'isDisputed': isDisputed,
      if (disputeReason != null) 'disputeReason': disputeReason,
      if (disputedBy != null) 'disputedBy': disputedBy,
      if (disputedAt != null) 'disputedAt': disputedAt!.toIso8601String(),
      if (disputeResolution != null) 'disputeResolution': disputeResolution,
      if (notes != null) 'notes': notes,
      if (attachments != null) 'attachments': attachments,
      if (poNumber != null) 'poNumber': poNumber,
      if (referenceNumber != null) 'referenceNumber': referenceNumber,
      if (metadata != null) 'metadata': metadata,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (brandColor != null) 'brandColor': brandColor,
      if (footerText != null) 'footerText': footerText,
    };
  }

  /// Create from JSON
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      number: json['number'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      from: json['from'] as String,
      fromName: json['fromName'] as String?,
      fromCompany: json['fromCompany'] as String?,
      fromEmail: json['fromEmail'] as String?,
      to: json['to'] as String,
      toName: json['toName'] as String?,
      toCompany: json['toCompany'] as String?,
      toEmail: json['toEmail'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      items: (json['items'] as List).map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>)).toList(),
      currency: json['currency'] as String,
      tokenAddress: json['tokenAddress'] as String,
      chainId: json['chainId'] as int,
      subtotal: BigInt.parse(json['subtotal'] as String),
      taxAmount: BigInt.parse(json['taxAmount'] as String),
      taxRate: json['taxRate'] as double?,
      discount: json['discount'] != null ? BigInt.parse(json['discount'] as String) : null,
      discountPercentage: json['discountPercentage'] as double?,
      shippingCost: json['shippingCost'] != null ? BigInt.parse(json['shippingCost'] as String) : null,
      total: BigInt.parse(json['total'] as String),
      dueDate: DateTime.parse(json['dueDate'] as String),
      paymentTerms: json['paymentTerms'] as String?,
      acceptedTokens: List<String>.from(json['acceptedTokens'] as List),
      acceptedChains: List<int>.from(json['acceptedChains'] as List),
      lateFeePercentage: json['lateFeePercentage'] as double?,
      lateFeeAmount: json['lateFeeAmount'] != null ? BigInt.parse(json['lateFeeAmount'] as String) : null,
      status: InvoiceStatus.values.firstWhere((e) => e.name == json['status']),
      payments: (json['payments'] as List? ?? []).map((p) => Payment.fromJson(p as Map<String, dynamic>)).toList(),
      paidAmount: BigInt.parse(json['paidAmount'] as String),
      remainingAmount: BigInt.parse(json['remainingAmount'] as String),
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt'] as String) : null,
      viewedAt: json['viewedAt'] != null ? DateTime.parse(json['viewedAt'] as String) : null,
      paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt'] as String) : null,
      storageBackend: InvoiceStorageBackend.values.firstWhere(
        (e) => e.name == json['storageBackend'],
        orElse: () => InvoiceStorageBackend.local,
      ),
      ipfsCid: json['ipfsCid'] as String?,
      arweaveTxId: json['arweaveTxId'] as String?,
      deliveryMethod: json['deliveryMethod'] != null
          ? InvoiceDeliveryMethod.values.firstWhere((e) => e.name == json['deliveryMethod'])
          : null,
      xmtpMessageId: json['xmtpMessageId'] as String?,
      mailchainMessageId: json['mailchainMessageId'] as String?,
      hasSplitPayment: json['hasSplitPayment'] as bool? ?? false,
      paymentSplits: json['paymentSplits'] != null
          ? (json['paymentSplits'] as List).map((s) => PaymentSplit.fromJson(s as Map<String, dynamic>)).toList()
          : null,
      useEscrow: json['useEscrow'] as bool? ?? false,
      escrowAddress: json['escrowAddress'] as String?,
      escrowReleased: json['escrowReleased'] as bool? ?? false,
      onChainId: json['onChainId'] as String?,
      isRecurring: json['isRecurring'] as bool? ?? false,
      recurringConfig: json['recurringConfig'] != null
          ? RecurringConfig.fromJson(json['recurringConfig'] as Map<String, dynamic>)
          : null,
      recurringTemplateId: json['recurringTemplateId'] as String?,
      nextOccurrence:
          json['nextOccurrence'] != null ? DateTime.parse(json['nextOccurrence'] as String) : null,
      isFactored: json['isFactored'] as bool? ?? false,
      factoringConfig: json['factoringConfig'] != null
          ? FactoringConfig.fromJson(json['factoringConfig'] as Map<String, dynamic>)
          : null,
      factorOwner: json['factorOwner'] as String?,
      factoringPrice:
          json['factoringPrice'] != null ? BigInt.parse(json['factoringPrice'] as String) : null,
      isDisputed: json['isDisputed'] as bool? ?? false,
      disputeReason: json['disputeReason'] as String?,
      disputedBy: json['disputedBy'] as String?,
      disputedAt: json['disputedAt'] != null ? DateTime.parse(json['disputedAt'] as String) : null,
      disputeResolution: json['disputeResolution'] as String?,
      notes: json['notes'] as String?,
      attachments: json['attachments'] != null ? List<String>.from(json['attachments'] as List) : null,
      poNumber: json['poNumber'] as String?,
      referenceNumber: json['referenceNumber'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      logoUrl: json['logoUrl'] as String?,
      brandColor: json['brandColor'] as String?,
      footerText: json['footerText'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        number,
        createdAt,
        updatedAt,
        from,
        to,
        status,
        total,
        paidAmount,
      ];

  @override
  String toString() {
    return 'Invoice(id: $id, number: $number, from: $from, to: $to, total: $total $currency, status: ${status.name})';
  }
}

/// Recurring invoice configuration
class RecurringConfig extends Equatable {
  /// Billing frequency
  final RecurringFrequency frequency;

  /// Custom interval (if frequency is custom)
  final Duration? customInterval;

  /// Start date for recurring billing
  final DateTime startDate;

  /// End date (null for indefinite)
  final DateTime? endDate;

  /// Maximum number of occurrences (null for indefinite)
  final int? maxOccurrences;

  /// Number of occurrences so far
  final int currentOccurrence;

  /// Whether to auto-send invoices
  final bool autoSend;

  /// Whether to auto-charge (if customer has payment method on file)
  final bool autoCharge;

  /// Days before due date to send
  final int daysBeforeDue;

  const RecurringConfig({
    required this.frequency,
    required this.startDate, this.customInterval,
    this.endDate,
    this.maxOccurrences,
    this.currentOccurrence = 0,
    this.autoSend = true,
    this.autoCharge = false,
    this.daysBeforeDue = 0,
  });

  /// Calculate next occurrence
  DateTime calculateNextOccurrence() {
    final interval = frequency == RecurringFrequency.custom && customInterval != null
        ? customInterval!
        : frequency.duration;

    return startDate.add(interval * (currentOccurrence + 1));
  }

  /// Whether recurring billing is active
  bool get isActive {
    final now = DateTime.now();

    if (now.isBefore(startDate)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    if (maxOccurrences != null && currentOccurrence >= maxOccurrences!) return false;

    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency.name,
      if (customInterval != null) 'customInterval': customInterval!.inMilliseconds,
      'startDate': startDate.toIso8601String(),
      if (endDate != null) 'endDate': endDate!.toIso8601String(),
      if (maxOccurrences != null) 'maxOccurrences': maxOccurrences,
      'currentOccurrence': currentOccurrence,
      'autoSend': autoSend,
      'autoCharge': autoCharge,
      'daysBeforeDue': daysBeforeDue,
    };
  }

  factory RecurringConfig.fromJson(Map<String, dynamic> json) {
    return RecurringConfig(
      frequency: RecurringFrequency.values.firstWhere((e) => e.name == json['frequency']),
      customInterval: json['customInterval'] != null
          ? Duration(milliseconds: json['customInterval'] as int)
          : null,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      maxOccurrences: json['maxOccurrences'] as int?,
      currentOccurrence: json['currentOccurrence'] as int? ?? 0,
      autoSend: json['autoSend'] as bool? ?? true,
      autoCharge: json['autoCharge'] as bool? ?? false,
      daysBeforeDue: json['daysBeforeDue'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        frequency,
        customInterval,
        startDate,
        endDate,
        maxOccurrences,
        currentOccurrence,
        autoSend,
        autoCharge,
        daysBeforeDue,
      ];
}

/// Invoice factoring configuration
class FactoringConfig extends Equatable {
  /// Discount rate for factoring (percentage)
  final double discountRate;

  /// Minimum factor price
  final BigInt minPrice;

  /// Whether factoring is enabled
  final bool enabled;

  /// Allowed factor buyers (null = anyone)
  final List<String>? allowedBuyers;

  /// Platform fee percentage
  final double? platformFeePercentage;

  /// When factoring was enabled
  final DateTime enabledAt;

  /// Factoring listing ID (set when listed for factoring)
  final String? listingId;

  /// When the invoice was listed for factoring
  final DateTime? listedAt;

  /// Address of the buyer who purchased the factored invoice
  final String? buyer;

  /// When the invoice was sold to a factor
  final DateTime? soldAt;

  /// Price paid by the factor to purchase the invoice
  final BigInt? factorPrice;

  const FactoringConfig({
    required this.discountRate,
    required this.minPrice,
    required this.enabledAt,
    this.enabled = true,
    this.allowedBuyers,
    this.platformFeePercentage,
    this.listingId,
    this.listedAt,
    this.buyer,
    this.soldAt,
    this.factorPrice,
  });

  /// Calculate factor price from invoice total
  BigInt calculateFactorPrice(BigInt invoiceTotal) {
    final discounted = invoiceTotal.toDouble() * (1.0 - discountRate / 100.0);
    final price = BigInt.from(discounted.round());

    return price > minPrice ? price : minPrice;
  }

  Map<String, dynamic> toJson() {
    return {
      'discountRate': discountRate,
      'minPrice': minPrice.toString(),
      'enabled': enabled,
      if (allowedBuyers != null) 'allowedBuyers': allowedBuyers,
      if (platformFeePercentage != null) 'platformFeePercentage': platformFeePercentage,
      'enabledAt': enabledAt.toIso8601String(),
      if (listingId != null) 'listingId': listingId,
      if (listedAt != null) 'listedAt': listedAt!.toIso8601String(),
      if (buyer != null) 'buyer': buyer,
      if (soldAt != null) 'soldAt': soldAt!.toIso8601String(),
      if (factorPrice != null) 'factorPrice': factorPrice.toString(),
    };
  }

  factory FactoringConfig.fromJson(Map<String, dynamic> json) {
    return FactoringConfig(
      discountRate: json['discountRate'] as double,
      minPrice: BigInt.parse(json['minPrice'] as String),
      enabled: json['enabled'] as bool? ?? true,
      allowedBuyers:
          json['allowedBuyers'] != null ? List<String>.from(json['allowedBuyers'] as List) : null,
      platformFeePercentage: json['platformFeePercentage'] as double?,
      enabledAt: DateTime.parse(json['enabledAt'] as String),
      listingId: json['listingId'] as String?,
      listedAt: json['listedAt'] != null ? DateTime.parse(json['listedAt'] as String) : null,
      buyer: json['buyer'] as String?,
      soldAt: json['soldAt'] != null ? DateTime.parse(json['soldAt'] as String) : null,
      factorPrice: json['factorPrice'] != null ? BigInt.parse(json['factorPrice'] as String) : null,
    );
  }

  @override
  List<Object?> get props => [
        discountRate,
        minPrice,
        enabled,
        allowedBuyers,
        platformFeePercentage,
        enabledAt,
        listingId,
        listedAt,
        buyer,
        soldAt,
        factorPrice,
      ];
}
