import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';

/// ABI (Application Binary Interface) encoder and decoder for Ethereum smart contracts.
///
/// Handles encoding function calls and decoding return values according to the
/// Ethereum Contract ABI specification.
///
/// Example:
/// ```dart
/// // Encode a function call
/// final data = AbiEncoder.encodeFunctionCall(
///   'transfer(address,uint256)',
///   [recipientAddress, amount],
/// );
///
/// // Decode a return value
/// final balance = AbiEncoder.decodeUint256(result);
/// ```
///
/// See: https://docs.soliditylang.org/en/latest/abi-spec.html
class AbiEncoder {
  AbiEncoder._();

  // ══════════════════════════════════════════════════════════════════════════
  // FUNCTION ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encodes a function call with parameters.
  ///
  /// The [signature] should be the canonical function signature like:
  /// - `transfer(address,uint256)`
  /// - `balanceOf(address)`
  /// - `approve(address,uint256)`
  ///
  /// The [params] list should contain values matching the signature types.
  ///
  /// Returns the encoded call data as a hex string starting with `0x`.
  ///
  /// Example:
  /// ```dart
  /// final data = AbiEncoder.encodeFunctionCall(
  ///   'transfer(address,uint256)',
  ///   ['0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb', BigInt.from(1000000)],
  /// );
  /// // Returns: 0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb00000000000000000000000000000000000000000000000000000000000f4240
  /// ```
  static String encodeFunctionCall(String signature, [List<dynamic>? params]) {
    final selector = getFunctionSelector(signature);
    
    if (params == null || params.isEmpty) {
      return '0x$selector';
    }

    // Parse parameter types from signature
    final types = _parseTypes(signature);
    
    if (types.length != params.length) {
      throw ArgumentError(
        'Parameter count mismatch: expected ${types.length}, got ${params.length}',
      );
    }

    // Encode parameters
    final encodedParams = _encodeParameters(types, params);
    
    return '0x$selector$encodedParams';
  }

  /// Gets the 4-byte function selector for a signature.
  ///
  /// The selector is the first 4 bytes of the Keccak-256 hash of the signature.
  ///
  /// Example:
  /// ```dart
  /// final selector = AbiEncoder.getFunctionSelector('transfer(address,uint256)');
  /// // Returns: 'a9059cbb'
  /// ```
  static String getFunctionSelector(String signature) {
    final hash = keccak256(utf8.encode(signature));
    return _bytesToHex(hash.sublist(0, 4));
  }

  /// Encodes parameters without function selector.
  ///
  /// Useful for encoding constructor arguments or raw data.
  static String encodeParameters(List<String> types, List<dynamic> values) {
    if (types.length != values.length) {
      throw ArgumentError(
        'Type/value count mismatch: ${types.length} types, ${values.length} values',
      );
    }
    return _encodeParameters(types, values);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DECODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Decodes a uint256 value from hex data.
  ///
  /// Example:
  /// ```dart
  /// final balance = AbiEncoder.decodeUint256('0x00000000000000000000000000000000000000000000000000000000000f4240');
  /// // Returns: BigInt.from(1000000)
  /// ```
  static BigInt decodeUint256(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.isEmpty) return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }

  /// Decodes an int256 value from hex data (handles negative numbers).
  static BigInt decodeInt256(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.isEmpty) return BigInt.zero;
    
    final value = BigInt.parse(clean, radix: 16);
    
