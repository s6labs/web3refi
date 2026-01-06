import 'dart:typed_data';
import 'dart:convert';
import 'package:web3refi/src/crypto/keccak.dart';
import 'package:web3refi/src/abi/function_selector.dart';
import 'package:web3refi/src/abi/types/abi_types.dart';

/// ABI encoding and decoding for Ethereum smart contracts.
///
/// Implements the Ethereum Contract ABI specification for encoding
/// function calls and decoding return values.
///
/// ## Features
///
/// - Function call encoding
/// - Return value decoding
/// - Event signature hashing
/// - Support for all Solidity types
///
/// ## Usage
///
/// ```dart
/// // Encode function call
/// final data = AbiCoder.encodeFunctionCall(
///   'transfer(address,uint256)',
///   ['0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb', BigInt.from(1000000)],
/// );
///
/// // Decode return value
/// final balance = AbiCoder.decodeParameters(
///   ['uint256'],
///   returnData,
/// );
/// ```
class AbiCoder {
  AbiCoder._();

  // ══════════════════════════════════════════════════════════════════════════
  // FUNCTION ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encode a function call with parameters.
  ///
  /// Returns hex string with 0x prefix.
  static String encodeFunctionCall(String signature, List<dynamic> params) {
    // Get function selector
    final selector = FunctionSelector.fromSignature(signature);

    // Parse parameter types from signature
    final parsed = parseSignature(signature);
    final types = parsed['params'] as List<String>;

    // Validate parameter count
    validateParameterCount(types, params);

    // Encode parameters
    final encodedParams = encodeParameters(types, params);

    // Combine selector + params
    return selector.hex + encodedParams.replaceFirst('0x', '');
  }

  /// Encode parameters only (no function selector).
  static String encodeParameters(List<String> types, List<dynamic> values) {
    validateParameterCount(types, values);

    if (types.isEmpty) {
      return '0x';
    }

    // Parse types and encode values
    final result = <int>[];
    final abiTypes = types.map((t) => parseType(t)).toList();

    // Handle head-tail encoding for dynamic types
    final headParts = <List<int>>[];
    final tailParts = <List<int>>[];

    for (int i = 0; i < abiTypes.length; i++) {
      final type = abiTypes[i];
      final value = values[i];

      if (type.isDynamic) {
        // Dynamic type: head contains offset, tail contains data
        headParts.add(_padLeft(_intToBytes(0), 32)); // Placeholder offset
        tailParts.add(type.encode(value));
      } else {
        // Static type: head contains data directly
        headParts.add(type.encode(value));
      }
    }

    // Calculate actual offsets for dynamic types
    final int headSize = headParts.fold<int>(0, (sum, part) => sum + part.length);
    int currentOffset = headSize;

    int dynamicIndex = 0;
    for (int i = 0; i < abiTypes.length; i++) {
      if (abiTypes[i].isDynamic) {
        // Update offset in head
        headParts[i] = _padLeft(_intToBytes(currentOffset), 32);
        currentOffset += tailParts[dynamicIndex].length;
        dynamicIndex++;
      }
    }

    // Combine head and tail
    for (final part in headParts) {
      result.addAll(part);
    }
    for (final part in tailParts) {
      result.addAll(part);
    }

    return '0x${_bytesToHex(result)}';
  }

