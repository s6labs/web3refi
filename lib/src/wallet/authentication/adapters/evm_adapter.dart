import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chain.dart';
import '../../exceptions/web3_exception.dart';
import '../wallet_abstraction.dart';
import '../authentication/auth_message.dart';

/// Base adapter for EVM-compatible wallets (Ethereum, Polygon, etc.).
///
/// This adapter handles common EVM wallet operations and can be extended
/// for specific wallet implementations like MetaMask, Rainbow, Trust, etc.
///
/// Example:
/// ```dart
/// final metamask = MetaMaskAdapter();
/// await metamask.connect();
/// final signature = await metamask.signMessage('Hello');
/// ```
class EvmWalletAdapter implements Web3WalletAdapter {
  /// Wallet identifier.
  final String walletId;

  /// Wallet display name.
  final String walletName;

  /// Deep link scheme (e.g., 'metamask://').
  final String deepLinkScheme;

  /// Universal link domain (e.g., 'metamask.app.link').
  final String? universalLinkDomain;

  /// App Store URL for iOS.
  final String? appStoreUrl;

  /// Play Store URL for Android.
  final String? playStoreUrl;

  /// Supported chain IDs.
  final List<String> supportedChainIds;

  // State
  String? _address;
  String? _chainId;
  String? _sessionId;
  WalletConnectionState _connectionState = WalletConnectionState.disconnected;

  // Stream controller for connection state
  final _stateController = StreamController<WalletConnectionState>.broadcast();

  EvmWalletAdapter({
    required this.walletId,
    required this.walletName,
    required this.deepLinkScheme,
    this.universalLinkDomain,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportedChainIds = const ['1', '137', '42161', '10', '8453'],
  });

  @override
  WalletInfo get info => WalletInfo(
        id: walletId,
        name: walletName,
        description: 'EVM-compatible wallet',
        iconPath: 'assets/wallets/$walletId.png',
        blockchainType: BlockchainType.evm,
        supportedChains: supportedChainIds,
        deepLinkScheme: deepLinkScheme,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
        supportsWalletConnect: true,
        supportsDeepLink: true,
        supportsMessageSigning: true,
        supportsTypedDataSigning: true,
        supportsChainSwitching: true,
      );

  @override
  Stream<WalletConnectionState> get connectionStateStream => _stateController.stream;

  @override
  WalletConnectionState get connectionState => _connectionState;

  @override
  String? get address => _address;

  @override
  String? get chainId => _chainId;

