import 'dart:convert';
import 'dart:typed_data';
import '../crypto/keccak.dart';
import '../crypto/signature.dart';
import '../abi/types/abi_types.dart';
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
          (value as List).map((v) => Map<String, String>.from(v as Map)).toList(),
        ),
      ),
      primaryType: data['primaryType'] as String,
      message: data['message'] as Map<String, dynamic>,
    );
  }

  /// Get EIP-712 domain separator hash.
  Uint8List getDomainSeparator() {
    // Add EIP712Domain type if not present
    if (!types.containsKey('EIP712Domain')) {
      types['EIP712Domain'] = _buildDomainTypeDefinition();
    }

    // Encode: keccak256(encodeType("EIP712Domain") || encodeData("EIP712Domain", domain))
    final typeHash = _hashType('EIP712Domain');
    final dataEncoded = _encodeData('EIP712Domain', domain);

    final combined = Uint8List(32 + dataEncoded.length);
    combined.setAll(0, typeHash);
    combined.setAll(32, dataEncoded);

    return Keccak.keccak256(combined);
  }

  /// Get struct hash for message.
  Uint8List getStructHash() {
    // Encode: keccak256(encodeType(primaryType) || encodeData(primaryType, message))
    final typeHash = _hashType(primaryType);
    final dataEncoded = _encodeData(primaryType, message);

    final combined = Uint8List(32 + dataEncoded.length);
    combined.setAll(0, typeHash);
    combined.setAll(32, dataEncoded);

    return Keccak.keccak256(combined);
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

    return Keccak.keccak256(combined);
  }

  /// Sign the typed data.
  Signature sign(Signer signer) {
    final hash = getSigningHash();
    return signer.sign(hash);
  }

  /// Encode type definition.
  ///
  /// Returns canonical type string like "Person(string name,address wallet)"
  String encodeType(String typeName) {
    final typeFields = types[typeName];
    if (typeFields == null) {
      throw ArgumentError('Type $typeName not defined');
    }

    // Find all referenced types (for dependency resolution)
    final referencedTypes = <String>{};
    for (final field in typeFields) {
      final fieldType = field['type']!;
      final baseType = _getBaseType(fieldType);
      if (types.containsKey(baseType) && baseType != typeName) {
        referencedTypes.add(baseType);
      }
    }

    // Build type string with dependencies
    final buffer = StringBuffer();

    // Primary type first
    buffer.write(typeName);
    buffer.write('(');
    buffer.write(typeFields.map((f) => '${f['type']} ${f['name']}').join(','));
    buffer.write(')');

    // Dependencies in alphabetical order
    final sortedDeps = referencedTypes.toList()..sort();
    for (final dep in sortedDeps) {
      final depFields = types[dep]!;
      buffer.write(dep);
      buffer.write('(');
      buffer.write(depFields.map((f) => '${f['type']} ${f['name']}').join(','));
      buffer.write(')');
    }

    return buffer.toString();
  }

  /// Hash type definition.
  Uint8List _hashType(String typeName) {
    final encoded = encodeType(typeName);
    final bytes = Uint8List.fromList(utf8.encode(encoded));
    return Keccak.keccak256(bytes);
  }

  /// Encode data for a type.
  Uint8List _encodeData(String typeName, Map<String, dynamic> data) {
    final typeFields = types[typeName];
    if (typeFields == null) {
      throw ArgumentError('Type $typeName not defined');
    }

    final encoded = <int>[];

    for (final field in typeFields) {
      final fieldName = field['name']!;
      final fieldType = field['type']!;
      final value = data[fieldName];

      encoded.addAll(_encodeValue(fieldType, value));
    }

    return Uint8List.fromList(encoded);
  }

  /// Encode a single value.
  List<int> _encodeValue(String type, dynamic value) {
    final baseType = _getBaseType(type);

    // Check if it's a custom type (struct)
    if (types.containsKey(baseType)) {
      // Encode struct as keccak256(encodeData(struct))
      final structEncoded = _encodeData(baseType, value as Map<String, dynamic>);
      final typeHash = _hashType(baseType);

      final combined = Uint8List(32 + structEncoded.length);
      combined.setAll(0, typeHash);
      combined.setAll(32, structEncoded);

      return Keccak.keccak256(combined);
    }

    // Dynamic types (bytes, string) and arrays are hashed
    if (type == 'bytes' || type == 'string' || type.contains('[')) {
      final abiType = parseType(type);
      final encoded = abiType.encode(value);
      return Keccak.keccak256(Uint8List.fromList(encoded));
    }

    // Static types are encoded normally
    final abiType = parseType(type);
    return abiType.encode(value);
  }

  /// Get base type (strip array notation).
  String _getBaseType(String type) {
    final bracketIndex = type.indexOf('[');
    return bracketIndex == -1 ? type : type.substring(0, bracketIndex);
  }

  /// Build EIP712Domain type definition based on domain fields.
  List<Map<String, String>> _buildDomainTypeDefinition() {
    final fields = <Map<String, String>>[];

    if (domain.containsKey('name')) {
      fields.add({'name': 'name', 'type': 'string'});
    }
    if (domain.containsKey('version')) {
      fields.add({'name': 'version', 'type': 'string'});
    }
    if (domain.containsKey('chainId')) {
      fields.add({'name': 'chainId', 'type': 'uint256'});
    }
    if (domain.containsKey('verifyingContract')) {
      fields.add({'name': 'verifyingContract', 'type': 'address'});
    }
    if (domain.containsKey('salt')) {
      fields.add({'name': 'salt', 'type': 'bytes32'});
    }

    return fields;
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
    if (salt != null) {
      map['salt'] = '0x${salt!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    }
    return map;
  }
}

