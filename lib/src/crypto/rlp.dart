import 'dart:typed_data';

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
      // TODO: Convert string to bytes and encode
      throw UnimplementedError('String encoding pending');
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

  /// Encode byte array.
  static Uint8List _encodeBytes(Uint8List bytes) {
    if (bytes.isEmpty) {
      return Uint8List.fromList([0x80]);
    }

    // Single byte in range [0x00, 0x7f]
    if (bytes.length == 1 && bytes[0] < 0x80) {
      return bytes;
    }

    // TODO: Implement length prefix encoding
    throw UnimplementedError('Byte encoding pending');
  }

  /// Encode BigInt.
  static Uint8List _encodeBigInt(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List.fromList([0x80]);
    }

    // TODO: Convert BigInt to minimal bytes and encode
    throw UnimplementedError('BigInt encoding pending');
  }

  /// Encode int.
  static Uint8List _encodeInt(int value) {
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

    // TODO: Add list length prefix
    throw UnimplementedError('List encoding pending');
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

    // TODO: Implement RLP decoding
    throw UnimplementedError('RLP decoding pending');
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

    // TODO: Parse length from prefix
    throw UnimplementedError('Length parsing pending');
  }
}
