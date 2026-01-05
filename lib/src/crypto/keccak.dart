import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/digests/keccak.dart';

/// Keccak-256 hashing implementation for Ethereum.
///
/// Provides cryptographic hashing functions compatible with Ethereum's
/// requirements. This is NOT the same as SHA3-256 (NIST standard).
///
/// ## Usage
///
/// ```dart
/// // Hash a string
/// final hash = Keccak.keccak256StringHex('hello');
///
/// // Hash bytes
/// final bytes = utf8.encode('hello');
/// final hashBytes = Keccak.keccak256(bytes);
/// ```
class Keccak {
  Keccak._();

  /// Compute Keccak-256 hash of input bytes.
  ///
  /// Returns 32-byte hash as Uint8List.
  static Uint8List keccak256(Uint8List input) {
    final digest = KeccakDigest(256);
    return digest.process(input);
  }

  /// Compute Keccak-256 hash and return as hex string with 0x prefix.
  static String keccak256Hex(Uint8List input) {
    final hash = keccak256(input);
    return '0x${bytesToHex(hash)}';
  }

  /// Hash a string and return hex result.
  static String keccak256StringHex(String input) {
    final bytes = Uint8List.fromList(utf8.encode(input));
    return keccak256Hex(bytes);
  }

  /// Verify a hash matches input.
  static bool verify(Uint8List input, Uint8List expectedHash) {
    final actualHash = keccak256(input);
    if (actualHash.length != expectedHash.length) return false;

    for (int i = 0; i < actualHash.length; i++) {
      if (actualHash[i] != expectedHash[i]) return false;
    }
    return true;
  }
}

/// Convert bytes to hex string (without 0x prefix).
String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// Convert hex string to bytes.
///
/// Accepts strings with or without 0x prefix.
Uint8List hexToBytes(String hex) {
  // Remove 0x prefix if present
  final cleanHex = hex.startsWith('0x') ? hex.substring(2) : hex;

  // Ensure even length
  final paddedHex = cleanHex.length.isOdd ? '0$cleanHex' : cleanHex;

  final bytes = <int>[];
  for (int i = 0; i < paddedHex.length; i += 2) {
    bytes.add(int.parse(paddedHex.substring(i, i + 2), radix: 16));
  }

  return Uint8List.fromList(bytes);
}
