import 'dart:typed_data';
import 'keccak.dart';

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

    // Remove 0x04 prefix if present
    final key = publicKey.length == 65 ? publicKey.sublist(1) : publicKey;

    // TODO: Hash and take last 20 bytes
    // final hash = Keccak.keccak256(key);
    // final addressBytes = hash.sublist(12); // Last 20 bytes
    // return toChecksumAddress(bytesToHex(addressBytes));

    throw UnimplementedError('Address derivation pending');
  }

  /// Derive address from private key.
  static String fromPrivateKey(Uint8List privateKey) {
    // TODO: Generate public key first, then derive address
    throw UnimplementedError('Address from private key pending');
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

    // TODO: Implement EIP-55 checksumming
    // 1. Hash lowercase address
    // 2. For each character, capitalize if corresponding hash character >= 8
    throw UnimplementedError('Checksum address pending');
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
    // TODO: Implement contract address creation
    throw UnimplementedError('Contract address creation pending');
  }

  /// Create CREATE2 contract address.
  ///
  /// address = rightmost 20 bytes of Keccak-256(0xff ++ sender ++ salt ++ Keccak-256(bytecode))
  static String create2Address({
    required String sender,
    required Uint8List salt,
    required Uint8List bytecodeHash,
  }) {
    // TODO: Implement CREATE2 address calculation
    throw UnimplementedError('CREATE2 address pending');
  }
}
