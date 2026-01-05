import 'dart:convert';
import 'dart:typed_data';
import '../crypto/keccak.dart';
import '../crypto/signature.dart';
import '../signers/hd_wallet.dart';

/// EIP-712 typed structured data signing.
///
/// Provides human-readable structured data signing for contracts
/// (e.g., permits, meta-transactions, governance votes).
///
/// ## Usage
///
/// ```dart
/// final typedData = TypedData(
///   domain: {
///     'name': 'MyDApp',
///     'version': '1',
///     'chainId': 1,
///     'verifyingContract': '0x...',
///   },
///   types: {
///     'Person': [
///       {'name': 'name', 'type': 'string'},
///       {'name': 'wallet', 'type': 'address'},
///     ],
///   },
///   primaryType: 'Person',
///   message: {
///     'name': 'Alice',
///     'wallet': '0x...',
///   },
/// );
///
/// final signature = typedData.sign(signer);
/// ```
class TypedData {
  /// EIP-712 domain separator fields.
  final Map<String, dynamic> domain;

  /// Type definitions.
  final Map<String, List<Map<String, String>>> types;

  /// Primary type to sign.
  final String primaryType;

  /// The message data.
  final Map<String, dynamic> message;

  TypedData({
    required this.domain,
    required this.types,
    required this.primaryType,
    required this.message,
  });

  /// Create from JSON string.
  factory TypedData.fromJson(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    return TypedData(
      domain: data['domain'] as Map<String, dynamic>,
      types: (data['types'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          key,
          (value as List).cast<Map<String, String>>(),
        ),
      ),
      primaryType: data['primaryType'] as String,
      message: data['message'] as Map<String, dynamic>,
    );
  }

  /// Get EIP-712 domain separator hash.
  Uint8List getDomainSeparator() {
    // TODO: Encode and hash domain
    // domainSeparator = keccak256(encodeType("EIP712Domain") || encodeData("EIP712Domain", domain))
    throw UnimplementedError('Domain separator calculation pending');
  }

  /// Get struct hash for message.
  Uint8List getStructHash() {
    // TODO: Encode and hash message
    // structHash = keccak256(encodeType(primaryType) || encodeData(primaryType, message))
    throw UnimplementedError('Struct hash calculation pending');
  }

  /// Get signing hash per EIP-712.
  ///
  /// `\x19\x01 || domainSeparator || structHash`
  Uint8List getSigningHash() {
    final domainSeparator = getDomainSeparator();
    final structHash = getStructHash();

    final combined = Uint8List(2 + 32 + 32);
    combined[0] = 0x19;
    combined[1] = 0x01;
    combined.setAll(2, domainSeparator);
    combined.setAll(34, structHash);

    // TODO: Hash combined
    // return Keccak.keccak256(combined);
    throw UnimplementedError('Signing hash calculation pending');
  }

  /// Sign the typed data.
  Signature sign(Signer signer) {
    final hash = getSigningHash();
    return signer.sign(hash);
  }

  /// Encode type definition.
  String encodeType(String typeName) {
    // TODO: Generate canonical type string
    // e.g., "Person(string name,address wallet)"
    throw UnimplementedError('Type encoding pending');
  }

  /// Encode data for a type.
  Uint8List encodeData(String typeName, Map<String, dynamic> data) {
    // TODO: ABI encode struct data
    throw UnimplementedError('Data encoding pending');
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'domain': domain,
        'types': types,
        'primaryType': primaryType,
        'message': message,
      };
}

/// EIP-712 domain builder.
class EIP712Domain {
  String? name;
  String? version;
  int? chainId;
  String? verifyingContract;
  Uint8List? salt;

  EIP712Domain({
    this.name,
    this.version,
    this.chainId,
    this.verifyingContract,
    this.salt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (version != null) map['version'] = version;
    if (chainId != null) map['chainId'] = chainId;
    if (verifyingContract != null) map['verifyingContract'] = verifyingContract;
    if (salt != null) map['salt'] = '0x${bytesToHex(salt!)}';
    return map;
  }
}
