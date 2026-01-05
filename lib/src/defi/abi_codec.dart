import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/keccak.dart';

/// ABI encoding and decoding utilities for Ethereum smart contract interactions.
///
/// Implements Ethereum ABI encoding specification for:
/// - Function selectors (first 4 bytes of keccak256)
/// - Parameter encoding (addresses, uint256, bytes, strings)
/// - Event topics
/// - Result decoding
///
/// ## Usage
///
/// ```dart
/// // Encode a function call
/// final data = AbiCodec.encodeFunctionCall(
///   'transfer(address,uint256)',
///   [
///     AbiCodec.encodeAddress('0x123...'),
///     AbiCodec.encodeUint256(BigInt.from(1000000)),
///   ],
/// );
///
/// // Decode a result
/// final balance = AbiCodec.decodeUint256(result);
/// ```
class AbiCodec {
  AbiCodec._();

  // ══════════════════════════════════════════════════════════════════════════
  // FUNCTION ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encode a function call with parameters.
  ///
  /// [signature] is the function signature (e.g., 'transfer(address,uint256)').
  /// [encodedParams] are the pre-encoded parameters.
  ///
  /// Returns the complete calldata as hex string with '0x' prefix.
  static String encodeFunctionCall(String signature, [List<String>? encodedParams]) {
    final selector = functionSelector(signature);
    final params = encodedParams?.join('') ?? '';
    return '0x$selector$params';
  }

  /// Calculate function selector (first 4 bytes of keccak256).
  ///
  /// ```dart
  /// final selector = AbiCodec.functionSelector('transfer(address,uint256)');
  /// // Returns: 'a9059cbb'
  /// ```
  static String functionSelector(String signature) {
    final hash = keccak256(utf8.encode(signature));
    return _bytesToHex(hash.sublist(0, 4));
  }

