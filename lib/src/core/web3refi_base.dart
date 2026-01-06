import 'dart:async';
import 'package:flutter/foundation.dart';
import 'web3refi_config.dart';
import '../transport/rpc_client.dart';
import '../core/chain.dart';
import '../transactions/transaction.dart';
import '../wallet/wallet_manager.dart';
import '../standards/erc20.dart';
import '../defi/token_helper.dart';
import '../messaging/message_client.dart';
import '../errors/web3_exception.dart';
import '../names/universal_name_service.dart';
import '../cifi/client.dart';

/// The main entry point for the web3refi SDK.
///
/// Initialize once at app startup:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Web3Refi.initialize(
///     config: Web3RefiConfig(
///       projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
///       chains: [Chains.ethereum, Chains.polygon],
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// Then access the singleton instance anywhere:
/// ```dart
/// final address = Web3Refi.instance.address;
/// await Web3Refi.instance.connect();
/// ```
class Web3Refi extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ══════════════════════════════════════════════════════════════════════════

  static Web3Refi? _instance;

  /// Get the singleton instance of Web3Refi.
  ///
  /// Throws if [initialize] has not been called.
  static Web3Refi get instance {
    if (_instance == null) {
      throw StateError(
        'Web3Refi not initialized. Call Web3Refi.initialize() first.',
      );
    }
    return _instance!;
  }

  /// Check if Web3Refi has been initialized.
  static bool get isInitialized => _instance != null;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the Web3Refi SDK.
  ///
  /// Must be called before accessing [instance].
  ///
  /// Example:
  /// ```dart
  /// await Web3Refi.initialize(
  ///   config: Web3RefiConfig(
  ///     projectId: 'xxx',
  ///     chains: [Chains.polygon],
  ///   ),
  /// );
  /// ```
  static Future<Web3Refi> initialize({
    required Web3RefiConfig config,
  }) async {
    if (_instance != null) {
      _instance!._log('Web3Refi already initialized. Reinitializing...');
      await _instance!.dispose();
    }

    final web3Refi = Web3Refi._(config);
    await web3Refi._initialize();
    _instance = web3Refi;

    return web3Refi;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// The configuration used to initialize the SDK.
  final Web3RefiConfig config;

  /// Wallet manager for connection and signing.
  late final WalletManager walletManager;

  /// RPC clients for each chain.
  final Map<int, RpcClient> _rpcClients = {};

  /// Current active chain.
  Chain _currentChain;

  /// Token helper for common operations.
  late final TokenHelper tokens;

  /// Messaging client (XMTP + Mailchain).
  late final MessagingClient messaging;

  /// Universal Name Service (ENS, CiFi, Unstoppable, etc.)
  late final UniversalNameService names;

  /// Whether initialization is complete.
  bool _isReady = false;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  Web3Refi._(this.config) : _currentChain = config.defaultChain;

  Future<void> _initialize() async {
    _log('Initializing Web3Refi...');

    // Initialize RPC clients for all configured chains
    for (final chain in config.chains) {
      _rpcClients[chain.chainId] = RpcClient(
        chain: chain,
        timeout: config.rpcTimeout,
        enableLogging: config.enableLogging,
      );
    }

    // Initialize wallet manager
    walletManager = WalletManager(
      projectId: config.projectId,
      appMetadata: config.appMetadata,
      chains: config.chains,
      defaultChain: config.defaultChain,
      enableLogging: config.enableLogging,
    );
    await walletManager.initialize();

    // Forward wallet state changes
    walletManager.addListener(() {
      notifyListeners();
    });

    // Initialize token helper
    tokens = TokenHelper(
      rpcClient: rpcClient,
      walletManager: walletManager,
    );

    // Initialize messaging
    messaging = MessagingClient(
      walletManager: walletManager,
      xmtpEnvironment: config.xmtpEnvironment,
      enableMailchain: config.enableMailchain,
    );

    // Initialize Universal Name Service
    names = UniversalNameService(
      rpcClient: rpcClient,
      cifiClient: config.cifiApiKey != null ? CiFiClient(apiKey: config.cifiApiKey!) : null,
      enableCiFiFallback: config.enableCiFiNames ?? true,
      enableUnstoppableDomains: config.enableUnstoppableDomains ?? true,
      enableSpaceId: config.enableSpaceId ?? true,
      enableSolanaNameService: config.enableSolanaNameService ?? false,
      enableSuiNameService: config.enableSuiNameService ?? false,
      cacheMaxSize: config.namesCacheSize ?? 1000,
      cacheTtl: config.namesCacheTtl ?? const Duration(hours: 1),
    );

    // Restore session if enabled
    if (config.autoRestoreSession) {
      await _restoreSession();
    }

    _isReady = true;
    _log('Web3Refi initialized successfully');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Whether the SDK is ready for use.
  bool get isReady => _isReady;

  /// The current active blockchain network.
  Chain get currentChain => _currentChain;

  /// RPC client for the current chain.
  RpcClient get rpcClient {
    final client = _rpcClients[_currentChain.chainId];
    if (client == null) {
      throw StateError('No RPC client for chain ${_currentChain.name}');
    }
    return client;
  }

  /// Get RPC client for a specific chain.
  RpcClient rpcClientFor(Chain chain) {
    final client = _rpcClients[chain.chainId];
    if (client == null) {
      throw ArgumentError('Chain ${chain.name} not configured');
    }
    return client;
  }

  /// Whether a wallet is currently connected.
  bool get isConnected => walletManager.isConnected;

  /// The connected wallet address, or null if not connected.
  String? get address => walletManager.address;

  /// User ID for multi-wallet profiles, if enabled.
  String? get userId => walletManager.userId;

  /// Current connection state.
  WalletConnectionState get connectionState => walletManager.state;

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET CONNECTION
  // ══════════════════════════════════════════════════════════════════════════

  /// Connect to a wallet.
  ///
  /// Opens the wallet selection modal or deep links to the wallet app.
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await Web3Refi.instance.connect();
  ///   print('Connected: ${Web3Refi.instance.address}');
  /// } on WalletException catch (e) {
  ///   if (e.code == 'user_rejected') {
  ///     print('User cancelled');
  ///   }
  /// }
  /// ```
  Future<void> connect({Chain? preferredChain}) async {
    await walletManager.connect(preferredChain: preferredChain ?? _currentChain);
    notifyListeners();
  }

  /// Disconnect the current wallet.
  Future<void> disconnect() async {
    await walletManager.disconnect();
    notifyListeners();
  }

  /// Save the current session for restoration.
  Future<void> saveSession() async {
    await walletManager.saveSession();
  }

  /// Restore a previously saved session.
  Future<bool> restoreSession() async {
    return _restoreSession();
  }

  Future<bool> _restoreSession() async {
    final restored = await walletManager.restoreSession();
    if (restored) {
      _log('Session restored');
      notifyListeners();
    }
    return restored;
  }

  /// Clear the saved session.
  Future<void> clearSession() async {
    await walletManager.clearSession();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAIN MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Switch to a different chain.
  ///
  /// This will request the wallet to switch networks.
  Future<void> switchChain(Chain chain) async {
    if (!config.chains.contains(chain)) {
      throw ArgumentError('Chain ${chain.name} not in configured chains');
    }

    await walletManager.switchChain(chain);
    _currentChain = chain;
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOKEN OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get an ERC20 token instance for the given address.
  ///
  /// Example:
  /// ```dart
  /// final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
  /// final balance = await usdc.balanceOf(address);
  /// ```
  ERC20 token(String address) {
    return ERC20(
      address: address,
      rpcClient: rpcClient,
      walletManager: walletManager,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE CURRENCY
  // ══════════════════════════════════════════════════════════════════════════

  /// Get native currency balance (ETH, MATIC, etc.).
  ///
  /// Returns balance in wei.
  Future<BigInt> getNativeBalance([String? addr]) async {
    final targetAddress = addr ?? address;
    if (targetAddress == null) {
      throw WalletException.notConnected();
    }
    return rpcClient.getBalance(targetAddress);
  }

  /// Format a native currency amount for display.
  ///
  /// Example:
  /// ```dart
  /// final balance = await Web3Refi.instance.getNativeBalance();
  /// final formatted = Web3Refi.instance.formatNativeAmount(balance);
  /// print('$formatted ${Web3Refi.instance.currentChain.symbol}');
  /// ```
  String formatNativeAmount(BigInt amount) {
    final decimals = _currentChain.decimals;
    final divisor = BigInt.from(10).pow(decimals);
    final whole = amount ~/ divisor;
    final fraction = (amount % divisor).toString().padLeft(decimals, '0');
    
    // Trim trailing zeros, keep at least 4 decimal places
    var trimmedFraction = fraction.replaceAll(RegExp(r'0+$'), '');
    if (trimmedFraction.length < 4) {
      trimmedFraction = fraction.substring(0, 4);
    }
    
    return '$whole.$trimmedFraction';
  }

  /// Parse a native currency amount from a string.
  BigInt parseNativeAmount(String amount) {
    final parts = amount.split('.');
    final whole = BigInt.parse(parts[0]);
    final decimals = _currentChain.decimals;
    
    if (parts.length == 1) {
      return whole * BigInt.from(10).pow(decimals);
    }
    
    var fractionStr = parts[1];
    if (fractionStr.length > decimals) {
      fractionStr = fractionStr.substring(0, decimals);
    }
    fractionStr = fractionStr.padRight(decimals, '0');
    
    final fraction = BigInt.parse(fractionStr);
    return whole * BigInt.from(10).pow(decimals) + fraction;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a raw transaction.
  ///
  /// Returns the transaction hash.
  Future<String> sendTransaction({
    required String to,
    String? value,
    String? data,
    String? gas,
    String? gasPrice,
  }) async {
    if (!isConnected) {
      throw WalletException.notConnected();
    }

    return walletManager.sendTransaction(
      to: to,
      value: value,
      data: data,
      gas: gas,
      gasPrice: gasPrice,
    );
  }

  /// Sign a message with the connected wallet.
  Future<String> signMessage(String message) async {
    if (!isConnected) {
      throw WalletException.notConnected();
    }
    return walletManager.signMessage(message);
  }

  /// Wait for a transaction to be confirmed.
  ///
  /// Returns the transaction receipt.
  Future<TransactionReceipt> waitForTransaction(
    String txHash, {
    int? confirmations,
    Duration? timeout,
  }) async {
    final requiredConfirmations = confirmations ?? config.defaultConfirmations;
    final timeoutDuration = timeout ?? const Duration(minutes: 5);
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeoutDuration) {
      final receipt = await rpcClient.getTransactionReceipt(txHash);
      
      if (receipt != null) {
        final status = receipt['status'] as String?;
        final blockNumber = receipt['blockNumber'] as String?;
        
        if (status == '0x1' || status == '1') {
          // Success - check confirmations
          if (blockNumber != null) {
            final txBlock = int.parse(blockNumber.substring(2), radix: 16);
            final currentBlock = await rpcClient.getBlockNumber();
            final confirmationCount = currentBlock - txBlock + 1;
            
            if (confirmationCount >= requiredConfirmations) {
              return TransactionReceipt(
                hash: txHash,
                status: TransactionStatus.confirmed,
                blockNumber: txBlock,
                gasUsed: _parseGas(receipt['gasUsed']),
                effectiveGasPrice: _parseGas(receipt['effectiveGasPrice']),
              );
            }
          }
        } else if (status == '0x0' || status == '0') {
          // Failed
          return TransactionReceipt(
            hash: txHash,
            status: TransactionStatus.failed,
            errorMessage: 'Transaction reverted',
          );
        }
      }
      
      // Wait before polling again
      await Future.delayed(const Duration(seconds: 2));
    }

    // Timeout
    return TransactionReceipt(
      hash: txHash,
      status: TransactionStatus.pending,
      errorMessage: 'Transaction still pending after timeout',
    );
  }

  BigInt? _parseGas(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return BigInt.parse(value.substring(2), radix: 16);
    }
    return BigInt.from(value as int);
  }

  /// Estimate gas for a transaction.
  Future<BigInt> estimateGas({
    required String to,
    String? value,
    String? data,
  }) async {
    final tx = <String, String>{
      'to': to,
      if (address != null) 'from': address!,
      if (value != null) 'value': value,
      if (data != null) 'data': data,
    };
    return rpcClient.estimateGas(tx);
  }

  /// Get current gas price.
  Future<BigInt> getGasPrice() async {
    return rpcClient.getGasPrice();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    if (config.enableLogging) {
      debugPrint('[web3refi] $message');
    }
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await walletManager.dispose();
    for (final client in _rpcClients.values) {
      client.dispose();
    }
    _rpcClients.clear();
    _isReady = false;
    _instance = null;
  }
}
