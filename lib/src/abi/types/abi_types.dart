/// ABI type system for Ethereum smart contracts.
///
/// Defines the type system used in Ethereum's Application Binary Interface (ABI).
/// Supports all Solidity types including:
/// - Elementary types (uint, int, bool, address, bytes, string)
/// - Fixed-size arrays
/// - Dynamic arrays
/// - Tuples (structs)
library abi_types;

import 'dart:typed_data';

/// Base class for all ABI types.
abstract class AbiType {
  /// The canonical type string (e.g., "uint256", "address", "bytes32").
  String get canonicalType;

  /// Whether this is a dynamic type (requires length prefix).
  bool get isDynamic;

  /// Encode a value of this type.
  List<int> encode(dynamic value);

  /// Decode bytes into a value of this type.
  dynamic decode(List<int> data, int offset);

  /// Size in bytes for static types, null for dynamic types.
  int? get staticSize;

  /// Get the number of bytes consumed during decoding.
  int getDecodedSize(List<int> data, int offset);
}

/// Elementary types (uint, int, bool, address, fixed bytes).
class AbiElementaryType extends AbiType {
  final String name;
  final int? size; // For uintN, intN, bytesN

  AbiElementaryType(this.name, {this.size});

  @override
  String get canonicalType {
    if (size != null) {
      return '$name$size';
    }
    return name;
  }

  @override
  bool get isDynamic => name == 'string' || (name == 'bytes' && size == null);

  @override
  int? get staticSize => isDynamic ? null : 32;

  @override
  List<int> encode(dynamic value) {
    final result = <int>[];

    switch (name) {
      case 'uint':
      case 'int':
        result.addAll(_encodeInteger(value, signed: name == 'int'));
        break;

      case 'bool':
        result.addAll(_encodeBoolean(value));
        break;

      case 'address':
        result.addAll(_encodeAddress(value));
        break;

      case 'bytes':
        if (size != null) {
          // Fixed-size bytes
          result.addAll(_encodeFixedBytes(value));
        } else {
          // Dynamic bytes
          result.addAll(_encodeDynamicBytes(value));
        }
        break;

      case 'string':
        result.addAll(_encodeString(value));
        break;

      default:
        throw ArgumentError('Unknown type: $name');
    }

    return result;
  }

  @override
  dynamic decode(List<int> data, int offset) {
    switch (name) {
      case 'uint':
        return _decodeUint(data, offset);
      case 'int':
        return _decodeInt(data, offset);
      case 'bool':
        return _decodeBoolean(data, offset);
      case 'address':
        return _decodeAddress(data, offset);
      case 'bytes':
        if (size != null) {
          return _decodeFixedBytes(data, offset);
        } else {
          return _decodeDynamicBytes(data, offset);
        }
      case 'string':
        return _decodeString(data, offset);
      default:
        throw ArgumentError('Unknown type: $name');
    }
  }

  @override
  int getDecodedSize(List<int> data, int offset) {
    if (isDynamic) {
      // Read length prefix
      final length = _bytesToInt(data.sublist(offset, offset + 32));
      return 32 + ((length + 31) ~/ 32) * 32; // Length + padded data
    }
    return 32;
  }

  // Encoding helpers

  List<int> _encodeInteger(dynamic value, {required bool signed}) {
    BigInt bigValue;
    if (value is BigInt) {
      bigValue = value;
    } else if (value is int) {
      bigValue = BigInt.from(value);
    } else if (value is String) {
      bigValue = BigInt.parse(value);
    } else {
      throw ArgumentError('Invalid integer value');
    }

    // Validate range if size is specified
    if (size != null) {
      final maxBits = size!;
      if (signed) {
        final max = BigInt.two.pow(maxBits - 1) - BigInt.one;
        final min = -BigInt.two.pow(maxBits - 1);
        if (bigValue < min || bigValue > max) {
          throw ArgumentError('Value out of range for $canonicalType');
        }
      } else {
        final max = BigInt.two.pow(maxBits) - BigInt.one;
        if (bigValue < BigInt.zero || bigValue > max) {
          throw ArgumentError('Value out of range for $canonicalType');
        }
      }
    }

    return _padLeft(_bigIntToBytes(bigValue), 32);
  }

  List<int> _encodeBoolean(bool value) {
    return _padLeft([value ? 1 : 0], 32);
  }

