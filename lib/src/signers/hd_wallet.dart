import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/digests/sha512.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:bip39/bip39.dart' as bip39;
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
    // Validate mnemonic
    if (!validateMnemonic(mnemonic)) {
      throw ArgumentError('Invalid mnemonic phrase');
    }

    // Convert mnemonic to seed using PBKDF2-HMAC-SHA512
    // Salt = "mnemonic" + passphrase
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic.trim()));
    final salt = Uint8List.fromList(
      utf8.encode('mnemonic${passphrase}'),
    );

    // PBKDF2 with 2048 iterations, 64-byte output
    final derivator = PBKDF2KeyDerivator(HMac(SHA512Digest(), 128));
    derivator.init(Pbkdf2Parameters(salt, 2048, 64));

    final seed = derivator.process(mnemonicBytes);

    return HDWallet.fromSeed(seed);
  }

  /// Create HD wallet from seed.
  factory HDWallet.fromSeed(Uint8List seed) {
    // BIP-32 master key derivation
    // I = HMAC-SHA512(Key = "Bitcoin seed", Data = S)
    final hmac = HMac(SHA512Digest(), 128);
    final key = Uint8List.fromList(utf8.encode('Bitcoin seed'));
    hmac.init(KeyParameter(key));

    final i = Uint8List(64);
    hmac.update(seed, 0, seed.length);
    hmac.doFinal(i, 0);

    // Split I into two 32-byte sequences, IL and IR
    final masterKey = i.sublist(0, 32);
    final masterChainCode = i.sublist(32, 64);

    // Validate master key
    if (!Secp256k1.isValidPrivateKey(masterKey)) {
      throw StateError('Invalid master key derived from seed');
    }

    return HDWallet._(masterKey, masterChainCode);
  }

  /// Derive child key (BIP-32 CKD function).
  _DerivedKey _deriveChild(Uint8List parentKey, Uint8List chainCode, int index) {
    final isHardened = index >= 0x80000000;

    // Prepare data for HMAC
    final data = Uint8List(37);

    if (isHardened) {
      // Hardened: data = 0x00 || parentKey || index
      data[0] = 0x00;
      data.setAll(1, parentKey);
    } else {
      // Normal: data = publicKey || index
      final publicKey = Secp256k1.getPublicKey(parentKey);
      // Compress public key: 0x02 or 0x03 prefix + x coordinate
      final yIsEven = publicKey[63] & 1 == 0;
      data[0] = yIsEven ? 0x02 : 0x03;
      data.setAll(1, publicKey.sublist(0, 32)); // x coordinate
    }

    // Add index (big-endian)
    data[33] = (index >> 24) & 0xff;
    data[34] = (index >> 16) & 0xff;
    data[35] = (index >> 8) & 0xff;
    data[36] = index & 0xff;

    // I = HMAC-SHA512(Key = chainCode, Data = data)
    final hmac = HMac(SHA512Digest(), 128);
    hmac.init(KeyParameter(chainCode));

    final i = Uint8List(64);
    hmac.update(data, 0, data.length);
    hmac.doFinal(i, 0);

    // Split I into IL and IR
    final il = i.sublist(0, 32);
    final ir = i.sublist(32, 64);

    // Child key = (IL + parentKey) mod n
    final ilNum = _bytesToBigInt(il);
    final parentNum = _bytesToBigInt(parentKey);
    final childNum = (ilNum + parentNum) % Secp256k1.n;

    if (childNum == BigInt.zero) {
      throw StateError('Invalid child key (zero)');
    }

    final childKey = _bigIntToBytes(childNum, 32);

    return _DerivedKey(childKey, ir);
  }

  /// Derive account at index using BIP-44 path.
  ///
  /// Path: m/44'/60'/0'/0/index
  PrivateKeySigner deriveAccount(int index) {
    // m/44'/60'/0'/0/index
    return derivePath("m/44'/60'/0'/0/$index");
  }

  /// Derive key at custom path.
  PrivateKeySigner derivePath(String path) {
    // Parse path: m/44'/60'/0'/0/0
    if (!path.startsWith('m/') && !path.startsWith('M/')) {
      throw ArgumentError('Path must start with m/');
    }

    final parts = path.substring(2).split('/');
    var currentKey = _masterKey;
    var currentChainCode = _masterChainCode;

    for (final part in parts) {
      if (part.isEmpty) continue;

      // Parse index
      final isHardened = part.endsWith("'") || part.endsWith('h');
      final indexStr = isHardened ? part.substring(0, part.length - 1) : part;
      final index = int.parse(indexStr);

      // Apply hardened offset
      final actualIndex = isHardened ? index + 0x80000000 : index;

      // Derive child
      final derived = _deriveChild(currentKey, currentChainCode, actualIndex);
      currentKey = derived.key;
      currentChainCode = derived.chainCode;
    }

    return PrivateKeySigner(currentKey);
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
    // Use bip39 package for mnemonic generation
    return bip39.generateMnemonic(strength: strength);
  }

  /// Validate mnemonic phrase.
  static bool validateMnemonic(String mnemonic) {
    // Use bip39 package for validation
    return bip39.validateMnemonic(mnemonic);
  }

  /// Helper: Convert bytes to BigInt.
  static BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }

  /// Helper: Convert BigInt to bytes.
  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var remaining = value;
    for (int i = length - 1; i >= 0; i--) {
      bytes[i] = (remaining & BigInt.from(0xff)).toInt();
      remaining = remaining >> 8;
    }
    return bytes;
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
    final random = Random.secure();
    final privateKey = Uint8List(32);

    // Keep generating until we get a valid private key
    while (true) {
      for (int i = 0; i < 32; i++) {
        privateKey[i] = random.nextInt(256);
      }

      if (Secp256k1.isValidPrivateKey(privateKey)) {
        return PrivateKeySigner(privateKey);
      }
    }
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

/// Helper class for BIP-32 derived key data.
class _DerivedKey {
  final Uint8List key;
  final Uint8List chainCode;

  _DerivedKey(this.key, this.chainCode);
}
