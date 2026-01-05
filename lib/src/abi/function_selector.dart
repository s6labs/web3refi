import 'dart:typed_data';
import '../crypto/keccak.dart';

/// Function selector calculation for Ethereum smart contracts.
///
/// The function selector is the first 4 bytes of the Keccak-256 hash
/// of the canonical function signature.
///
/// ## Usage
///
/// ```dart
/// // Get selector for transfer(address,uint256)
/// final selector = FunctionSelector.fromSignature('transfer(address,uint256)');
/// print(selector.hex); // "0xa9059cbb"
///
/// // Encode function call
/// final data = selector.encodeCall([recipientAddress, amount]);
/// ```
class FunctionSelector {
  /// The 4-byte selector.
  final Uint8List bytes;

  const FunctionSelector(this.bytes) : assert(bytes.length == 4);

  /// Create selector from canonical function signature.
  ///
  /// Example signatures:
  /// - "transfer(address,uint256)"
  /// - "balanceOf(address)"
  /// - "approve(address,uint256)"
  factory FunctionSelector.fromSignature(String signature) {
    // TODO: Hash signature and take first 4 bytes
    // final hash = Keccak.keccak256(utf8.encode(signature));
    // return FunctionSelector(Uint8List.fromList(hash.sublist(0, 4)));

    throw UnimplementedError('Function selector calculation pending');
  }

  /// Create selector from hex string.
  factory FunctionSelector.fromHex(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.length != 8) {
      throw ArgumentError('Selector hex must be 8 characters (4 bytes)');
    }

    final bytes = hexToBytes(clean);
    return FunctionSelector(bytes);
  }

  /// Get hex representation with 0x prefix.
  String get hex => '0x${bytesToHex(bytes)}';

  /// Get hex without 0x prefix.
  String get hexWithoutPrefix => bytesToHex(bytes);

  /// Encode a function call with parameters.
  ///
  /// Returns selector + encoded parameters.
  String encodeCall(List<dynamic> parameters) {
    // TODO: Encode parameters and prepend selector
    throw UnimplementedError('Function call encoding pending');
  }

  /// Check if data starts with this selector.
  bool matches(String data) {
    final clean = data.startsWith('0x') ? data.substring(2) : data;
    return clean.startsWith(hexWithoutPrefix);
  }

  /// Extract selector from encoded call data.
  static FunctionSelector? extractFromCallData(String data) {
    final clean = data.startsWith('0x') ? data.substring(2) : data;
    if (clean.length < 8) return null;

    return FunctionSelector.fromHex(clean.substring(0, 8));
  }

  @override
  String toString() => hex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FunctionSelector &&
        bytes[0] == other.bytes[0] &&
        bytes[1] == other.bytes[1] &&
        bytes[2] == other.bytes[2] &&
        bytes[3] == other.bytes[3];
  }

  @override
  int get hashCode =>
      bytes[0] ^ bytes[1] << 8 ^ bytes[2] << 16 ^ bytes[3] << 24;
}

/// Common function selectors.
class CommonSelectors {
  /// ERC-20 transfer(address,uint256)
  static final transfer = FunctionSelector.fromHex('0xa9059cbb');

  /// ERC-20 approve(address,uint256)
  static final approve = FunctionSelector.fromHex('0x095ea7b3');

  /// ERC-20 transferFrom(address,address,uint256)
  static final transferFrom = FunctionSelector.fromHex('0x23b872dd');

  /// ERC-20 balanceOf(address)
  static final balanceOf = FunctionSelector.fromHex('0x70a08231');

  /// ERC-20 allowance(address,address)
  static final allowance = FunctionSelector.fromHex('0xdd62ed3e');

  /// ERC-721 safeTransferFrom(address,address,uint256)
  static final safeTransferFrom721 = FunctionSelector.fromHex('0x42842e0e');

  /// ERC-1155 safeTransferFrom(address,address,uint256,uint256,bytes)
  static final safeTransferFrom1155 = FunctionSelector.fromHex('0xf242432a');
}
