import 'dart:typed_data';
import '../crypto/secp256k1.dart';
import '../crypto/address.dart';
import '../crypto/signature.dart';

/// Hierarchical Deterministic (HD) wallet implementation.
///
/// Implements BIP-32, BIP-39, and BIP-44 standards for deriving
/// multiple accounts from a single seed phrase.
///
/// ## Derivation Path
///
/// Ethereum uses: m/44'/60'/0'/0/index
/// - 44' = BIP-44
/// - 60' = Ethereum coin type
/// - 0' = Account 0
/// - 0 = External chain (receiving addresses)
/// - index = Address index
///
/// ## Usage
///
/// ```dart
/// // From mnemonic
/// final wallet = HDWallet.fromMnemonic(
///   'word1 word2 ... word12',
/// );
///
/// // Derive accounts
/// final account0 = wallet.deriveAccount(0);
/// final account1 = wallet.deriveAccount(1);
///
/// // Sign with account
/// final signature = account0.sign(messageHash);
/// ```
class HDWallet {
  /// Master private key.
  final Uint8List _masterKey;

  /// Master chain code.
  final Uint8List _masterChainCode;

  HDWallet._(this._masterKey, this._masterChainCode);

  /// Create HD wallet from mnemonic phrase.
  factory HDWallet.fromMnemonic(
    String mnemonic, {
    String passphrase = '',
  }) {
    // TODO: Implement BIP-39 mnemonic to seed conversion
    // 1. Validate mnemonic
    // 2. Convert to seed using PBKDF2
    // 3. Derive master key using BIP-32
    throw UnimplementedError('HD wallet from mnemonic pending');
  }

  /// Create HD wallet from seed.
  factory HDWallet.fromSeed(Uint8List seed) {
    // TODO: Implement BIP-32 master key derivation
    throw UnimplementedError('HD wallet from seed pending');
  }

  /// Derive account at index using BIP-44 path.
  ///
  /// Path: m/44'/60'/0'/0/index
  PrivateKeySigner deriveAccount(int index) {
    // TODO: Implement BIP-32 child key derivation
    throw UnimplementedError('Account derivation pending');
  }

  /// Derive key at custom path.
  PrivateKeySigner derivePath(String path) {
    // TODO: Parse and derive custom path
    throw UnimplementedError('Custom path derivation pending');
  }

  /// Get public key for derivation path.
  Uint8List derivePublicKey(String path) {
    final signer = derivePath(path);
    return signer.publicKey;
  }

  /// Get address for derivation path.
  String deriveAddress(String path) {
    final signer = derivePath(path);
    return signer.address;
  }

  /// Generate mnemonic phrase.
  static String generateMnemonic({int strength = 128}) {
    // TODO: Implement BIP-39 mnemonic generation
    // strength: 128 (12 words), 160 (15), 192 (18), 224 (21), 256 (24)
    throw UnimplementedError('Mnemonic generation pending');
  }

  /// Validate mnemonic phrase.
  static bool validateMnemonic(String mnemonic) {
    // TODO: Validate mnemonic checksum
    throw UnimplementedError('Mnemonic validation pending');
  }
}

/// Abstract signer interface.
abstract class Signer {
  /// Get the signer's address.
  String get address;

  /// Get the public key.
  Uint8List get publicKey;

  /// Sign a message hash.
  Signature sign(Uint8List messageHash);

  /// Sign with specific chain ID (EIP-155).
  Signature signWithChainId(Uint8List messageHash, int chainId);
}

/// Private key signer implementation.
class PrivateKeySigner implements Signer {
  /// The private key (32 bytes).
  final Uint8List privateKey;

  /// Cached public key.
  Uint8List? _publicKey;

  /// Cached address.
  String? _address;

  PrivateKeySigner(this.privateKey) {
    if (privateKey.length != 32) {
      throw ArgumentError('Private key must be 32 bytes');
    }
    if (!Secp256k1.isValidPrivateKey(privateKey)) {
      throw ArgumentError('Invalid private key');
    }
  }

  /// Create signer from hex string.
  factory PrivateKeySigner.fromHex(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    if (clean.length != 64) {
      throw ArgumentError('Private key hex must be 64 characters');
    }

    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return PrivateKeySigner(bytes);
  }

  @override
  Uint8List get publicKey {
    _publicKey ??= Secp256k1.getPublicKey(privateKey);
    return _publicKey!;
  }

  @override
  String get address {
    _address ??= EthereumAddress.fromPublicKey(publicKey);
    return _address!;
  }

  @override
  Signature sign(Uint8List messageHash) {
    return Secp256k1.sign(messageHash, privateKey);
  }

  @override
  Signature signWithChainId(Uint8List messageHash, int chainId) {
    return Secp256k1.signRecoverable(
      messageHash,
      privateKey,
      chainId: chainId,
    );
  }

  /// Export private key as hex string.
  String toHex() {
    return '0x${privateKey.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Generate random private key.
  static PrivateKeySigner random() {
    // TODO: Generate random 32 bytes securely
    throw UnimplementedError('Random key generation pending');
  }
}

/// Wallet connect signer (delegates to WalletConnect).
class WalletConnectSigner implements Signer {
  final String _address;

  // TODO: Add WalletConnect session reference

  WalletConnectSigner(this._address);

  @override
  String get address => _address;

  @override
  Uint8List get publicKey {
    throw UnsupportedError('WalletConnect does not expose public key');
  }

  @override
  Signature sign(Uint8List messageHash) {
    // TODO: Request signature via WalletConnect
    throw UnimplementedError('WalletConnect signing pending');
  }

  @override
  Signature signWithChainId(Uint8List messageHash, int chainId) {
    // TODO: Request signature via WalletConnect with chain ID
    throw UnimplementedError('WalletConnect signing with chain ID pending');
  }
}
