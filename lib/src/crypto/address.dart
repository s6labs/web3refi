import 'dart:typed_data';
import 'package:web3refi/src/crypto/keccak.dart';
import 'package:web3refi/src/crypto/rlp.dart';
import 'package:web3refi/src/crypto/secp256k1.dart';

/// Ethereum address utilities.
///
/// Provides functions for:
/// - Deriving addresses from public keys
/// - Checksumming addresses (EIP-55)
/// - Validating address formats
/// - Converting between formats
class EthereumAddress {
  EthereumAddress._();

  /// Derive Ethereum address from public key.
  ///
  /// Takes 64-byte uncompressed public key and returns checksummed address.
  ///
  /// Algorithm:
  /// 1. Take Keccak-256 hash of public key
  /// 2. Take last 20 bytes
  /// 3. Apply EIP-55 checksum
  static String fromPublicKey(Uint8List publicKey) {
    if (publicKey.length != 64 && publicKey.length != 65) {
      throw ArgumentError('Public key must be 64 or 65 bytes');
    }

    // Remove 0x04 prefix if present (uncompressed key marker)
    final key = publicKey.length == 65 ? publicKey.sublist(1) : publicKey;

    // Hash the public key
    final hash = Keccak.keccak256(key);

    // Take last 20 bytes
    final addressBytes = hash.sublist(12);

    // Convert to hex and apply checksum
    final addressHex = bytesToHex(addressBytes);
    return toChecksumAddress(addressHex);
  }

  /// Derive address from private key.
  static String fromPrivateKey(Uint8List privateKey) {
    final publicKey = Secp256k1.getPublicKey(privateKey);
    return fromPublicKey(publicKey);
  }

  /// Apply EIP-55 checksum to address.
  ///
  /// Mixed-case encoding provides checksum protection without
  /// requiring additional data.
  ///
  /// Example:
  /// ```dart
  /// final checksummed = EthereumAddress.toChecksumAddress(
  ///   '5aaeb6053f3e94c9b9a09f33669435e7ef1beaed'
  /// );
  /// // Returns: '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed'
  /// ```
  static String toChecksumAddress(String address) {
    // Remove 0x prefix
    final cleanAddress = address.toLowerCase().replaceFirst('0x', '');

    if (cleanAddress.length != 40) {
      throw ArgumentError('Address must be 40 hex characters');
    }

    // Hash the lowercase address
    final hash = Keccak.keccak256StringHex(cleanAddress);
    final hashHex = hash.substring(2); // Remove 0x prefix

    // Build checksummed address
    final result = StringBuffer('0x');
    for (int i = 0; i < 40; i++) {
      final char = cleanAddress[i];
      final hashChar = hashHex[i];

      // Capitalize if hash character is >= 8 (hex)
      if (int.parse(hashChar, radix: 16) >= 8) {
        result.write(char.toUpperCase());
      } else {
        result.write(char);
      }
    }

    return result.toString();
  }

  /// Validate address format and checksum.
  static bool isValid(String address) {
    // Remove 0x prefix
    final cleanAddress = address.replaceFirst('0x', '');

    // Check length
    if (cleanAddress.length != 40) return false;

    // Check hex format
    if (!RegExp(r'^[0-9a-fA-F]{40}$').hasMatch(cleanAddress)) return false;

    // If mixed case, verify checksum
    if (cleanAddress != cleanAddress.toLowerCase() &&
        cleanAddress != cleanAddress.toUpperCase()) {
      return verifyChecksum(address);
    }

    return true;
  }

  /// Verify EIP-55 checksum.
  static bool verifyChecksum(String address) {
    try {
      final checksummed = toChecksumAddress(address);
      return checksummed.toLowerCase() == address.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  /// Normalize address to lowercase with 0x prefix.
  static String normalize(String address) {
    final clean = address.replaceFirst('0x', '').toLowerCase();
    return '0x$clean';
  }

  /// Compare two addresses for equality (case-insensitive).
  static bool equals(String a, String b) {
    return normalize(a) == normalize(b);
  }

  /// Check if address is zero address (0x0000...0000).
  static bool isZero(String address) {
    final clean = address.replaceFirst('0x', '');
    return clean == '0' * 40;
  }

  /// The zero address constant.
  static const String zero = '0x0000000000000000000000000000000000000000';

  /// Create contract address from deployer and nonce.
  ///
  /// Contract address = rightmost 20 bytes of Keccak-256(RLP(sender, nonce))
  static String createContractAddress(String sender, BigInt nonce) {
    // Convert sender address to bytes (remove 0x prefix)
    final senderClean = sender.replaceFirst('0x', '');
    final senderBytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      senderBytes[i] = int.parse(senderClean.substring(i * 2, i * 2 + 2), radix: 16);
    }

    // RLP encode [sender, nonce]
    final rlpEncoded = RLP.encode([senderBytes, nonce]);

    // Hash and take last 20 bytes
    final hash = Keccak.keccak256(rlpEncoded);
    final addressBytes = hash.sublist(12);

    // Convert to hex and apply checksum
    final addressHex = bytesToHex(addressBytes);
    return toChecksumAddress(addressHex);
  }

  /// Create CREATE2 contract address.
  ///
  /// address = rightmost 20 bytes of Keccak-256(0xff ++ sender ++ salt ++ bytecodeHash)
  static String create2Address({
    required String sender,
    required Uint8List salt,
    required Uint8List bytecodeHash,
  }) {
    if (salt.length != 32) {
      throw ArgumentError('Salt must be 32 bytes');
    }
    if (bytecodeHash.length != 32) {
      throw ArgumentError('Bytecode hash must be 32 bytes');
    }

    // Convert sender address to bytes (remove 0x prefix)
    final senderClean = sender.replaceFirst('0x', '');
    final senderBytes = Uint8List(20);
    for (int i = 0; i < 20; i++) {
      senderBytes[i] = int.parse(senderClean.substring(i * 2, i * 2 + 2), radix: 16);
    }

    // Concatenate: 0xff ++ sender ++ salt ++ bytecodeHash
    final data = Uint8List(1 + 20 + 32 + 32);
    data[0] = 0xff;
    data.setAll(1, senderBytes);
    data.setAll(21, salt);
    data.setAll(53, bytecodeHash);

    // Hash and take last 20 bytes
    final hash = Keccak.keccak256(data);
    final addressBytes = hash.sublist(12);

    // Convert to hex and apply checksum
    final addressHex = bytesToHex(addressBytes);
    return toChecksumAddress(addressHex);
  }
}
