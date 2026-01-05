import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chain.dart';
import '../../errors/web3_exception.dart';
import '../wallet_abstraction.dart';
import '../authentication/auth_message.dart';

/// Adapter for Solana wallets.
///
/// Supports wallets like Phantom, Solflare, Glow, and other Solana wallets.
///
/// Solana uses Ed25519 for cryptographic operations.
///
/// Example:
/// ```dart
/// final phantom = PhantomAdapter();
/// await phantom.connect();
/// final signature = await phantom.signMessage('Hello Solana');
/// ```
class SolanaWalletAdapter implements Web3WalletAdapter {
  /// Wallet identifier.
  final String walletId;

  /// Wallet display name.
  final String walletName;

  /// Deep link scheme.
  final String deepLinkScheme;

  /// Universal link domain.
  final String? universalLinkDomain;

  /// App Store URL.
  final String? appStoreUrl;

  /// Play Store URL.
  final String? playStoreUrl;

  /// Supported clusters.
  final List<String> supportedClusters;

  // State
  String? _publicKey;
  String? _cluster;
  String? _session;
  Uint8List? _sharedSecret;
  Uint8List? _dappKeyPair;
  WalletConnectionState _connectionState = WalletConnectionState.disconnected;

  final _stateController = StreamController<WalletConnectionState>.broadcast();

  SolanaWalletAdapter({
    required this.walletId,
    required this.walletName,
    required this.deepLinkScheme,
    this.universalLinkDomain,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportedClusters = const ['mainnet-beta', 'devnet', 'testnet'],
  });

  @override
  WalletInfo get info => WalletInfo(
        id: walletId,
        name: walletName,
        description: 'Solana wallet',
        iconPath: 'assets/wallets/$walletId.png',
        blockchainType: BlockchainType.solana,
        supportedChains: supportedClusters.map((c) => 'solana-$c').toList(),
        deepLinkScheme: deepLinkScheme,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
        supportsWalletConnect: false, // Solana uses its own deep link protocol
        supportsDeepLink: true,
        supportsMessageSigning: true,
        supportsTypedDataSigning: false,
        supportsChainSwitching: true, // Can switch clusters
      );

  @override
  Stream<WalletConnectionState> get connectionStateStream => _stateController.stream;

  @override
  WalletConnectionState get connectionState => _connectionState;

  @override
  String? get address => _publicKey;

  @override
  String? get chainId => _cluster != null ? 'solana-$_cluster' : null;

  /// The current Solana cluster.
  String? get cluster => _cluster;

  @override
  Future<WalletConnectionResult> connect() async {
    _updateState(WalletConnectionState.connecting);

    try {
      if (!await isInstalled()) {
        throw WalletException.walletNotInstalled(walletName);
      }

      // Generate ephemeral keypair for encryption
      _dappKeyPair = _generateKeyPair();
      final dappPublicKey = _getPublicKeyFromKeypair(_dappKeyPair!);

      // Build connect URI
      final connectUri = _buildConnectUri(dappPublicKey);

      // Launch wallet
      _updateState(WalletConnectionState.awaitingApproval);
      await _launchWallet(connectUri);

      // Wait for response
      final result = await _waitForConnection();

      _publicKey = result.address;
      _cluster = result.chainId.replaceFirst('solana-', '');
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
    if (_session != null) {
      try {
        final disconnectUri = _buildDisconnectUri();
        await _launchWallet(disconnectUri);
      } catch (e) {
        // Ignore disconnect errors
      }
    }

    _publicKey = null;
    _cluster = null;
    _session = null;
    _sharedSecret = null;
    _dappKeyPair = null;
    _updateState(WalletConnectionState.disconnected);
  }

  @override
  Future<WalletSignature> signAuthMessage(AuthMessageData message) async {
    _requireConnected();

    final authMessage = AuthMessage.solana(
      domain: message.domain,
      address: _publicKey!,
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
        signerAddress: _publicKey!,
        message: message,
        timestamp: DateTime.now(),
        format: SignatureFormat.solanaEd25519,
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Signing failed: $e', e);
    }
  }

  @override
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData) async {
    throw UnsupportedError('Solana does not support typed data signing');
  }

