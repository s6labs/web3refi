import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/digests/keccak.dart';
import '../core/chain.dart';
import 'hex_utils.dart';

/// Utilities for working with blockchain addresses.
///
/// Supports multiple address formats:
/// - EVM (Ethereum, Polygon, etc.): 0x prefixed, 40 hex characters
/// - Bitcoin: Various formats (P2PKH, P2SH, Bech32)
/// - Solana: Base58 encoded, 32-44 characters
/// - Hedera: Account ID format (0.0.xxxxx)
///
/// Example:
/// ```dart
/// // Validate an address
/// AddressUtils.isValidAddress('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
///
/// // Format for display
/// AddressUtils.truncate('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
/// // '0x742d...0bEb'
///
/// // EIP-55 checksum
/// AddressUtils.toChecksumAddress('0x742d35cc6634c0532925a3b844bc9e7595f0beb');
/// // '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'
/// ```
abstract class AddressUtils {
  AddressUtils._();

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Zero address (burn address) for EVM chains.
  static const String zeroAddress =
      '0x0000000000000000000000000000000000000000';

  /// Dead address commonly used for burning tokens.
  static const String deadAddress =
      '0x000000000000000000000000000000000000dEaD';

  /// EVM address length in bytes.
  static const int evmAddressLength = 20;

  /// EVM address length in hex characters (without prefix).
  static const int evmAddressHexLength = 40;

  /// Solana address length range.
  static const int solanaAddressMinLength = 32;
  static const int solanaAddressMaxLength = 44;

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - UNIVERSAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates an address for the given blockchain type.
  ///
  /// Example:
  /// ```dart
  /// AddressUtils.isValidAddress(
  ///   '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  ///   type: BlockchainType.evm,
  /// ); // true
  /// ```
  static bool isValidAddress(String address, {BlockchainType? type}) {
    if (address.isEmpty) return false;

    // Auto-detect type if not provided
    final chainType = type ?? detectAddressType(address);

    switch (chainType) {
      case BlockchainType.evm:
        return isValidEvmAddress(address);
      case BlockchainType.bitcoin:
        return isValidBitcoinAddress(address);
      case BlockchainType.solana:
        return isValidSolanaAddress(address);
      case BlockchainType.hedera:
        return isValidHederaAddress(address);
      case BlockchainType.sui:
        return isValidSuiAddress(address);
      default:
        return false;
    }
  }

