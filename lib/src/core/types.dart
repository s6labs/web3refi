// ═══════════════════════════════════════════════════════════════════════════════
// CORE TYPE DEFINITIONS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive type definitions for web3refi including:
// - Token information and balances
// - NFT metadata and attributes
// - Wallet connection state and sessions
// - Multi-wallet profile linking
//
// Part of web3refi - The Universal Web3 SDK for Flutter
// Created by S6 Labs LLC
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:equatable/equatable.dart';
import '../core/chain.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN TYPES
// ═══════════════════════════════════════════════════════════════════════════════

/// Token standard/type classification.
enum TokenStandard {
  /// Native currency (ETH, MATIC, BNB, etc.)
  native,

  /// ERC-20 fungible token.
  erc20,

  /// ERC-721 non-fungible token (NFT).
  erc721,

  /// ERC-1155 multi-token standard.
  erc1155,

  /// SPL token (Solana).
  spl,

  /// BEP-20 token (BSC - same as ERC-20).
  bep20,

  /// Unknown token standard.
  unknown,
}

/// Extension methods for [TokenStandard].
extension TokenStandardExtension on TokenStandard {
  /// Human-readable name.
  String get displayName {
    switch (this) {
      case TokenStandard.native:
        return 'Native';
      case TokenStandard.erc20:
        return 'ERC-20';
      case TokenStandard.erc721:
        return 'ERC-721 (NFT)';
      case TokenStandard.erc1155:
        return 'ERC-1155';
      case TokenStandard.spl:
        return 'SPL Token';
      case TokenStandard.bep20:
        return 'BEP-20';
      case TokenStandard.unknown:
        return 'Unknown';
    }
  }

  /// Whether this is a fungible token (can have fractional amounts).
  bool get isFungible =>
      this == TokenStandard.native ||
      this == TokenStandard.erc20 ||
      this == TokenStandard.spl ||
      this == TokenStandard.bep20;

  /// Whether this is an NFT standard.
  bool get isNFT =>
      this == TokenStandard.erc721 || this == TokenStandard.erc1155;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Information about a fungible token.
///
/// ## Example
///
/// ```dart
/// final usdc = TokenInfo(
///   address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
///   chainId: 1,
///   name: 'USD Coin',
///   symbol: 'USDC',
///   decimals: 6,
/// );
///
/// print(usdc.formatAmount(BigInt.from(1000000))); // "1.0"
/// ```
class TokenInfo extends Equatable {
  /// Token contract address (or empty string for native token).
  final String address;

  /// Chain ID where this token exists.
  final int chainId;

  /// Full token name (e.g., "USD Coin").
  final String name;

  /// Token symbol (e.g., "USDC").
  final String symbol;

  /// Number of decimal places.
  final int decimals;

  /// Token standard (ERC-20, etc.).
  final TokenStandard standard;

  /// Token logo URL or asset path.
  final String? logoUrl;

  /// Whether this is a stablecoin.
  final bool isStablecoin;

  /// Whether this token is verified/trusted.
  final bool isVerified;

  /// Coingecko ID for price lookups.
  final String? coingeckoId;

  /// Additional metadata.
  final Map<String, dynamic>? metadata;

  const TokenInfo({
    required this.address,
    required this.chainId,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.standard = TokenStandard.erc20,
    this.logoUrl,
    this.isStablecoin = false,
    this.isVerified = false,
    this.coingeckoId,
    this.metadata,
  });

  /// Create a native token info (ETH, MATIC, etc.).
  factory TokenInfo.native({
    required int chainId,
    required String name,
    required String symbol,
    int decimals = 18,
    String? logoUrl,
  }) {
    return TokenInfo(
      address: '', // Native tokens don't have an address
      chainId: chainId,
      name: name,
      symbol: symbol,
      decimals: decimals,
      standard: TokenStandard.native,
      logoUrl: logoUrl,
      isVerified: true,
    );
  }