    // Check if negative (first bit is 1)
    final maxPositive = BigInt.two.pow(255) - BigInt.one;
    if (value > maxPositive) {
      return value - BigInt.two.pow(256);
    }
    return value;
  }

  /// Decodes an address from hex data.
  ///
  /// Example:
  /// ```dart
  /// final address = AbiEncoder.decodeAddress('0x000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb');
  /// // Returns: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'
  /// ```
  static String decodeAddress(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length < 40) {
      throw ArgumentError('Invalid address data: too short');
    }
    // Take last 40 characters (20 bytes)
    final addressHex = clean.substring(clean.length - 40);
    return '0x$addressHex';
  }

  /// Decodes a boolean value from hex data.
  static bool decodeBool(String hexData) {
    final value = decodeUint256(hexData);
    return value != BigInt.zero;
  }

  /// Decodes a bytes32 value from hex data.
  static String decodeBytes32(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length > 64) {
      return '0x${clean.substring(0, 64)}';
    }
    return '0x${clean.padLeft(64, '0')}';
  }

  /// Decodes a dynamic string from hex data.
  ///
  /// Handles the ABI encoding for dynamic types (offset + length + data).
  static String decodeString(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length < 128) return '';

    // First 32 bytes: offset (usually 0x20 = 32)
    // Next 32 bytes: length
    // Remaining: actual string data
    
    final lengthHex = clean.substring(64, 128);
    final length = int.parse(lengthHex, radix: 16);
    
    if (length == 0) return '';
    
    final dataHex = clean.substring(128, 128 + length * 2);
    return _hexToString(dataHex);
  }

  /// Decodes dynamic bytes from hex data.
  static Uint8List decodeBytes(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length < 128) return Uint8List(0);

    final lengthHex = clean.substring(64, 128);
    final length = int.parse(lengthHex, radix: 16);
    
    if (length == 0) return Uint8List(0);
    
    final dataHex = clean.substring(128, 128 + length * 2);
    return _hexToBytes(dataHex);
  }

  /// Decodes an array of uint256 values.
  static List<BigInt> decodeUint256Array(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length < 128) return [];

    // Offset (32 bytes) + Length (32 bytes) + Data
    final lengthHex = clean.substring(64, 128);
    final length = int.parse(lengthHex, radix: 16);
    
    final result = <BigInt>[];
    for (var i = 0; i < length; i++) {
      final start = 128 + (i * 64);
      final end = start + 64;
      if (end <= clean.length) {
        result.add(BigInt.parse(clean.substring(start, end), radix: 16));
      }
    }
    return result;
  }

  /// Decodes an array of addresses.
  static List<String> decodeAddressArray(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length < 128) return [];

    final lengthHex = clean.substring(64, 128);
    final length = int.parse(lengthHex, radix: 16);
    
    final result = <String>[];
    for (var i = 0; i < length; i++) {
      final start = 128 + (i * 64);
      final end = start + 64;
      if (end <= clean.length) {
        final addrHex = clean.substring(start + 24, end); // Last 40 chars
        result.add('0x$addrHex');
      }
    }
    return result;
  }

  /// Decodes multiple return values.
  ///
  /// Example:
  /// ```dart
  /// final results = AbiEncoder.decodeMultiple(
  ///   hexData,
  ///   ['uint256', 'address', 'bool'],
  /// );
  /// final amount = results[0] as BigInt;
  /// final recipient = results[1] as String;
  /// final success = results[2] as bool;
  /// ```
  static List<dynamic> decodeMultiple(String hexData, List<String> types) {
    final clean = _cleanHex(hexData);
    final results = <dynamic>[];
    var offset = 0;

    for (final type in types) {
      if (offset + 64 > clean.length) break;
      
      final chunk = clean.substring(offset, offset + 64);
      
      if (type == 'uint256' || type.startsWith('uint')) {
        results.add(BigInt.parse(chunk, radix: 16));
      } else if (type == 'int256' || type.startsWith('int')) {
        results.add(decodeInt256('0x$chunk'));
      } else if (type == 'address') {
        results.add('0x${chunk.substring(24)}');
      } else if (type == 'bool') {
        results.add(BigInt.parse(chunk, radix: 16) != BigInt.zero);
      } else if (type == 'bytes32') {
        results.add('0x$chunk');
      } else {
        // For dynamic types, this is the offset - more complex handling needed
        results.add('0x$chunk');
      }
      
      offset += 64;
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENCODING HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Encodes an address to 32 bytes (padded with leading zeros).
  static String encodeAddress(String address) {
    final clean = _cleanHex(address);
    return clean.padLeft(64, '0');
  }

  /// Encodes a uint256 to 32 bytes.
  static String encodeUint256(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('uint256 cannot be negative');
    }
    return value.toRadixString(16).padLeft(64, '0');
  }

  /// Encodes an int256 to 32 bytes (handles negative numbers).
  static String encodeInt256(BigInt value) {
    if (value.isNegative) {
      // Two's complement for negative numbers
      final positive = BigInt.two.pow(256) + value;
      return positive.toRadixString(16).padLeft(64, '0');
    }
    return value.toRadixString(16).padLeft(64, '0');
  }

  /// Encodes a boolean to 32 bytes.
  static String encodeBool(bool value) {
    return value ? '${'0'.padLeft(63, '0')}1' : '0'.padLeft(64, '0');
  }

  /// Encodes bytes32 (fixed-size).
  static String encodeBytes32(String hexData) {
    final clean = _cleanHex(hexData);
    if (clean.length > 64) {
      return clean.substring(0, 64);
    }
    return clean.padRight(64, '0');
  }

  /// Encodes a dynamic string.
  static String encodeString(String value) {
    final bytes = utf8.encode(value);
    return _encodeDynamicBytes(bytes);
  }

  /// Encodes dynamic bytes.
  static String encodeDynamicBytes(Uint8List data) {
    return _encodeDynamicBytes(data);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ══════════════════════════════════════════════════════════════════════════

  static String _encodeParameters(List<String> types, List<dynamic> values) {
    final headParts = <String>[];
    final tailParts = <String>[];
    var dynamicOffset = types.length * 32; // Start after all head elements

    for (var i = 0; i < types.length; i++) {
      final type = types[i];
      final value = values[i];

      if (_isDynamicType(type)) {
        // For dynamic types, head contains offset, tail contains data
        headParts.add(encodeUint256(BigInt.from(dynamicOffset)));
        
        final encoded = _encodeValue(type, value);
        tailParts.add(encoded);
        dynamicOffset += encoded.length ~/ 2; // Convert hex chars to bytes
      } else {
        // For static types, encode directly in head
        headParts.add(_encodeValue(type, value));
      }
    }

    return headParts.join() + tailParts.join();
  }

  static String _encodeValue(String type, dynamic value) {
    // Handle arrays
    if (type.endsWith('[]')) {
      final baseType = type.substring(0, type.length - 2);
      final list = value as List;
      final encodedItems = list.map((v) => _encodeValue(baseType, v)).join();
      final length = encodeUint256(BigInt.from(list.length));
      return length + encodedItems;
    }

    // Handle fixed arrays like uint256[3]
    final fixedArrayMatch = RegExp(r'^(.+)\[(\d+)\]$').firstMatch(type);
    if (fixedArrayMatch != null) {
      final baseType = fixedArrayMatch.group(1)!;
      final list = value as List;
      return list.map((v) => _encodeValue(baseType, v)).join();
    }

    // Handle basic types
    switch (type) {
      case 'address':
        return encodeAddress(value as String);
      
      case 'bool':
        return encodeBool(value as bool);
      
      case 'string':
        return encodeString(value as String);
      
      case 'bytes':
        if (value is String) {
          return encodeDynamicBytes(_hexToBytes(value));
        }
        return encodeDynamicBytes(value as Uint8List);
      
      case 'bytes32':
        return encodeBytes32(value as String);
      
      default:
        // Handle uint<N> and int<N>
        if (type.startsWith('uint')) {
          final val = value is BigInt ? value : BigInt.from(value as int);
          return encodeUint256(val);
        }
        if (type.startsWith('int')) {
          final val = value is BigInt ? value : BigInt.from(value as int);
          return encodeInt256(val);
        }
        // Handle bytes<N>
        if (type.startsWith('bytes')) {
          return encodeBytes32(value as String);
        }
        
        throw ArgumentError('Unsupported type: $type');
    }
  }

  static bool _isDynamicType(String type) {
    return type == 'string' || 
           type == 'bytes' || 
           type.endsWith('[]');
  }

  static List<String> _parseTypes(String signature) {
    // Extract types from signature like "transfer(address,uint256)"
    final start = signature.indexOf('(');
    final end = signature.lastIndexOf(')');
    
    if (start == -1 || end == -1 || end <= start) {
      return [];
    }
    
    final typesStr = signature.substring(start + 1, end);
    if (typesStr.isEmpty) return [];
    
    // Handle nested tuples and arrays properly
    final types = <String>[];
    var depth = 0;
    var current = StringBuffer();
    
    for (var i = 0; i < typesStr.length; i++) {
      final char = typesStr[i];
      if (char == '(') {
        depth++;
        current.write(char);
      } else if (char == ')') {
        depth--;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        types.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }
    
    if (current.isNotEmpty) {
      types.add(current.toString().trim());
    }
    
    return types;
  }

  static String _encodeDynamicBytes(List<int> bytes) {
    final length = encodeUint256(BigInt.from(bytes.length));
    final data = _bytesToHex(bytes);
    // Pad to 32-byte boundary
    final paddedLength = ((bytes.length + 31) ~/ 32) * 64;
    final paddedData = data.padRight(paddedLength, '0');
    return length + paddedData;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  static String _cleanHex(String hex) {
    return hex.toLowerCase().replaceFirst('0x', '');
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final clean = _cleanHex(hex);
    final result = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  static String _hexToString(String hex) {
    final bytes = _hexToBytes(hex);
    return utf8.decode(bytes, allowMalformed: true);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// KECCAK-256 IMPLEMENTATION
// ════════════════════════════════════════════════════════════════════════════

/// Computes Keccak-256 hash (used by Ethereum, NOT SHA3-256).
///
/// Note: Ethereum uses Keccak-256, which is different from NIST SHA3-256.
Uint8List keccak256(List<int> data) {
  final digest = Digest('Keccak/256');
  return digest.process(Uint8List.fromList(data));
}

/// Computes Keccak-256 hash and returns as hex string.
String keccak256Hex(List<int> data) {
  final hash = keccak256(data);
  return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

// ════════════════════════════════════════════════════════════════════════════
// EVENT TOPIC UTILITIES
// ════════════════════════════════════════════════════════════════════════════

/// Utilities for working with event topics.
class EventEncoder {
  EventEncoder._();

  /// Gets the topic hash for an event signature.
  ///
  /// Example:
  /// ```dart
  /// final topic = EventEncoder.getEventTopic('Transfer(address,address,uint256)');
  /// // Returns: '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
  /// ```
  static String getEventTopic(String signature) {
    return keccak256Hex(utf8.encode(signature));
  }

  /// Standard ERC-20 Transfer event topic.
  static const transferTopic = 
    '0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef';

  /// Standard ERC-20 Approval event topic.
  static const approvalTopic = 
    '0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925';
}
