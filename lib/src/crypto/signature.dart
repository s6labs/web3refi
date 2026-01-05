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

    // Extract r (first 32 bytes)
    final rBytes = compact.sublist(0, 32);
    final r = BigInt.parse(
      rBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // Extract s (next 32 bytes)
    final sBytes = compact.sublist(32, 64);
    final s = BigInt.parse(
      sBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // Extract v (last byte)
    final v = compact[64];

    return Signature(r: r, s: s, v: v);
  }

  /// Create signature from hex string.
  factory Signature.fromHex(String hex) {
    final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;

    if (cleanHex.length != 130) {
      throw ArgumentError('Hex signature must be 130 characters (65 bytes)');
    }

    final bytes = Uint8List(65);
    for (int i = 0; i < 65; i++) {
      bytes[i] = int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return Signature.fromCompact(bytes);
  }

  /// Serialize to compact 65-byte representation.
  Uint8List toCompact() {
    final result = Uint8List(65);

    // Serialize r (32 bytes)
    final rHex = r.toRadixString(16).padLeft(64, '0');
    for (int i = 0; i < 32; i++) {
      result[i] = int.parse(rHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    // Serialize s (32 bytes)
    final sHex = s.toRadixString(16).padLeft(64, '0');
    for (int i = 0; i < 32; i++) {
      result[32 + i] = int.parse(sHex.substring(i * 2, i * 2 + 2), radix: 16);
    }

    // Serialize v (1 byte)
    result[64] = v;

    return result;
  }

  /// Serialize to hex string with 0x prefix.
  String toHex() {
    final compact = toCompact();
    return '0x${compact.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Get recovery ID (0 or 1) from v.
  int get recoveryId {
    if (isEip155) {
      // For EIP-155: v = chainId * 2 + 35 + recoveryId
      return v - (chainId! * 2 + 35);
    } else {
      // For legacy: v = 27 + recoveryId
      return v - 27;
    }
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
    // Import at usage to avoid circular dependency
    // ignore: depend_on_referenced_packages
    return secp256k1.Secp256k1.recoverPublicKey(this, messageHash);
  }

  /// Verify signature against message hash and public key.
  bool verify(Uint8List messageHash, Uint8List publicKey) {
    // Import at usage to avoid circular dependency
    // ignore: depend_on_referenced_packages
    return secp256k1.Secp256k1.verify(this, messageHash, publicKey);
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
