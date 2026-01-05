import 'dart:async';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../core/chain.dart';
import '../../errors/web3_exception.dart';
import '../wallet_abstraction.dart';
import '../authentication/auth_message.dart';

/// Adapter for Bitcoin wallets.
///
/// Supports wallets like BlueWallet, Electrum, and other BIP-137 compatible wallets.
///
/// Bitcoin wallets use different signing standards:
/// - BIP-137: Message signing standard
/// - BIP-322: Generic signed message format (newer)
///
/// Example:
/// ```dart
/// final blueWallet = BlueWalletAdapter();
/// await blueWallet.connect();
/// final signature = await blueWallet.signMessage('Hello Bitcoin');
/// ```
class BitcoinWalletAdapter implements Web3WalletAdapter {
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
  String? _chainId;
  AddressType _addressType = AddressType.unknown;
  WalletConnectionState _connectionState = WalletConnectionState.disconnected;

  final _stateController = StreamController<WalletConnectionState>.broadcast();

  BitcoinWalletAdapter({
    required this.walletId,
    required this.walletName,
    required this.deepLinkScheme,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportedNetworks = const ['bitcoin-mainnet', 'bitcoin-testnet'],
  });

  @override
  WalletInfo get info => WalletInfo(
        id: walletId,
        name: walletName,
        description: 'Bitcoin wallet',
        iconPath: 'assets/wallets/$walletId.png',
        blockchainType: BlockchainType.bitcoin,
        supportedChains: supportedNetworks,
        deepLinkScheme: deepLinkScheme,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
        supportsWalletConnect: false, // Bitcoin doesn't use WalletConnect
        supportsDeepLink: true,
        supportsMessageSigning: true,
        supportsTypedDataSigning: false, // Not applicable for Bitcoin
        supportsChainSwitching: false, // Bitcoin doesn't have multiple chains
      );

  @override
  Stream<WalletConnectionState> get connectionStateStream => _stateController.stream;

  @override
  WalletConnectionState get connectionState => _connectionState;

  @override
  String? get address => _address;

  @override
  String? get chainId => _chainId;

  /// The type of Bitcoin address connected.
  AddressType get addressType => _addressType;

  @override
  Future<WalletConnectionResult> connect() async {
    _updateState(WalletConnectionState.connecting);

    try {
      // Check if wallet is installed
      if (!await isInstalled()) {
        throw WalletException.walletNotInstalled(walletName);
      }

      // Build connect URI
      final requestId = _generateRequestId();
      final connectUri = _buildConnectUri(requestId);

      // Launch wallet
      _updateState(WalletConnectionState.awaitingApproval);
      await _launchWallet(connectUri);

      // Wait for response
      final result = await _waitForConnection(requestId);

      _address = result.address;
      _chainId = result.chainId;
      _addressType = _detectAddressType(result.address);
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
    _addressType = AddressType.unknown;
    _updateState(WalletConnectionState.disconnected);
  }

  @override
  Future<WalletSignature> signAuthMessage(AuthMessageData message) async {
    _requireConnected();

    final authMessage = AuthMessage.bitcoin(
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
      final requestId = _generateRequestId();
      final signUri = _buildSignMessageUri(requestId, message);

      await _launchWallet(signUri);
      final signature = await _waitForSignature(requestId);

      return WalletSignature(
        signature: signature,
        signerAddress: _address!,
        message: message,
        timestamp: DateTime.now(),
        format: SignatureFormat.bitcoinMessage,
        metadata: {
          'addressType': _addressType.name,
          'signatureFormat': 'BIP-137',
        },
      );
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Signing failed: $e', e);
    }
  }

  @override
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData) async {
    throw UnsupportedError('Bitcoin does not support typed data signing');
  }

  @override
  Future<String> sendTransaction(TransactionData transaction) async {
    _requireConnected();

    try {
      final requestId = _generateRequestId();
      final txUri = _buildSendTransactionUri(requestId, transaction);

      await _launchWallet(txUri);
      final txId = await _waitForTransaction(requestId);

      return txId;
    } catch (e) {
      if (e is WalletException) rethrow;
      throw WalletException.generic('Transaction failed: $e', e);
    }
  }