  /// Decode parameters from encoded data.
  static List<dynamic> decodeParameters(List<String> types, String data) {
    final clean = data.replaceFirst('0x', '');
    final bytes = _hexToBytes(clean);

    final abiTypes = types.map((t) => parseType(t)).toList();
    final results = <dynamic>[];

    int offset = 0;
    for (final type in abiTypes) {
      results.add(type.decode(bytes, offset));
      offset += type.getDecodedSize(bytes, offset);
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ELEMENTARY TYPE ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encode uint256.
  static String encodeUint256(BigInt value) {
    final hex = value.toRadixString(16).padLeft(64, '0');
    return hex;
  }

  /// Encode address (20 bytes, left-padded to 32 bytes).
  static String encodeAddress(String address, {bool padded = false}) {
    final clean = address.toLowerCase().replaceFirst('0x', '');
    if (clean.length != 40) {
      throw ArgumentError('Invalid address length');
    }
    return padded ? clean.padLeft(64, '0') : clean;
  }

  /// Encode bool.
  static String encodeBool(bool value) {
    return value ? '1'.padLeft(64, '0') : '0'.padLeft(64, '0');
  }

  /// Encode bytes (fixed size).
  static String encodeBytes(Uint8List bytes, {required int size}) {
    if (bytes.length != size) {
      throw ArgumentError('Bytes length must be $size');
    }
    final hex = _bytesToHex(bytes);
    return hex.padRight(64, '0'); // Right-pad for fixed bytes
  }

  /// Encode string.
  static String encodeString(String value) {
    final bytes = Uint8List.fromList(utf8.encode(value));
    return encodeDynamicBytes(bytes);
  }

  /// Encode dynamic bytes.
  static String encodeDynamicBytes(Uint8List bytes) {
    // Length prefix
    final length = encodeUint256(BigInt.from(bytes.length));

    // Data (right-padded to multiple of 32 bytes)
    final paddedLength = ((bytes.length + 31) ~/ 32) * 32;
    final padded = Uint8List(paddedLength);
    padded.setAll(0, bytes);

    final data = _bytesToHex(padded);

    return length + data;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DECODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Decode uint256 from hex string.
  static BigInt decodeUint256(String hex) {
    final clean = hex.replaceFirst('0x', '');
    if (clean.isEmpty) return BigInt.zero;

    // Take first 64 characters (32 bytes)
    final value = clean.length > 64 ? clean.substring(0, 64) : clean;
    return BigInt.parse(value, radix: 16);
  }

  /// Decode address from hex string.
  static String decodeAddress(String hex) {
    final clean = hex.replaceFirst('0x', '');

    // Address is last 40 characters (20 bytes)
    final address = clean.length >= 64
        ? clean.substring(24, 64) // Skip 12 bytes of padding
        : clean.substring(clean.length - 40);

    return '0x$address';
  }

  /// Decode bool.
  static bool decodeBool(String hex) {
    final value = decodeUint256(hex);
    return value != BigInt.zero;
  }

  /// Decode string.
  static String decodeString(String hex) {
    final bytes = decodeDynamicBytes(hex);
    return utf8.decode(bytes);
  }

  /// Decode dynamic bytes.
  static Uint8List decodeDynamicBytes(String hex) {
    final clean = hex.replaceFirst('0x', '');

    // Read length (first 32 bytes)
    final lengthHex = clean.substring(0, 64);
    final length = BigInt.parse(lengthHex, radix: 16).toInt();

    // Read data
    final dataHex = clean.substring(64, 64 + (length * 2));
    return _hexToBytes(dataHex);
  }

  /// Decode fixed bytes.
  static Uint8List decodeBytes(String hex, {required int size}) {
    final clean = hex.replaceFirst('0x', '');
    final bytesHex = clean.substring(0, size * 2);
    return _hexToBytes(bytesHex);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENT ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Get event signature hash (topic[0]).
  ///
  /// Example: Transfer(address,address,uint256) ->
  ///   0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
  static String eventSignature(String signature) {
    final bytes = Uint8List.fromList(utf8.encode(signature));
    final hash = Keccak.keccak256(bytes);
    return '0x${_bytesToHex(hash)}';
  }

  /// Encode indexed event parameter.
  ///
  /// For dynamic types (string, bytes, arrays), returns keccak256 hash.
  /// For static types, returns ABI-encoded value.
  static String encodeIndexedParameter(dynamic value, String type) {
    final abiType = parseType(type);

    if (abiType.isDynamic) {
      // Dynamic types are hashed
      final encoded = abiType.encode(value);
      final hash = Keccak.keccak256(Uint8List.fromList(encoded));
      return '0x${_bytesToHex(hash)}';
    } else {
      // Static types are encoded normally
      final encoded = abiType.encode(value);
      return '0x${_bytesToHex(encoded)}';
    }
  }

  /// Decode event log data.
  ///
  /// Non-indexed parameters are encoded in the data field.
  static List<dynamic> decodeEventData(List<String> types, String data) {
    return decodeParameters(types, data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encode constructor parameters.
  ///
  /// Used when deploying contracts with constructor arguments.
  static String encodeConstructor(List<String> types, List<dynamic> values) {
    return encodeParameters(types, values);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Parse function signature into name and parameter types.
  static Map<String, dynamic> parseSignature(String signature) {
    final match = RegExp(r'(\w+)\((.*)\)').firstMatch(signature);
    if (match == null) {
      throw ArgumentError('Invalid function signature: $signature');
    }

    final name = match.group(1)!;
    final paramsStr = match.group(2)!;
    final params = paramsStr.isEmpty
        ? <String>[]
        : paramsStr.split(',').map((s) => s.trim()).toList();

    return {
      'name': name,
      'params': params,
      'signature': signature,
    };
  }

  /// Validate parameter count matches types.
  static void validateParameterCount(List<String> types, List<dynamic> values) {
    if (types.length != values.length) {
      throw ArgumentError(
        'Parameter count mismatch: expected ${types.length}, got ${values.length}',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static List<int> _padLeft(List<int> bytes, int length) {
    if (bytes.length >= length) return bytes;
    return List<int>.filled(length - bytes.length, 0) + bytes;
  }

  static List<int> _intToBytes(int value) {
    if (value == 0) return [0];

    final bytes = <int>[];
    int remaining = value;

    while (remaining > 0) {
      bytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }

    return bytes;
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}

/// Pre-defined event signatures for common standards.
class CommonEvents {
  /// ERC-20 Transfer event
  static final transfer = AbiCoder.eventSignature('Transfer(address,address,uint256)');

  /// ERC-20 Approval event
  static final approval = AbiCoder.eventSignature('Approval(address,address,uint256)');

  /// ERC-721 Transfer event (same as ERC-20)
  static final transferNFT = transfer;

  /// ERC-721 Approval event
  static final approvalNFT = AbiCoder.eventSignature('Approval(address,address,uint256)');

  /// ERC-721 ApprovalForAll event
  static final approvalForAll = AbiCoder.eventSignature('ApprovalForAll(address,address,bool)');

  /// ERC-1155 TransferSingle event
  static final transferSingle = AbiCoder.eventSignature(
    'TransferSingle(address,address,address,uint256,uint256)',
  );

  /// ERC-1155 TransferBatch event
  static final transferBatch = AbiCoder.eventSignature(
    'TransferBatch(address,address,address,uint256[],uint256[])',
  );

  /// ERC-1155 ApprovalForAll event (same as ERC-721)
  static final approvalForAll1155 = approvalForAll;
}
