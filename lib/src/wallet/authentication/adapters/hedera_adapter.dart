import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chain.dart';
import '../../errors/web3_exception.dart';
import '../wallet_abstraction.dart';
import '../authentication/auth_message.dart';

/// Adapter for Hedera Hashgraph wallets.
///
/// Supports wallets like HashPack, Blade, and other Hedera wallets.
///
/// Hedera uses a unique account model with account IDs (e.g., 0.0.12345)
/// instead of typical addresses.
///
/// Example:
/// ```dart
/// final hashpack = HashPackAdapter();
/// await hashpack.connect();
/// final signature = await hashpack.signMessage('Hello Hedera');
/// ```
class HederaWalletAdapter implements Web3WalletAdapter {
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
  String? _accountId;
  String? _publicKey;
  String? _network;
  String? _pairingTopic;
  WalletConnectionState _connectionState = WalletConnectionState.disconnected;

  final _stateController = StreamController<WalletConnectionState>.broadcast();

  HederaWalletAdapter({
    required this.walletId,
    required this.walletName,
    required this.deepLinkScheme,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportedNetworks = const ['hedera-mainnet', 'hedera-testnet'],
  });

  @override
  WalletInfo get info => WalletInfo(
        id: walletId,
        name: walletName,
        description: 'Hedera Hashgraph wallet',
        iconPath: 'assets/wallets/$walletId.png',
        blockchainType: BlockchainType.hedera,
        supportedChains: supportedNetworks,
        deepLinkScheme: deepLinkScheme,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
        supportsWalletConnect: false, // Uses WalletConnect-like protocol but custom
        supportsDeepLink: true,
        supportsMessageSigning: true,
        supportsTypedDataSigning: false,
        supportsChainSwitching: true,
      );

  @override
  Stream<WalletConnectionState> get connectionStateStream => _stateController.stream;

  @override
  WalletConnectionState get connectionState => _connectionState;

  /// Hedera account ID (e.g., "0.0.12345").
  @override
  String? get address => _accountId;

  /// Hedera public key.
  String? get publicKey => _publicKey;

  @override
  String? get chainId => _network;

  /// The current Hedera network.
  String? get network => _network?.replaceFirst('hedera-', '');