  List<int> _encodeAddress(String address) {
    // Remove 0x prefix
    final clean = address.toLowerCase().replaceFirst('0x', '');
    if (clean.length != 40) {
      throw ArgumentError('Invalid address length');
    }

    final bytes = <int>[];
    for (int i = 0; i < 20; i++) {
      bytes.add(int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16));
    }

    return _padLeft(bytes, 32);
  }

  List<int> _encodeFixedBytes(dynamic value) {
    Uint8List bytes;
    if (value is Uint8List) {
      bytes = value;
    } else if (value is List<int>) {
      bytes = Uint8List.fromList(value);
    } else if (value is String) {
      final clean = value.replaceFirst('0x', '');
      bytes = Uint8List(clean.length ~/ 2);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
    } else {
      throw ArgumentError('Invalid bytes value');
    }

    if (bytes.length != size) {
      throw ArgumentError('Expected $size bytes, got ${bytes.length}');
    }

    return _padRight(bytes, 32);
  }

  List<int> _encodeDynamicBytes(dynamic value) {
    Uint8List bytes;
    if (value is Uint8List) {
      bytes = value;
    } else if (value is List<int>) {
      bytes = Uint8List.fromList(value);
    } else if (value is String) {
      final clean = value.replaceFirst('0x', '');
      bytes = Uint8List(clean.length ~/ 2);
      for (int i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      }
    } else {
      throw ArgumentError('Invalid bytes value');
    }

    final result = <int>[];
    // Length prefix
    result.addAll(_padLeft(_intToBytes(bytes.length), 32));
    // Data (right-padded to multiple of 32)
    result.addAll(_padRight(bytes, ((bytes.length + 31) ~/ 32) * 32));
    return result;
  }

  List<int> _encodeString(String value) {
    final bytes = Uint8List.fromList(value.codeUnits);
    return _encodeDynamicBytes(bytes);
  }

  // Decoding helpers

  BigInt _decodeUint(List<int> data, int offset) {
    final bytes = data.sublist(offset, offset + 32);
    return _bytesToBigInt(bytes);
  }

  BigInt _decodeInt(List<int> data, int offset) {
    final bytes = data.sublist(offset, offset + 32);
    final value = _bytesToBigInt(bytes);

    // Check if negative (sign bit set)
    if (bytes[0] & 0x80 != 0) {
      // Two's complement
      return value - (BigInt.one << 256);
    }
    return value;
  }

  bool _decodeBoolean(List<int> data, int offset) {
    return data[offset + 31] != 0;
  }

  String _decodeAddress(List<int> data, int offset) {
    final bytes = data.sublist(offset + 12, offset + 32);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hex';
  }

  Uint8List _decodeFixedBytes(List<int> data, int offset) {
    return Uint8List.fromList(data.sublist(offset, offset + size!));
  }

  Uint8List _decodeDynamicBytes(List<int> data, int offset) {
    final length = _bytesToInt(data.sublist(offset, offset + 32));
    return Uint8List.fromList(data.sublist(offset + 32, offset + 32 + length));
  }

  String _decodeString(List<int> data, int offset) {
    final bytes = _decodeDynamicBytes(data, offset);
    return String.fromCharCodes(bytes);
  }

  // Utility functions

  List<int> _padLeft(List<int> bytes, int length) {
    if (bytes.length >= length) return bytes;
    return List<int>.filled(length - bytes.length, 0) + bytes;
  }

  List<int> _padRight(List<int> bytes, int length) {
    if (bytes.length >= length) return bytes;
    return bytes + List<int>.filled(length - bytes.length, 0);
  }

  List<int> _bigIntToBytes(BigInt value) {
    if (value == BigInt.zero) return [0];

    final negative = value < BigInt.zero;
    var absValue = negative ? -value : value;

    final bytes = <int>[];
    while (absValue > BigInt.zero) {
      bytes.insert(0, (absValue & BigInt.from(0xff)).toInt());
      absValue >>= 8;
    }

    if (negative) {
      // Two's complement for 32 bytes
      final padded = _padLeft(bytes, 32);
      for (int i = 0; i < padded.length; i++) {
        padded[i] = ~padded[i] & 0xff;
      }
      // Add 1
      int carry = 1;
      for (int i = padded.length - 1; i >= 0 && carry > 0; i--) {
        final sum = padded[i] + carry;
        padded[i] = sum & 0xff;
        carry = sum >> 8;
      }
      return padded;
    }

    return bytes;
  }

  List<int> _intToBytes(int value) {
    return _bigIntToBytes(BigInt.from(value));
  }

  BigInt _bytesToBigInt(List<int> bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  int _bytesToInt(List<int> bytes) {
    return _bytesToBigInt(bytes).toInt();
  }
}

