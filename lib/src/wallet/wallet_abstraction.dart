import 'dart:async';
import 'package:web3refi/src/core/chain.dart';

/// Base interface that ALL wallet adapters must implement.
///
/// This abstraction allows web3refi to support any blockchain and wallet
/// without hard-coding specific implementations.
///
/// Example implementation:
/// ```dart
/// class MyCustomWallet extends Web3WalletAdapter {
///   @override
///   WalletInfo get info => WalletInfo(
///     id: 'my-wallet',
///     name: 'My Custom Wallet',
///     // ...
///   );
///
///   @override
///   Future<WalletConnectionResult> connect() async {
///     // Your connection logic
///   }
/// }
/// ```
abstract class Web3WalletAdapter {
  /// Wallet metadata and capabilities.
  WalletInfo get info;

  /// Stream of connection state changes.
  Stream<WalletConnectionState> get connectionStateStream;

  /// Current connection state.
  WalletConnectionState get connectionState;

  /// Whether the wallet is currently connected.
  bool get isConnected => connectionState == WalletConnectionState.connected;

  /// Connected wallet address, null if not connected.
  String? get address;

  /// Current chain ID, null if not connected.
  String? get chainId;

  /// Connect to the wallet.
  ///
  /// Returns connection details on success.
  /// Throws [WalletException] on failure.
  Future<WalletConnectionResult> connect();

  /// Disconnect from the wallet.
  Future<void> disconnect();

  /// Sign an authentication message (SIWE-like).
  ///
  /// Used for proving wallet ownership without transactions.
  Future<WalletSignature> signAuthMessage(AuthMessageData message);

  /// Sign a personal message.
  Future<WalletSignature> signMessage(String message);

  /// Sign typed data (EIP-712 for EVM chains).
  Future<WalletSignature> signTypedData(Map<String, dynamic> typedData);

  /// Send a transaction for signing.
  ///
  /// Returns the transaction hash after user approval.
  Future<String> sendTransaction(TransactionData transaction);

  /// Switch to a different chain (if supported).
  Future<void> switchChain(String chainId);

  /// Check if the wallet app is installed on the device.
  Future<bool> isInstalled();

  /// Get the deep link to open the wallet app.
  String? getDeepLink();

  /// Dispose of resources.
  void dispose();
}

/// Wallet metadata and capabilities.
class WalletInfo {
  /// Unique identifier for this wallet (e.g., 'metamask', 'phantom').
  final String id;

  /// Display name (e.g., 'MetaMask', 'Phantom').
  final String name;

  /// Short description of the wallet.
  final String description;

  /// Icon asset path or URL.
  final String iconPath;

  /// The blockchain type this wallet supports.
  final BlockchainType blockchainType;

  /// List of supported chain IDs.
  final List<String> supportedChains;

  /// Deep link scheme for opening the wallet (e.g., 'metamask://').
  final String? deepLinkScheme;

  /// App Store URL for iOS.
  final String? appStoreUrl;

  /// Play Store URL for Android.
  final String? playStoreUrl;

  /// Whether this wallet supports WalletConnect.
  final bool supportsWalletConnect;

  /// Whether this wallet supports direct deep linking.
  final bool supportsDeepLink;

  /// Whether this wallet supports message signing.
  final bool supportsMessageSigning;

  /// Whether this wallet supports typed data signing (EIP-712).
  final bool supportsTypedDataSigning;

  /// Whether this wallet supports chain switching.
  final bool supportsChainSwitching;

  const WalletInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.blockchainType,
    required this.supportedChains,
    this.deepLinkScheme,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportsWalletConnect = true,
    this.supportsDeepLink = true,
    this.supportsMessageSigning = true,
    this.supportsTypedDataSigning = true,
    this.supportsChainSwitching = true,
  });

  @override
  String toString() => 'WalletInfo($id: $name)';
}

/// Connection state for a wallet.
enum WalletConnectionState {
  /// No connection attempt made.
  disconnected,

