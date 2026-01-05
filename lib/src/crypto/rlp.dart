import 'dart:typed_data';
import 'dart:convert';

/// Recursive Length Prefix (RLP) encoding for Ethereum.
///
/// RLP is the serialization format used for Ethereum transactions,
/// blocks, and other data structures.
///
/// ## Rules
///
/// - Single byte [0x00, 0x7f]: encoded as itself
/// - String 0-55 bytes: [0x80 + length, ...bytes]
/// - String 56+ bytes: [0xb7 + length_of_length, ...length, ...bytes]
/// - List 0-55 bytes: [0xc0 + length, ...items]
/// - List 56+ bytes: [0xf7 + length_of_length, ...length, ...items]
///
/// ## Usage
///
/// ```dart
/// // Encode a transaction
/// final encoded = RLP.encode([
///   nonce,
///   gasPrice,
///   gasLimit,
///   to,
///   value,
///   data,
/// ]);
///
/// // Decode
/// final decoded = RLP.decode(encoded);
/// ```
class RLP {
  RLP._();

  /// Encode a value to RLP bytes.
  ///
  /// Accepts:
  /// - Uint8List (byte array)
  /// - String (converted to bytes)
  /// - BigInt (converted to minimal bytes)
  /// - int (converted to bytes)
  /// - List (nested encoding)
  static Uint8List encode(dynamic input) {
    if (input is Uint8List) {
      return _encodeBytes(input);
    } else if (input is String) {
      return _encodeString(input);
    } else if (input is BigInt) {
      return _encodeBigInt(input);
    } else if (input is int) {
      return _encodeInt(input);
    } else if (input is List) {
      return _encodeList(input);
    } else {
      throw ArgumentError('Unsupported type: ${input.runtimeType}');
    }
  }

  /// Encode string to RLP.
  static Uint8List _encodeString(String str) {
    final bytes = Uint8List.fromList(utf8.encode(str));
    return _encodeBytes(bytes);
  }

