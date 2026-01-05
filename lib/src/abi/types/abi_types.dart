/// ABI type system for Ethereum smart contracts.
///
/// Defines the type system used in Ethereum's Application Binary Interface (ABI).
/// Supports all Solidity types including:
/// - Elementary types (uint, int, bool, address, bytes, string)
/// - Fixed-size arrays
/// - Dynamic arrays
/// - Tuples (structs)
library abi_types;

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
  bool get isDynamic => name == 'string' || name == 'bytes';

  @override
  int? get staticSize => isDynamic ? null : 32;

  @override
  List<int> encode(dynamic value) {
    // TODO: Implement elementary type encoding
    throw UnimplementedError('Elementary type encoding pending');
  }

  @override
  dynamic decode(List<int> data, int offset) {
    // TODO: Implement elementary type decoding
    throw UnimplementedError('Elementary type decoding pending');
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
    // TODO: Implement array encoding
    throw UnimplementedError('Array encoding pending');
  }

  @override
  dynamic decode(List<int> data, int offset) {
    // TODO: Implement array decoding
    throw UnimplementedError('Array decoding pending');
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
    // TODO: Implement tuple encoding
    throw UnimplementedError('Tuple encoding pending');
  }

  @override
  dynamic decode(List<int> data, int offset) {
    // TODO: Implement tuple decoding
    throw UnimplementedError('Tuple decoding pending');
  }
}

/// Parse type string into AbiType.
///
/// Examples:
/// - "uint256" -> AbiElementaryType
/// - "address[]" -> AbiArrayType(AbiElementaryType)
/// - "tuple(uint256,address)" -> AbiTupleType
AbiType parseType(String typeString) {
  // TODO: Implement type string parsing
  throw UnimplementedError('Type parsing pending');
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