  @override
  Future<String> sendTransaction(TransactionData transaction) async {
    _requireConnected();

    try {
      // For Solana, we need to build a proper Solana transaction
      // This is a simplified version - real implementation needs Solana SDK
      final txUri = _buildSignTransactionUri(transaction);

      await _launchWallet(txUri);
      final signature = await _waitForTransaction();

      return signature;
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Transaction failed: $e', e);
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    _requireConnected();

    final newCluster = chainId.replaceFirst('solana-', '');
    if (!supportedClusters.contains(newCluster)) {
      throw WalletException.chainNotSupported(chainId);
    }

    // Most Solana wallets require reconnection for cluster switch
    _cluster = newCluster;
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

  Uint8List _generateKeyPair() {
    // Generate 64-byte keypair (32 private + 32 public)
    final random = Random.secure();
    return Uint8List.fromList(List.generate(64, (_) => random.nextInt(256)));
  }

  String _getPublicKeyFromKeypair(Uint8List keypair) {
    // Get public key portion and encode as base58
    final publicKey = keypair.sublist(32);
    return _encodeBase58(publicKey);
  }

  String _buildConnectUri(String dappPublicKey) {
    final params = {
      'dapp_encryption_public_key': dappPublicKey,
      'cluster': _cluster ?? 'mainnet-beta',
      'app_url': 'https://web3refi.dev',
      'redirect_link': 'web3refi://solana/connect',
    };

    return '${deepLinkScheme}v1/connect?${_encodeParams(params)}';
  }

  String _buildDisconnectUri() {
    final params = {
      'session': _session!,
      'redirect_link': 'web3refi://solana/disconnect',
    };

    return '${deepLinkScheme}v1/disconnect?${_encodeParams(params)}';
  }

  String _buildSignMessageUri(List<int> message) {
    final params = {
      'session': _session!,
      'message': base58Encode(Uint8List.fromList(message)),
      'redirect_link': 'web3refi://solana/signMessage',
    };

    return '${deepLinkScheme}v1/signMessage?${_encodeParams(params)}';
  }

  String _buildSignTransactionUri(TransactionData tx) {
    // Build serialized Solana transaction
    // This is simplified - real implementation needs proper Solana transaction serialization
    final params = {
      'session': _session!,
      'transaction': 'base58_encoded_transaction',
      'redirect_link': 'web3refi://solana/signTransaction',
    };

    return '${deepLinkScheme}v1/signTransaction?${_encodeParams(params)}';
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

    // Simulated response - implement deep link callback handling
    _session = 'session_${DateTime.now().millisecondsSinceEpoch}';

    return WalletConnectionResult(
      address: '9xqeWvG816bUx9EPjHmaT23yvVM2ZWbrrpZb9PusVFin',
      chainId: 'solana-mainnet-beta',
      blockchainType: BlockchainType.solana,
      sessionId: _session,
    );
  }

  Future<String> _waitForSignature() async {
    await Future.delayed(const Duration(seconds: 1));
    return base58Encode(Uint8List(64)); // Simulated 64-byte signature
  }

  Future<String> _waitForTransaction() async {
    await Future.delayed(const Duration(seconds: 1));
    return base58Encode(Uint8List(64)); // Simulated transaction signature
  }

  String _encodeBase58(List<int> bytes) {
    return base58Encode(Uint8List.fromList(bytes));
  }
}

/// Base58 encoding for Solana addresses and signatures.
String base58Encode(Uint8List bytes) {
  const alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  if (bytes.isEmpty) return '';

  // Count leading zeros
  var zeros = 0;
  for (final byte in bytes) {
    if (byte == 0) {
      zeros++;
    } else {
      break;
    }
  }

  // Convert to base58
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = value * BigInt.from(256) + BigInt.from(byte);
  }

  final result = StringBuffer();
  while (value > BigInt.zero) {
    final remainder = (value % BigInt.from(58)).toInt();
    value ~/= BigInt.from(58);
    result.write(alphabet[remainder]);
  }

  // Add leading '1's for each leading zero byte
  for (var i = 0; i < zeros; i++) {
    result.write('1');
  }

  return result.toString().split('').reversed.join();
}

// ════════════════════════════════════════════════════════════════════════════
// SPECIFIC SOLANA WALLET IMPLEMENTATIONS
// ════════════════════════════════════════════════════════════════════════════

/// Phantom wallet adapter.
class PhantomAdapter extends SolanaWalletAdapter {
  PhantomAdapter()
      : super(
          walletId: 'phantom',
          walletName: 'Phantom',
          deepLinkScheme: 'phantom://',
          universalLinkDomain: 'phantom.app',
          appStoreUrl: 'https://apps.apple.com/app/phantom-solana-wallet/id1598432977',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=app.phantom',
        );
}

/// Solflare wallet adapter.
class SolflareAdapter extends SolanaWalletAdapter {
  SolflareAdapter()
      : super(
          walletId: 'solflare',
          walletName: 'Solflare',
          deepLinkScheme: 'solflare://',
          appStoreUrl: 'https://apps.apple.com/app/solflare/id1580902717',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.solflare.mobile',
        );
}

/// Glow wallet adapter.
class GlowAdapter extends SolanaWalletAdapter {
  GlowAdapter()
      : super(
          walletId: 'glow',
          walletName: 'Glow',
          deepLinkScheme: 'glow://',
          appStoreUrl: 'https://apps.apple.com/app/glow-solana-wallet/id1599584512',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=com.luma.wallet.prod',
        );
}

/// Backpack wallet adapter.
class BackpackAdapter extends SolanaWalletAdapter {
  BackpackAdapter()
      : super(
          walletId: 'backpack',
          walletName: 'Backpack',
          deepLinkScheme: 'backpack://',
          appStoreUrl: 'https://apps.apple.com/app/backpack-crypto-wallet/id6444544032',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=app.backpack.mobile',
        );
}
