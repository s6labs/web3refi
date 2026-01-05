import 'package:equatable/equatable.dart';

/// Transaction status.
enum TransactionStatus {
  /// Transaction has been sent but not yet mined.
  pending,

  /// Transaction is being mined (in a block but not confirmed).
  confirming,

  /// Transaction has been confirmed.
  confirmed,

  /// Transaction failed or was reverted.
  failed,

  /// Transaction was dropped from mempool.
  dropped,
}

/// Result of waiting for a transaction.
class TransactionReceipt extends Equatable {
  /// Transaction hash.
  final String hash;

  /// Current status of the transaction.
  final TransactionStatus status;

  /// Block number the transaction was included in.
  final int? blockNumber;

  /// Block hash.
  final String? blockHash;

  /// Gas used by the transaction.
  final BigInt? gasUsed;

  /// Effective gas price paid.
  final BigInt? effectiveGasPrice;

  /// Contract address created (for contract deployments).
  final String? contractAddress;

  /// Error message if transaction failed.
  final String? errorMessage;

  /// Transaction logs.
  final List<TransactionLog>? logs;

  const TransactionReceipt({
    required this.hash,
    required this.status,
    this.blockNumber,
    this.blockHash,
    this.gasUsed,
    this.effectiveGasPrice,
    this.contractAddress,
    this.errorMessage,
    this.logs,
  });

  /// Whether the transaction was successful.
  bool get isSuccess => status == TransactionStatus.confirmed;

  /// Whether the transaction is still pending.
  bool get isPending => status == TransactionStatus.pending || status == TransactionStatus.confirming;

  /// Whether the transaction failed.
  bool get isFailed => status == TransactionStatus.failed || status == TransactionStatus.dropped;

  /// Calculate total gas cost in wei.
  BigInt? get gasCost {
    if (gasUsed == null || effectiveGasPrice == null) return null;
    return gasUsed! * effectiveGasPrice!;
  }

  @override
  List<Object?> get props => [hash, status, blockNumber];

  @override
  String toString() => 'TransactionReceipt($hash, $status)';

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'status': status.name,
        'blockNumber': blockNumber,
        'blockHash': blockHash,
        'gasUsed': gasUsed?.toString(),
        'effectiveGasPrice': effectiveGasPrice?.toString(),
        'contractAddress': contractAddress,
        'errorMessage': errorMessage,
      };
}

/// A log entry from a transaction receipt.
class TransactionLog extends Equatable {
  /// Log index in the block.
  final int logIndex;

  /// Transaction index in the block.
  final int transactionIndex;

  /// Address of the contract that emitted the log.
  final String address;

  /// Log topics (indexed parameters).
  final List<String> topics;

  /// Log data (non-indexed parameters).
  final String data;

  /// Block number.
  final int blockNumber;

  /// Transaction hash.
  final String transactionHash;

  /// Block hash.
  final String blockHash;

  const TransactionLog({
    required this.logIndex,
    required this.transactionIndex,
    required this.address,
    required this.topics,
    required this.data,
    required this.blockNumber,
    required this.transactionHash,
    required this.blockHash,
  });

  /// First topic is typically the event signature.
  String? get eventSignature => topics.isNotEmpty ? topics[0] : null;

  @override
  List<Object?> get props => [logIndex, transactionHash];

  factory TransactionLog.fromJson(Map<String, dynamic> json) {
    return TransactionLog(
      logIndex: _parseHexInt(json['logIndex']),
      transactionIndex: _parseHexInt(json['transactionIndex']),
      address: json['address'] as String,
      topics: (json['topics'] as List).cast<String>(),
      data: json['data'] as String,
      blockNumber: _parseHexInt(json['blockNumber']),
      transactionHash: json['transactionHash'] as String,
      blockHash: json['blockHash'] as String,
    );
  }

  static int _parseHexInt(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.parse(value.replaceFirst('0x', ''), radix: 16);
    }
    return 0;
  }
}

/// A pending transaction being tracked.
class PendingTransaction {
  /// Transaction hash.
  final String hash;

  /// When the transaction was sent.
  final DateTime sentAt;

  /// Description of what the transaction does.
  final String? description;

  /// Token address if this is a token transaction.
  final String? tokenAddress;

  /// Recipient address.
  final String? to;

  /// Value being sent.
  final BigInt? value;

  /// Current status.
  TransactionStatus status;

  PendingTransaction({
    required this.hash,
    required this.sentAt,
    this.description,
    this.tokenAddress,
    this.to,
    this.value,
    this.status = TransactionStatus.pending,
  });

  /// How long ago the transaction was sent.
  Duration get age => DateTime.now().difference(sentAt);
}

/// Transaction intent before signing.
class TransactionRequest extends Equatable {
  /// Recipient address.
  final String to;

  /// Value in wei.
  final BigInt value;

  /// Contract call data.
  final String? data;

  /// Gas limit.
  final BigInt? gasLimit;

  /// Max fee per gas (EIP-1559).
  final BigInt? maxFeePerGas;

  /// Max priority fee per gas (EIP-1559).
  final BigInt? maxPriorityFeePerGas;

  /// Legacy gas price.
  final BigInt? gasPrice;

  /// Transaction nonce.
  final int? nonce;

  const TransactionRequest({
    required this.to,
    this.value = BigInt.zero,
    this.data,
    this.gasLimit,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.gasPrice,
    this.nonce,
  });

  /// Convert to map for RPC call.
  Map<String, String> toJson() {
    return {
      'to': to,
      'value': '0x${value.toRadixString(16)}',
      if (data != null) 'data': data!,
      if (gasLimit != null) 'gas': '0x${gasLimit!.toRadixString(16)}',
      if (gasPrice != null) 'gasPrice': '0x${gasPrice!.toRadixString(16)}',
      if (maxFeePerGas != null) 'maxFeePerGas': '0x${maxFeePerGas!.toRadixString(16)}',
      if (maxPriorityFeePerGas != null) 'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas!.toRadixString(16)}',
      if (nonce != null) 'nonce': '0x${nonce!.toRadixString(16)}',
    };
  }

  @override
  List<Object?> get props => [to, value, data, gasLimit];

  TransactionRequest copyWith({
    String? to,
    BigInt? value,
    String? data,
    BigInt? gasLimit,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
    BigInt? gasPrice,
    int? nonce,
  }) {
    return TransactionRequest(
      to: to ?? this.to,
      value: value ?? this.value,
      data: data ?? this.data,
      gasLimit: gasLimit ?? this.gasLimit,
      maxFeePerGas: maxFeePerGas ?? this.maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas ?? this.maxPriorityFeePerGas,
      gasPrice: gasPrice ?? this.gasPrice,
      nonce: nonce ?? this.nonce,
    );
  }
}