/// Array types (fixed and dynamic).
class AbiArrayType extends AbiType {
  final AbiType elementType;
  final int? length; // null for dynamic arrays

  AbiArrayType(this.elementType, {this.length});

  @override
  String get canonicalType {
    if (length != null) {
      return '${elementType.canonicalType}[$length]';
    }
    return '${elementType.canonicalType}[]';
  }

  @override
  bool get isDynamic => length == null || elementType.isDynamic;

  @override
  int? get staticSize => isDynamic ? null : (elementType.staticSize! * length!);

  @override
  List<int> encode(dynamic value) {
    if (value is! List) {
      throw ArgumentError('Array value must be a List');
    }

    if (length != null && value.length != length) {
      throw ArgumentError('Expected $length elements, got ${value.length}');
    }

    final result = <int>[];

    // For dynamic arrays, add length prefix
    if (length == null) {
      result.addAll(_padLeft(_intToBytes(value.length), 32));
    }

    // Encode each element
    for (final element in value) {
      result.addAll(elementType.encode(element));
    }

    return result;
  }

  @override
  dynamic decode(List<int> data, int offset) {
    int arrayLength;
    int dataOffset = offset;

    if (length == null) {
      // Dynamic array - read length
      arrayLength = _bytesToInt(data.sublist(offset, offset + 32));
      dataOffset += 32;
    } else {
      arrayLength = length!;
    }

    final result = [];
    for (int i = 0; i < arrayLength; i++) {
      result.add(elementType.decode(data, dataOffset));
      dataOffset += elementType.getDecodedSize(data, dataOffset);
    }

    return result;
  }

  @override
  int getDecodedSize(List<int> data, int offset) {
    int arrayLength;
    int size = 0;

    if (length == null) {
      arrayLength = _bytesToInt(data.sublist(offset, offset + 32));
      size = 32;
      offset += 32;
    } else {
      arrayLength = length!;
    }

    for (int i = 0; i < arrayLength; i++) {
      final elementSize = elementType.getDecodedSize(data, offset);
      size += elementSize;
      offset += elementSize;
    }

    return size;
  }

  List<int> _padLeft(List<int> bytes, int length) {
    if (bytes.length >= length) return bytes;
    return List<int>.filled(length - bytes.length, 0) + bytes;
  }

  List<int> _intToBytes(int value) {
    final bigValue = BigInt.from(value);
    final bytes = <int>[];
    var temp = bigValue;
    while (temp > BigInt.zero) {
      bytes.insert(0, (temp & BigInt.from(0xff)).toInt());
      temp >>= 8;
    }
    return bytes.isEmpty ? [0] : bytes;
  }

  int _bytesToInt(List<int> bytes) {
    int result = 0;
    for (final byte in bytes) {
      result = (result << 8) | byte;
    }
    return result;
  }
}

/// Tuple types (structs).
class AbiTupleType extends AbiType {
  final List<AbiType> components;

  AbiTupleType(this.components);

  @override
  String get canonicalType {
    final types = components.map((c) => c.canonicalType).join(',');
    return '($types)';
  }

  @override
  bool get isDynamic => components.any((c) => c.isDynamic);

  @override
  int? get staticSize {
    if (isDynamic) return null;
    return components.fold<int>(
      0,
      (sum, c) => sum + (c.staticSize ?? 0),
    );
  }

  @override
  List<int> encode(dynamic value) {
    if (value is! List) {
      throw ArgumentError('Tuple value must be a List');
    }

    if (value.length != components.length) {
      throw ArgumentError(
        'Expected ${components.length} components, got ${value.length}',
      );
    }

    final result = <int>[];
    for (int i = 0; i < components.length; i++) {
      result.addAll(components[i].encode(value[i]));
    }

    return result;
  }