  /// Attempts to detect the blockchain type from an address format.
  static BlockchainType detectAddressType(String address) {
    if (address.isEmpty) return BlockchainType.unknown;

    // EVM: Starts with 0x, 42 characters total
    if (address.startsWith('0x') && address.length == 42) {
      return BlockchainType.evm;
    }

    // Sui: Starts with 0x, 66 characters total (32 bytes)
    if (address.startsWith('0x') && address.length == 66) {
      return BlockchainType.sui;
    }

    // Hedera: Format 0.0.xxxxx
    if (RegExp(r'^\d+\.\d+\.\d+$').hasMatch(address)) {
      return BlockchainType.hedera;
    }

    // Bitcoin: Various formats
    if (_looksLikeBitcoinAddress(address)) {
      return BlockchainType.bitcoin;
    }

    // Solana: Base58, 32-44 characters
    if (_looksLikeSolanaAddress(address)) {
      return BlockchainType.solana;
    }

    return BlockchainType.unknown;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - EVM
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates an EVM address (Ethereum, Polygon, Arbitrum, etc.).
  ///
  /// Checks:
  /// - Starts with "0x"
  /// - Exactly 40 hex characters after prefix
  /// - Valid hex characters only
  ///
  /// Example:
  /// ```dart
  /// AddressUtils.isValidEvmAddress('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'); // true
  /// AddressUtils.isValidEvmAddress('0x123');  // false (too short)
  /// AddressUtils.isValidEvmAddress('0xGGGG'); // false (invalid hex)
  /// ```
  static bool isValidEvmAddress(String address) {
    if (!address.startsWith('0x') && !address.startsWith('0X')) {
      return false;
    }

    final hex = address.substring(2);
    if (hex.length != evmAddressHexLength) {
      return false;
    }

    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  /// Validates an EVM address with checksum verification (EIP-55).
  ///
  /// Returns true if:
  /// - Address is valid
  /// - Checksum is correct (if mixed case)
  /// - Or address is all lowercase/uppercase (no checksum applied)
  static bool isValidEvmAddressWithChecksum(String address) {
    if (!isValidEvmAddress(address)) return false;

    final hex = address.substring(2);

    // All lowercase or all uppercase = no checksum, valid
    if (hex == hex.toLowerCase() || hex == hex.toUpperCase()) {
      return true;
    }

    // Mixed case = verify checksum
    return toChecksumAddress(address) == address;
  }

  /// Converts an EVM address to EIP-55 checksum format.
  ///
  /// EIP-55 uses the hash of the lowercase address to determine
  /// which characters should be uppercase.
  ///
  /// Example:
  /// ```dart
  /// AddressUtils.toChecksumAddress('0x742d35cc6634c0532925a3b844bc9e7595f0beb');
  /// // '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb'
  /// ```
  static String toChecksumAddress(String address) {
    if (!isValidEvmAddress(address)) {
      throw ArgumentError('Invalid EVM address: $address');
    }

    final lowercaseAddress = address.substring(2).toLowerCase();
    final hash = _keccak256String(lowercaseAddress);

    final checksumAddress = StringBuffer('0x');
    for (var i = 0; i < lowercaseAddress.length; i++) {
      final char = lowercaseAddress[i];
      final hashChar = hash[i];

      // If hash character >= 8, uppercase the address character
      if (int.parse(hashChar, radix: 16) >= 8) {
        checksumAddress.write(char.toUpperCase());
      } else {
        checksumAddress.write(char);
      }
    }

    return checksumAddress.toString();
  }

  /// Normalizes an EVM address to lowercase with checksum.
  static String normalizeEvmAddress(String address) {
    if (!isValidEvmAddress(address)) {
      throw ArgumentError('Invalid EVM address: $address');
    }
    return toChecksumAddress(address);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - BITCOIN
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates a Bitcoin address.
  ///
  /// Supports:
  /// - P2PKH (Legacy): Starts with 1, 25-34 characters
  /// - P2SH (SegWit compatible): Starts with 3, 25-34 characters
  /// - Bech32 (Native SegWit): Starts with bc1, 42-62 characters
  /// - Bech32m (Taproot): Starts with bc1p, 62 characters
  static bool isValidBitcoinAddress(String address) {
    if (address.isEmpty) return false;

    // Bech32/Bech32m (SegWit/Taproot)
    if (address.toLowerCase().startsWith('bc1')) {
      return _isValidBech32Address(address);
    }

    // Legacy (P2PKH) - starts with 1
    if (address.startsWith('1')) {
      return _isValidBase58CheckAddress(address, 25, 34);
    }

    // P2SH - starts with 3
    if (address.startsWith('3')) {
      return _isValidBase58CheckAddress(address, 25, 34);
    }

    // Testnet addresses
    if (address.startsWith('m') ||
        address.startsWith('n') ||
        address.startsWith('2') ||
        address.toLowerCase().startsWith('tb1')) {
      return true; // Simplified testnet validation
    }

    return false;
  }

  static bool _isValidBech32Address(String address) {
    final lower = address.toLowerCase();
    if (!lower.startsWith('bc1')) return false;
    if (address.length < 42 || address.length > 62) return false;

    // Check valid bech32 characters
    final data = lower.substring(4);
    return RegExp(r'^[qpzry9x8gf2tvdw0s3jn54khce6mua7l]+$').hasMatch(data);
  }

  static bool _isValidBase58CheckAddress(String address, int minLen, int maxLen) {
    if (address.length < minLen || address.length > maxLen) return false;

    // Base58 alphabet (no 0, O, I, l)
    return RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$')
        .hasMatch(address);
  }

  static bool _looksLikeBitcoinAddress(String address) {
    if (address.isEmpty) return false;
    return address.startsWith('1') ||
        address.startsWith('3') ||
        address.toLowerCase().startsWith('bc1') ||
        address.startsWith('m') ||
        address.startsWith('n') ||
        address.startsWith('2') ||
        address.toLowerCase().startsWith('tb1');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - SOLANA
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates a Solana address.
  ///
  /// Solana uses Base58 encoding, 32-44 characters.
  static bool isValidSolanaAddress(String address) {
    if (address.length < solanaAddressMinLength ||
        address.length > solanaAddressMaxLength) {
      return false;
    }

    // Base58 alphabet (no 0, O, I, l)
    return RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$')
        .hasMatch(address);
  }

  static bool _looksLikeSolanaAddress(String address) {
    if (address.length < 32 || address.length > 44) return false;
    if (address.startsWith('0x')) return false;
    return RegExp(r'^[123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz]+$')
        .hasMatch(address);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - HEDERA
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates a Hedera account ID.
  ///
  /// Format: shard.realm.account (e.g., 0.0.12345)
  static bool isValidHederaAddress(String address) {
    return RegExp(r'^\d+\.\d+\.\d+$').hasMatch(address);
  }

  /// Parses a Hedera account ID into components.
  static ({int shard, int realm, int account})? parseHederaAddress(String address) {
    if (!isValidHederaAddress(address)) return null;

    final parts = address.split('.');
    return (
      shard: int.parse(parts[0]),
      realm: int.parse(parts[1]),
      account: int.parse(parts[2]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION - SUI
  // ══════════════════════════════════════════════════════════════════════════

  /// Validates a Sui address.
  ///
  /// Sui addresses are 32 bytes (64 hex characters) with 0x prefix.
  static bool isValidSuiAddress(String address) {
    if (!address.startsWith('0x') && !address.startsWith('0X')) {
      return false;
    }

    final hex = address.substring(2);
    if (hex.length != 64) return false;

    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORMATTING
  // ══════════════════════════════════════════════════════════════════════════

  /// Truncates an address for display.
  ///
  /// Example:
  /// ```dart
  /// AddressUtils.truncate('0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb');
  /// // '0x742d...0bEb'
  ///
  /// AddressUtils.truncate(
  ///   '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  ///   prefixLength: 10,
  ///   suffixLength: 8,
  /// );
  /// // '0x742d35Cc63...95f0bEb'
  /// ```
  static String truncate(
    String address, {
    int prefixLength = 6,
    int suffixLength = 4,
    String separator = '...',
  }) {
    if (address.length <= prefixLength + suffixLength + separator.length) {
      return address;
    }

    final prefix = address.substring(0, prefixLength);
    final suffix = address.substring(address.length - suffixLength);
    return '$prefix$separator$suffix';
  }

  /// Formats an address with the checksum (for EVM) and truncates.
  static String formatForDisplay(
    String address, {
    BlockchainType? type,
    bool truncated = true,
  }) {
    final chainType = type ?? detectAddressType(address);

    String formatted = address;
    if (chainType == BlockchainType.evm && isValidEvmAddress(address)) {
      formatted = toChecksumAddress(address);
    }

    if (truncated) {
      return truncate(formatted);
    }
    return formatted;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPARISON
  // ══════════════════════════════════════════════════════════════════════════

  /// Compares two addresses for equality.
  ///
  /// For EVM addresses, comparison is case-insensitive.
  ///
  /// Example:
  /// ```dart
  /// AddressUtils.equals(
  ///   '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  ///   '0x742d35cc6634c0532925a3b844bc9e7595f0beb',
  /// ); // true
  /// ```
  static bool equals(String address1, String address2, {BlockchainType? type}) {
    if (address1.isEmpty || address2.isEmpty) return false;

    final chainType = type ?? detectAddressType(address1);

    switch (chainType) {
      case BlockchainType.evm:
      case BlockchainType.sui:
        return address1.toLowerCase() == address2.toLowerCase();
      default:
        return address1 == address2;
    }
  }

  /// Returns true if the address is a zero/null address.
  static bool isZeroAddress(String address, {BlockchainType? type}) {
    final chainType = type ?? detectAddressType(address);

    switch (chainType) {
      case BlockchainType.evm:
        return address.toLowerCase() == zeroAddress.toLowerCase();
      case BlockchainType.sui:
        return HexUtils.isZero(address);
      default:
        return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSION
  // ══════════════════════════════════════════════════════════════════════════

  /// Converts an EVM address to bytes.
  static Uint8List evmAddressToBytes(String address) {
    if (!isValidEvmAddress(address)) {
      throw ArgumentError('Invalid EVM address: $address');
    }
    return HexUtils.hexToBytes(address);
  }

  /// Converts bytes to an EVM address.
  static String bytesToEvmAddress(Uint8List bytes) {
    if (bytes.length != evmAddressLength) {
      throw ArgumentError('Invalid byte length for EVM address: ${bytes.length}');
    }
    return toChecksumAddress(HexUtils.bytesToHex(bytes));
  }

  /// Extracts an address from a 32-byte ABI-encoded value.
  ///
  /// In ABI encoding, addresses are padded to 32 bytes (left-padded with zeros).
  static String extractAddressFromAbi(String abiEncodedAddress) {
    final clean = HexUtils.stripHexPrefix(abiEncodedAddress);
    if (clean.length != 64) {
      throw ArgumentError('Invalid ABI-encoded address length');
    }

    // Take last 40 characters (20 bytes)
    final addressHex = clean.substring(24);
    return toChecksumAddress('0x$addressHex');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Computes Keccak-256 hash of a string and returns hex.
  static String _keccak256String(String input) {
    final keccak = KeccakDigest(256);
    final inputBytes = Uint8List.fromList(input.codeUnits);
    final hash = keccak.process(inputBytes);
    return HexUtils.stripHexPrefix(HexUtils.bytesToHex(hash));
  }
}

/// Extension methods for String to work with addresses.
extension AddressStringExtension on String {
  /// Returns true if this string is a valid blockchain address.
  bool get isValidAddress => AddressUtils.isValidAddress(this);

  /// Returns true if this string is a valid EVM address.
  bool get isValidEvmAddress => AddressUtils.isValidEvmAddress(this);

  /// Converts this EVM address to checksum format.
  String get toChecksumAddress => AddressUtils.toChecksumAddress(this);

  /// Truncates this address for display.
  String get truncatedAddress => AddressUtils.truncate(this);

  /// Detects the blockchain type of this address.
  BlockchainType get addressType => AddressUtils.detectAddressType(this);
}
