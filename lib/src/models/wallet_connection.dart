// ═══════════════════════════════════════════════════════════════════════════════
// WALLET CONNECTION MODELS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Models for wallet connections, sessions, and authentication including:
// - Wallet connection state and metadata
// - Supported wallets and their capabilities
// - Session persistence
// - Multi-wallet profile linking
//
// Part of web3refi - The Universal Web3 SDK for Flutter
// Created by S6 Labs LLC
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:equatable/equatable.dart';
import '../core/chain.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CONNECTION STATE
// ═══════════════════════════════════════════════════════════════════════════════

/// Current state of wallet connection.
enum WalletConnectionState {
  /// No wallet connected, ready to connect.
  disconnected,

  /// Connection in progress (waiting for user approval).
  connecting,

  /// Wallet successfully connected.
  connected,

  /// Reconnecting after interruption.
  reconnecting,

  /// Connection failed with error.
  error,
}

/// Extension methods for [WalletConnectionState].
extension WalletConnectionStateExtension on WalletConnectionState {
  /// Whether a wallet is currently connected.
  bool get isConnected => this == WalletConnectionState.connected;

  /// Whether connection is in progress.
  bool get isConnecting =>
      this == WalletConnectionState.connecting ||
      this == WalletConnectionState.reconnecting;

  /// Whether in a disconnected state (including error).
  bool get isDisconnected =>
      this == WalletConnectionState.disconnected ||
      this == WalletConnectionState.error;

