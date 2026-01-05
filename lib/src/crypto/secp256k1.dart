import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'signature.dart';

/// secp256k1 elliptic curve cryptography for Ethereum.
///
/// Provides signing and key pair operations using the secp256k1 curve
/// (same as Bitcoin and Ethereum).
///
/// ## Features
///
/// - Generate key pairs from private keys
/// - Sign messages with ECDSA
/// - Verify signatures
/// - Recover public keys from signatures
class Secp256k1 {
  Secp256k1._();

  /// Curve parameters for secp256k1
  static final ECDomainParameters _params = ECDomainParameters('secp256k1');

  /// Curve order (n).
  static final BigInt n = BigInt.parse(
    'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141',
    radix: 16,
  );

  /// Generate public key from private key.
  ///
  /// Returns 64-byte uncompressed public key (x, y coordinates).
  static Uint8List getPublicKey(Uint8List privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    // Convert private key bytes to BigInt
    final d = BigInt.parse(
      privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // Generate public key: Q = d * G
    final Q = _params.G * d;

    // Return uncompressed format (64 bytes: x || y)
    final xBytes = _encodeBigInt(Q!.x!.toBigInteger()!);
    final yBytes = _encodeBigInt(Q.y!.toBigInteger()!);

    final result = Uint8List(64);
    result.setAll(0, xBytes);
    result.setAll(32, yBytes);

    return result;
  }

  /// Get compressed public key (33 bytes).
  ///
  /// Format: [0x02 or 0x03][x-coordinate (32 bytes)]
  static Uint8List getPublicKeyCompressed(Uint8List privateKey) {
    final publicKey = getPublicKey(privateKey);

    // Extract y coordinate to determine prefix
    final yBytes = publicKey.sublist(32, 64);
    final y = BigInt.parse(
      yBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // Prefix: 0x02 if y is even, 0x03 if y is odd
    final prefix = y.isEven ? 0x02 : 0x03;

    final result = Uint8List(33);
    result[0] = prefix;
    result.setAll(1, publicKey.sublist(0, 32)); // x coordinate

    return result;
  }

  /// Sign message hash with private key.
  ///
  /// Returns ECDSA signature with recovery ID.
  static Signature sign(Uint8List messageHash, Uint8List privateKey) {
    if (messageHash.length != 32) {
      throw ArgumentError('Message hash must be 32 bytes');
    }
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }

    final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));
    final key = ECPrivateKey(
      BigInt.parse(
        privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      ),
      _params,
    );

    signer.init(true, PrivateKeyParameter(key));
    final sig = signer.generateSignature(messageHash) as ECSignature;

