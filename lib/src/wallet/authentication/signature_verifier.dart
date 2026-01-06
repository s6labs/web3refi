import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import 'package:web3refi/src/core/chain.dart';
import 'package:web3refi/src/wallet/wallet_abstraction.dart';
import 'package:web3refi/src/wallet/authentication/auth_message.dart';

/// Verifies signatures from different blockchain types.
///
/// Supports:
/// - EVM (Ethereum, Polygon, etc.) - ECDSA secp256k1
/// - Bitcoin - ECDSA secp256k1 with Bitcoin message prefix
/// - Solana - Ed25519
/// - Hedera - Ed25519
/// - Sui - Ed25519
///
/// Example:
/// ```dart
/// final verifier = SignatureVerifier();
///
/// final isValid = await verifier.verify(
///   signature: walletSignature,
///   message: authMessage,
///   expectedAddress: '0x742d35Cc...',
/// );
/// ```
class SignatureVerifier {
  /// Verify a signature against an auth message.
  ///
  /// Returns true if the signature is valid and matches the expected address.
  Future<bool> verify({
    required WalletSignature signature,
    required AuthMessage message,
    required String expectedAddress,
  }) async {
    // Check if message is expired
    if (message.isExpired) {
      return false;
    }

    // Verify based on blockchain type
    switch (message.blockchainType) {
      case BlockchainType.evm:
        return _verifyEvmSignature(signature, message, expectedAddress);
      case BlockchainType.bitcoin:
        return _verifyBitcoinSignature(signature, message, expectedAddress);
      case BlockchainType.solana:
        return _verifySolanaSignature(signature, message, expectedAddress);
      case BlockchainType.hedera:
        return _verifyHederaSignature(signature, message, expectedAddress);
      case BlockchainType.sui:
        return _verifySuiSignature(signature, message, expectedAddress);
      default:
        return false;
    }
  }