  /// Human-readable status message.
  String get message {
    switch (this) {
      case WalletConnectionState.disconnected:
        return 'Not connected';
      case WalletConnectionState.connecting:
        return 'Connecting...';
      case WalletConnectionState.connected:
        return 'Connected';
      case WalletConnectionState.reconnecting:
        return 'Reconnecting...';
      case WalletConnectionState.error:
        return 'Connection error';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET CONNECTION
// ═══════════════════════════════════════════════════════════════════════════════

/// Represents an active wallet connection.
///
/// ## Example
///
/// ```dart
/// final connection = WalletConnection(
///   address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
///   chainId: 137,
///   walletId: 'metamask',
/// );
///
/// print(connection.shortAddress); // "0x742d...bEb"
/// ```
class WalletConnection extends Equatable {
  /// Connected wallet address.
  final String address;

  /// Current chain ID.
  final int chainId;

  /// Wallet identifier (e.g., "metamask", "rainbow").
  final String? walletId;

  /// Wallet name for display.
  final String? walletName;

  /// WalletConnect session topic (if using WalletConnect).
  final String? sessionTopic;

  /// Connection timestamp.
  final DateTime connectedAt;

  /// Last activity timestamp.
  final DateTime? lastActivityAt;

  /// Supported chains for this connection.
  final List<int>? supportedChainIds;

  /// Wallet capabilities/methods.
  final List<String>? capabilities;

  /// Additional metadata from wallet.
  final Map<String, dynamic>? metadata;

  const WalletConnection({
    required this.address,
    required this.chainId,
    this.walletId,
    this.walletName,
    this.sessionTopic,
    required this.connectedAt,
    this.lastActivityAt,
    this.supportedChainIds,
    this.capabilities,
    this.metadata,
  });

  /// Create from WalletConnect session data.
  factory WalletConnection.fromWalletConnect({
    required String address,
    required int chainId,
    required String sessionTopic,
    required Map<String, dynamic> sessionData,
  }) {
    final peerMeta = sessionData['peer']?['metadata'] as Map<String, dynamic>?;

    return WalletConnection(
      address: address,
      chainId: chainId,
      sessionTopic: sessionTopic,
      walletName: peerMeta?['name'] as String?,
      connectedAt: DateTime.now(),
      metadata: peerMeta,
    );
  }

  /// Shortened address for display (e.g., "0x742d...bEb").
  String get shortAddress {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Address in lowercase for comparison.
  String get addressLower => address.toLowerCase();

  /// Whether this connection supports a specific chain.
  bool supportsChain(int targetChainId) {
    if (supportedChainIds == null) return true; // Assume yes if not specified
    return supportedChainIds!.contains(targetChainId);
  }

  /// Whether this connection has a specific capability.
  bool hasCapability(String capability) {
    if (capabilities == null) return true; // Assume yes if not specified
    return capabilities!.contains(capability);
  }

  /// Create a copy with updated chain ID.
  WalletConnection withChainId(int newChainId) {
    return copyWith(chainId: newChainId);
  }

  /// Create a copy with updated activity timestamp.
  WalletConnection withActivity() {
    return copyWith(lastActivityAt: DateTime.now());
  }

  WalletConnection copyWith({
    String? address,
    int? chainId,
    String? walletId,
    String? walletName,
    String? sessionTopic,
    DateTime? connectedAt,
    DateTime? lastActivityAt,
    List<int>? supportedChainIds,
    List<String>? capabilities,
    Map<String, dynamic>? metadata,
  }) {
    return WalletConnection(
      address: address ?? this.address,
      chainId: chainId ?? this.chainId,
      walletId: walletId ?? this.walletId,
      walletName: walletName ?? this.walletName,
      sessionTopic: sessionTopic ?? this.sessionTopic,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      supportedChainIds: supportedChainIds ?? this.supportedChainIds,
      capabilities: capabilities ?? this.capabilities,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'walletId': walletId,
        'walletName': walletName,
        'sessionTopic': sessionTopic,
        'connectedAt': connectedAt.toIso8601String(),
        'lastActivityAt': lastActivityAt?.toIso8601String(),
        'supportedChainIds': supportedChainIds,
        'capabilities': capabilities,
        'metadata': metadata,
      };

  factory WalletConnection.fromJson(Map<String, dynamic> json) {
    return WalletConnection(
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      walletId: json['walletId'] as String?,
      walletName: json['walletName'] as String?,
      sessionTopic: json['sessionTopic'] as String?,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
      lastActivityAt: json['lastActivityAt'] != null
          ? DateTime.parse(json['lastActivityAt'] as String)
          : null,
      supportedChainIds: (json['supportedChainIds'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
      capabilities: (json['capabilities'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [address.toLowerCase(), chainId];

  @override
  String toString() =>
      'WalletConnection($shortAddress, chainId: $chainId, wallet: $walletName)';
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Information about a supported wallet.
///
/// Used for wallet selection UI and connection routing.
class WalletInfo extends Equatable {
  /// Unique identifier (e.g., "metamask", "rainbow").
  final String id;

  /// Display name (e.g., "MetaMask").
  final String name;

  /// Wallet description.
  final String? description;

  /// Wallet icon asset path or URL.
  final String? iconUrl;

  /// Blockchain type this wallet supports.
  final BlockchainType chainType;

  /// Specific networks supported.
  final List<String>? supportedNetworks;

  /// Deep link scheme for mobile (e.g., "metamask://").
  final String? deepLinkScheme;

  /// Universal link for mobile.
  final String? universalLink;

  /// App Store URL for iOS.
  final String? appStoreUrl;

  /// Play Store URL for Android.
  final String? playStoreUrl;

  /// Whether this wallet supports WalletConnect.
  final bool supportsWalletConnect;

  /// Whether this wallet has a mobile app.
  final bool hasMobileApp;

  /// Whether this wallet has a browser extension.
  final bool hasBrowserExtension;

  /// Priority for sorting (lower = higher priority).
  final int priority;

  const WalletInfo({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    required this.chainType,
    this.supportedNetworks,
    this.deepLinkScheme,
    this.universalLink,
    this.appStoreUrl,
    this.playStoreUrl,
    this.supportsWalletConnect = true,
    this.hasMobileApp = true,
    this.hasBrowserExtension = false,
    this.priority = 100,
  });

  /// Whether this wallet can be launched via deep link.
  bool get canDeepLink => deepLinkScheme != null || universalLink != null;

  /// Get the appropriate link for launching the wallet.
  String? get launchUrl => deepLinkScheme ?? universalLink;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'iconUrl': iconUrl,
        'chainType': chainType.name,
        'supportedNetworks': supportedNetworks,
        'deepLinkScheme': deepLinkScheme,
        'universalLink': universalLink,
        'appStoreUrl': appStoreUrl,
        'playStoreUrl': playStoreUrl,
        'supportsWalletConnect': supportsWalletConnect,
        'hasMobileApp': hasMobileApp,
        'hasBrowserExtension': hasBrowserExtension,
        'priority': priority,
      };

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    return WalletInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      chainType: BlockchainType.values.firstWhere(
        (e) => e.name == json['chainType'],
        orElse: () => BlockchainType.evm,
      ),
      supportedNetworks: (json['supportedNetworks'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      deepLinkScheme: json['deepLinkScheme'] as String?,
      universalLink: json['universalLink'] as String?,
      appStoreUrl: json['appStoreUrl'] as String?,
      playStoreUrl: json['playStoreUrl'] as String?,
      supportsWalletConnect: json['supportsWalletConnect'] as bool? ?? true,
      hasMobileApp: json['hasMobileApp'] as bool? ?? true,
      hasBrowserExtension: json['hasBrowserExtension'] as bool? ?? false,
      priority: json['priority'] as int? ?? 100,
    );
  }

  @override
  List<Object?> get props => [id];
}

// ═══════════════════════════════════════════════════════════════════════════════
// PREDEFINED WALLETS
// ═══════════════════════════════════════════════════════════════════════════════

/// Predefined wallet configurations.
abstract class Wallets {
  Wallets._();

  // ─────────────────────────────────────────────────────────────────────────────
  // EVM WALLETS
  // ─────────────────────────────────────────────────────────────────────────────

  static const metamask = WalletInfo(
    id: 'metamask',
    name: 'MetaMask',
    description: 'The most popular Ethereum wallet',
    chainType: BlockchainType.evm,
    deepLinkScheme: 'metamask://',
    universalLink: 'https://metamask.app.link',
    appStoreUrl: 'https://apps.apple.com/app/metamask/id1438144202',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=io.metamask',
    hasBrowserExtension: true,
    priority: 1,
  );

  static const rainbow = WalletInfo(
    id: 'rainbow',
    name: 'Rainbow',
    description: 'A fun, simple, and secure Ethereum wallet',
    chainType: BlockchainType.evm,
    deepLinkScheme: 'rainbow://',
    universalLink: 'https://rnbwapp.com',
    appStoreUrl: 'https://apps.apple.com/app/rainbow-ethereum-wallet/id1457119021',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=me.rainbow',
    priority: 2,
  );

  static const trustWallet = WalletInfo(
    id: 'trust',
    name: 'Trust Wallet',
    description: 'Multi-chain mobile wallet',
    chainType: BlockchainType.evm,
    deepLinkScheme: 'trust://',
    universalLink: 'https://link.trustwallet.com',
    appStoreUrl: 'https://apps.apple.com/app/trust-crypto-bitcoin-wallet/id1288339409',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=com.wallet.crypto.trustapp',
    priority: 3,
  );

  static const coinbaseWallet = WalletInfo(
    id: 'coinbase',
    name: 'Coinbase Wallet',
    description: 'Self-custody wallet from Coinbase',
    chainType: BlockchainType.evm,
    deepLinkScheme: 'cbwallet://',
    universalLink: 'https://go.cb-w.com',
    appStoreUrl: 'https://apps.apple.com/app/coinbase-wallet/id1278383455',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=org.toshi',
    hasBrowserExtension: true,
    priority: 4,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // SOLANA WALLETS
  // ─────────────────────────────────────────────────────────────────────────────

  static const phantom = WalletInfo(
    id: 'phantom',
    name: 'Phantom',
    description: 'A friendly Solana wallet',
    chainType: BlockchainType.solana,
    deepLinkScheme: 'phantom://',
    universalLink: 'https://phantom.app/ul',
    appStoreUrl: 'https://apps.apple.com/app/phantom-solana-wallet/id1598432977',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=app.phantom',
    hasBrowserExtension: true,
    priority: 1,
  );

  static const solflare = WalletInfo(
    id: 'solflare',
    name: 'Solflare',
    description: 'Secure Solana wallet',
    chainType: BlockchainType.solana,
    deepLinkScheme: 'solflare://',
    appStoreUrl: 'https://apps.apple.com/app/solflare/id1580902717',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=com.solflare.mobile',
    hasBrowserExtension: true,
    priority: 2,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // BITCOIN WALLETS
  // ─────────────────────────────────────────────────────────────────────────────

  static const blueWallet = WalletInfo(
    id: 'bluewallet',
    name: 'BlueWallet',
    description: 'Bitcoin & Lightning wallet',
    chainType: BlockchainType.bitcoin,
    deepLinkScheme: 'bluewallet://',
    appStoreUrl: 'https://apps.apple.com/app/bluewallet-bitcoin-wallet/id1376878040',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=io.bluewallet.bluewallet',
    supportsWalletConnect: false,
    priority: 1,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // HEDERA WALLETS
  // ─────────────────────────────────────────────────────────────────────────────

  static const hashpack = WalletInfo(
    id: 'hashpack',
    name: 'HashPack',
    description: 'Hedera wallet',
    chainType: BlockchainType.hedera,
    deepLinkScheme: 'hashpack://',
    universalLink: 'https://www.hashpack.app',
    appStoreUrl: 'https://apps.apple.com/app/hashpack/id1604480652',
    playStoreUrl:
        'https://play.google.com/store/apps/details?id=app.hashpack.wallet',
    supportsWalletConnect: false,
    priority: 1,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // SUI WALLETS
  // ─────────────────────────────────────────────────────────────────────────────

  static const suiWallet = WalletInfo(
    id: 'sui',
    name: 'Sui Wallet',
    description: 'Official Sui wallet',
    chainType: BlockchainType.sui,
    deepLinkScheme: 'suiwallet://',
    hasBrowserExtension: true,
    supportsWalletConnect: false,
    priority: 1,
  );

  // ─────────────────────────────────────────────────────────────────────────────
  // LISTS
  // ─────────────────────────────────────────────────────────────────────────────

  /// All EVM wallets.
  static const List<WalletInfo> evmWallets = [
    metamask,
    rainbow,
    trustWallet,
    coinbaseWallet,
  ];

  /// All Solana wallets.
  static const List<WalletInfo> solanaWallets = [
    phantom,
    solflare,
  ];

  /// All Bitcoin wallets.
  static const List<WalletInfo> bitcoinWallets = [
    blueWallet,
  ];

  /// All wallets.
  static const List<WalletInfo> all = [
    ...evmWallets,
    ...solanaWallets,
    ...bitcoinWallets,
    hashpack,
    suiWallet,
  ];

  /// Get wallets by chain type.
  static List<WalletInfo> forChainType(BlockchainType type) {
    return all.where((w) => w.chainType == type).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  /// Find wallet by ID.
  static WalletInfo? byId(String id) {
    try {
      return all.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINKED WALLET (MULTI-WALLET PROFILE)
// ═══════════════════════════════════════════════════════════════════════════════

/// A wallet linked to a user profile in a multi-wallet system.
class LinkedWallet extends Equatable {
  /// Wallet address.
  final String address;

  /// Chain ID or chain identifier.
  final String chainId;

  /// Blockchain type.
  final BlockchainType chainType;

  /// When this wallet was linked.
  final DateTime linkedAt;

  /// Whether this is the primary wallet.
  final bool isPrimary;

  /// Display label set by user.
  final String? label;

  /// Last used timestamp.
  final DateTime? lastUsedAt;

  const LinkedWallet({
    required this.address,
    required this.chainId,
    required this.chainType,
    required this.linkedAt,
    this.isPrimary = false,
    this.label,
    this.lastUsedAt,
  });

  /// Shortened address for display.
  String get shortAddress {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  /// Display name (label or short address).
  String get displayName => label ?? shortAddress;

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'chainType': chainType.name,
        'linkedAt': linkedAt.toIso8601String(),
        'isPrimary': isPrimary,
        'label': label,
        'lastUsedAt': lastUsedAt?.toIso8601String(),
      };

  factory LinkedWallet.fromJson(Map<String, dynamic> json) {
    return LinkedWallet(
      address: json['address'] as String,
      chainId: json['chainId'] as String,
      chainType: BlockchainType.values.firstWhere(
        (e) => e.name == json['chainType'],
        orElse: () => BlockchainType.evm,
      ),
      linkedAt: DateTime.parse(json['linkedAt'] as String),
      isPrimary: json['isPrimary'] as bool? ?? false,
      label: json['label'] as String?,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [address.toLowerCase(), chainId];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET SESSION
// ═══════════════════════════════════════════════════════════════════════════════

/// Persisted wallet session for automatic reconnection.
class WalletSession extends Equatable {
  /// Session identifier.
  final String id;

  /// WalletConnect session topic.
  final String? wcTopic;

  /// Connected wallet address.
  final String address;

  /// Chain ID at time of connection.
  final int chainId;

  /// Wallet identifier.
  final String? walletId;

  /// When session was created.
  final DateTime createdAt;

  /// When session expires.
  final DateTime? expiresAt;

  /// Whether session is still valid.
  final bool isValid;

  const WalletSession({
    required this.id,
    this.wcTopic,
    required this.address,
    required this.chainId,
    this.walletId,
    required this.createdAt,
    this.expiresAt,
    this.isValid = true,
  });

  /// Whether this session has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this session can be used.
  bool get canUse => isValid && !isExpired;

  Map<String, dynamic> toJson() => {
        'id': id,
        'wcTopic': wcTopic,
        'address': address,
        'chainId': chainId,
        'walletId': walletId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'isValid': isValid,
      };

  factory WalletSession.fromJson(Map<String, dynamic> json) {
    return WalletSession(
      id: json['id'] as String,
      wcTopic: json['wcTopic'] as String?,
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      walletId: json['walletId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      isValid: json['isValid'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [id, address];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET SIGNATURE
// ═══════════════════════════════════════════════════════════════════════════════

/// Result of a message signing operation.
class WalletSignature extends Equatable {
  /// The signature bytes/string.
  final String signature;

  /// Address that signed.
  final String address;

  /// Original message that was signed.
  final String message;

  /// When the signature was created.
  final DateTime timestamp;

  /// Signature scheme used (e.g., "personal_sign", "eth_signTypedData_v4").
  final String? signatureType;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const WalletSignature({
    required this.signature,
    required this.address,
    required this.message,
    required this.timestamp,
    this.signatureType,
    this.metadata,
  });

  /// Signature without 0x prefix.
  String get signatureHex => signature.replaceFirst('0x', '');

  /// V component of signature (for EVM).
  int? get v {
    if (signatureHex.length < 130) return null;
    return int.parse(signatureHex.substring(128, 130), radix: 16);
  }

  /// R component of signature (for EVM).
  String? get r {
    if (signatureHex.length < 64) return null;
    return '0x${signatureHex.substring(0, 64)}';
  }

  /// S component of signature (for EVM).
  String? get s {
    if (signatureHex.length < 128) return null;
    return '0x${signatureHex.substring(64, 128)}';
  }

  Map<String, dynamic> toJson() => {
        'signature': signature,
        'address': address,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'signatureType': signatureType,
        'metadata': metadata,
      };

  factory WalletSignature.fromJson(Map<String, dynamic> json) {
    return WalletSignature(
      signature: json['signature'] as String,
      address: json['address'] as String,
      message: json['message'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      signatureType: json['signatureType'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [signature, address, message];
}