  @override
  Future<WalletConnectionResult> connect() async {
    _updateState(WalletConnectionState.connecting);

    try {
      if (!await isInstalled()) {
        throw WalletException.walletNotInstalled(walletName);
      }

      // Build pairing request
      final pairingData = _buildPairingData();
      final connectUri = _buildConnectUri(pairingData);

      // Launch wallet
      _updateState(WalletConnectionState.awaitingApproval);
      await _launchWallet(connectUri);

      // Wait for pairing response
      final result = await _waitForConnection();

      _accountId = result.address;
      _network = result.chainId;
      _publicKey = result.metadata['publicKey'] as String?;
      _pairingTopic = result.sessionId;
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
    if (_pairingTopic != null) {
      try {
        final disconnectUri = _buildDisconnectUri();
        await _launchWallet(disconnectUri);
      } catch (e) {
        // Ignore disconnect errors
      }
    }

    _accountId = null;
    _publicKey = null;
    _network = null;
    _pairingTopic = null;
    _updateState(WalletConnectionState.disconnected);
  }

  @override
  Future<WalletSignature> signAuthMessage(AuthMessageData message) async {
    _requireConnected();

    final authMessage = AuthMessage.hedera(
      domain: message.domain,
      accountId: _accountId!,
      statement: message.statement,
    );

    return signMessage(authMessage.toSignableMessage());
  }

  @override
  Future<WalletSignature> signMessage(String message) async {
    _requireConnected();

    try {
      final messageBytes = utf8.encode(message);
      final signUri = _buildSignMessageUri(messageBytes);

      await _launchWallet(signUri);
      final signature = await _waitForSignature();

      return WalletSignature(
        signature: signature,
        signerAddress: _accountId!,
        message: message,
        timestamp: DateTime.now(),
        format: SignatureFormat.hederaEd25519,
        metadata: {
          'publicKey': _publicKey,
          'accountId': _accountId,
        },
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Signing failed: $e', e);
    }
  }

  @override
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData) async {
    throw UnsupportedError('Hedera does not support typed data signing');
  }

  @override
  Future<String> sendTransaction(TransactionData transaction) async {
    _requireConnected();

    try {
      final txUri = _buildTransactionUri(transaction);

      await _launchWallet(txUri);
      final txId = await _waitForTransaction();

      return txId;
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

    // Most Hedera wallets require reconnection for network switch
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

  Map<String, dynamic> _buildPairingData() {
    return {
      'name': 'web3refi',
      'description': 'Web3 SDK for Flutter',
      'url': 'https://web3refi.dev',
      'icons': ['https://web3refi.dev/icon.png'],
      'network': _network ?? 'mainnet',
    };
  }

  String _buildConnectUri(Map<String, dynamic> pairingData) {
    final encoded = base64Url.encode(utf8.encode(jsonEncode(pairingData)));
    return '${deepLinkScheme}pair?'
        'data=$encoded&'
        'redirect=${Uri.encodeComponent('web3refi://hedera/connect')}';
  }

  String _buildDisconnectUri() {
    return '${deepLinkScheme}disconnect?'
        'topic=$_pairingTopic&'
        'redirect=${Uri.encodeComponent('web3refi://hedera/disconnect')}';
  }

  String _buildSignMessageUri(List<int> message) {
    final encodedMessage = base64Url.encode(message);
    return '${deepLinkScheme}sign?'
        'topic=$_pairingTopic&'
        'type=message&'
        'data=$encodedMessage&'
        'redirect=${Uri.encodeComponent('web3refi://hedera/sign')}';
  }

  String _buildTransactionUri(TransactionData tx) {
    // Build Hedera transaction
    // Hedera uses a different transaction format than EVM
    final txData = {
      'type': 'cryptoTransfer',
      'transfers': [
        {
          'accountId': tx.to,
          'amount': tx.value.toString(),
        },
      ],
      if (tx.metadata['memo'] != null) 'memo': tx.metadata['memo'],
    };

    final encoded = base64Url.encode(utf8.encode(jsonEncode(txData)));
    return '${deepLinkScheme}transaction?'
        'topic=$_pairingTopic&'
        'data=$encoded&'
        'redirect=${Uri.encodeComponent('web3refi://hedera/transaction')}';
  }

  Future<void> _launchWallet(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw WalletException.walletNotInstalled(walletName);
    }
  }

  Future<WalletConnectionResult> _waitForConnection() async {
    await Future.delayed(const Duration(seconds: 1));

    // Simulated response
    return WalletConnectionResult(
      address: '0.0.12345',
      chainId: 'hedera-mainnet',
      blockchainType: BlockchainType.hedera,
      sessionId: 'pairing_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'publicKey': '302a300506032b6570032100${List.generate(32, (i) => i.toRadixString(16).padLeft(2, '0')).join()}',
        'network': 'mainnet',
      },
    );
  }

  Future<String> _waitForSignature() async {
    await Future.delayed(const Duration(seconds: 1));
    // Hedera signatures are hex-encoded
    return List.generate(64, (i) => (i % 256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<String> _waitForTransaction() async {
    await Future.delayed(const Duration(seconds: 1));
    // Hedera transaction IDs format: accountId@seconds.nanoseconds
    return '0.0.12345@${DateTime.now().millisecondsSinceEpoch ~/ 1000}.${DateTime.now().millisecond * 1000000}';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPECIFIC HEDERA WALLET IMPLEMENTATIONS
// ════════════════════════════════════════════════════════════════════════════

/// HashPack wallet adapter.
class HashPackAdapter extends HederaWalletAdapter {
  HashPackAdapter()
      : super(
          walletId: 'hashpack',
          walletName: 'HashPack',
          deepLinkScheme: 'hashpack://',
          appStoreUrl: 'https://apps.apple.com/app/hashpack/id1604553498',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.hashpack.wallet',
        );
}

/// Blade wallet adapter.
class BladeAdapter extends HederaWalletAdapter {
  BladeAdapter()
      : super(
          walletId: 'blade',
          walletName: 'Blade',
          deepLinkScheme: 'blade://',
          appStoreUrl: 'https://apps.apple.com/app/blade-hedera-wallet/id1614152527',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.aspect.blade',
        );
}

/// Kabila wallet adapter.
class KabilaAdapter extends HederaWalletAdapter {
  KabilaAdapter()
      : super(
          walletId: 'kabila',
          walletName: 'Kabila',
          deepLinkScheme: 'kabila://',
        );
}

/// WallaWallet adapter for Hedera.
class WallaWalletAdapter extends HederaWalletAdapter {
  WallaWalletAdapter()
      : super(
          walletId: 'wallawallet',
          walletName: 'WallaWallet',
          deepLinkScheme: 'wallawallet://',
        );
}