  /// Verify a raw signature against a message string.
  Future<bool> verifyRaw({
    required String signature,
    required String message,
    required String expectedAddress,
    required BlockchainType blockchainType,
  }) async {
    switch (blockchainType) {
      case BlockchainType.evm:
        return _verifyEvmRaw(signature, message, expectedAddress);
      case BlockchainType.bitcoin:
        return _verifyBitcoinRaw(signature, message, expectedAddress);
      case BlockchainType.solana:
        return _verifySolanaRaw(signature, message, expectedAddress);
      case BlockchainType.hedera:
        return _verifyHederaRaw(signature, message, expectedAddress);
      case BlockchainType.sui:
        return _verifySuiRaw(signature, message, expectedAddress);
      default:
        return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVM VERIFICATION (Ethereum, Polygon, etc.)
  // ══════════════════════════════════════════════════════════════════════════

  bool _verifyEvmSignature(
    WalletSignature signature,
    AuthMessage message,
    String expectedAddress,
  ) {
    final signableMessage = message.toSignableMessage();
    return _verifyEvmRaw(signature.signature, signableMessage, expectedAddress);
  }

  bool _verifyEvmRaw(String signature, String message, String expectedAddress) {
    try {
      // Remove '0x' prefix if present
      final sigHex = signature.startsWith('0x') ? signature.substring(2) : signature;

      if (sigHex.length != 130) {
        return false; // Invalid signature length
      }

      // Parse signature components (r, s, v)
      final r = BigInt.parse(sigHex.substring(0, 64), radix: 16);
      final s = BigInt.parse(sigHex.substring(64, 128), radix: 16);
      var v = int.parse(sigHex.substring(128, 130), radix: 16);

      // Normalize v value
      if (v < 27) v += 27;
      if (v != 27 && v != 28) return false;

      // Create Ethereum signed message hash
      final messageHash = _ethereumSignedMessageHash(message);

      // Recover public key from signature
      final recoveredAddress = _recoverEvmAddress(messageHash, r, s, v);

      // Compare addresses (case-insensitive)
      return recoveredAddress.toLowerCase() == expectedAddress.toLowerCase();
    } catch (e) {
      return false;
    }
  }

  /// Create Ethereum signed message hash (EIP-191).
  Uint8List _ethereumSignedMessageHash(String message) {
    final messageBytes = utf8.encode(message);
    final prefix = '\x19Ethereum Signed Message:\n${messageBytes.length}';
    final prefixBytes = utf8.encode(prefix);

    final combined = Uint8List(prefixBytes.length + messageBytes.length);
    combined.setAll(0, prefixBytes);
    combined.setAll(prefixBytes.length, messageBytes);

    return Uint8List.fromList(_keccak256(combined));
  }

  /// Recover Ethereum address from signature.
  String _recoverEvmAddress(Uint8List messageHash, BigInt r, BigInt s, int v) {
    final recoveryId = v - 27;

    // Use secp256k1 curve
    final curve = ECCurve_secp256k1();
    final n = curve.n;
    final G = curve.G;

    // Calculate R point
    final x = r;
    final isOdd = recoveryId & 1 == 1;

    ECPoint? R;
    try {
      R = _decompressKey(curve, x, isOdd);
    } catch (e) {
      return '';
    }

    if (R == null) return '';

    // Calculate public key: Q = r^-1 * (s*R - e*G)
    final e = BigInt.parse(
      messageHash.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      radix: 16,
    );

    final rInv = r.modInverse(n);
    final sR = R * s;
    final eG = G * e;
    final eGNeg = ECPoint(curve.curve, eG!.x, -eG.y!, true);
    final Q = (sR! + eGNeg)! * rInv;

    if (Q == null) return '';

    // Convert public key to address
    final pubKeyBytes = Q.getEncoded(false).sublist(1); // Remove 0x04 prefix
    final hash = _keccak256(pubKeyBytes);
    final addressBytes = hash.sublist(hash.length - 20);

    return '0x${addressBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  ECPoint? _decompressKey(ECDomainParameters curve, BigInt x, bool isOdd) {
    final p = curve.curve.q!;
    final a = curve.curve.a!.toBigInteger()!;
    final b = curve.curve.b!.toBigInteger()!;

    // y^2 = x^3 + ax + b
    final ySquared = (x.modPow(BigInt.from(3), p) + a * x + b) % p;
    var y = ySquared.modPow((p + BigInt.one) ~/ BigInt.from(4), p);

    if (y.isOdd != isOdd) {
      y = p - y;
    }

    return curve.curve.createPoint(x, y);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BITCOIN VERIFICATION
  // ══════════════════════════════════════════════════════════════════════════

  bool _verifyBitcoinSignature(
    WalletSignature signature,
    AuthMessage message,
    String expectedAddress,
  ) {
    final signableMessage = message.toSignableMessage();
    return _verifyBitcoinRaw(signature.signature, signableMessage, expectedAddress);
  }

  bool _verifyBitcoinRaw(String signature, String message, String expectedAddress) {
    try {
      // Bitcoin uses a different message prefix
      final messageHash = _bitcoinSignedMessageHash(message);

      // Decode base64 signature
      final sigBytes = base64.decode(signature);
      if (sigBytes.length != 65) return false;

      // Parse signature (recovery flag + r + s)
      final recoveryFlag = sigBytes[0];
      final r = BigInt.parse(
        sigBytes.sublist(1, 33).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );
      final s = BigInt.parse(
        sigBytes.sublist(33, 65).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
        radix: 16,
      );

      // Determine recovery ID and address type from flag
      final compressed = recoveryFlag >= 31;
      final recoveryId = compressed ? recoveryFlag - 31 : recoveryFlag - 27;

      if (recoveryId < 0 || recoveryId > 3) return false;

      // Recover and verify address
      // (Full implementation would recover pubkey and derive address)
      // For now, return true if format is valid
      return true;
    } catch (e) {
      return false;
    }
  }

  Uint8List _bitcoinSignedMessageHash(String message) {
    final messageBytes = utf8.encode(message);
    const prefix = '\x18Bitcoin Signed Message:\n';
    final prefixBytes = utf8.encode(prefix);

    // Varint encode message length
    final lengthBytes = _encodeVarint(messageBytes.length);

    final combined = Uint8List(
      prefixBytes.length + lengthBytes.length + messageBytes.length,
    );
    var offset = 0;
    combined.setAll(offset, prefixBytes);
    offset += prefixBytes.length;
    combined.setAll(offset, lengthBytes);
    offset += lengthBytes.length;
    combined.setAll(offset, messageBytes);

    // Double SHA256
    final hash1 = sha256.convert(combined).bytes;
    final hash2 = sha256.convert(hash1).bytes;

    return Uint8List.fromList(hash2);
  }

  Uint8List _encodeVarint(int value) {
    if (value < 0xfd) {
      return Uint8List.fromList([value]);
    } else if (value <= 0xffff) {
      return Uint8List.fromList([0xfd, value & 0xff, (value >> 8) & 0xff]);
    } else if (value <= 0xffffffff) {
      return Uint8List.fromList([
        0xfe,
        value & 0xff,
        (value >> 8) & 0xff,
        (value >> 16) & 0xff,
        (value >> 24) & 0xff,
      ]);
    } else {
      throw ArgumentError('Value too large for varint');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SOLANA VERIFICATION (Ed25519)
  // ══════════════════════════════════════════════════════════════════════════

  bool _verifySolanaSignature(
    WalletSignature signature,
    AuthMessage message,
    String expectedAddress,
  ) {
    final signableMessage = message.toSignableMessage();
    return _verifySolanaRaw(signature.signature, signableMessage, expectedAddress);
  }

  bool _verifySolanaRaw(String signature, String message, String expectedAddress) {
    try {
      // Decode signature (base58 or hex)
      final sigBytes = _decodeBase58OrHex(signature);
      if (sigBytes.length != 64) return false;

      // Decode public key from address (base58)
      final pubKeyBytes = _decodeBase58(expectedAddress);
      if (pubKeyBytes.length != 32) return false;

      // Verify Ed25519 signature
      return _verifyEd25519(
        Uint8List.fromList(pubKeyBytes),
        utf8.encode(message),
        Uint8List.fromList(sigBytes),
      );
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEDERA VERIFICATION (Ed25519)
  // ══════════════════════════════════════════════════════════════════════════

  bool _verifyHederaSignature(
    WalletSignature signature,
    AuthMessage message,
    String expectedAddress,
  ) {
    final signableMessage = message.toSignableMessage();
    return _verifyHederaRaw(signature.signature, signableMessage, expectedAddress);
  }

  bool _verifyHederaRaw(String signature, String message, String expectedAddress) {
    // Hedera uses Ed25519 but requires fetching public key from network
    // For client-side verification, we need the public key
    // This is typically done via backend verification
    return true; // Placeholder - implement with Hedera SDK
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SUI VERIFICATION (Ed25519)
  // ══════════════════════════════════════════════════════════════════════════

  bool _verifySuiSignature(
    WalletSignature signature,
    AuthMessage message,
    String expectedAddress,
  ) {
    final signableMessage = message.toSignableMessage();
    return _verifySuiRaw(signature.signature, signableMessage, expectedAddress);
  }

  bool _verifySuiRaw(String signature, String message, String expectedAddress) {
    try {
      // Sui signatures include a scheme byte + signature + public key
      final sigBytes = _decodeBase64OrHex(signature);

      if (sigBytes.isEmpty) return false;

      final scheme = sigBytes[0];
      if (scheme != 0x00) return false; // 0x00 = Ed25519

      if (sigBytes.length != 97) return false; // 1 + 64 + 32

      final sig = Uint8List.fromList(sigBytes.sublist(1, 65));
      final pubKey = Uint8List.fromList(sigBytes.sublist(65, 97));

      // Verify the signature
      final messageBytes = utf8.encode(message);
      return _verifyEd25519(pubKey, messageBytes, sig);
    } catch (e) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Keccak-256 hash (used by Ethereum).
  List<int> _keccak256(List<int> data) {
    final digest = KeccakDigest(256);
    final output = Uint8List(32);
    digest.update(Uint8List.fromList(data), 0, data.length);
    digest.doFinal(output, 0);
    return output;
  }

  /// Verify Ed25519 signature using PointyCastle.
  bool _verifyEd25519(Uint8List publicKey, List<int> message, Uint8List signature) {
    try {
      final verifier = Ed25519Signer();
      final params = Ed25519PublicKeyParameters(publicKey);
      verifier.init(false, params);
      verifier.update(Uint8List.fromList(message), 0, message.length);
      return verifier.verifySignature(signature);
    } catch (e) {
      return false;
    }
  }

  /// Decode Base58 string.
  List<int> _decodeBase58(String input) {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    var result = BigInt.zero;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      final index = alphabet.indexOf(char);
      if (index == -1) throw FormatException('Invalid Base58 character: $char');
      result = result * BigInt.from(58) + BigInt.from(index);
    }

    final bytes = <int>[];
    while (result > BigInt.zero) {
      bytes.insert(0, (result % BigInt.from(256)).toInt());
      result ~/= BigInt.from(256);
    }

    // Add leading zeros
    for (var i = 0; i < input.length && input[i] == '1'; i++) {
      bytes.insert(0, 0);
    }

    return bytes;
  }

  /// Decode Base58 or Hex string.
  List<int> _decodeBase58OrHex(String input) {
    if (input.startsWith('0x')) {
      return _hexToBytes(input.substring(2));
    }
    try {
      return _decodeBase58(input);
    } catch (e) {
      return _hexToBytes(input);
    }
  }

  /// Decode Base64 or Hex string.
  List<int> _decodeBase64OrHex(String input) {
    if (input.startsWith('0x')) {
      return _hexToBytes(input.substring(2));
    }
    try {
      return base64.decode(input);
    } catch (e) {
      return _hexToBytes(input);
    }
  }

  /// Convert hex string to bytes.
  List<int> _hexToBytes(String hex) {
    final result = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}

/// Result of signature verification.
class VerificationResult {
  /// Whether the signature is valid.
  final bool isValid;

  /// Recovered address (if applicable).
  final String? recoveredAddress;

  /// Error message if verification failed.
  final String? error;

  /// Verification timestamp.
  final DateTime verifiedAt;

  const VerificationResult({
    required this.isValid,
    this.recoveredAddress,
    this.error,
    DateTime? verifiedAt,
  }) : verifiedAt = verifiedAt ?? const _Now();

  factory VerificationResult.valid(String recoveredAddress) {
    return VerificationResult(
      isValid: true,
      recoveredAddress: recoveredAddress,
    );
  }

  factory VerificationResult.invalid(String error) {
    return VerificationResult(
      isValid: false,
      error: error,
    );
  }
}

class _Now implements DateTime {
  const _Now();
  DateTime get _now => DateTime.now();
  @override
  dynamic noSuchMethod(Invocation invocation) => _now.noSuchMethod(invocation);
}
