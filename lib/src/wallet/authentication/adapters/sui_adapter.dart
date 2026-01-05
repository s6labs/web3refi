import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chain.dart';
import '../../exceptions/web3_exception.dart';
import '../wallet_abstraction.dart';
import '../authentication/auth_message.dart';

/// Adapter for Sui blockchain wallets.
///
/// Supports wallets like Sui Wallet, Suiet, Ethos, and other Sui wallets.
///
/// Sui uses the Move programming language and has a unique object-based
/// transaction model.
///
/// Example:
/// ```dart
/// final suiWallet = SuiWalletAdapter();
/// await suiWallet.connect();
/// final signature = await suiWallet.signMessage('Hello Sui');
/// ```
class SuiWalletAdapter implements Web3WalletAdapter {
  /// Wallet identifier.
  final String walletId;

  /// Wallet display name.
  final String walletName;

  /// Deep link scheme.
  final String deepLinkScheme;

  /// App Store URL.
  final String? appStoreUrl;

  /// Play Store URL.
  final String? playStoreUrl;

  /// Supported networks.
  final List<String> supportedNetworks;

  // State
  String? _address;
  String? _publicKey;
  String? _network;
  WalletConnectionState _connectionState = WalletConnectionState.disconnected;

  final _stateController = StreamController<WalletConnectionState>.broadcast();

  SuiWalletAdapter({
    required this.walletId,
    required this.walletName,
    required this.deepLinkScheme,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportedNetworks = const ['sui-mainnet', 'sui-testnet', 'sui-devnet'],
  });

  @override
  WalletInfo get info => WalletInfo(
        id: walletId,
        name: walletName,
        description: 'Sui blockchain wallet',
        iconPath: 'assets/wallets/$walletId.png',
        blockchainType: BlockchainType.sui,
        supportedChains: supportedNetworks,
        deepLinkScheme: deepLinkScheme,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
        supportsWalletConnect: false,
        supportsDeepLink: true,
        supportsMessageSigning: true,
        supportsTypedDataSigning: false,
        supportsChainSwitching: true,
      );

  @override
  Stream<WalletConnectionState> get connectionStateStream => _stateController.stream;

  @override
  WalletConnectionState get connectionState => _connectionState;

  @override
  String? get address => _address;

  /// The Sui public key.
  String? get publicKey => _publicKey;

  @override
  String? get chainId => _network;

  /// The current Sui network.
  String? get network => _network?.replaceFirst('sui-', '');

  @override
  Future<WalletConnectionResult> connect() async {
    _updateState(WalletConnectionState.connecting);

    try {
      if (!await isInstalled()) {
        throw WalletException.walletNotInstalled(walletName);
      }

      // Build connect request
      final connectUri = _buildConnectUri();

      // Launch wallet
      _updateState(WalletConnectionState.awaitingApproval);
      await _launchWallet(connectUri);

      // Wait for response
      final result = await _waitForConnection();

      _address = result.address;
      _network = result.chainId;
      _publicKey = result.metadata['publicKey'] as String?;
      _updateState(WalletConnectionState.connected);

      return result;
    } catch (e) {
      _updateState(WalletConnectionState.error);
      if (e is WalletException) rethrow;
      throw WalletException.generic('Connection failed: $e', e);
    }
  }

  @override
  Future<void> disconnect() async {
    _address = null;
    _publicKey = null;
    _network = null;
    _updateState(WalletConnectionState.disconnected);
  }

  @override
  Future<WalletSignature> signAuthMessage(AuthMessageData message) async {
    _requireConnected();

    final authMessage = AuthMessage.sui(
      domain: message.domain,
      address: _address!,
      statement: message.statement,
    );

    return signMessage(authMessage.toSignableMessage());
  }

  @override
  Future<WalletSignature> signMessage(String message) async {
    _requireConnected();

    try {
      final signUri = _buildSignMessageUri(message);

      await _launchWallet(signUri);
      final signature = await _waitForSignature();

      return WalletSignature(
        signature: signature,
        signerAddress: _address!,
        message: message,
        timestamp: DateTime.now(),
        format: SignatureFormat.suiEd25519,
        metadata: {
          'publicKey': _publicKey,
          'scheme': 'ED25519',
        },
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Signing failed: $e', e);
    }
  }

  @override
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData) async {
    throw UnsupportedError('Sui does not support typed data signing');
  }