/// Common EIP-712 typed data structures.
class CommonTypedData {
  /// ERC-2612 Permit (ERC-20 approvals via signature).
  static TypedData permit({
    required String name,
    required String version,
    required int chainId,
    required String verifyingContract,
    required String owner,
    required String spender,
    required BigInt value,
    required int nonce,
    required int deadline,
  }) {
    return TypedData(
      domain: {
        'name': name,
        'version': version,
        'chainId': chainId,
        'verifyingContract': verifyingContract,
      },
      types: {
        'Permit': [
          {'name': 'owner', 'type': 'address'},
          {'name': 'spender', 'type': 'address'},
          {'name': 'value', 'type': 'uint256'},
          {'name': 'nonce', 'type': 'uint256'},
          {'name': 'deadline', 'type': 'uint256'},
        ],
      },
      primaryType: 'Permit',
      message: {
        'owner': owner,
        'spender': spender,
        'value': value,
        'nonce': nonce,
        'deadline': deadline,
      },
    );
  }

  /// EIP-2771 meta-transaction forward request.
  static TypedData forwardRequest({
    required String name,
    required String version,
    required int chainId,
    required String verifyingContract,
    required String from,
    required String to,
    required BigInt value,
    required BigInt gas,
    required BigInt nonce,
    required Uint8List data,
  }) {
    return TypedData(
      domain: {
        'name': name,
        'version': version,
        'chainId': chainId,
        'verifyingContract': verifyingContract,
      },
      types: {
        'ForwardRequest': [
          {'name': 'from', 'type': 'address'},
          {'name': 'to', 'type': 'address'},
          {'name': 'value', 'type': 'uint256'},
          {'name': 'gas', 'type': 'uint256'},
          {'name': 'nonce', 'type': 'uint256'},
          {'name': 'data', 'type': 'bytes'},
        ],
      },
      primaryType: 'ForwardRequest',
      message: {
        'from': from,
        'to': to,
        'value': value,
        'gas': gas,
        'nonce': nonce,
        'data': data,
      },
    );
  }
}