  @override
  Future<WalletConnectionResult> connect() async {
    _updateState(WalletConnectionState.connecting);

    try {
      // Check if wallet is installed
      if (!await isInstalled()) {
        throw WalletException.walletNotInstalled(walletName);
      }

      // Generate connection request
      final requestId = _generateRequestId();

      // Build WalletConnect URI or deep link
      final connectUri = _buildConnectUri(requestId);

      // Launch wallet app
      _updateState(WalletConnectionState.awaitingApproval);
      await _launchWallet(connectUri);

      // Wait for response (in production, this would use WalletConnect or deep link callback)
      final result = await _waitForConnection(requestId);

      _address = result.address;
      _chainId = result.chainId;
      _sessionId = result.sessionId;
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
    _chainId = null;
    _sessionId = null;
    _updateState(WalletConnectionState.disconnected);
  }

  @override
  Future<WalletSignature> signAuthMessage(AuthMessageData message) async {
    _requireConnected();

    final authMessage = AuthMessage(
      domain: message.domain,
      address: message.address,
      chainId: message.chainId,
      blockchainType: BlockchainType.evm,
      nonce: message.nonce,
      issuedAt: message.issuedAt,
      expiresAt: message.expiresAt,
      statement: message.statement,
      uri: message.uri,
      version: message.version,
      resources: message.resources,
    );

    return signMessage(authMessage.toSignableMessage());
  }

  @override
  Future<WalletSignature> signMessage(String message) async {
    _requireConnected();

    try {
      // Build signing request
      final requestId = _generateRequestId();
      final signUri = _buildSignMessageUri(requestId, message);

      // Launch wallet for signing
      await _launchWallet(signUri);

      // Wait for signature
      final signature = await _waitForSignature(requestId);

      return WalletSignature(
        signature: signature,
        signerAddress: _address!,
        message: message,
        timestamp: DateTime.now(),
        format: SignatureFormat.ethereumPersonalSign,
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Signing failed: $e', e);
    }
  }

  @override
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData) async {
    _requireConnected();

    try {
      final requestId = _generateRequestId();
      final signUri = _buildSignTypedDataUri(requestId, typedData);

      await _launchWallet(signUri);
      final signature = await _waitForSignature(requestId);

      return WalletSignature(
        signature: signature,
        signerAddress: _address!,
        message: typedData.toString(),
        timestamp: DateTime.now(),
        format: SignatureFormat.ethereumTypedData,
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Typed data signing failed: $e', e);
    }
  }

  @override
  Future<String> sendTransaction(TransactionData transaction) async {
    _requireConnected();

    try {
      final requestId = _generateRequestId();
      final txJson = transaction.toEvmJson(_address!);
      final txUri = _buildSendTransactionUri(requestId, txJson);

      await _launchWallet(txUri);
      final txHash = await _waitForTransaction(requestId);

      return txHash;
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Transaction failed: $e', e);
    }
  }

  @override
  Future<void> switchChain(String newChainId) async {
    _requireConnected();

    if (!supportedChainIds.contains(newChainId)) {
      throw WalletException.chainNotSupported('Chain $newChainId');
    }

    try {
      final requestId = _generateRequestId();
      final switchUri = _buildSwitchChainUri(requestId, newChainId);

      await _launchWallet(switchUri);
      await _waitForChainSwitch(requestId);

      _chainId = newChainId;
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Chain switch failed: $e', e);
    }
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

  String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }

  String _buildConnectUri(String requestId) {
    // In production, this would build a WalletConnect URI
    // For direct deep linking:
    return '${deepLinkScheme}wc?'
        'requestId=$requestId&'
        'method=eth_requestAccounts&'
        'redirect=${Uri.encodeComponent('web3refi://')}';
  }

  String _buildSignMessageUri(String requestId, String message) {
    return '${deepLinkScheme}wc?'
        'requestId=$requestId&'
        'method=personal_sign&'
        'message=${Uri.encodeComponent(message)}&'
        'address=$_address&'
        'redirect=${Uri.encodeComponent('web3refi://')}';
  }

  String _buildSignTypedDataUri(String requestId, Map<String, dynamic> typedData) {
    return '${deepLinkScheme}wc?'
        'requestId=$requestId&'
        'method=eth_signTypedData_v4&'
        'data=${Uri.encodeComponent(typedData.toString())}&'
        'address=$_address&'
        'redirect=${Uri.encodeComponent('web3refi://')}';
  }

  String _buildSendTransactionUri(String requestId, Map<String, String> tx) {
    return '${deepLinkScheme}wc?'
        'requestId=$requestId&'
        'method=eth_sendTransaction&'
        'tx=${Uri.encodeComponent(tx.toString())}&'
        'redirect=${Uri.encodeComponent('web3refi://')}';
  }

  String _buildSwitchChainUri(String requestId, String chainId) {
    return '${deepLinkScheme}wc?'
        'requestId=$requestId&'
        'method=wallet_switchEthereumChain&'
        'chainId=${Uri.encodeComponent('0x${int.parse(chainId).toRadixString(16)}')}&'
        'redirect=${Uri.encodeComponent('web3refi://')}';
  }

  Future<void> _launchWallet(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw WalletException.walletNotInstalled(walletName);
    }
  }

  Future<WalletConnectionResult> _waitForConnection(String requestId) async {
    // In production, implement proper deep link callback handling
    // For now, simulate with timeout
    await Future.delayed(const Duration(seconds: 1));

    // Simulated response - replace with actual callback handling
    return WalletConnectionResult(
      address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      chainId: '1',
      blockchainType: BlockchainType.evm,
      sessionId: 'session_$requestId',
    );
  }

  Future<String> _waitForSignature(String requestId) async {
    await Future.delayed(const Duration(seconds: 1));
    return '0x${'a' * 130}'; // Simulated signature
  }

  Future<String> _waitForTransaction(String requestId) async {
    await Future.delayed(const Duration(seconds: 1));
    return '0x${'b' * 64}'; // Simulated tx hash
  }

  Future<void> _waitForChainSwitch(String requestId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SPECIFIC EVM WALLET IMPLEMENTATIONS
// ════════════════════════════════════════════════════════════════════════════

/// MetaMask wallet adapter.
class MetaMaskAdapter extends EvmWalletAdapter {
  MetaMaskAdapter()
      : super(
          walletId: 'metamask',
          walletName: 'MetaMask',
          deepLinkScheme: 'metamask://',
          universalLinkDomain: 'metamask.app.link',
          appStoreUrl: 'https://apps.apple.com/app/metamask/id1438144202',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.metamask',
        );
}

/// Rainbow wallet adapter.
class RainbowAdapter extends EvmWalletAdapter {
  RainbowAdapter()
      : super(
          walletId: 'rainbow',
          walletName: 'Rainbow',
          deepLinkScheme: 'rainbow://',
          universalLinkDomain: 'rnbwapp.com',
          appStoreUrl: 'https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=me.rainbow',
        );
}

/// Trust Wallet adapter.
class TrustWalletAdapter extends EvmWalletAdapter {
  TrustWalletAdapter()
      : super(
          walletId: 'trust',
          walletName: 'Trust Wallet',
          deepLinkScheme: 'trust://',
          universalLinkDomain: 'link.trustwallet.com',
          appStoreUrl: 'https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.wallet.crypto.trustapp',
        );
}

/// Coinbase Wallet adapter.
class CoinbaseWalletAdapter extends EvmWalletAdapter {
  CoinbaseWalletAdapter()
      : super(
          walletId: 'coinbase',
          walletName: 'Coinbase Wallet',
          deepLinkScheme: 'cbwallet://',
          universalLinkDomain: 'go.cb-w.com',
          appStoreUrl: 'https://apps.apple.com/app/coinbase-wallet/id1278383455',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=org.toshi',
        );
}

/// Generic EVM wallet adapter for WalletConnect-only wallets.
class GenericEvmAdapter extends EvmWalletAdapter {
  GenericEvmAdapter({
    required String walletId,
    required String walletName,
    String? deepLinkScheme,
  }) : super(
          walletId: walletId,
          walletName: walletName,
          deepLinkScheme: deepLinkScheme ?? 'wc://',
        );
}