  @override
  Future<String> sendTransaction(TransactionData transaction) async {
    _requireConnected();

    try {
      // For Sui, transactions are serialized differently
      final txUri = _buildTransactionUri(transaction);

      await _launchWallet(txUri);
      final digest = await _waitForTransaction();

      return digest;
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Transaction failed: $e', e);
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    _requireConnected();

    if (!supportedNetworks.contains(chainId)) {
      throw WalletException.chainNotSupported(chainId);
    }

    _network = chainId;
  }

  @override
  Future<bool> isInstalled() async {
    try {
      final uri = Uri.parse('$deepLinkScheme//');
      return await canLaunchUrl(uri);
    } catch (e) {
      return false;
    }
  }

  @override
  String? getDeepLink() => deepLinkScheme;

  @override
  void dispose() {
    _stateController.close();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ══════════════════════════════════════════════════════════════════════════

  void _requireConnected() {
    if (!isConnected) {
      throw WalletException.notConnected();
    }
  }

  void _updateState(WalletConnectionState newState) {
    _connectionState = newState;
    _stateController.add(newState);
  }

  String _buildConnectUri() {
    final params = {
      'app_name': 'web3refi',
      'app_url': 'https://web3refi.dev',
      'app_icon': 'https://web3refi.dev/icon.png',
      'redirect': 'web3refi://sui/connect',
      'network': _network ?? 'mainnet',
    };

    return '${deepLinkScheme}dapp/connect?${_encodeParams(params)}';
  }

  String _buildSignMessageUri(String message) {
    final messageBytes = utf8.encode(message);
    final encodedMessage = base64Url.encode(messageBytes);

    final params = {
      'message': encodedMessage,
      'redirect': 'web3refi://sui/signMessage',
    };

    return '${deepLinkScheme}dapp/sign-message?${_encodeParams(params)}';
  }

  String _buildTransactionUri(TransactionData tx) {
    // Sui transactions need to be serialized as TransactionBlock
    // This is a simplified version
    final txData = {
      'kind': 'pay',
      'recipient': tx.to,
      'amount': tx.value.toString(),
    };

    final encoded = base64Url.encode(utf8.encode(jsonEncode(txData)));
    final params = {
      'transaction': encoded,
      'redirect': 'web3refi://sui/signTransaction',
    };

    return '${deepLinkScheme}dapp/sign-transaction?${_encodeParams(params)}';
  }

  String _encodeParams(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _launchWallet(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw WalletException.walletNotInstalled(walletName);
    }
  }

  Future<WalletConnectionResult> _waitForConnection() async {
    await Future.delayed(const Duration(seconds: 1));

    // Simulated response - Sui addresses are 32 bytes (64 hex chars) prefixed with 0x
    final address = '0x${List.generate(32, (i) => i.toRadixString(16).padLeft(2, '0')).join()}';
    final publicKey = List.generate(32, (i) => ((i + 10) % 256).toRadixString(16).padLeft(2, '0')).join();

    return WalletConnectionResult(
      address: address,
      chainId: 'sui-mainnet',
      blockchainType: BlockchainType.sui,
      metadata: {
        'publicKey': publicKey,
        'scheme': 'ED25519',
      },
    );
  }

  Future<String> _waitForSignature() async {
    await Future.delayed(const Duration(seconds: 1));

    // Sui signature format: scheme byte (0x00 for Ed25519) + 64-byte signature + 32-byte public key
    final scheme = [0x00];
    final signature = List.generate(64, (i) => i % 256);
    final pubKey = List.generate(32, (i) => (i + 10) % 256);

    final combined = [...scheme, ...signature, ...pubKey];
    return base64.encode(combined);
  }

  Future<String> _waitForTransaction() async {
    await Future.delayed(const Duration(seconds: 1));
    // Sui transaction digest is base58-encoded
    return _generateFakeBase58Digest();
  }

  String _generateFakeBase58Digest() {
    const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';
    final buffer = StringBuffer();
    for (var i = 0; i < 44; i++) {
      buffer.write(alphabet[i % alphabet.length]);
    }
    return buffer.toString();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPECIFIC SUI WALLET IMPLEMENTATIONS
// ════════════════════════════════════════════════════════════════════════════

/// Official Sui Wallet adapter.
class OfficialSuiWalletAdapter extends SuiWalletAdapter {
  OfficialSuiWalletAdapter()
      : super(
          walletId: 'sui-wallet',
          walletName: 'Sui Wallet',
          deepLinkScheme: 'suiwallet://',
          appStoreUrl: 'https://apps.apple.com/app/sui-wallet/id1668703916',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.mystenlabs.suiwallet',
        );
}

/// Suiet wallet adapter.
class SuietAdapter extends SuiWalletAdapter {
  SuietAdapter()
      : super(
          walletId: 'suiet',
          walletName: 'Suiet',
          deepLinkScheme: 'suiet://',
          appStoreUrl: 'https://apps.apple.com/app/suiet-sui-wallet/id1665305902',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.suiet.wallet',
        );
}

/// Ethos wallet adapter.
class EthosAdapter extends SuiWalletAdapter {
  EthosAdapter()
      : super(
          walletId: 'ethos',
          walletName: 'Ethos',
          deepLinkScheme: 'ethos://',
          appStoreUrl: 'https://apps.apple.com/app/ethos-sui-wallet/id1665301947',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.aspect.ethos',
        );
}

/// Martian wallet adapter for Sui.
class MartianSuiAdapter extends SuiWalletAdapter {
  MartianSuiAdapter()
      : super(
          walletId: 'martian',
          walletName: 'Martian',
          deepLinkScheme: 'martian://',
          appStoreUrl: 'https://apps.apple.com/app/martian-wallet/id1644601883',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.aspect.martian',
        );
}

/// Nightly wallet adapter for Sui.
class NightlySuiAdapter extends SuiWalletAdapter {
  NightlySuiAdapter()
      : super(
          walletId: 'nightly',
          walletName: 'Nightly',
          deepLinkScheme: 'nightly://',
        );
}