  @override
  dynamic decode(List<int> data, int offset) {
    final result = [];
    int currentOffset = offset;

    for (final component in components) {
      result.add(component.decode(data, currentOffset));
      currentOffset += component.getDecodedSize(data, currentOffset);
    }

    return result;
  }

  @override
  int getDecodedSize(List<int> data, int offset) {
    int size = 0;
    int currentOffset = offset;

    for (final component in components) {
      final componentSize = component.getDecodedSize(data, currentOffset);
      size += componentSize;
      currentOffset += componentSize;
    }

    return size;
  }
}

/// Parse type string into AbiType.
///
/// Examples:
/// - "uint256" -> AbiElementaryType
/// - "address[]" -> AbiArrayType(AbiElementaryType)
/// - "tuple(uint256,address)" -> AbiTupleType
AbiType parseType(String typeString) {
  // Handle arrays
  if (typeString.endsWith(']')) {
    final bracketIndex = typeString.lastIndexOf('[');
    final baseType = typeString.substring(0, bracketIndex);
    final arrayPart = typeString.substring(bracketIndex + 1, typeString.length - 1);

    final elementType = parseType(baseType);

    if (arrayPart.isEmpty) {
      // Dynamic array
      return AbiArrayType(elementType);
    } else {
      // Fixed-size array
      final length = int.parse(arrayPart);
      return AbiArrayType(elementType, length: length);
    }
  }

  // Handle tuples
  if (typeString.startsWith('tuple(') || typeString.startsWith('(')) {
    String content;
    if (typeString.startsWith('tuple(')) {
      content = typeString.substring(6, typeString.length - 1);
    } else {
      content = typeString.substring(1, typeString.length - 1);
    }

    final components = _splitComponents(content);
    final types = components.map((c) => parseType(c)).toList();
    return AbiTupleType(types);
  }

  // Handle elementary types
  return _parseElementaryType(typeString);
}

AbiElementaryType _parseElementaryType(String typeString) {
  // uint, int with size
  final uintMatch = RegExp(r'^uint(\d+)$').firstMatch(typeString);
  if (uintMatch != null) {
    final size = int.parse(uintMatch.group(1)!);
    return AbiElementaryType('uint', size: size);
  }

  final intMatch = RegExp(r'^int(\d+)$').firstMatch(typeString);
  if (intMatch != null) {
    final size = int.parse(intMatch.group(1)!);
    return AbiElementaryType('int', size: size);
  }

  // bytes with size
  final bytesMatch = RegExp(r'^bytes(\d+)$').firstMatch(typeString);
  if (bytesMatch != null) {
    final size = int.parse(bytesMatch.group(1)!);
    return AbiElementaryType('bytes', size: size);
  }

  // Special cases
  switch (typeString) {
    case 'uint':
      return AbiElementaryType('uint', size: 256);
    case 'int':
      return AbiElementaryType('int', size: 256);
    case 'address':
      return AbiElementaryType('address');
    case 'bool':
      return AbiElementaryType('bool');
    case 'bytes':
      return AbiElementaryType('bytes');
    case 'string':
      return AbiElementaryType('string');
    default:
      throw ArgumentError('Unknown type: $typeString');
  }
}

List<String> _splitComponents(String content) {
  final components = <String>[];
  int depth = 0;
  int start = 0;

  for (int i = 0; i < content.length; i++) {
    if (content[i] == '(') {
      depth++;
    } else if (content[i] == ')') {
      depth--;
    } else if (content[i] == ',' && depth == 0) {
      components.add(content.substring(start, i).trim());
      start = i + 1;
    }
  }

  if (start < content.length) {
    components.add(content.substring(start).trim());
  }

  return components;
}

/// Common type constants.
class AbiTypes {
  static final uint256 = AbiElementaryType('uint', size: 256);
  static final uint128 = AbiElementaryType('uint', size: 128);
  static final uint64 = AbiElementaryType('uint', size: 64);
  static final uint32 = AbiElementaryType('uint', size: 32);
  static final uint16 = AbiElementaryType('uint', size: 16);
  static final uint8 = AbiElementaryType('uint', size: 8);

  static final int256 = AbiElementaryType('int', size: 256);
  static final address = AbiElementaryType('address');
  static final bool$ = AbiElementaryType('bool');
  static final bytes32 = AbiElementaryType('bytes', size: 32);
  static final bytes$ = AbiElementaryType('bytes');
  static final string = AbiElementaryType('string');
}
