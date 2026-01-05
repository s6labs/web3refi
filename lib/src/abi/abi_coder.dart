import 'dart:typed_data';
import 'dart:convert';
import '../crypto/keccak.dart';
import 'function_selector.dart';

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
/// final balance = AbiCoder.decodeUint256(returnData);
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
    // TODO: Get function selector and encode parameters
    throw UnimplementedError('Function call encoding pending');
  }

  /// Encode parameters only (no function selector).
  static String encodeParameters(List<String> types, List<dynamic> values) {
    // TODO: Encode parameters according to ABI spec
    throw UnimplementedError('Parameter encoding pending');
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
    final hex = bytesToHex(bytes);
    return hex.padRight(64, '0'); // Right-pad for fixed bytes
  }

  /// Encode string.
  static String encodeString(String value) {
    // TODO: Encode as dynamic bytes with length prefix
    throw UnimplementedError('String encoding pending');
  }

  /// Encode dynamic bytes.
  static String encodeDynamicBytes(Uint8List bytes) {
    // TODO: Encode with length prefix
    throw UnimplementedError('Dynamic bytes encoding pending');
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
    // TODO: Decode dynamic bytes and convert to string
    throw UnimplementedError('String decoding pending');
  }

  /// Decode fixed bytes.
  static Uint8List decodeBytes(String hex, {required int size}) {
    final clean = hex.replaceFirst('0x', '');
    final bytesHex = clean.substring(0, size * 2);
    return hexToBytes(bytesHex);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENT ENCODING
  // ══════════════════════════════════════════════════════════════════════════

  /// Get event signature hash (topic[0]).
  ///
  /// Example: Transfer(address,address,uint256) ->
  ///   0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
  static String eventSignature(String signature) {
    // TODO: Hash event signature
    throw UnimplementedError('Event signature hashing pending');
  }

  /// Encode indexed event parameter.
  static String encodeIndexedParameter(dynamic value, String type) {
    // TODO: Encode and hash if needed (strings/bytes/arrays are hashed)
    throw UnimplementedError('Indexed parameter encoding pending');
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
    final params = paramsStr.isEmpty ? <String>[] : paramsStr.split(',');

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
}