  /// Calculate event signature hash.
  ///
  /// ```dart
  /// final topic = AbiCodec.eventSignature('Transfer(address,address,uint256)');
  /// // Returns: '0xddf252ad...'
  /// ```
  static String eventSignature(String signature) {
    final hash = keccak256(utf8.encode(signature));
    return '0x${_bytesToHex(hash)}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PARAMETER ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Encode an address to 32 bytes (padded left with zeros).
  ///
  /// [padded] if true, includes '0x' prefix and full 32-byte padding.
  static String encodeAddress(String address, {bool padded = false}) {
    final clean = address.toLowerCase().replaceFirst('0x', '');
    if (clean.length != 40) {
      throw ArgumentError('Invalid address length: $address');
    }
    final encoded = clean.padLeft(64, '0');
    return padded ? '0x$encoded' : encoded;
  }

  /// Encode a uint256 to 32 bytes.
  static String encodeUint256(BigInt value) {
    if (value.isNegative) {
      throw ArgumentError('uint256 cannot be negative');
    }
    return value.toRadixString(16).padLeft(64, '0');
  }

  /// Encode an int256 to 32 bytes (two's complement for negatives).
  static String encodeInt256(BigInt value) {
    if (value.isNegative) {
      // Two's complement for negative numbers
      final maxUint256 = BigInt.two.pow(256);
      final encoded = (maxUint256 + value).toRadixString(16);
      return encoded.padLeft(64, 'f');
    }
    return value.toRadixString(16).padLeft(64, '0');
  }

  /// Encode bytes32.
  static String encodeBytes32(List<int> bytes) {
    if (bytes.length > 32) {
      throw ArgumentError('bytes32 cannot exceed 32 bytes');
    }
    return _bytesToHex(bytes).padRight(64, '0');
  }

  /// Encode a boolean.
  static String encodeBool(bool value) {
    return encodeUint256(value ? BigInt.one : BigInt.zero);
  }

  /// Encode dynamic bytes.
  ///
  /// Returns offset + length + data (for dynamic types).
  static String encodeDynamicBytes(List<int> bytes) {
    final length = encodeUint256(BigInt.from(bytes.length));
    final data = _bytesToHex(bytes).padRight(
      ((bytes.length + 31) ~/ 32) * 64,
      '0',
    );
    return '$length$data';
  }

  /// Encode a string.
  static String encodeString(String value) {
    return encodeDynamicBytes(utf8.encode(value));
  }

  /// Encode an array of uint256.
  static String encodeUint256Array(List<BigInt> values) {
    final length = encodeUint256(BigInt.from(values.length));
    final elements = values.map((v) => encodeUint256(v)).join('');
    return '$length$elements';
  }

  /// Encode an array of addresses.
  static String encodeAddressArray(List<String> addresses) {
    final length = encodeUint256(BigInt.from(addresses.length));
    final elements = addresses.map((a) => encodeAddress(a)).join('');
    return '$length$elements';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DECODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Decode a uint256 from hex result.
  static BigInt decodeUint256(String hex) {
    final clean = hex.replaceFirst('0x', '').trim();
    if (clean.isEmpty || clean == '0') return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }

  /// Decode an int256 from hex result (handles negative via two's complement).
  static BigInt decodeInt256(String hex) {
    final value = decodeUint256(hex);
    final maxInt256 = BigInt.two.pow(255);
    
    if (value >= maxInt256) {
      // Negative number (two's complement)
      return value - BigInt.two.pow(256);
    }
    return value;
  }

  /// Decode an address from hex result.
  static String decodeAddress(String hex) {
    final clean = hex.replaceFirst('0x', '').trim();
    // Take last 40 characters (address is 20 bytes = 40 hex chars)
    final addressHex = clean.length >= 40 
        ? clean.substring(clean.length - 40) 
        : clean.padLeft(40, '0');
    return '0x$addressHex';
  }

  /// Decode a boolean from hex result.
  static bool decodeBool(String hex) {
    return decodeUint256(hex) != BigInt.zero;
  }

  /// Decode a string from hex result.
  ///
  /// Handles ABI-encoded dynamic string format.
  static String decodeString(String hex) {
    final clean = hex.replaceFirst('0x', '');
    if (clean.isEmpty) return '';
    
    // For simple responses, data starts at offset 0
    // For complex responses, first 32 bytes are offset
    
    int dataStart = 0;
    
    // Check if this looks like a dynamic response (offset + length + data)
    if (clean.length >= 128) {
      // Try to read offset
      final offset = int.tryParse(clean.substring(0, 64), radix: 16);
      if (offset != null && offset == 32) {
        dataStart = 64; // Skip offset, length is next
      }
    }
    
    // Read length
    final lengthHex = clean.substring(dataStart, dataStart + 64);
    final length = int.tryParse(lengthHex, radix: 16) ?? 0;
    
    if (length == 0) return '';
    if (length > 10000) return ''; // Sanity check
    
    // Read string data
    final dataHex = clean.substring(dataStart + 64);
    final dataBytes = <int>[];
    
    for (var i = 0; i < length * 2 && i < dataHex.length; i += 2) {
      dataBytes.add(int.parse(dataHex.substring(i, i + 2), radix: 16));
    }
    
    try {
      return utf8.decode(dataBytes);
    } catch (e) {
      // If UTF-8 decode fails, try latin1
      return String.fromCharCodes(dataBytes);
    }
  }

  /// Decode bytes from hex result.
  static List<int> decodeBytes(String hex) {
    final clean = hex.replaceFirst('0x', '');
    
    // Skip offset if present
    int dataStart = 0;
    if (clean.length >= 128) {
      final offset = int.tryParse(clean.substring(0, 64), radix: 16);
      if (offset == 32) dataStart = 64;
    }
    
    // Read length
    final lengthHex = clean.substring(dataStart, dataStart + 64);
    final length = int.tryParse(lengthHex, radix: 16) ?? 0;
    
    // Read data
    final dataHex = clean.substring(dataStart + 64);
    return _hexToBytes(dataHex.substring(0, length * 2));
  }

  /// Decode an array of uint256.
  static List<BigInt> decodeUint256Array(String hex) {
    final clean = hex.replaceFirst('0x', '');
    
    // Skip offset if present
    int dataStart = 0;
    if (clean.length >= 128) {
      final offset = int.tryParse(clean.substring(0, 64), radix: 16);
      if (offset == 32) dataStart = 64;
    }
    
    // Read length
    final lengthHex = clean.substring(dataStart, dataStart + 64);
    final length = int.tryParse(lengthHex, radix: 16) ?? 0;
    
    // Read elements
    final elements = <BigInt>[];
    var position = dataStart + 64;
    
    for (var i = 0; i < length && position + 64 <= clean.length; i++) {
      elements.add(BigInt.parse(clean.substring(position, position + 64), radix: 16));
      position += 64;
    }
    
    return elements;
  }

  /// Decode an array of addresses.
  static List<String> decodeAddressArray(String hex) {
    final clean = hex.replaceFirst('0x', '');
    
    int dataStart = 0;
    if (clean.length >= 128) {
      final offset = int.tryParse(clean.substring(0, 64), radix: 16);
      if (offset == 32) dataStart = 64;
    }
    
    final lengthHex = clean.substring(dataStart, dataStart + 64);
    final length = int.tryParse(lengthHex, radix: 16) ?? 0;
    
    final addresses = <String>[];
    var position = dataStart + 64;
    
    for (var i = 0; i < length && position + 64 <= clean.length; i++) {
      addresses.add(decodeAddress(clean.substring(position, position + 64)));
      position += 64;
    }
    
    return addresses;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-VALUE DECODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Decode multiple return values.
  ///
  /// [types] specifies the types in order (e.g., ['uint256', 'address', 'bool']).
  static List<dynamic> decodeMultiple(String hex, List<String> types) {
    final clean = hex.replaceFirst('0x', '');
    final results = <dynamic>[];
    var position = 0;

    for (final type in types) {
      if (position + 64 > clean.length) break;

      final chunk = clean.substring(position, position + 64);

      switch (type) {
        case 'uint256':
        case 'uint128':
        case 'uint64':
        case 'uint32':
        case 'uint16':
        case 'uint8':
          results.add(BigInt.parse(chunk, radix: 16));
          break;
        case 'int256':
        case 'int128':
        case 'int64':
        case 'int32':
        case 'int16':
        case 'int8':
          results.add(decodeInt256('0x$chunk'));
          break;
        case 'address':
          results.add(decodeAddress(chunk));
          break;
        case 'bool':
          results.add(BigInt.parse(chunk, radix: 16) != BigInt.zero);
          break;
        case 'bytes32':
          results.add(_hexToBytes(chunk));
          break;
        default:
          // For dynamic types, this gets more complex
          // Handle string, bytes, arrays separately
          results.add(chunk);
      }

      position += 64;
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HASHING
  // ══════════════════════════════════════════════════════════════════════════

  /// Compute Keccak-256 hash.
  static List<int> keccak256(List<int> input) {
    final digest = KeccakDigest(256);
    final output = Uint8List(32);
    digest.update(Uint8List.fromList(input), 0, input.length);
    digest.doFinal(output, 0);
    return output.toList();
  }

  /// Compute Keccak-256 hash of hex string.
  static String keccak256Hex(String hexInput) {
    final bytes = _hexToBytes(hexInput.replaceFirst('0x', ''));
    final hash = keccak256(bytes);
    return '0x${_bytesToHex(hash)}';
  }

  /// Compute hash of packed parameters (solidityKeccak256).
  static String solidityKeccak256(List<dynamic> types, List<dynamic> values) {
    if (types.length != values.length) {
      throw ArgumentError('Types and values must have same length');
    }

    final packed = StringBuffer();
    
    for (var i = 0; i < types.length; i++) {
      final type = types[i] as String;
      final value = values[i];

      switch (type) {
        case 'address':
          packed.write((value as String).replaceFirst('0x', '').toLowerCase());
          break;
        case 'uint256':
          packed.write((value as BigInt).toRadixString(16).padLeft(64, '0'));
          break;
        case 'bytes32':
          final bytes = value as List<int>;
          packed.write(_bytesToHex(bytes).padRight(64, '0'));
          break;
        case 'string':
          packed.write(_bytesToHex(utf8.encode(value as String)));
          break;
        default:
          throw ArgumentError('Unsupported type for packed encoding: $type');
      }
    }

    return keccak256Hex(packed.toString());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Convert bytes to hex string.
  static String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
  }

  /// Convert hex string to bytes.
  static List<int> _hexToBytes(String hex) {
    final clean = hex.replaceFirst('0x', '');
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  /// Validate hex string format.
  static bool isValidHex(String hex) {
    final clean = hex.replaceFirst('0x', '');
    return RegExp(r'^[a-fA-F0-9]*$').hasMatch(clean);
  }

  /// Validate Ethereum address format.
  static bool isValidAddress(String address) {
    if (!address.startsWith('0x')) return false;
    if (address.length != 42) return false;
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
  }

  /// Checksum an Ethereum address (EIP-55).
  static String checksumAddress(String address) {
    final addr = address.toLowerCase().replaceFirst('0x', '');
    final hash = _bytesToHex(keccak256(utf8.encode(addr)));
    
    final result = StringBuffer('0x');
    for (var i = 0; i < addr.length; i++) {
      final char = addr[i];
      if (int.tryParse(char, radix: 16) != null && int.tryParse(char, radix: 16)! >= 0) {
        final hashChar = int.parse(hash[i], radix: 16);
        result.write(hashChar >= 8 ? char.toUpperCase() : char);
      } else {
        result.write(char);
      }
    }
    
    return result.toString();
  }

  /// Verify checksum of an Ethereum address.
  static bool verifyChecksum(String address) {
    if (!address.startsWith('0x')) return false;
    return address == checksumAddress(address);
  }
}