  /// Currently attempting to connect.
  connecting,

  /// Successfully connected.
  connected,

  /// Connection failed or errored.
  error,

  /// Waiting for user action in wallet app.
  awaitingApproval,
}

/// Result of a successful wallet connection.
class WalletConnectionResult {
  /// The connected wallet address.
  final String address;

  /// The chain ID the wallet is connected to.
  final String chainId;

  /// The blockchain type.
  final BlockchainType blockchainType;

  /// Session identifier for maintaining connection.
  final String? sessionId;

  /// Additional metadata from the wallet.
  final Map<String, dynamic> metadata;

  /// When the connection was established.
  final DateTime connectedAt;

  const WalletConnectionResult({
    required this.address,
    required this.chainId,
    required this.blockchainType,
    this.sessionId,
    this.metadata = const {},
    DateTime? connectedAt,
  }) : connectedAt = connectedAt ?? const _Now();

  @override
  String toString() => 'WalletConnectionResult($address on $chainId)';

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'blockchainType': blockchainType.name,
        'sessionId': sessionId,
        'metadata': metadata,
        'connectedAt': connectedAt.toIso8601String(),
      };

  factory WalletConnectionResult.fromJson(Map<String, dynamic> json) {
    return WalletConnectionResult(
      address: json['address'] as String,
      chainId: json['chainId'] as String,
      blockchainType: BlockchainType.values.firstWhere(
        (e) => e.name == json['blockchainType'],
        orElse: () => BlockchainType.evm,
      ),
      sessionId: json['sessionId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      connectedAt: DateTime.parse(json['connectedAt'] as String),
    );
  }
}

// Helper class for default DateTime
class _Now implements DateTime {
  const _Now();

  DateTime get _now => DateTime.now();

  @override
  dynamic noSuchMethod(Invocation invocation) => _now.noSuchMethod(invocation);
}

/// Signature result from signing operations.
class WalletSignature {
  /// The signature bytes as hex string.
  final String signature;

  /// The address that signed.
  final String signerAddress;

  /// The message that was signed.
  final String message;

  /// When the signature was created.
  final DateTime timestamp;

  /// Signature format/type.
  final SignatureFormat format;

  /// Additional metadata.
  final Map<String, dynamic> metadata;

  const WalletSignature({
    required this.signature,
    required this.signerAddress,
    required this.message,
    required this.timestamp,
    this.format = SignatureFormat.ethereumPersonalSign,
    this.metadata = const {},
  });

  @override
  String toString() => 'WalletSignature(${signature.substring(0, 20)}...)';

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'signerAddress': signerAddress,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'format': format.name,
        'metadata': metadata,
      };
}

/// Signature formats for different chains.
enum SignatureFormat {
  /// EVM personal_sign (EIP-191).
  ethereumPersonalSign,

  /// EVM typed data (EIP-712).
  ethereumTypedData,

  /// Bitcoin message signing (BIP-137).
  bitcoinMessage,

  /// Solana Ed25519 signing.
  solanaEd25519,

  /// Hedera Ed25519 signing.
  hederaEd25519,

  /// Sui Ed25519 signing.
  suiEd25519,

  /// Generic/unknown format.
  unknown,
}

/// Transaction data for signing.
class TransactionData {
  /// Recipient address.
  final String to;

  /// Value to send (in smallest unit, e.g., wei).
  final BigInt value;

  /// Transaction data (for contract calls).
  final String? data;

  /// Gas limit.
  final BigInt? gasLimit;

  /// Gas price (legacy).
  final BigInt? gasPrice;

  /// Max fee per gas (EIP-1559).
  final BigInt? maxFeePerGas;

  /// Max priority fee per gas (EIP-1559).
  final BigInt? maxPriorityFeePerGas;

  /// Transaction nonce.
  final int? nonce;

  /// Chain-specific metadata.
  final Map<String, dynamic> metadata;