  @override
  Future<void> switchChain(String chainId) async {
    // Bitcoin doesn't have multiple chains in the EVM sense
    // But we can switch between mainnet and testnet
    if (chainId == _chainId) return;

    if (!supportedNetworks.contains(chainId)) {
      throw WalletException.chainNotSupported(chainId);
    }

    // Most Bitcoin wallets require reconnection for network switch
    throw WalletException.generic(
      'Please reconnect to switch Bitcoin networks',
    );
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

  /// Detect Bitcoin address type from address format.
  AddressType _detectAddressType(String address) {
    if (address.startsWith('1')) {
      return AddressType.p2pkh; // Legacy
    } else if (address.startsWith('3')) {
      return AddressType.p2sh; // Script hash (often SegWit wrapped)
    } else if (address.startsWith('bc1q')) {
      return AddressType.p2wpkh; // Native SegWit
    } else if (address.startsWith('bc1p')) {
      return AddressType.p2tr; // Taproot
    } else if (address.startsWith('tb1') || address.startsWith('2') || address.startsWith('m') || address.startsWith('n')) {
      return AddressType.testnet;
    }
    return AddressType.unknown;
  }

  String _buildConnectUri(String requestId) {
    return '${deepLinkScheme}request?'
        'requestId=$requestId&'
        'action=getAddress&'
        'callback=${Uri.encodeComponent('web3refi://bitcoin')}';
  }

  String _buildSignMessageUri(String requestId, String message) {
    final encodedMessage = base64Url.encode(utf8.encode(message));
    return '${deepLinkScheme}request?'
        'requestId=$requestId&'
        'action=signMessage&'
        'message=$encodedMessage&'
        'address=$_address&'
        'callback=${Uri.encodeComponent('web3refi://bitcoin')}';
  }

  String _buildSendTransactionUri(String requestId, TransactionData tx) {
    return '${deepLinkScheme}request?'
        'requestId=$requestId&'
        'action=sendPayment&'
        'address=${tx.to}&'
        'amount=${tx.value.toString()}&'
        'callback=${Uri.encodeComponent('web3refi://bitcoin')}';
  }

  Future<void> _launchWallet(String uri) async {
    final url = Uri.parse(uri);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw WalletException.walletNotInstalled(walletName);
    }
  }

  Future<WalletConnectionResult> _waitForConnection(String requestId) async {
    // Implement deep link callback handling
    await Future.delayed(const Duration(seconds: 1));

    // Simulated response
    return WalletConnectionResult(
      address: 'bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh',
      chainId: 'bitcoin-mainnet',
      blockchainType: BlockchainType.bitcoin,
      metadata: {'addressType': 'p2wpkh'},
    );
  }

  Future<String> _waitForSignature(String requestId) async {
    await Future.delayed(const Duration(seconds: 1));
    // Return base64 encoded signature (BIP-137 format)
    return base64.encode(List.generate(65, (i) => i % 256));
  }

  Future<String> _waitForTransaction(String requestId) async {
    await Future.delayed(const Duration(seconds: 1));
    return 'a' * 64; // Simulated txid
  }
}

/// Bitcoin address types.
enum AddressType {
  /// Legacy Pay-to-Public-Key-Hash (starts with 1).
  p2pkh,

  /// Pay-to-Script-Hash (starts with 3).
  p2sh,

  /// Native SegWit Pay-to-Witness-Public-Key-Hash (starts with bc1q).
  p2wpkh,

  /// Pay-to-Witness-Script-Hash (starts with bc1q, longer).
  p2wsh,

  /// Taproot (starts with bc1p).
  p2tr,

  /// Testnet address.
  testnet,

  /// Unknown address type.
  unknown,
}

// ════════════════════════════════════════════════════════════════════════════
// SPECIFIC BITCOIN WALLET IMPLEMENTATIONS
// ════════════════════════════════════════════════════════════════════════════

/// BlueWallet adapter.
class BlueWalletAdapter extends BitcoinWalletAdapter {
  BlueWalletAdapter()
      : super(
          walletId: 'bluewallet',
          walletName: 'BlueWallet',
          deepLinkScheme: 'bluewallet://',
          appStoreUrl: 'https://apps.apple.com/app/bluewallet-bitcoin-wallet/id1376878040',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=io.bluewallet.bluewallet',
        );
}

/// Electrum wallet adapter.
class ElectrumAdapter extends BitcoinWalletAdapter {
  ElectrumAdapter()
      : super(
          walletId: 'electrum',
          walletName: 'Electrum',
          deepLinkScheme: 'electrum://',
        );
}

/// Sparrow wallet adapter.
class SparrowAdapter extends BitcoinWalletAdapter {
  SparrowAdapter()
      : super(
          walletId: 'sparrow',
          walletName: 'Sparrow',
          deepLinkScheme: 'sparrow://',
        );
}

/// Generic Bitcoin wallet adapter using BIP-21 URIs.
class GenericBitcoinAdapter extends BitcoinWalletAdapter {
  GenericBitcoinAdapter({
    required String walletId,
    required String walletName,
  }) : super(
          walletId: walletId,
          walletName: walletName,
          deepLinkScheme: 'bitcoin:',
        );
}