  /// Create from JSON (e.g., from token list).
  factory TokenInfo.fromJson(Map<String, dynamic> json) {
    return TokenInfo(
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      decimals: json['decimals'] as int,
      standard: TokenStandard.values.firstWhere(
        (s) => s.name == json['standard'],
        orElse: () => TokenStandard.erc20,
      ),
      logoUrl: json['logoUrl'] as String?,
      isStablecoin: json['isStablecoin'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      coingeckoId: json['coingeckoId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Whether this is the native token.
  bool get isNative => standard == TokenStandard.native || address.isEmpty;

  /// Lowercased address for comparison.
  String get addressLower => address.toLowerCase();

  /// Format a raw token amount to human-readable string.
  ///
  /// ```dart
  /// token.formatAmount(BigInt.from(1000000), decimals: 2); // "1.00"
  /// ```
  String formatAmount(BigInt amount, {int? displayDecimals}) {
    if (amount == BigInt.zero) return '0';

    final isNegative = amount.isNegative;
    final absAmount = amount.abs();
    final divisor = BigInt.from(10).pow(decimals);
    final whole = absAmount ~/ divisor;
    final remainder = absAmount % divisor;

    // Pad remainder to full decimal places
    final remainderStr = remainder.toString().padLeft(decimals, '0');

    // Determine display decimals
    final showDecimals = displayDecimals ?? (decimals > 8 ? 8 : decimals);

    String fractional;
    if (showDecimals == 0) {
      fractional = '';
    } else if (showDecimals >= decimals) {
      fractional = '.$remainderStr';
    } else {
      fractional = '.${remainderStr.substring(0, showDecimals)}';
    }

    // Trim trailing zeros (keep at least 2 for stablecoins)
    if (!isStablecoin) {
      fractional = fractional.replaceAll(RegExp(r'\.?0+$'), '');
    } else if (fractional.length > 3) {
      // Keep 2 decimals for stablecoins
      fractional = fractional.substring(0, 3);
    }

    final prefix = isNegative ? '-' : '';
    return '$prefix$whole$fractional';
  }

  /// Parse a human-readable amount to raw token units.
  ///
  /// ```dart
  /// token.parseAmount('1.5'); // BigInt for 1.5 tokens
  /// ```
  BigInt parseAmount(String amount) {
    final sanitized = amount.replaceAll(',', '').trim();
    final parts = sanitized.split('.');

    if (parts.isEmpty || parts[0].isEmpty) {
      return BigInt.zero;
    }

    final whole = BigInt.parse(parts[0]);

    if (parts.length == 1) {
      return whole * BigInt.from(10).pow(decimals);
    }

    var fractionStr = parts[1];

    // Truncate if more decimals than token supports
    if (fractionStr.length > decimals) {
      fractionStr = fractionStr.substring(0, decimals);
    }

    // Pad to full decimals
    fractionStr = fractionStr.padRight(decimals, '0');

    final fraction = BigInt.parse(fractionStr);
    return whole * BigInt.from(10).pow(decimals) + fraction;
  }

  /// Get unique identifier (chainId:address).
  String get uniqueId => '$chainId:${address.toLowerCase()}';

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'name': name,
        'symbol': symbol,
        'decimals': decimals,
        'standard': standard.name,
        'logoUrl': logoUrl,
        'isStablecoin': isStablecoin,
        'isVerified': isVerified,
        'coingeckoId': coingeckoId,
        'metadata': metadata,
      };

  @override
  List<Object?> get props => [address.toLowerCase(), chainId];

  @override
  String toString() => 'TokenInfo($symbol, $address, chainId: $chainId)';
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN BALANCE
// ═══════════════════════════════════════════════════════════════════════════════

/// Token balance with metadata.
///
/// Combines token information with the actual balance amount.
class TokenBalance extends Equatable {
  /// Token information.
  final TokenInfo token;

  /// Raw balance in smallest units (wei, etc.).
  final BigInt balance;

  /// USD value of the balance (optional).
  final double? usdValue;

  /// Token price in USD (optional).
  final double? tokenPrice;

  /// Last updated timestamp.
  final DateTime? updatedAt;

  const TokenBalance({
    required this.token,
    required this.balance,
    this.usdValue,
    this.tokenPrice,
    this.updatedAt,
  });

  /// Formatted balance for display.
  String get formattedBalance => token.formatAmount(balance);

  /// Formatted balance with symbol.
  String get displayBalance => '${token.formatAmount(balance)} ${token.symbol}';

  /// Formatted USD value.
  String? get formattedUsdValue {
    if (usdValue == null) return null;
    return '\$${usdValue!.toStringAsFixed(2)}';
  }

  /// Whether the balance is zero.
  bool get isZero => balance == BigInt.zero;

  /// Whether the balance is non-zero.
  bool get hasBalance => balance > BigInt.zero;

  /// Create a zero balance for a token.
  factory TokenBalance.zero(TokenInfo token) {
    return TokenBalance(
      token: token,
      balance: BigInt.zero,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token.toJson(),
        'balance': balance.toString(),
        'usdValue': usdValue,
        'tokenPrice': tokenPrice,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [token, balance];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN PRICE
// ═══════════════════════════════════════════════════════════════════════════════

/// Token price and market data.
class TokenPrice extends Equatable {
  /// Token address.
  final String address;

  /// Chain ID.
  final int chainId;

  /// Current price in USD.
  final double priceUsd;

  /// 24-hour price change percentage.
  final double? change24h;

  /// 24-hour trading volume in USD.
  final double? volume24h;

  /// Market cap in USD.
  final double? marketCap;

  /// All-time high price.
  final double? athPrice;

  /// All-time low price.
  final double? atlPrice;

  /// Last updated timestamp.
  final DateTime updatedAt;

  const TokenPrice({
    required this.address,
    required this.chainId,
    required this.priceUsd,
    this.change24h,
    this.volume24h,
    this.marketCap,
    this.athPrice,
    this.atlPrice,
    required this.updatedAt,
  });

  /// Whether the price is stale (older than 5 minutes).
  bool get isStale => DateTime.now().difference(updatedAt).inMinutes > 5;

  /// Formatted price string.
  String get formattedPrice {
    if (priceUsd >= 1) {
      return '\$${priceUsd.toStringAsFixed(2)}';
    } else if (priceUsd >= 0.01) {
      return '\$${priceUsd.toStringAsFixed(4)}';
    } else {
      return '\$${priceUsd.toStringAsFixed(8)}';
    }
  }

  /// Formatted 24h change.
  String? get formattedChange {
    if (change24h == null) return null;
    final sign = change24h! >= 0 ? '+' : '';
    return '$sign${change24h!.toStringAsFixed(2)}%';
  }

  /// Whether price is up in last 24h.
  bool? get isUp => change24h != null ? change24h! >= 0 : null;

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'priceUsd': priceUsd,
        'change24h': change24h,
        'volume24h': volume24h,
        'marketCap': marketCap,
        'athPrice': athPrice,
        'atlPrice': atlPrice,
        'updatedAt': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [address, chainId, priceUsd];
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN ALLOWANCE
// ═══════════════════════════════════════════════════════════════════════════════

/// ERC-20 token allowance (approval) information.
class TokenAllowance extends Equatable {
  /// Token information.
  final TokenInfo token;

  /// Owner address (who approved).
  final String owner;

  /// Spender address (who can spend).
  final String spender;

  /// Approved amount.
  final BigInt amount;

  /// When the allowance was last updated/checked.
  final DateTime? updatedAt;

  const TokenAllowance({
    required this.token,
    required this.owner,
    required this.spender,
    required this.amount,
    this.updatedAt,
  });

  /// Maximum uint256 value (infinite approval).
  static final BigInt maxUint256 = BigInt.parse(
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    radix: 16,
  );

  /// Whether this is an infinite/unlimited approval.
  bool get isUnlimited => amount >= maxUint256 ~/ BigInt.from(2);

  /// Whether there is any allowance.
  bool get hasAllowance => amount > BigInt.zero;

  /// Formatted allowance amount.
  String get formattedAmount {
    if (isUnlimited) return 'Unlimited';
    return token.formatAmount(amount);
  }

  /// Check if allowance is sufficient for an amount.
  bool isSufficientFor(BigInt requiredAmount) => amount >= requiredAmount;

  Map<String, dynamic> toJson() => {
        'token': token.toJson(),
        'owner': owner,
        'spender': spender,
        'amount': amount.toString(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [token, owner, spender, amount];
}

// ═══════════════════════════════════════════════════════════════════════════════
// NFT INFO
// ═══════════════════════════════════════════════════════════════════════════════

/// Information about a non-fungible token (NFT).
class NFTInfo extends Equatable {
  /// Contract address.
  final String contractAddress;

  /// Token ID.
  final String tokenId;

  /// Token standard (ERC-721 or ERC-1155).
  final TokenStandard standard;

  /// Chain ID.
  final int chainId;

  /// NFT name.
  final String? name;

  /// NFT description.
  final String? description;

  /// Image URL.
  final String? imageUrl;

  /// Animation URL (for videos/animations).
  final String? animationUrl;

  /// External URL.
  final String? externalUrl;

  /// Collection name.
  final String? collectionName;

  /// Collection symbol.
  final String? collectionSymbol;

  /// Creator address.
  final String? creator;

  /// Current owner address.
  final String? owner;

  /// NFT attributes/traits.
  final List<NFTAttribute>? attributes;

  /// Amount owned (for ERC-1155).
  final BigInt? amount;

  /// Metadata URI.
  final String? tokenUri;

  const NFTInfo({
    required this.contractAddress,
    required this.tokenId,
    required this.chainId,
    this.standard = TokenStandard.erc721,
    this.name,
    this.description,
    this.imageUrl,
    this.animationUrl,
    this.externalUrl,
    this.collectionName,
    this.collectionSymbol,
    this.creator,
    this.owner,
    this.attributes,
    this.amount,
    this.tokenUri,
  });

  /// Unique identifier.
  String get uniqueId => '$chainId:$contractAddress:$tokenId';

  /// Display name (fallback to token ID if no name).
  String get displayName => name ?? '#$tokenId';

  /// Whether this is an ERC-1155 token.
  bool get isERC1155 => standard == TokenStandard.erc1155;

  factory NFTInfo.fromJson(Map<String, dynamic> json) {
    return NFTInfo(
      contractAddress: json['contractAddress'] as String,
      tokenId: json['tokenId'] as String,
      chainId: json['chainId'] as int,
      standard: TokenStandard.values.firstWhere(
        (s) => s.name == json['standard'],
        orElse: () => TokenStandard.erc721,
      ),
      name: json['name'] as String?,
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      animationUrl: json['animationUrl'] as String?,
      externalUrl: json['externalUrl'] as String?,
      collectionName: json['collectionName'] as String?,
      collectionSymbol: json['collectionSymbol'] as String?,
      creator: json['creator'] as String?,
      owner: json['owner'] as String?,
      attributes: (json['attributes'] as List<dynamic>?)
          ?.map((a) => NFTAttribute.fromJson(a as Map<String, dynamic>))
          .toList(),
      amount: json['amount'] != null
          ? BigInt.parse(json['amount'] as String)
          : null,
      tokenUri: json['tokenUri'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'contractAddress': contractAddress,
        'tokenId': tokenId,
        'chainId': chainId,
        'standard': standard.name,
        'name': name,
        'description': description,
        'imageUrl': imageUrl,
        'animationUrl': animationUrl,
        'externalUrl': externalUrl,
        'collectionName': collectionName,
        'collectionSymbol': collectionSymbol,
        'creator': creator,
        'owner': owner,
        'attributes': attributes?.map((a) => a.toJson()).toList(),
        'amount': amount?.toString(),
        'tokenUri': tokenUri,
      };

  @override
  List<Object?> get props => [contractAddress, tokenId, chainId];
}

/// NFT attribute/trait.
class NFTAttribute extends Equatable {
  /// Attribute type/category (e.g., "Background", "Eyes").
  final String traitType;

  /// Attribute value (e.g., "Blue", "Rare").
  final dynamic value;

  /// Display type (e.g., "number", "date", "boost_percentage").
  final String? displayType;

  /// Max value (for numeric traits).
  final num? maxValue;

  const NFTAttribute({
    required this.traitType,
    required this.value,
    this.displayType,
    this.maxValue,
  });

  factory NFTAttribute.fromJson(Map<String, dynamic> json) {
    return NFTAttribute(
      traitType: json['trait_type'] as String,
      value: json['value'],
      displayType: json['display_type'] as String?,
      maxValue: json['max_value'] as num?,
    );
  }

  Map<String, dynamic> toJson() => {
        'trait_type': traitType,
        'value': value,
        if (displayType != null) 'display_type': displayType,
        if (maxValue != null) 'max_value': maxValue,
      };

  @override
  List<Object?> get props => [traitType, value];
}

// ═══════════════════════════════════════════════════════════════════════════════
// WALLET CONNECTION TYPES
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
