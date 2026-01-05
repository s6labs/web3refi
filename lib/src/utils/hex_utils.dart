import 'dart:convert';
import 'dart:typed_data';

/// Utilities for working with hexadecimal strings.
///
/// Blockchain data is typically represented as hex strings (prefixed with "0x").
/// This class provides comprehensive methods for conversion, validation,
/// and manipulation of hex data.
///
/// Example:
/// ```dart
/// // Convert hex to BigInt
/// final value = HexUtils.hexToBigInt('0x1a2b3c');
///
/// // Convert BigInt to hex
/// final hex = HexUtils.bigIntToHex(BigInt.from(1000000));
///
/// // Pad for ABI encoding
/// final padded = HexUtils.padLeft('0x1234', 64);
/// ```
abstract class HexUtils {
  HexUtils._();

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Hex prefix used in Ethereum and EVM chains.
  static const String hexPrefix = '0x';

  /// Empty hex data.
  static const String emptyHex = '0x';

  /// Zero value in hex.
  static const String zeroHex = '0x0';

  /// 32 bytes of zeros (common in ABI encoding).
  static const String zero32Bytes =
      '0x0000000000000000000000000000000000000000000000000000000000000000';

  /// Maximum uint256 value in hex.
  static const String maxUint256Hex =
      '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  /// Maximum uint256 as BigInt.
  static final BigInt maxUint256 = BigInt.parse(
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    radix: 16,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns true if [value] is a valid hex string.
  ///
  /// Valid hex strings:
  /// - Start with "0x" or "0X" (optional based on [requirePrefix])
  /// - Contain only hex characters (0-9, a-f, A-F)
  ///
  /// Example:
  /// ```dart
  /// HexUtils.isValidHex('0x1a2b3c'); // true
  /// HexUtils.isValidHex('1a2b3c');   // true (prefix not required by default)
  /// HexUtils.isValidHex('0xGHIJ');   // false (invalid characters)
  /// ```
  static bool isValidHex(String value, {bool requirePrefix = false}) {
    if (value.isEmpty) return false;

    String hex = value;
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    } else if (requirePrefix) {
      return false;
    }

    if (hex.isEmpty) return true; // '0x' alone is valid

    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  /// Returns true if [value] is a valid hex string with even length.
  ///
  /// Many operations require hex strings to have even length
  /// (each byte = 2 hex characters).
  static bool isValidHexBytes(String value) {
    if (!isValidHex(value)) return false;
    final clean = stripHexPrefix(value);
    return clean.length % 2 == 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PREFIX HANDLING
  // ══════════════════════════════════════════════════════════════════════════

  /// Removes the "0x" prefix if present.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.stripHexPrefix('0x1234'); // '1234'
  /// HexUtils.stripHexPrefix('1234');   // '1234'
  /// ```
  static String stripHexPrefix(String value) {
    if (value.startsWith('0x') || value.startsWith('0X')) {
      return value.substring(2);
    }
    return value;
  }

  /// Adds the "0x" prefix if not present.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.addHexPrefix('1234');   // '0x1234'
  /// HexUtils.addHexPrefix('0x1234'); // '0x1234'
  /// ```
  static String addHexPrefix(String value) {
    if (value.startsWith('0x') || value.startsWith('0X')) {
      return value.toLowerCase();
    }
    return '0x${value.toLowerCase()}';
  }

  /// Ensures hex string is lowercase with "0x" prefix.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.normalize('0X1A2B3C'); // '0x1a2b3c'
  /// HexUtils.normalize('1A2B3C');   // '0x1a2b3c'
  /// ```
  static String normalize(String value) {
    return addHexPrefix(stripHexPrefix(value).toLowerCase());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSION: HEX TO NUMBERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts a hex string to [int].
  ///
  /// Note: Use [hexToBigInt] for values that may exceed int range.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.hexToInt('0xff');   // 255
  /// HexUtils.hexToInt('0x100');  // 256
  /// ```
  static int hexToInt(String hex) {
    final clean = stripHexPrefix(hex);
    if (clean.isEmpty) return 0;
    return int.parse(clean, radix: 16);
  }

  /// Converts a hex string to [BigInt].
  ///
  /// Safe for large values like token amounts and uint256.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.hexToBigInt('0xde0b6b3a7640000'); // 1000000000000000000 (1 ETH in wei)
  /// ```
  static BigInt hexToBigInt(String hex) {
    final clean = stripHexPrefix(hex);
    if (clean.isEmpty) return BigInt.zero;
    return BigInt.parse(clean, radix: 16);
  }

  /// Converts a hex string to [double].
  ///
  /// Useful for gas prices and other floating-point values.
  static double hexToDouble(String hex) {
    return hexToBigInt(hex).toDouble();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSION: NUMBERS TO HEX
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts an [int] to hex string with "0x" prefix.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.intToHex(255);  // '0xff'
  /// HexUtils.intToHex(0);    // '0x0'
  /// ```
  static String intToHex(int value) {
    return '0x${value.toRadixString(16)}';
  }

  /// Converts a [BigInt] to hex string with "0x" prefix.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.bigIntToHex(BigInt.from(1000000)); // '0xf4240'
  /// ```
  static String bigIntToHex(BigInt value) {
    if (value == BigInt.zero) return '0x0';
    final isNegative = value.isNegative;
    final hex = value.abs().toRadixString(16);
    return isNegative ? '-0x$hex' : '0x$hex';
  }

  /// Converts a [BigInt] to a padded hex string (for ABI encoding).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.bigIntToHexPadded(BigInt.from(256), 64);
  /// // '0000000000000000000000000000000000000000000000000000000000000100'
  /// ```
  static String bigIntToHexPadded(BigInt value, int length) {
    final hex = value.toRadixString(16);
    return hex.padLeft(length, '0');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSION: HEX TO BYTES
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts a hex string to [Uint8List] (byte array).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.hexToBytes('0x1234'); // Uint8List [0x12, 0x34]
  /// ```
  static Uint8List hexToBytes(String hex) {
    String clean = stripHexPrefix(hex);

    // Ensure even length
    if (clean.length % 2 != 0) {
      clean = '0$clean';
    }

    final length = clean.length ~/ 2;
    final bytes = Uint8List(length);

    for (var i = 0; i < length; i++) {
      final byteHex = clean.substring(i * 2, i * 2 + 2);
      bytes[i] = int.parse(byteHex, radix: 16);
    }

    return bytes;
  }

  /// Converts a [Uint8List] to hex string with "0x" prefix.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.bytesToHex(Uint8List.fromList([0x12, 0x34])); // '0x1234'
  /// ```
  static String bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer('0x');
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSION: HEX TO STRING
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts a hex string to UTF-8 string.
  ///
  /// Useful for decoding string return values from contracts.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.hexToString('0x48656c6c6f'); // 'Hello'
  /// ```
  static String hexToString(String hex) {
    final bytes = hexToBytes(hex);
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Converts a UTF-8 string to hex.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.stringToHex('Hello'); // '0x48656c6c6f'
  /// ```
  static String stringToHex(String value) {
    final bytes = utf8.encode(value);
    return bytesToHex(Uint8List.fromList(bytes));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PADDING (ABI ENCODING)
  // ══════════════════════════════════════════════════════════════════════════

  /// Pads a hex string on the left to reach [length] characters.
  ///
  /// Used for ABI encoding where values must be 32 bytes (64 hex chars).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.padLeft('0x1234', 64);
  /// // '0x0000000000000000000000000000000000000000000000000000000000001234'
  /// ```
  static String padLeft(String hex, int length, {String padChar = '0'}) {
    final clean = stripHexPrefix(hex);
    if (clean.length >= length) return addHexPrefix(clean);
    return addHexPrefix(clean.padLeft(length, padChar));
  }

  /// Pads a hex string on the right to reach [length] characters.
  ///
  /// Used for ABI encoding of bytes and strings.
  static String padRight(String hex, int length, {String padChar = '0'}) {
    final clean = stripHexPrefix(hex);
    if (clean.length >= length) return addHexPrefix(clean);
    return addHexPrefix(clean.padRight(length, padChar));
  }

  /// Pads an address for ABI encoding (20 bytes -> 32 bytes).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.padAddress('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
  /// // '000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb'
  /// ```
  static String padAddress(String address) {
    final clean = stripHexPrefix(address).toLowerCase();
    return clean.padLeft(64, '0');
  }

  /// Pads a uint256 value for ABI encoding.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.padUint256(BigInt.from(1000));
  /// // '00000000000000000000000000000000000000000000000000000000000003e8'
  /// ```
  static String padUint256(BigInt value) {
    return bigIntToHexPadded(value, 64);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SLICING
  // ══════════════════════════════════════════════════════════════════════════

  /// Extracts a slice from a hex string.
  ///
  /// [start] and [end] are byte positions (not hex character positions).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.slice('0x1234567890', 0, 2); // '0x1234'
  /// HexUtils.slice('0x1234567890', 2, 4); // '0x5678'
  /// ```
  static String slice(String hex, int start, [int? end]) {
    final clean = stripHexPrefix(hex);
    final startChar = start * 2;
    final endChar = end != null ? end * 2 : clean.length;

    if (startChar >= clean.length) return emptyHex;
    if (endChar > clean.length) {
      return addHexPrefix(clean.substring(startChar));
    }

    return addHexPrefix(clean.substring(startChar, endChar));
  }

  /// Gets the first [n] bytes from a hex string.
  static String take(String hex, int n) {
    return slice(hex, 0, n);
  }

  /// Skips the first [n] bytes from a hex string.
  static String skip(String hex, int n) {
    return slice(hex, n);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONCATENATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Concatenates multiple hex strings.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.concat(['0x1234', '0x5678']); // '0x12345678'
  /// ```
  static String concat(List<String> hexStrings) {
    final buffer = StringBuffer();
    for (final hex in hexStrings) {
      buffer.write(stripHexPrefix(hex));
    }
    return addHexPrefix(buffer.toString());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPARISON
  // ══════════════════════════════════════════════════════════════════════════

  /// Compares two hex strings for equality (case-insensitive).
  ///
  /// Example:
  /// ```dart
  /// HexUtils.equals('0x1234', '0x1234'); // true
  /// HexUtils.equals('0x1234', '0X1234'); // true
  /// HexUtils.equals('1234', '0x1234');   // true
  /// ```
  static bool equals(String a, String b) {
    return normalize(a) == normalize(b);
  }

  /// Returns true if hex string is zero or empty.
  static bool isZero(String hex) {
    final clean = stripHexPrefix(hex);
    if (clean.isEmpty) return true;
    return BigInt.tryParse(clean, radix: 16) == BigInt.zero;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BYTE LENGTH
  // ══════════════════════════════════════════════════════════════════════════

  /// Returns the byte length of a hex string.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.byteLength('0x1234'); // 2
  /// HexUtils.byteLength('0x123');  // 2 (rounds up)
  /// ```
  static int byteLength(String hex) {
    final clean = stripHexPrefix(hex);
    return (clean.length + 1) ~/ 2;
  }

  /// Returns true if hex string has exactly [n] bytes.
  static bool hasLength(String hex, int n) {
    return byteLength(hex) == n;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORMATTING
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a hex string with spaces for readability.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.format('0x1234567890abcdef');
  /// // '12 34 56 78 90 ab cd ef'
  /// ```
  static String format(String hex, {int groupSize = 2, String separator = ' '}) {
    final clean = stripHexPrefix(hex);
    final buffer = StringBuffer();

    for (var i = 0; i < clean.length; i += groupSize) {
      if (i > 0) buffer.write(separator);
      final end = (i + groupSize < clean.length) ? i + groupSize : clean.length;
      buffer.write(clean.substring(i, end));
    }

    return buffer.toString();
  }

  /// Truncates a hex string for display.
  ///
  /// Example:
  /// ```dart
  /// HexUtils.truncate('0x1234567890abcdef', prefixLength: 4, suffixLength: 4);
  /// // '0x1234...cdef'
  /// ```
  static String truncate(
    String hex, {
    int prefixLength = 6,
    int suffixLength = 4,
    String ellipsis = '...',
  }) {
    final clean = stripHexPrefix(hex);
    if (clean.length <= prefixLength + suffixLength) {
      return addHexPrefix(clean);
    }

    final prefix = clean.substring(0, prefixLength);
    final suffix = clean.substring(clean.length - suffixLength);
    return '0x$prefix$ellipsis$suffix';
  }
}
