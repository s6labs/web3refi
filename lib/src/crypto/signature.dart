import 'dart:typed_data';

/// ECDSA signature representation for Ethereum transactions.
///
/// Ethereum uses secp256k1 elliptic curve signatures with recoverable
/// public keys (EIP-155 and later).
///
/// ## Structure
///
/// - `r`: First 32 bytes of signature
/// - `s`: Second 32 bytes of signature
/// - `v`: Recovery ID (27/28 for legacy, chainId * 2 + 35/36 for EIP-155)
class Signature {
  /// R component (32 bytes).
  final BigInt r;

  /// S component (32 bytes).
  final BigInt s;

  /// V component (recovery ID + chain info).
  final int v;

  const Signature({
    required this.r,
    required this.s,
    required this.v,
  });

  /// Create signature from compact representation (65 bytes).
  ///
  /// Format: [r (32 bytes)][s (32 bytes)][v (1 byte)]
  factory Signature.fromCompact(Uint8List compact) {
    if (compact.length != 65) {
      throw ArgumentError('Compact signature must be 65 bytes');
    }

    // TODO: Parse r, s, v from bytes
    throw UnimplementedError('Signature parsing pending');
  }

  /// Create signature from hex string.
  factory Signature.fromHex(String hex) {
    // TODO: Parse hex and create signature
    throw UnimplementedError('Hex signature parsing pending');
  }

  /// Serialize to compact 65-byte representation.
  Uint8List toCompact() {
    // TODO: Serialize r, s, v to bytes
    throw UnimplementedError('Signature serialization pending');
  }

  /// Serialize to hex string with 0x prefix.
  String toHex() {
    final compact = toCompact();
    return '0x${compact.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Get recovery ID (0 or 1) from v.
  int get recoveryId {
    // TODO: Extract recovery ID from v value
    throw UnimplementedError('Recovery ID extraction pending');
  }

  /// Check if this is an EIP-155 signature.
  bool get isEip155 => v >= 35;

  /// Extract chain ID from EIP-155 signature.
  ///
  /// Returns null for non-EIP-155 signatures.
  int? get chainId {
    if (!isEip155) return null;
    return (v - 35) ~/ 2;
  }

  /// Recover public key from signature and message hash.
  ///
  /// Returns 64-byte uncompressed public key (x, y coordinates).
  Uint8List recoverPublicKey(Uint8List messageHash) {
    // TODO: Implement ECDSA public key recovery
    throw UnimplementedError('Public key recovery pending');
  }

  /// Verify signature against message hash and public key.
  bool verify(Uint8List messageHash, Uint8List publicKey) {
    // TODO: Implement signature verification
    throw UnimplementedError('Signature verification pending');
  }

  @override
  String toString() => 'Signature(r: $r, s: $s, v: $v)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Signature && other.r == r && other.s == s && other.v == v;
  }

  @override
  int get hashCode => r.hashCode ^ s.hashCode ^ v.hashCode;
}
