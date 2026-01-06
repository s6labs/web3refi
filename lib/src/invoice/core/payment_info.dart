import 'package:equatable/equatable.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';

/// Payment information for an invoice
class Payment extends Equatable {
  /// Unique payment identifier
  final String id;

  /// Associated invoice ID
  final String invoiceId;

  /// Transaction hash
  final String txHash;

  /// Payer address
  final String from;

  /// Recipient address
  final String to;

  /// Amount paid (in smallest token unit)
  final BigInt amount;

  /// Token address (or 'ETH' for native token)
  final String token;

  /// Token symbol (USDC, ETH, etc.)
  final String tokenSymbol;

  /// Chain ID where payment was made
  final int chainId;

  /// When payment was initiated
  final DateTime createdAt;

  /// When payment was confirmed
  final DateTime? confirmedAt;

  /// Payment status
  final PaymentStatus status;

  /// Block number
  final int? blockNumber;

  /// Number of confirmations
  final int confirmations;

  /// Optional payment notes
  final String? notes;

  /// Gas paid for transaction
  final BigInt? gasPaid;

  /// Custom metadata
  final Map<String, dynamic>? metadata;

  const Payment({
    required this.id,
    required this.invoiceId,
    required this.txHash,
    required this.from,
    required this.to,
    required this.amount,
    required this.token,
    required this.tokenSymbol,
    required this.chainId,
    required this.createdAt,
    required this.status, this.confirmedAt,
    this.blockNumber,
    this.confirmations = 0,
    this.notes,
    this.gasPaid,
    this.metadata,
  });

  /// Whether payment is confirmed
  bool get isConfirmed => status == PaymentStatus.confirmed;

  /// Whether payment is pending
  bool get isPending => status == PaymentStatus.pending;

  /// Whether payment failed
  bool get isFailed => status == PaymentStatus.failed;

  /// Duration since payment was made
  Duration get age => DateTime.now().difference(createdAt);

  /// Copy with modifications
  Payment copyWith({
    String? id,
    String? invoiceId,
    String? txHash,
    String? from,
    String? to,
    BigInt? amount,
    String? token,
    String? tokenSymbol,
    int? chainId,
    DateTime? createdAt,
    DateTime? confirmedAt,
    PaymentStatus? status,
    int? blockNumber,
    int? confirmations,
    String? notes,
    BigInt? gasPaid,
    Map<String, dynamic>? metadata,
  }) {
    return Payment(
      id: id ?? this.id,
      invoiceId: invoiceId ?? this.invoiceId,
      txHash: txHash ?? this.txHash,
      from: from ?? this.from,
      to: to ?? this.to,
      amount: amount ?? this.amount,
      token: token ?? this.token,
      tokenSymbol: tokenSymbol ?? this.tokenSymbol,
      chainId: chainId ?? this.chainId,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      status: status ?? this.status,
      blockNumber: blockNumber ?? this.blockNumber,
      confirmations: confirmations ?? this.confirmations,
      notes: notes ?? this.notes,
      gasPaid: gasPaid ?? this.gasPaid,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'txHash': txHash,
      'from': from,
      'to': to,
      'amount': amount.toString(),
      'token': token,
      'tokenSymbol': tokenSymbol,
      'chainId': chainId,
      'createdAt': createdAt.toIso8601String(),
      if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
      'status': status.name,
      if (blockNumber != null) 'blockNumber': blockNumber,
      'confirmations': confirmations,
      if (notes != null) 'notes': notes,
      if (gasPaid != null) 'gasPaid': gasPaid.toString(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create from JSON
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      invoiceId: json['invoiceId'] as String,
      txHash: json['txHash'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      amount: BigInt.parse(json['amount'] as String),
      token: json['token'] as String,
      tokenSymbol: json['tokenSymbol'] as String,
      chainId: json['chainId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      confirmedAt: json['confirmedAt'] != null ? DateTime.parse(json['confirmedAt'] as String) : null,
      status: PaymentStatus.values.firstWhere((e) => e.name == json['status']),
      blockNumber: json['blockNumber'] as int?,
      confirmations: json['confirmations'] as int? ?? 0,
      notes: json['notes'] as String?,
      gasPaid: json['gasPaid'] != null ? BigInt.parse(json['gasPaid'] as String) : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        invoiceId,
        txHash,
        from,
        to,
        amount,
        token,
        tokenSymbol,
        chainId,
        createdAt,
        confirmedAt,
        status,
        blockNumber,
        confirmations,
        notes,
        gasPaid,
        metadata,
      ];

  @override
  String toString() {
    return 'Payment(id: $id, txHash: $txHash, amount: $amount $tokenSymbol, status: ${status.name})';
  }
}

/// Split payment configuration (for multi-recipient invoices)
class PaymentSplit extends Equatable {
  /// Recipient address
  final String address;

  /// Recipient name (optional, from UNS)
  final String? name;

  /// Percentage of total (0-100)
  final double percentage;

  /// Fixed amount (alternative to percentage)
  final BigInt? fixedAmount;

  /// Whether this is the primary recipient
  final bool isPrimary;

  const PaymentSplit({
    required this.address,
    required this.percentage, this.name,
    this.fixedAmount,
    this.isPrimary = false,
  });

  /// Calculate amount from total
  BigInt calculateAmount(BigInt total) {
    if (fixedAmount != null) return fixedAmount!;
    return BigInt.from((total.toDouble() * percentage / 100.0).round());
  }

  Map<String, dynamic> toJson() {
    return {
      'address': address,
      if (name != null) 'name': name,
      'percentage': percentage,
      if (fixedAmount != null) 'fixedAmount': fixedAmount.toString(),
      'isPrimary': isPrimary,
    };
  }

  factory PaymentSplit.fromJson(Map<String, dynamic> json) {
    return PaymentSplit(
      address: json['address'] as String,
      name: json['name'] as String?,
      percentage: json['percentage'] as double,
      fixedAmount: json['fixedAmount'] != null ? BigInt.parse(json['fixedAmount'] as String) : null,
      isPrimary: json['isPrimary'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [address, name, percentage, fixedAmount, isPrimary];
}
