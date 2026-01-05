// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN INFO MODEL
// ═══════════════════════════════════════════════════════════════════════════════
//
// Comprehensive token information models including:
// - Token metadata (name, symbol, decimals)
// - Token balances with formatting
// - Token prices and market data
// - NFT token information
//
// Part of web3refi - The Universal Web3 SDK for Flutter
// Created by S6 Labs LLC
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// TOKEN STANDARD ENUM
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
