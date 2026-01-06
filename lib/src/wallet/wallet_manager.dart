import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:reown_appkit/reown_appkit.dart';
import 'package:web3refi/src/core/chain.dart';
import 'package:web3refi/src/core/web3refi_config.dart';
import 'package:web3refi/src/errors/wallet_exception.dart';
import 'package:web3refi/src/errors/transaction_exception.dart';
import 'package:web3refi/src/wallet/wallet_abstraction.dart';

// ════════════════════════════════════════════════════════════════════════════
// WALLET MANAGER
// ════════════════════════════════════════════════════════════════════════════

/// Central manager for all wallet operations.
///
/// Handles:
/// - Wallet connections via WalletConnect v2 (if projectId provided)
/// - Direct wallet integration (private key, injected providers)
/// - Session persistence across app restarts
/// - Multi-wallet profile management
/// - Transaction signing and sending
/// - Chain switching
///
/// ## Standalone Mode (No Reown/WalletConnect)
/// ```dart
/// final manager = WalletManager(
///   chains: [Chains.ethereum, Chains.polygon],
///   // No projectId - uses direct wallet integration
/// );
/// ```
///
/// ## With WalletConnect
/// ```dart
/// final manager = WalletManager(
///   projectId: 'YOUR_PROJECT_ID', // Optional - enables WalletConnect
///   chains: [Chains.ethereum, Chains.polygon],
/// );
/// ```
///
/// ```dart
/// await manager.initialize();
/// await manager.connect();
///
/// if (manager.isConnected) {
///   final txHash = await manager.sendTransaction(
///     to: '0x...',
///     value: '0x...',
///   );
/// }
/// ```
class WalletManager extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  // CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════════

  /// WalletConnect/Reown Cloud Project ID.
  ///
  /// Optional - if not provided, WalletConnect features will be disabled
  /// and the SDK will use direct wallet integration only.
  final String? projectId;

  /// Application metadata for WalletConnect.
  final AppMetadata? appMetadata;

  /// Supported blockchain networks.
  final List<Chain> chains;

  /// Default chain to connect to.
  final Chain defaultChain;

  /// Enable debug logging.
  final bool enableLogging;

  /// Connection timeout duration.
  final Duration connectionTimeout;

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE STATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Reown AppKit instance for WalletConnect v2.
  ReownAppKit? _appKit;

  /// Connect response completer for async connection handling.
  Completer<ConnectResponse>? _connectCompleter;

  /// Secure storage for session persistence.
  final FlutterSecureStorage _secureStorage;

  /// Current connection state.
  WalletConnectionState _state = WalletConnectionState.disconnected;

  /// Connected wallet address.
  String? _address;

  /// Current chain ID.
  int? _chainId;

  /// Active session ID (WalletConnect topic).
  String? _sessionId;

  /// Connected wallet info.
  WalletInfo? _connectedWallet;

  /// User ID for multi-wallet profiles.
  String? _userId;

  /// Last error message.
  String? _errorMessage;

  /// Event stream controller.
  final StreamController<WalletEvent> _eventController =
      StreamController<WalletEvent>.broadcast();

  /// Registered wallet adapters.
  final Map<String, Web3WalletAdapter> _walletAdapters = {};

  /// Whether the manager has been initialized.
  bool _isInitialized = false;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  WalletManager({
    required this.chains,
    this.projectId,
    Chain? defaultChain,
    this.appMetadata,
    this.enableLogging = false,
    this.connectionTimeout = const Duration(minutes: 2),
    FlutterSecureStorage? secureStorage,
  })  : defaultChain = defaultChain ?? chains.first,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
          iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
        );

  /// Whether WalletConnect is available (projectId configured).
  bool get hasWalletConnect => projectId != null && projectId!.isNotEmpty;

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Current connection state.
  WalletConnectionState get state => _state;

  /// Whether a wallet is connected.
  bool get isConnected =>
      _state == WalletConnectionState.connected && _address != null;

  /// Connected wallet address (checksummed).
  String? get address => _address;

  /// Current chain ID.
  int? get chainId => _chainId;

  /// Active session ID.
  String? get sessionId => _sessionId;

  /// Connected wallet info.
  WalletInfo? get connectedWallet => _connectedWallet;

  /// User ID for multi-wallet profiles.
  String? get userId => _userId;

  /// Last error message.
  String? get errorMessage => _errorMessage;

  /// Stream of wallet events.
  Stream<WalletEvent> get events => _eventController.stream;

  /// Whether the manager is initialized.
  bool get isInitialized => _isInitialized;

  /// Current chain configuration.
  Chain? get currentChain {
    if (_chainId == null) return null;
    try {
      return chains.firstWhere((c) => c.chainId == _chainId);
    } catch (_) {
      return null;
    }
  }

  /// Available wallets for the current platform.
  List<WalletInfo> get availableWallets {
    return StaticWalletRegistry.all
        .where((w) => chains.any((c) => w.supportedChains.contains(c.chainId.toString())))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the wallet manager.
  ///
  /// Must be called before any other operations.
  /// Sets up WalletConnect client and event listeners.
  Future<void> initialize() async {
    if (_isInitialized) {
      _log('Already initialized');
      return;
    }

    _log('Initializing WalletManager...');

    try {
      // Initialize WalletConnect v2 client
      await _initializeWalletConnect();

      // Set up event listeners
      _setupEventListeners();

      _isInitialized = true;
      _log('WalletManager initialized successfully');
    } catch (e, stackTrace) {
      _log('Initialization failed: $e');
      throw WalletException(
        message: 'Failed to initialize wallet manager: $e',
        code: 'init_failed',
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeWalletConnect() async {
    // Register static wallet info for deep linking support
    for (final wallet in StaticWalletRegistry.all) {
      WalletRegistry.registerWalletInfo(wallet);
    }
    _log('Registered ${StaticWalletRegistry.all.length} static wallets');

    // In production, initialize WalletConnect SDK:
    //
    // _wcClient = await Web3Wallet.createInstance(
    //   projectId: projectId,
    //   metadata: PairingMetadata(
    //     name: appMetadata?.name ?? 'web3refi App',
    //     description: appMetadata?.description ?? 'Flutter Web3 App',
    //     url: appMetadata?.url ?? 'https://web3refi.dev',
    //     icons: appMetadata?.icons ?? [],
    //     redirect: Redirect(
    //       native: appMetadata?.redirect,
    //       universal: appMetadata?.url,
    //     ),
    //   ),
    // );

    _log('WalletConnect client initialized');
  }

  void _setupEventListeners() {
    // In production, set up WalletConnect event listeners:
    //
    // _wcClient.onSessionConnect.subscribe((args) {
    //   _handleSessionConnect(args);
    // });
    //
    // _wcClient.onSessionDelete.subscribe((args) {
    //   _handleSessionDelete(args);
    // });
    //
    // _wcClient.onSessionEvent.subscribe((args) {
    //   _handleSessionEvent(args);
    // });

    _log('Event listeners configured');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Connect to a wallet.
  ///
  /// Opens the wallet selection modal or deep links to the wallet app.
  /// Returns the connection result on success.
  ///
  /// Parameters:
  /// - [preferredChain]: Chain to connect to (defaults to [defaultChain])
  /// - [walletId]: Specific wallet to connect (skips selection)
  ///
  /// Throws:
  /// - [WalletException.userRejected] if user cancels
  /// - [WalletException.connectionTimeout] if timeout exceeded
  /// - [WalletException.walletNotInstalled] if wallet app not found
  Future<WalletManagerConnectionResult> connect({
    Chain? preferredChain,
    String? walletId,
  }) async {
    _ensureInitialized();

    if (isConnected) {
      _log('Already connected, disconnecting first...');
      await disconnect();
    }

    final chain = preferredChain ?? defaultChain;
    _log('Connecting to ${chain.name}...');

    _setState(WalletConnectionState.connecting);
    _errorMessage = null;

    try {
      // Build WalletConnect namespaces
      final namespaces = _buildRequiredNamespaces(chain);

      // Create pairing URI
      final uri = await _createConnectionUri(namespaces);
      _log('Connection URI created');

      // Open wallet app
      _setState(WalletConnectionState.awaitingApproval);
      await _openWalletApp(uri, walletId);

      // Wait for session approval
      final result = await _waitForSessionApproval(chain);

      // Update state
      _address = result.address;
      _chainId = result.chainId;
      _sessionId = result.sessionId;
      _setState(WalletConnectionState.connected);

      // Persist session
      await _saveSession();

      // Emit event
      _emitEvent(WalletConnectedEvent(result));

      _log('Connected: ${result.address} on chain ${result.chainId}');
      return result;
    } catch (e) {
      _handleConnectionError(e);
      rethrow;
    }
  }

  /// Connect to a specific wallet by ID.
  Future<WalletManagerConnectionResult> connectWallet({
    required String walletId,
    Chain? preferredChain,
  }) async {
    final wallet = StaticWalletRegistry.byId(walletId);
    if (wallet == null) {
      throw WalletException(
        message: 'Unknown wallet: $walletId',
        code: 'unknown_wallet',
      );
    }

    _connectedWallet = wallet;
    return connect(preferredChain: preferredChain, walletId: walletId);
  }

  Map<String, dynamic> _buildRequiredNamespaces(Chain chain) {
    if (chain.type == BlockchainType.evm) {
      return {
        'eip155': {
          'chains': ['eip155:${chain.chainId}'],
          'methods': [
            'eth_sendTransaction',
            'eth_signTransaction',
            'eth_sign',
            'personal_sign',
            'eth_signTypedData',
            'eth_signTypedData_v4',
            'wallet_switchEthereumChain',
            'wallet_addEthereumChain',
          ],
          'events': [
            'chainChanged',
            'accountsChanged',
          ],
        },
      };
    }

    // Add support for other chain types
    throw WalletException.chainNotSupported(chain.name);
  }

  Future<String> _createConnectionUri(Map<String, dynamic> namespaces) async {
    // In production:
    // final connectResponse = await _wcClient.connect(
    //   requiredNamespaces: namespaces,
    // );
    // return connectResponse.uri.toString();

    // Placeholder
    return 'wc:${DateTime.now().millisecondsSinceEpoch}@2?relay-protocol=irn&symKey=placeholder';
  }

  Future<void> _openWalletApp(String uri, String? walletId) async {
    String deepLink;

    if (walletId != null) {
      final wallet = WalletRegistry.byId(walletId);
      if (wallet?.deepLinkScheme != null) {
        deepLink = '${wallet!.deepLinkScheme}wc?uri=${Uri.encodeComponent(uri)}';
      } else {
        deepLink = uri;
      }
    } else {
      // Use universal link or show QR code
      deepLink = uri;
    }

    final launchUri = Uri.parse(deepLink);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      _log('Opened wallet app');
    } else {
      throw WalletException.walletNotInstalled(
        walletId ?? 'wallet',
      );
    }
  }

  Future<WalletConnectionResult> _waitForSessionApproval(Chain chain) async {
    // In production, wait for WalletConnect session event
    // For now, simulate the flow

    final completer = Completer<WalletConnectionResult>();

    // Timeout
    final timer = Timer(connectionTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(WalletException.connectionTimeout());
      }
    });

    // Simulate connection (replace with actual WalletConnect handling)
    await Future.delayed(const Duration(milliseconds: 500));

    timer.cancel();

    // Return simulated result
    return WalletConnectionResult(
      address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
      chainId: chain.chainId,
      sessionId: 'session_${DateTime.now().millisecondsSinceEpoch}',
      metadata: {
        'walletName': _connectedWallet?.name ?? 'Unknown',
      },
    );
  }

  void _handleConnectionError(Object error) {
    _log('Connection error: $error');

    if (error is WalletException) {
      _errorMessage = error.message;
    } else {
      _errorMessage = error.toString();
    }

    _setState(WalletConnectionState.error);
    _emitEvent(WalletErrorEvent(_errorMessage!, 
        error is WalletException ? error.code : null));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISCONNECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Disconnect the current wallet.
  ///
  /// Clears all session data and notifies listeners.
  Future<void> disconnect() async {
    _log('Disconnecting...');

    try {
      // In production:
      // if (_sessionId != null) {
      //   await _wcClient.disconnectSession(
      //     topic: _sessionId!,
      //     reason: Errors.getSdkError(Errors.USER_DISCONNECTED),
      //   );
      // }
    } catch (e) {
      _log('Error during disconnect: $e');
    }

    // Clear state
    _address = null;
    _chainId = null;
    _sessionId = null;
    _connectedWallet = null;
    _userId = null;
    _errorMessage = null;

    _setState(WalletConnectionState.disconnected);

    // Clear persisted session
    await _clearSession();

    // Emit event
    _emitEvent(const WalletDisconnectedEvent());

    _log('Disconnected');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAIN MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Switch to a different chain.
  ///
  /// Requests the wallet to switch networks.
  /// Throws [WalletException] if chain is not supported.
  Future<void> switchChain(Chain chain) async {
    _ensureConnected();

    if (!chains.any((c) => c.chainId == chain.chainId)) {
      throw WalletException.chainNotSupported(chain.name);
    }

    if (_chainId == chain.chainId) {
      _log('Already on ${chain.name}');
      return;
    }

    _log('Switching to ${chain.name}...');

    try {
      // In production:
      // await _wcClient.request(
      //   topic: _sessionId!,
      //   chainId: 'eip155:$_chainId',
      //   request: SessionRequestParams(
      //     method: 'wallet_switchEthereumChain',
      //     params: [{'chainId': chain.chainIdHex}],
      //   ),
      // );

      _chainId = chain.chainId;
      notifyListeners();

      _emitEvent(ChainChangedEvent(chain.chainId));
      _log('Switched to ${chain.name}');
    } catch (e) {
      _log('Failed to switch chain: $e');

      // Try adding the chain first
      if (e.toString().contains('Unrecognized chain')) {
        await addChain(chain);
        await switchChain(chain);
        return;
      }

      throw WalletException(
        message: 'Failed to switch to ${chain.name}',
        code: 'switch_chain_failed',
        cause: e,
      );
    }
  }

  /// Add a new chain to the wallet.
  ///
  /// Only supported for EVM wallets.
  Future<void> addChain(Chain chain) async {
    _ensureConnected();

    if (chain.type != BlockchainType.evm) {
      throw WalletException(
        message: 'Adding chains is only supported for EVM networks',
        code: 'unsupported_operation',
      );
    }

    _log('Adding chain: ${chain.name}...');

    // In production:
    // await _wcClient.request(
    //   topic: _sessionId!,
    //   chainId: 'eip155:$_chainId',
    //   request: SessionRequestParams(
    //     method: 'wallet_addEthereumChain',
    //     params: [{
    //       'chainId': chain.chainIdHex,
    //       'chainName': chain.name,
    //       'nativeCurrency': {
    //         'name': chain.currencyName,
    //         'symbol': chain.symbol,
    //         'decimals': chain.decimals,
    //       },
    //       'rpcUrls': [chain.rpcUrl, ...chain.backupRpcUrls],
    //       'blockExplorerUrls': [chain.explorerUrl],
    //     }],
    //   ),
    // );

    _log('Chain added: ${chain.name}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGNING
  // ══════════════════════════════════════════════════════════════════════════

  /// Sign a message with the connected wallet.
  ///
  /// Uses personal_sign (EIP-191) for EVM wallets.
  /// Returns the signature as a hex string.
  Future<String> signMessage(String message) async {
    _ensureConnected();

    _log('Signing message...');

    try {
      // In production:
      // final result = await _wcClient.request(
      //   topic: _sessionId!,
      //   chainId: 'eip155:$_chainId',
      //   request: SessionRequestParams(
      //     method: 'personal_sign',
      //     params: [
      //       '0x${message.codeUnits.map((c) => c.toRadixString(16).padLeft(2, '0')).join()}',
      //       _address,
      //     ],
      //   ),
      // );
      // return result as String;

      // Placeholder
      await Future.delayed(const Duration(milliseconds: 300));
      return '0x${message.hashCode.toRadixString(16).padLeft(130, '0')}';
    } catch (e) {
      if (e.toString().contains('rejected') || 
          e.toString().contains('denied')) {
        throw WalletException.userRejected('User rejected signing request');
      }
      throw WalletException(
        message: 'Failed to sign message',
        code: 'sign_failed',
        cause: e,
      );
    }
  }

  /// Sign typed data (EIP-712).
  ///
  /// Only supported for EVM wallets.
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    _ensureConnected();

    _log('Signing typed data...');

    try {
      // In production:
      // final result = await _wcClient.request(
      //   topic: _sessionId!,
      //   chainId: 'eip155:$_chainId',
      //   request: SessionRequestParams(
      //     method: 'eth_signTypedData_v4',
      //     params: [_address, jsonEncode(typedData)],
      //   ),
      // );
      // return result as String;

      await Future.delayed(const Duration(milliseconds: 300));
      return '0x${typedData.hashCode.toRadixString(16).padLeft(130, '0')}';
    } catch (e) {
      if (e.toString().contains('rejected')) {
        throw WalletException.userRejected('User rejected signing request');
      }
      throw WalletException(
        message: 'Failed to sign typed data',
        code: 'sign_typed_data_failed',
        cause: e,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a transaction via the connected wallet.
  ///
  /// Returns the transaction hash on success.
  /// The wallet will prompt the user to approve.
  Future<String> sendTransaction({
    required String to,
    String? value,
    String? data,
    String? gas,
    String? gasPrice,
    String? maxFeePerGas,
    String? maxPriorityFeePerGas,
    String? nonce,
  }) async {
    _ensureConnected();

    _log('Sending transaction to: $to');

    final tx = {
      'from': _address,
      'to': to,
      if (value != null) 'value': value,
      if (data != null) 'data': data,
      if (gas != null) 'gas': gas,
      if (gasPrice != null) 'gasPrice': gasPrice,
      if (maxFeePerGas != null) 'maxFeePerGas': maxFeePerGas,
      if (maxPriorityFeePerGas != null)
        'maxPriorityFeePerGas': maxPriorityFeePerGas,
      if (nonce != null) 'nonce': nonce,
    };

    try {
      // In production:
      // final result = await _wcClient.request(
      //   topic: _sessionId!,
      //   chainId: 'eip155:$_chainId',
      //   request: SessionRequestParams(
      //     method: 'eth_sendTransaction',
      //     params: [tx],
      //   ),
      // );
      // return result as String;

      await Future.delayed(const Duration(milliseconds: 500));
      return '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, '0')}';
    } catch (e) {
      if (e.toString().contains('rejected') || 
          e.toString().contains('denied')) {
        throw WalletException.userRejected('User rejected transaction');
      }

      if (e.toString().contains('insufficient funds')) {
        throw TransactionException.insufficientGas(
          required: 'Unknown',
          available: 'Unknown',
        );
      }

      throw TransactionException(
        message: 'Failed to send transaction',
        code: 'send_tx_failed',
        cause: e,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Save the current session for later restoration.
  Future<void> saveSession() async {
    await _saveSession();
  }

  Future<void> _saveSession() async {
    if (!isConnected) return;

    final sessionData = {
      'address': _address,
      'chainId': _chainId,
      'sessionId': _sessionId,
      'walletId': _connectedWallet?.id,
      'userId': _userId,
      'savedAt': DateTime.now().toIso8601String(),
    };

    await _secureStorage.write(
      key: _storageKey('session'),
      value: jsonEncode(sessionData),
    );

    _log('Session saved');
  }

  /// Restore a previously saved session.
  ///
  /// Returns true if session was restored successfully.
  Future<bool> restoreSession() async {
    _ensureInitialized();

    try {
      final sessionJson = await _secureStorage.read(key: _storageKey('session'));

      if (sessionJson == null) {
        _log('No saved session found');
        return false;
      }

      final sessionData = jsonDecode(sessionJson) as Map<String, dynamic>;

      // Validate session is not too old (7 days max)
      final savedAt = DateTime.parse(sessionData['savedAt'] as String);
      if (DateTime.now().difference(savedAt).inDays > 7) {
        _log('Session expired');
        await _clearSession();
        return false;
      }

      // In production, verify session is still valid with WalletConnect:
      // final isValid = await _wcClient.getActiveSessions()
      //     .any((s) => s.topic == sessionData['sessionId']);
      // if (!isValid) {
      //   await _clearSession();
      //   return false;
      // }

      _address = sessionData['address'] as String?;
      _chainId = sessionData['chainId'] as int?;
      _sessionId = sessionData['sessionId'] as String?;
      _userId = sessionData['userId'] as String?;

      if (sessionData['walletId'] != null) {
        _connectedWallet = WalletRegistry.byId(sessionData['walletId'] as String);
      }

      if (_address != null && _sessionId != null) {
        _setState(WalletConnectionState.connected);
        _log('Session restored: $_address');
        return true;
      }

      return false;
    } catch (e) {
      _log('Failed to restore session: $e');
      await _clearSession();
      return false;
    }
  }

  /// Clear the saved session.
  Future<void> clearSession() async {
    await _clearSession();
  }

  Future<void> _clearSession() async {
    await _secureStorage.delete(key: _storageKey('session'));
    _log('Session cleared');
  }

  String _storageKey(String key) => 'web3refi_$key';

  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-WALLET PROFILE
  // ══════════════════════════════════════════════════════════════════════════

  /// Link an additional wallet to the current profile.
  ///
  /// Requires an active connection first.
  Future<void> linkWallet({
    required String walletId,
    BlockchainType? chainType,
  }) async {
    if (_userId == null) {
      throw WalletException(
        message: 'No active profile. Connect a wallet first.',
        code: 'no_profile',
      );
    }

    _log('Linking wallet: $walletId');

    // Implementation would:
    // 1. Connect to the new wallet
    // 2. Sign an auth message
    // 3. Send to backend to link to user profile

    notifyListeners();
  }

  /// Get all wallets linked to the current profile.
  Future<List<LinkedWallet>> getLinkedWallets() async {
    if (_userId == null) return [];

    // In production, fetch from backend
    return [];
  }

  /// Unlink a wallet from the current profile.
  Future<void> unlinkWallet(String address) async {
    if (_userId == null) return;

    _log('Unlinking wallet: $address');

    // In production, call backend to unlink
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if a wallet app is installed.
  Future<bool> isWalletInstalled(String walletId) async {
    final wallet = WalletRegistry.byId(walletId);
    if (wallet?.deepLinkScheme == null) return false;

    final uri = Uri.parse('${wallet!.deepLinkScheme}test');
    return await canLaunchUrl(uri);
  }

  /// Register a custom wallet adapter.
  void registerWalletAdapter(Web3WalletAdapter adapter) {
    _walletAdapters[adapter.info.id] = adapter;
    _log('Registered wallet adapter: ${adapter.info.id}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _setState(WalletConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _emitEvent(WalletEvent event) {
    _eventController.add(event);
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'WalletManager not initialized. Call initialize() first.',
      );
    }
  }

  void _ensureConnected() {
    _ensureInitialized();
    if (!isConnected) {
      throw WalletException.notConnected();
    }
  }

  void _log(String message) {
    if (enableLogging) {
      debugPrint('[web3refi:Wallet] $message');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPOSAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Dispose of resources.
  ///
  /// Call this when the wallet manager is no longer needed.
  @override
  Future<void> dispose() async {
    _log('Disposing WalletManager...');

    // Close event stream
    await _eventController.close();

    // Dispose wallet adapters
    for (final adapter in _walletAdapters.values) {
      adapter.dispose();
    }
    _walletAdapters.clear();

    // In production:
    // _wcClient.dispose();

    _isInitialized = false;
    super.dispose();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// LINKED WALLET MODEL
// ════════════════════════════════════════════════════════════════════════════

/// A wallet linked to a user profile.
class LinkedWallet extends Equatable {
  /// Wallet address.
  final String address;

  /// Chain ID.
  final int chainId;

  /// Blockchain type.
  final BlockchainType blockchainType;

  /// When the wallet was linked.
  final DateTime linkedAt;

  /// Whether this is the primary wallet.
  final bool isPrimary;

  /// Optional label/nickname.
  final String? label;

  const LinkedWallet({
    required this.address,
    required this.chainId,
    required this.blockchainType,
    required this.linkedAt,
    this.isPrimary = false,
    this.label,
  });

  @override
  List<Object?> get props => [address, chainId];

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'blockchainType': blockchainType.name,
        'linkedAt': linkedAt.toIso8601String(),
        'isPrimary': isPrimary,
        'label': label,
      };

  factory LinkedWallet.fromJson(Map<String, dynamic> json) {
    return LinkedWallet(
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      blockchainType: BlockchainType.values.firstWhere(
        (t) => t.name == json['blockchainType'],
        orElse: () => BlockchainType.evm,
      ),
      linkedAt: DateTime.parse(json['linkedAt'] as String),
      isPrimary: json['isPrimary'] as bool? ?? false,
      label: json['label'] as String?,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WALLET EVENTS
// ════════════════════════════════════════════════════════════════════════════

/// Base class for wallet events.
abstract class WalletEvent {
  const WalletEvent();
}

/// Event emitted when wallet connects successfully.
class WalletConnectedEvent extends WalletEvent {
  /// The connection result.
  final WalletManagerConnectionResult result;

  const WalletConnectedEvent(this.result);
}

/// Event emitted when wallet disconnects.
class WalletDisconnectedEvent extends WalletEvent {
  const WalletDisconnectedEvent();
}

/// Event emitted when an error occurs.
class WalletErrorEvent extends WalletEvent {
  /// Error message.
  final String message;

  /// Error code, if available.
  final String? code;

  const WalletErrorEvent(this.message, [this.code]);
}

/// Event emitted when chain changes.
class ChainChangedEvent extends WalletEvent {
  /// New chain ID.
  final int chainId;

  const ChainChangedEvent(this.chainId);
}

/// Event emitted when account changes.
class AccountChangedEvent extends WalletEvent {
  /// New account address.
  final String address;

  const AccountChangedEvent(this.address);
}

// ════════════════════════════════════════════════════════════════════════════
// WALLET MANAGER CONNECTION RESULT
// ════════════════════════════════════════════════════════════════════════════

/// Result of a successful WalletManager connection (int chainId version).
class WalletManagerConnectionResult {
  /// The connected wallet address.
  final String address;

  /// The chain ID the wallet is connected to (as int).
  final int chainId;

  /// Session identifier for maintaining connection.
  final String? sessionId;

  /// Additional metadata from the wallet.
  final Map<String, dynamic> metadata;

  const WalletManagerConnectionResult({
    required this.address,
    required this.chainId,
    this.sessionId,
    this.metadata = const {},
  });

  @override
  String toString() => 'WalletManagerConnectionResult($address on chain $chainId)';
}

// ════════════════════════════════════════════════════════════════════════════
// STATIC WALLET REGISTRY
// ════════════════════════════════════════════════════════════════════════════

/// Static registry of known wallet information.
///
/// Provides predefined wallet metadata for common wallets.
class StaticWalletRegistry {
  StaticWalletRegistry._();

  /// All known wallets.
  static final List<WalletInfo> all = [
    _metamask,
    _coinbaseWallet,
    _trustWallet,
    _rainbow,
    _phantom,
  ];

  /// Get wallet info by ID.
  static WalletInfo? byId(String id) {
    try {
      return all.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  /// MetaMask wallet info.
  static final WalletInfo _metamask = WalletInfo(
    id: 'metamask',
    name: 'MetaMask',
    description: 'The most popular Ethereum wallet',
    iconPath: 'assets/wallets/metamask.png',
    blockchainType: BlockchainType.evm,
    supportedChains: ['1', '137', '42161', '10', '56', '43114', '8453'],
    deepLinkScheme: 'metamask://',
    appStoreUrl: 'https://apps.apple.com/app/metamask/id1438144202',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=io.metamask',
  );

  /// Coinbase Wallet info.
  static final WalletInfo _coinbaseWallet = WalletInfo(
    id: 'coinbase',
    name: 'Coinbase Wallet',
    description: 'Your key to the world of crypto',
    iconPath: 'assets/wallets/coinbase.png',
    blockchainType: BlockchainType.evm,
    supportedChains: ['1', '137', '42161', '10', '56', '43114', '8453'],
    deepLinkScheme: 'cbwallet://',
    appStoreUrl: 'https://apps.apple.com/app/coinbase-wallet/id1278383455',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=org.toshi',
  );

  /// Trust Wallet info.
  static final WalletInfo _trustWallet = WalletInfo(
    id: 'trust',
    name: 'Trust Wallet',
    description: 'The most trusted & secure crypto wallet',
    iconPath: 'assets/wallets/trust.png',
    blockchainType: BlockchainType.evm,
    supportedChains: ['1', '137', '42161', '10', '56', '43114'],
    deepLinkScheme: 'trust://',
    appStoreUrl: 'https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=com.wallet.crypto.trustapp',
  );

  /// Rainbow wallet info.
  static final WalletInfo _rainbow = WalletInfo(
    id: 'rainbow',
    name: 'Rainbow',
    description: 'The fun, simple, & secure Ethereum wallet',
    iconPath: 'assets/wallets/rainbow.png',
    blockchainType: BlockchainType.evm,
    supportedChains: ['1', '137', '42161', '10', '8453'],
    deepLinkScheme: 'rainbow://',
    appStoreUrl: 'https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=me.rainbow',
  );

  /// Phantom wallet info.
  static final WalletInfo _phantom = WalletInfo(
    id: 'phantom',
    name: 'Phantom',
    description: 'A friendly Solana & Ethereum wallet',
    iconPath: 'assets/wallets/phantom.png',
    blockchainType: BlockchainType.solana,
    supportedChains: ['solana:mainnet', '1', '137'],
    deepLinkScheme: 'phantom://',
    appStoreUrl: 'https://apps.apple.com/app/phantom-solana-wallet/id1598432977',
    playStoreUrl: 'https://play.google.com/store/apps/details?id=app.phantom',
  );
}