  TransactionData({
    required this.to,
    BigInt? value,
    this.data,
    this.gasLimit,
    this.gasPrice,
    this.maxFeePerGas,
    this.maxPriorityFeePerGas,
    this.nonce,
    this.metadata = const {},
  }) : value = value ?? BigInt.zero;

  /// Convert to JSON-RPC format for EVM chains.
  Map<String, String> toEvmJson(String from) {
    return {
      'from': from,
      'to': to,
      'value': '0x${value.toRadixString(16)}',
      if (data != null) 'data': data!,
      if (gasLimit != null) 'gas': '0x${gasLimit!.toRadixString(16)}',
      if (gasPrice != null) 'gasPrice': '0x${gasPrice!.toRadixString(16)}',
      if (maxFeePerGas != null)
        'maxFeePerGas': '0x${maxFeePerGas!.toRadixString(16)}',
      if (maxPriorityFeePerGas != null)
        'maxPriorityFeePerGas': '0x${maxPriorityFeePerGas!.toRadixString(16)}',
      if (nonce != null) 'nonce': '0x${nonce!.toRadixString(16)}',
    };
  }
}

/// Authentication message data for SIWE-like flows.
class AuthMessageData {
  /// Domain requesting authentication.
  final String domain;

  /// Wallet address.
  final String address;

  /// Chain identifier.
  final String chainId;

  /// Unique nonce for replay protection.
  final String nonce;

  /// When the message was issued.
  final DateTime issuedAt;

  /// When the message expires.
  final DateTime? expiresAt;

  /// Human-readable statement.
  final String? statement;

  /// Request URI.
  final String? uri;

  /// Version of the message format.
  final String version;

  /// Resources being requested.
  final List<String>? resources;

  const AuthMessageData({
    required this.domain,
    required this.address,
    required this.chainId,
    required this.nonce,
    required this.issuedAt,
    this.expiresAt,
    this.statement,
    this.uri,
    this.version = '1',
    this.resources,
  });
}

/// Registry of available wallet adapters.
class WalletRegistry {
  final Map<String, Web3WalletAdapter> _adapters = {};

  /// Static map for registered wallet info (used by WalletManager).
  static final Map<String, WalletInfo> _staticWalletInfo = {};

  /// Register a wallet adapter.
  void register(Web3WalletAdapter adapter) {
    _adapters[adapter.info.id] = adapter;
    _staticWalletInfo[adapter.info.id] = adapter.info;
  }

  /// Unregister a wallet adapter.
  void unregister(String walletId) {
    _adapters.remove(walletId);
    _staticWalletInfo.remove(walletId);
  }

  /// Get a wallet adapter by ID.
  Web3WalletAdapter? get(String walletId) => _adapters[walletId];

  /// Get all registered adapters.
  List<Web3WalletAdapter> get all => _adapters.values.toList();

  /// Get adapters for a specific blockchain type.
  List<Web3WalletAdapter> getForBlockchain(BlockchainType type) {
    return _adapters.values
        .where((adapter) => adapter.info.blockchainType == type)
        .toList();
  }

  /// Get adapters that support a specific chain.
  List<Web3WalletAdapter> getForChain(String chainId) {
    return _adapters.values
        .where((adapter) => adapter.info.supportedChains.contains(chainId))
        .toList();
  }

  /// Clear all registered adapters.
  void clear() {
    for (final adapter in _adapters.values) {
      adapter.dispose();
    }
    _adapters.clear();
    _staticWalletInfo.clear();
  }

  /// Static method to get wallet info by ID.
  ///
  /// Returns the wallet info if registered, null otherwise.
  /// This is used by WalletManager for deep linking.
  static WalletInfo? byId(String walletId) {
    return _staticWalletInfo[walletId];
  }

  /// Register wallet info statically (without full adapter).
  ///
  /// Useful for registering known wallet metadata for deep linking
  /// without requiring a full adapter implementation.
  static void registerWalletInfo(WalletInfo info) {
    _staticWalletInfo[info.id] = info;
  }
}