  /// Encode byte array.
  static Uint8List _encodeBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return Uint8List.fromList([0x80]);
    }

    // Single byte in range [0x00, 0x7f]
    if (bytes.length == 1 && bytes[0] < 0x80) {
      return bytes;
    }

    // String 0-55 bytes
    if (bytes.length <= 55) {
      final result = Uint8List(1 + bytes.length);
      result[0] = 0x80 + bytes.length;
      result.setAll(1, bytes);
      return result;
    }

    // String 56+ bytes
    final lengthBytes = _toBigEndianBytes(bytes.length);
    final result = Uint8List(1 + lengthBytes.length + bytes.length);
    result[0] = 0xb7 + lengthBytes.length;
    result.setAll(1, lengthBytes);
    result.setAll(1 + lengthBytes.length, bytes);
    return result;
  }

  /// Encode BigInt.
  static Uint8List _encodeBigInt(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List.fromList([0x80]);
    }

    if (value < BigInt.zero) {
      throw ArgumentError('RLP does not support negative numbers');
    }

    // Convert to minimal byte representation (no leading zeros)
    final bytes = _bigIntToBytes(value);
    return _encodeBytes(bytes);
  }

  /// Encode int.
  static Uint8List _encodeInt(int value) {
    if (value < 0) {
      throw ArgumentError('RLP does not support negative numbers');
    }
    return _encodeBigInt(BigInt.from(value));
  }

  /// Encode list of values.
  static Uint8List _encodeList(List items) {
    // Encode each item
    final encodedItems = items.map((item) => encode(item)).toList();

    // Concatenate all encoded items
    final totalLength = encodedItems.fold<int>(
      0,
      (sum, item) => sum + item.length,
    );

    // List 0-55 bytes
    if (totalLength <= 55) {
      final result = Uint8List(1 + totalLength);
      result[0] = 0xc0 + totalLength;
      int offset = 1;
      for (final item in encodedItems) {
        result.setAll(offset, item);
        offset += item.length;
      }
      return result;
    }

    // List 56+ bytes
    final lengthBytes = _toBigEndianBytes(totalLength);
    final result = Uint8List(1 + lengthBytes.length + totalLength);
    result[0] = 0xf7 + lengthBytes.length;
    result.setAll(1, lengthBytes);
    int offset = 1 + lengthBytes.length;
    for (final item in encodedItems) {
      result.setAll(offset, item);
      offset += item.length;
    }
    return result;
  }

  /// Decode RLP bytes.
  ///
  /// Returns either:
  /// - Uint8List for encoded bytes
  /// - List for encoded lists (may contain nested lists/bytes)
  static dynamic decode(Uint8List input) {
    if (input.isEmpty) {
      throw ArgumentError('Cannot decode empty input');
    }

    final result = _decode(input, 0);
    return result.value;
  }

  /// Internal decode with offset tracking.
  static _DecodeResult _decode(Uint8List input, int offset) {
    if (offset >= input.length) {
      throw ArgumentError('Offset exceeds input length');
    }

    final prefix = input[offset];

    // Single byte [0x00, 0x7f]
    if (prefix <= 0x7f) {
      return _DecodeResult(
        value: Uint8List.fromList([prefix]),
        consumed: 1,
      );
    }

    // String 0-55 bytes: [0x80, 0xb7]
    if (prefix <= 0xb7) {
      final length = prefix - 0x80;
      if (length == 0) {
        return _DecodeResult(
          value: Uint8List(0),
          consumed: 1,
        );
      }

      if (offset + 1 + length > input.length) {
        throw ArgumentError('Input too short for declared length');
      }

      return _DecodeResult(
        value: Uint8List.fromList(input.sublist(offset + 1, offset + 1 + length)),
        consumed: 1 + length,
      );
    }

    // String 56+ bytes: [0xb8, 0xbf]
    if (prefix <= 0xbf) {
      final lengthOfLength = prefix - 0xb7;
      if (offset + 1 + lengthOfLength > input.length) {
        throw ArgumentError('Input too short for length bytes');
      }

      final lengthBytes = input.sublist(offset + 1, offset + 1 + lengthOfLength);
      final length = _fromBigEndianBytes(lengthBytes);

      if (offset + 1 + lengthOfLength + length > input.length) {
        throw ArgumentError('Input too short for declared length');
      }

      return _DecodeResult(
        value: Uint8List.fromList(
          input.sublist(
            offset + 1 + lengthOfLength,
            offset + 1 + lengthOfLength + length,
          ),
        ),
        consumed: 1 + lengthOfLength + length,
      );
    }

    // List 0-55 bytes: [0xc0, 0xf7]
    if (prefix <= 0xf7) {
      final length = prefix - 0xc0;
      if (length == 0) {
        return _DecodeResult(
          value: [],
          consumed: 1,
        );
      }

      if (offset + 1 + length > input.length) {
        throw ArgumentError('Input too short for declared list length');
      }

      final items = <dynamic>[];
      int consumed = 1;
      int itemOffset = offset + 1;

      while (consumed < 1 + length) {
        final item = _decode(input, itemOffset);
        items.add(item.value);
        consumed += item.consumed;
        itemOffset += item.consumed;
      }

      return _DecodeResult(
        value: items,
        consumed: consumed,
      );
    }

    // List 56+ bytes: [0xf8, 0xff]
    final lengthOfLength = prefix - 0xf7;
    if (offset + 1 + lengthOfLength > input.length) {
      throw ArgumentError('Input too short for list length bytes');
    }

    final lengthBytes = input.sublist(offset + 1, offset + 1 + lengthOfLength);
    final length = _fromBigEndianBytes(lengthBytes);

    if (offset + 1 + lengthOfLength + length > input.length) {
      throw ArgumentError('Input too short for declared list length');
    }

    final items = <dynamic>[];
    int consumed = 1 + lengthOfLength;
    int itemOffset = offset + 1 + lengthOfLength;
    final endOffset = offset + 1 + lengthOfLength + length;

    while (itemOffset < endOffset) {
      final item = _decode(input, itemOffset);
      items.add(item.value);
      consumed += item.consumed;
      itemOffset += item.consumed;
    }

    return _DecodeResult(
      value: items,
      consumed: consumed,
    );
  }

  /// Decode to list (throws if not a list).
  static List<dynamic> decodeList(Uint8List input) {
    final result = decode(input);
    if (result is! List) {
      throw ArgumentError('Input is not an RLP-encoded list');
    }
    return result;
  }

  /// Decode to bytes (throws if not bytes).
  static Uint8List decodeBytes(Uint8List input) {
    final result = decode(input);
    if (result is! Uint8List) {
      throw ArgumentError('Input is not RLP-encoded bytes');
    }
    return result;
  }

  /// Get the length of RLP-encoded data without decoding.
  static int getLength(Uint8List input) {
    if (input.isEmpty) return 0;

    final prefix = input[0];

    // Single byte
    if (prefix <= 0x7f) return 1;

    // String 0-55 bytes
    if (prefix <= 0xb7) {
      return 1 + (prefix - 0x80);
    }

    // String 56+ bytes
    if (prefix <= 0xbf) {
      final lengthOfLength = prefix - 0xb7;
      final lengthBytes = input.sublist(1, 1 + lengthOfLength);
      final length = _fromBigEndianBytes(lengthBytes);
      return 1 + lengthOfLength + length;
    }

    // List 0-55 bytes
    if (prefix <= 0xf7) {
      return 1 + (prefix - 0xc0);
    }

    // List 56+ bytes
    final lengthOfLength = prefix - 0xf7;
    final lengthBytes = input.sublist(1, 1 + lengthOfLength);
    final length = _fromBigEndianBytes(lengthBytes);
    return 1 + lengthOfLength + length;
  }

  /// Convert BigInt to minimal byte representation (no leading zeros).
  static Uint8List _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List(0);
    }

    // Convert to hex and parse
    final hex = value.toRadixString(16);
    final paddedHex = hex.length.isOdd ? '0$hex' : hex;

    final bytes = Uint8List(paddedHex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = int.parse(paddedHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return bytes;
  }

  /// Convert integer to big-endian bytes.
  static Uint8List _toBigEndianBytes(int value) {
    if (value == 0) {
      return Uint8List.fromList([0]);
    }

    final bytes = <int>[];
    int remaining = value;

    while (remaining > 0) {
      bytes.insert(0, remaining & 0xff);
      remaining >>= 8;
    }

    return Uint8List.fromList(bytes);
  }

  /// Convert big-endian bytes to integer.
  static int _fromBigEndianBytes(Uint8List bytes) {
    int result = 0;
    for (final byte in bytes) {
      result = (result << 8) | byte;
    }
    return result;
  }
}

/// Internal class for tracking decode results.
class _DecodeResult {
  final dynamic value;
  final int consumed;

  _DecodeResult({required this.value, required this.consumed});
}
