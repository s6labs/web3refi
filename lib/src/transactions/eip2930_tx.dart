import 'dart:typed_data';
import '../crypto/rlp.dart';
import '../crypto/signature.dart';
import '../signers/hd_wallet.dart';

/// EIP-2930 transaction (Type 1).
///
/// Introduced in Berlin hard fork. Adds access lists to optimize
/// gas costs for contracts that access multiple storage slots.
///
/// ## Structure
///
/// - chainId
/// - nonce
/// - gasPrice
/// - gasLimit
/// - to
/// - value
/// - data
/// - accessList
/// - v, r, s (signature)
///
/// ## Encoding
///
/// `0x01 || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList, v, r, s])`
class EIP2930Transaction {
  final int chainId;
  final BigInt nonce;
  final BigInt gasPrice;
  final BigInt gasLimit;
  final String? to; // null for contract creation
  final BigInt value;
  final Uint8List data;
  final List<AccessListEntry> accessList;

  // Signature components (null before signing)
  BigInt? v;
  BigInt? r;
  BigInt? s;

  EIP2930Transaction({
    required this.chainId,
    required this.nonce,
    required this.gasPrice,
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
  factory EIP2930Transaction.create({
    required int chainId,
    required BigInt nonce,
    required BigInt gasPrice,
    required BigInt gasLimit,
    String? to,
    BigInt? value,
    Uint8List? data,
    List<AccessListEntry>? accessList,
  }) {
    return EIP2930Transaction(
      chainId: chainId,
      nonce: nonce,
      gasPrice: gasPrice,
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
    // 0x01 || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList])
    throw UnimplementedError('EIP-2930 signing hash pending');
  }

  /// Sign transaction with signer.
  void sign(Signer signer) {
    final hash = getSigningHash();
    final signature = signer.sign(hash);

    v = BigInt.from(signature.v);
    r = signature.r;
    s = signature.s;
  }

  /// Serialize signed transaction.
  Uint8List serialize() {
    if (!isSigned) {
      throw StateError('Transaction must be signed before serialization');
    }

    // TODO: RLP encode signed transaction
    // 0x01 || rlp([chainId, nonce, gasPrice, gasLimit, to, value, data, accessList, v, r, s])
    throw UnimplementedError('EIP-2930 serialization pending');
  }

  /// Get serialized transaction as hex string.
  String toHex() {
    final bytes = serialize();
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Deserialize transaction from bytes.
  factory EIP2930Transaction.fromBytes(Uint8List bytes) {
    // TODO: Decode RLP and create transaction
    throw UnimplementedError('EIP-2930 deserialization pending');
  }

  /// Parse from hex string.
  factory EIP2930Transaction.fromHex(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return EIP2930Transaction.fromBytes(bytes);
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
}

/// Access list entry for EIP-2930.
class AccessListEntry {
  final String address;
  final List<String> storageKeys;

  const AccessListEntry({
    required this.address,
    required this.storageKeys,
  });

  /// Convert to RLP-encodable format.
  List<dynamic> toRlp() {
    return [address, storageKeys];
  }

  /// Create from RLP data.
  factory AccessListEntry.fromRlp(List<dynamic> data) {
    return AccessListEntry(
      address: data[0] as String,
      storageKeys: (data[1] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'storageKeys': storageKeys,
      };
}