    // Use recovery ID = 0 for basic signing
    return Signature(r: sig.r, s: sig.s, v: 27);
  }

  /// Sign with specific recovery ID.
  ///
  /// Used for Ethereum transaction signing where we need recoverable signatures.
  static Signature signRecoverable(
    Uint8List messageHash,
    Uint8List privateKey, {
    int? chainId,
  }) {
    final sig = sign(messageHash, privateKey);

    // Calculate correct recovery ID
    final publicKey = getPublicKey(privateKey);
    final recoveryId = _findRecoveryId(sig, messageHash, publicKey);

    // Calculate v based on EIP-155 or legacy
    final int v;
    if (chainId != null) {
      // EIP-155: v = chainId * 2 + 35 + recoveryId
      v = chainId * 2 + 35 + recoveryId;
    } else {
      // Legacy: v = 27 + recoveryId
      v = 27 + recoveryId;
    }

    return Signature(r: sig.r, s: sig.s, v: v);
  }

  /// Verify signature.
  static bool verify(
    Signature signature,
    Uint8List messageHash,
    Uint8List publicKey,
  ) {
    try {
      final signer = ECDSASigner(null, HMac(SHA256Digest(), 64));

      // Parse public key
      final xBytes = publicKey.sublist(0, 32);
      final yBytes = publicKey.sublist(32, 64);

      final x = BigInt.parse(
        xBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );
      final y = BigInt.parse(
        yBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );

      final point = _params.curve.createPoint(x, y);
      final pubKey = ECPublicKey(point, _params);

      signer.init(false, PublicKeyParameter(pubKey));

      return signer.verifySignature(
        messageHash,
        ECSignature(signature.r, signature.s),
      );
    } catch (_) {
      return false;
    }
  }

  /// Recover public key from signature and message hash.
  static Uint8List recoverPublicKey(
    Signature signature,
    Uint8List messageHash,
  ) {
    final recoveryId = signature.recoveryId;

    // Try to recover the public key
    for (int i = 0; i < 4; i++) {
      try {
        final recovered = _recoverPublicKeyFromSignature(
          recoveryId,
          signature.r,
          signature.s,
          messageHash,
        );

        if (recovered != null) {
          return recovered;
        }
      } catch (_) {
        continue;
      }
    }

    throw StateError('Failed to recover public key');
  }

  /// Helper: Encode BigInt to 32-byte array
  static Uint8List _encodeBigInt(BigInt number) {
    final hex = number.toRadixString(16).padLeft(64, '0');
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Helper: Find correct recovery ID
  static int _findRecoveryId(
    Signature sig,
    Uint8List messageHash,
    Uint8List publicKey,
  ) {
    for (int i = 0; i < 4; i++) {
      try {
        final recovered = _recoverPublicKeyFromSignature(
          i,
          sig.r,
          sig.s,
          messageHash,
        );

        if (recovered != null &&
            _bytesEqual(recovered.sublist(0, 64), publicKey)) {
          return i;
        }
      } catch (_) {
        continue;
      }
    }
    return 0;
  }

  /// Helper: Recover public key from signature
  static Uint8List? _recoverPublicKeyFromSignature(
    int recoveryId,
    BigInt r,
    BigInt s,
    Uint8List messageHash,
  ) {
    try {
      // Implementation based on SEC1 4.1.6
      final n = _params.n;
      final i = BigInt.from(recoveryId ~/ 2);
      final x = r + (i * n);

      final prime = _params.curve.fieldSize;
      if (x.compareTo(prime) >= 0) return null;

      final R = _decompressKey(x, (recoveryId & 1) == 1);
      if (R == null) return null;

      final e = BigInt.parse(
        messageHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );

      final eInv = (BigInt.zero - e) % n;
      final rInv = r.modInverse(n);
      final srInv = (rInv * s) % n;
      final eInvrInv = (rInv * eInv) % n;

      final q = (_params.G * eInvrInv)! + (R * srInv)!;

      final qx = _encodeBigInt(q.x!.toBigInteger()!);
      final qy = _encodeBigInt(q.y!.toBigInteger()!);

      final result = Uint8List(64);
      result.setAll(0, qx);
      result.setAll(32, qy);

      return result;
    } catch (_) {
      return null;
    }
  }

  /// Helper: Decompress EC point
  static ECPoint? _decompressKey(BigInt x, bool yBit) {
    final curve = _params.curve as ECCurve_fp;
    final a = curve.a!.toBigInteger()!;
    final b = curve.b!.toBigInteger()!;
    final p = curve.fieldSize;

    // y² = x³ + ax + b
    final ySquared = (x.modPow(BigInt.from(3), p) + (a * x) + b) % p;

    // y = ySquared^((p+1)/4) mod p (works for p ≡ 3 mod 4)
    final y = ySquared.modPow((p + BigInt.one) >> 2, p);

    final yEven = y.isEven;
    final yFinal = (yEven == !yBit) ? y : p - y;

    return curve.createPoint(x, yFinal);
  }

  /// Helper: Compare byte arrays
  static bool _bytesEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Validate private key is in valid range.
  static bool isValidPrivateKey(Uint8List privateKey) {
    if (privateKey.length != 32) return false;

    final key = BigInt.parse(
      privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    // Must be in range [1, n-1]
    return key > BigInt.zero && key < n;
  }

  /// Validate public key format.
  static bool isValidPublicKey(Uint8List publicKey) {
    // Uncompressed: 64 bytes
    if (publicKey.length == 64) return true;

    // Compressed: 33 bytes starting with 0x02 or 0x03
    if (publicKey.length == 33) {
      return publicKey[0] == 0x02 || publicKey[0] == 0x03;
    }

    // Uncompressed with prefix: 65 bytes starting with 0x04
    if (publicKey.length == 65) {
      return publicKey[0] == 0x04;
    }

    return false;
  }
}
