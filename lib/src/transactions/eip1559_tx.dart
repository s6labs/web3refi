import 'dart:typed_data';
import '../crypto/rlp.dart';
import '../crypto/signature.dart';
import '../signers/hd_wallet.dart';
import 'eip2930_tx.dart';

/// EIP-1559 transaction (Type 2).
///
/// Introduced in London hard fork. Uses base fee + priority fee model
/// for more predictable gas pricing.
///
/// ## Structure
///
/// - chainId
/// - nonce
/// - maxPriorityFeePerGas (tip to miner)
/// - maxFeePerGas (max total fee)
/// - gasLimit
/// - to
/// - value
/// - data
/// - accessList
/// - v, r, s (signature)
///
/// ## Fee Calculation
///
/// ```
/// effectiveGasPrice = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
/// totalCost = gasUsed * effectiveGasPrice
/// ```
///
/// ## Encoding
///
/// `0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])`
class EIP1559Transaction {
  final int chainId;
  final BigInt nonce;
  final BigInt maxPriorityFeePerGas; // Tip to miner
  final BigInt maxFeePerGas; // Max total fee
  final BigInt gasLimit;
  final String? to; // null for contract creation
  final BigInt value;
  final Uint8List data;
  final List<AccessListEntry> accessList;

  // Signature components (null before signing)
  BigInt? v;
  BigInt? r;
  BigInt? s;

  EIP1559Transaction({
    required this.chainId,
    required this.nonce,
    required this.maxPriorityFeePerGas,
    required this.maxFeePerGas,
    required this.gasLimit,
    this.to,
    required this.value,
    required this.data,
    this.accessList = const [],
    this.v,
    this.r,
    this.s,
  });

  /// Create unsigned transaction.
  factory EIP1559Transaction.create({
    required int chainId,
    required BigInt nonce,
    required BigInt maxPriorityFeePerGas,
    required BigInt maxFeePerGas,
    required BigInt gasLimit,
    String? to,
    BigInt? value,
    Uint8List? data,
    List<AccessListEntry>? accessList,
  }) {
    // Validate fees
    if (maxPriorityFeePerGas > maxFeePerGas) {
      throw ArgumentError(
        'maxPriorityFeePerGas cannot exceed maxFeePerGas',
      );
    }

    return EIP1559Transaction(
      chainId: chainId,
      nonce: nonce,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
      maxFeePerGas: maxFeePerGas,
      gasLimit: gasLimit,
      to: to,
      value: value ?? BigInt.zero,
      data: data ?? Uint8List(0),
      accessList: accessList ?? [],
    );
  }

  /// Check if transaction is signed.
  bool get isSigned => v != null && r != null && s != null;

  /// Get transaction hash for signing.
  Uint8List getSigningHash() {
    // TODO: RLP encode unsigned transaction and hash
    // 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList])
    throw UnimplementedError('EIP-1559 signing hash pending');
  }

  /// Sign transaction with signer.
  void sign(Signer signer) {
    final hash = getSigningHash();
    final signature = signer.sign(hash);

    // For EIP-1559, v is always 0 or 1 (no chain ID encoding)
    v = BigInt.from(signature.recoveryId);
    r = signature.r;
    s = signature.s;
  }

  /// Serialize signed transaction.
  Uint8List serialize() {
    if (!isSigned) {
      throw StateError('Transaction must be signed before serialization');
    }

    // TODO: RLP encode signed transaction
    // 0x02 || rlp([chainId, nonce, maxPriorityFeePerGas, maxFeePerGas, gasLimit, to, value, data, accessList, v, r, s])
    throw UnimplementedError('EIP-1559 serialization pending');
  }

  /// Get serialized transaction as hex string.
  String toHex() {
    final bytes = serialize();
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Deserialize transaction from bytes.
  factory EIP1559Transaction.fromBytes(Uint8List bytes) {
    // TODO: Decode RLP and create transaction
    throw UnimplementedError('EIP-1559 deserialization pending');
  }

  /// Parse from hex string.
  factory EIP1559Transaction.fromHex(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return EIP1559Transaction.fromBytes(bytes);
  }

  /// Get transaction hash (for tracking).
  String getHash() {
    // TODO: Keccak-256 of serialized transaction
    throw UnimplementedError('Transaction hash calculation pending');
  }

  /// Recover sender address from signature.
  String? getSender() {
    if (!isSigned) return null;

    // TODO: Recover address from signature
    throw UnimplementedError('Sender recovery pending');
  }

  /// Calculate effective gas price given base fee.
  ///
  /// Used to estimate actual transaction cost.
  BigInt getEffectiveGasPrice(BigInt baseFee) {
    final maxPriorityFee = maxPriorityFeePerGas;
    final maxTotal = maxFeePerGas;

    // effective = min(maxFeePerGas, baseFee + maxPriorityFeePerGas)
    final withPriority = baseFee + maxPriorityFee;
    return withPriority < maxTotal ? withPriority : maxTotal;
  }

  /// Estimate maximum transaction cost.
  BigInt getMaxCost() {
    return gasLimit * maxFeePerGas + value;
  }

  /// Convert to JSON for RPC calls.
  Map<String, dynamic> toJson() {
    return {
      'type': '0x2',
      'chainId': '0x${chainId.toRadixString(16)}',
      'nonce': '0x${nonce.toRadixString(16)}',
      'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas.toRadixString(16)}',
      'maxFeePerGas': '0x${maxFeePerGas.toRadixString(16)}',
      'gas': '0x${gasLimit.toRadixString(16)}',
      if (to != null) 'to': to,
      'value': '0x${value.toRadixString(16)}',
      'data': '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      if (accessList.isNotEmpty)
        'accessList': accessList.map((e) => e.toJson()).toList(),
    };
  }
}
