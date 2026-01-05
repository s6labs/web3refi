import 'dart:typed_data';
import '../crypto/rlp.dart';
import '../crypto/signature.dart';
import '../crypto/keccak.dart';
import '../crypto/address.dart';
import '../crypto/secp256k1.dart';
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
    // Encode unsigned transaction fields
    final encoded = _encodeFields(includeSig: false);

    // Hash: keccak256(0x01 || rlp([...fields]))
    final withPrefix = Uint8List(1 + encoded.length);
    withPrefix[0] = 0x01;
    withPrefix.setAll(1, encoded);

    return Keccak.keccak256(withPrefix);
  }

  /// Sign transaction with signer.
  void sign(Signer signer) {
    final hash = getSigningHash();
    final signature = signer.sign(hash);

    // For EIP-2930, v is the yParity (0 or 1, no chain ID encoding)
    v = BigInt.from(signature.recoveryId);
    r = signature.r;
    s = signature.s;
  }

  /// Serialize signed transaction.
  Uint8List serialize() {
    if (!isSigned) {
      throw StateError('Transaction must be signed before serialization');
    }

    // Encode with signature
    final encoded = _encodeFields(includeSig: true);

    // Add type prefix: 0x01 || rlp([...])
    final result = Uint8List(1 + encoded.length);
    result[0] = 0x01;
    result.setAll(1, encoded);

    return result;
  }

  /// Get serialized transaction as hex string.
  String toHex() {
    final bytes = serialize();
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Deserialize transaction from bytes.
  factory EIP2930Transaction.fromBytes(Uint8List bytes) {
    // Check type prefix
    if (bytes.isEmpty || bytes[0] != 0x01) {
      throw ArgumentError('Invalid EIP-2930 transaction: wrong type prefix');
    }

    // Decode RLP (skip type byte)
    final decoded = RLP.decode(bytes.sublist(1)) as List;

    if (decoded.length != 8 && decoded.length != 11) {
      throw ArgumentError('Invalid EIP-2930 transaction: wrong field count');
    }

    // Parse fields
    final chainId = _toBigInt(decoded[0]).toInt();
    final nonce = _toBigInt(decoded[1]);
    final gasPrice = _toBigInt(decoded[2]);
    final gasLimit = _toBigInt(decoded[3]);
    final toBytes = decoded[4] as Uint8List;
    final to = toBytes.isEmpty
        ? null
        : '0x${toBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    final value = _toBigInt(decoded[5]);
    final data = decoded[6] as Uint8List;

    // Parse access list
    final accessListRaw = decoded[7] as List;
    final accessList = accessListRaw.map((entry) {
      final entryList = entry as List;
      final addrBytes = entryList[0] as Uint8List;
      final address =
          '0x${addrBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';

      final storageKeysRaw = entryList[1] as List;
      final storageKeys = storageKeysRaw.map((keyBytes) {
        final kb = keyBytes as Uint8List;
        return '0x${kb.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
      }).toList();

      return AccessListEntry(address: address, storageKeys: storageKeys);
    }).toList();

    // Parse signature if present
    BigInt? v;
    BigInt? r;
    BigInt? s;
    if (decoded.length == 11) {
      v = _toBigInt(decoded[8]);
      r = _toBigInt(decoded[9]);
      s = _toBigInt(decoded[10]);
    }

    return EIP2930Transaction(
      chainId: chainId,
      nonce: nonce,
      gasPrice: gasPrice,
      gasLimit: gasLimit,
      to: to,
      value: value,
      data: data,
      accessList: accessList,
      v: v,
      r: r,
      s: s,
    );
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
    final serialized = serialize();
    final hash = Keccak.keccak256(serialized);
    return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Recover sender address from signature.
  String? getSender() {
    if (!isSigned) return null;

    try {
      final hash = getSigningHash();

      // Create signature with v adjusted for recovery
      final signature = Signature(
        r: r!,
        s: s!,
        v: v!.toInt() + 27, // Convert yParity to recovery format
      );

      final publicKey = Secp256k1.recoverPublicKey(signature, hash);
      return EthereumAddress.fromPublicKey(publicKey);
    } catch (_) {
      return null;
    }
  }

  /// Encode transaction fields to RLP.
  Uint8List _encodeFields({required bool includeSig}) {
    // Convert to address to bytes (or empty for contract creation)
    Uint8List toBytes;
    if (to != null) {
      final clean = to!.replaceFirst('0x', '');
      toBytes = Uint8List(20);
      for (int i = 0; i < 20; i++) {
        toBytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
    } else {
      toBytes = Uint8List(0);
    }

    // Encode access list
    final accessListEncoded = accessList.map((entry) {
      final addrClean = entry.address.replaceFirst('0x', '');
      final addrBytes = Uint8List(20);
      for (int i = 0; i < 20; i++) {
        addrBytes[i] = int.parse(addrClean.substring(i * 2, i * 2 + 2), radix: 16);
      }

      final storageKeys = entry.storageKeys.map((key) {
        final keyClean = key.replaceFirst('0x', '');
        final keyBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          keyBytes[i] = int.parse(keyClean.substring(i * 2, i * 2 + 2), radix: 16);
        }
        return keyBytes;
      }).toList();

      return [addrBytes, storageKeys];
    }).toList();

    // Build field list
    final fields = <dynamic>[
      chainId,
      nonce,
      gasPrice,
      gasLimit,
      toBytes,
      value,
      data,
      accessListEncoded,
    ];

    // Add signature if included
    if (includeSig) {
      fields.addAll([v, r, s]);
    }

    return RLP.encode(fields);
  }

  /// Convert to JSON for RPC calls.
  Map<String, dynamic> toJson() {
    return {
      'type': '0x1',
      'chainId': '0x${chainId.toRadixString(16)}',
      'nonce': '0x${nonce.toRadixString(16)}',
      'gasPrice': '0x${gasPrice.toRadixString(16)}',
      'gas': '0x${gasLimit.toRadixString(16)}',
      if (to != null) 'to': to,
      'value': '0x${value.toRadixString(16)}',
      'data': '0x${data.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      if (accessList.isNotEmpty)
        'accessList': accessList.map((e) => e.toJson()).toList(),
    };
  }

  /// Helper: Convert RLP decoded value to BigInt.
  static BigInt _toBigInt(dynamic value) {
    if (value is BigInt) return value;
    if (value is int) return BigInt.from(value);
    if (value is Uint8List) {
      if (value.isEmpty) return BigInt.zero;
      BigInt result = BigInt.zero;
      for (final byte in value) {
        result = (result << 8) | BigInt.from(byte);
      }
      return result;
    }
    throw ArgumentError('Cannot convert to BigInt: ${value.runtimeType}');
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

/// Helper for building EIP-2930 transactions.
class EIP2930TxBuilder {
  int? _chainId;
  BigInt? _nonce;
  BigInt? _gasPrice;
  BigInt? _gasLimit;
  String? _to;
  BigInt? _value;
  Uint8List? _data;
  List<AccessListEntry>? _accessList;

  EIP2930TxBuilder();

  EIP2930TxBuilder chainId(int value) {
    _chainId = value;
    return this;
  }

  EIP2930TxBuilder nonce(BigInt value) {
    _nonce = value;
    return this;
  }

  EIP2930TxBuilder gasPrice(BigInt value) {
    _gasPrice = value;
    return this;
  }

  EIP2930TxBuilder gasLimit(BigInt value) {
    _gasLimit = value;
    return this;
  }

  EIP2930TxBuilder to(String value) {
    _to = value;
    return this;
  }

  EIP2930TxBuilder value(BigInt value) {
    _value = value;
    return this;
  }

  EIP2930TxBuilder data(Uint8List value) {
    _data = value;
    return this;
  }

  EIP2930TxBuilder accessList(List<AccessListEntry> value) {
    _accessList = value;
    return this;
  }

  EIP2930Transaction build() {
    if (_chainId == null) throw StateError('chainId is required');
    if (_nonce == null) throw StateError('nonce is required');
    if (_gasPrice == null) throw StateError('gasPrice is required');
    if (_gasLimit == null) throw StateError('gasLimit is required');

    return EIP2930Transaction.create(
      chainId: _chainId!,
      nonce: _nonce!,
      gasPrice: _gasPrice!,
      gasLimit: _gasLimit!,
      to: _to,
      value: _value,
      data: _data,
      accessList: _accessList,
    );
  }
}
