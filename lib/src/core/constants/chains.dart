import 'package:equatable/equatable.dart';

/// Represents a blockchain network configuration.
///
/// Supports both EVM-compatible chains and non-EVM chains like
/// Bitcoin, Solana, Hedera, Constellation, and Sui.
///
/// Example:
/// ```dart
/// final xdc = Chain.evm(
///   chainId: 50,
///   name: 'XDC Network',
///   rpcUrl: 'https://rpc.xinfin.network',
///   symbol: 'XDC',
///   explorerUrl: 'https://explorer.xinfin.network',
/// );
/// ```
class Chain extends Equatable {
  // ══════════════════════════════════════════════════════════════════════════
  // CORE PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Unique chain identifier.
  /// - EVM chains: Standard chain ID (e.g., 1 for Ethereum, 50 for XDC)
  /// - Non-EVM: Custom identifier for internal use
  final int chainId;

  /// Human-readable chain name.
  final String name;

  /// Short name for display (e.g., "ETH", "XDC", "SOL").
  final String shortName;

  /// The blockchain type (EVM, Bitcoin, Solana, etc.).
  final BlockchainType type;

  /// Whether this is a testnet.
  final bool isTestnet;

  // ══════════════════════════════════════════════════════════════════════════
  // NETWORK PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Primary RPC/API endpoint URL.
  final String rpcUrl;

  /// Backup RPC endpoints for failover.
  final List<String> backupRpcUrls;

  /// WebSocket RPC URL (for subscriptions).
  final String? wsUrl;

  /// Block explorer URL.
  final String explorerUrl;

  /// API endpoint for the block explorer (if different from explorer).
  final String? explorerApiUrl;

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE CURRENCY
  // ══════════════════════════════════════════════════════════════════════════

  /// Native currency symbol (e.g., "ETH", "XDC", "SOL").
  final String symbol;

  /// Native currency full name (e.g., "Ether", "XDC", "Solana").
  final String currencyName;

  /// Number of decimals for native currency.
  /// - EVM chains: typically 18
  /// - Bitcoin: 8 (satoshis)
  /// - Solana: 9 (lamports)
  /// - Hedera: 8 (tinybars)
  final int decimals;

  // ══════════════════════════════════════════════════════════════════════════
  // CHAIN CHARACTERISTICS
  // ══════════════════════════════════════════════════════════════════════════

  /// Average block time in seconds.
  final double blockTimeSeconds;

  /// Whether this chain supports EIP-1559 fee market.
  final bool supportsEIP1559;

  /// Whether this chain supports smart contracts.
  final bool supportsContracts;

  /// Chain icon asset path or URL.
  final String? iconUrl;

  /// Additional chain-specific metadata.
  final Map<String, dynamic> metadata;

  // ══════════════════════════════════════════════════════════════════════════
  // COMPUTED PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// EIP-155 chain ID in hex format (e.g., "0x32" for XDC).
  String get chainIdHex => '0x${chainId.toRadixString(16)}';

  /// CAIP-2 chain identifier for multi-chain standards.
  /// Format: namespace:chainId (e.g., "eip155:50", "solana:mainnet")
  String get caip2Id {
    switch (type) {
      case BlockchainType.evm:
        return 'eip155:$chainId';
      case BlockchainType.solana:
        final network = isTestnet ? 'devnet' : 'mainnet';
        return 'solana:$network';
      case BlockchainType.bitcoin:
        final network = isTestnet ? 'testnet' : 'mainnet';
        return 'bip122:$network';
      case BlockchainType.hedera:
        return 'hedera:$chainId';
      case BlockchainType.constellation:
        return 'constellation:$chainId';
      case BlockchainType.sui:
        return 'sui:$chainId';
      case BlockchainType.cosmos:
        return 'cosmos:$chainId';
      case BlockchainType.unknown:
        return 'unknown:$chainId';
    }
  }

  /// Whether this is an EVM-compatible chain.
  bool get isEVM => type == BlockchainType.evm;

  /// The smallest unit name (wei, satoshi, lamport, etc.)
  String get smallestUnitName {
    switch (type) {
      case BlockchainType.evm:
        return 'wei';
      case BlockchainType.bitcoin:
        return 'satoshi';
      case BlockchainType.solana:
        return 'lamport';
      case BlockchainType.hedera:
        return 'tinybar';
      case BlockchainType.sui:
        return 'mist';
      case BlockchainType.constellation:
        return 'datum';
      default:
        return 'unit';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  const Chain({
    required this.chainId,
    required this.name,
    required this.rpcUrl,
    required this.symbol,
    required this.explorerUrl,
    String? shortName,
    String? currencyName,
    this.decimals = 18,
    this.backupRpcUrls = const [],
    this.wsUrl,
    this.explorerApiUrl,
    this.iconUrl,
    this.isTestnet = false,
    this.type = BlockchainType.evm,
    this.blockTimeSeconds = 12.0,
    this.supportsEIP1559 = true,
    this.supportsContracts = true,
    this.metadata = const {},
  })  : shortName = shortName ?? symbol,
        currencyName = currencyName ?? symbol;

  // ══════════════════════════════════════════════════════════════════════════
  // FACTORY CONSTRUCTORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates an EVM-compatible chain.
  factory Chain.evm({
    required int chainId,
    required String name,
    required String rpcUrl,
    required String symbol,
    required String explorerUrl,
    String? shortName,
    String? currencyName,
    int decimals = 18,
    List<String> backupRpcUrls = const [],
    String? wsUrl,
    String? explorerApiUrl,
    String? iconUrl,
    bool isTestnet = false,
    double blockTimeSeconds = 12.0,
    bool supportsEIP1559 = true,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: symbol,
      explorerUrl: explorerUrl,
      shortName: shortName,
      currencyName: currencyName,
      decimals: decimals,
      backupRpcUrls: backupRpcUrls,
      wsUrl: wsUrl,
      explorerApiUrl: explorerApiUrl,
      iconUrl: iconUrl,
      isTestnet: isTestnet,
      type: BlockchainType.evm,
      blockTimeSeconds: blockTimeSeconds,
      supportsEIP1559: supportsEIP1559,
      supportsContracts: true,
    );
  }

  /// Creates a Solana chain configuration.
  factory Chain.solana({
    required String name,
    required String rpcUrl,
    required String explorerUrl,
    int chainId = 101,
    List<String> backupRpcUrls = const [],
    String? wsUrl,
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: 'SOL',
      currencyName: 'Solana',
      explorerUrl: explorerUrl,
      decimals: 9,
      backupRpcUrls: backupRpcUrls,
      wsUrl: wsUrl,
      isTestnet: isTestnet,
      type: BlockchainType.solana,
      blockTimeSeconds: 0.4,
      supportsEIP1559: false,
      supportsContracts: true,
    );
  }

  /// Creates a Bitcoin chain configuration.
  factory Chain.bitcoin({
    required String name,
    required String rpcUrl,
    required String explorerUrl,
    int chainId = 0,
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: 'BTC',
      currencyName: 'Bitcoin',
      explorerUrl: explorerUrl,
      decimals: 8,
      isTestnet: isTestnet,
      type: BlockchainType.bitcoin,
      blockTimeSeconds: 600.0,
      supportsEIP1559: false,
      supportsContracts: false,
    );
  }

  /// Creates a Hedera chain configuration.
  factory Chain.hedera({
    required String name,
    required String rpcUrl,
    required String explorerUrl,
    required int chainId,
    List<String> backupRpcUrls = const [],
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: 'HBAR',
      currencyName: 'Hedera',
      explorerUrl: explorerUrl,
      decimals: 8,
      backupRpcUrls: backupRpcUrls,
      isTestnet: isTestnet,
      type: BlockchainType.hedera,
      blockTimeSeconds: 3.0,
      supportsEIP1559: false,
      supportsContracts: true,
    );
  }

  /// Creates a Constellation DAG chain configuration.
  factory Chain.constellation({
    required String name,
    required String rpcUrl,
    required String explorerUrl,
    int chainId = 1,
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: 'DAG',
      currencyName: 'Constellation',
      explorerUrl: explorerUrl,
      decimals: 8,
      isTestnet: isTestnet,
      type: BlockchainType.constellation,
      blockTimeSeconds: 5.0,
      supportsEIP1559: false,
      supportsContracts: true,
    );
  }

  /// Creates a Sui chain configuration.
  factory Chain.sui({
    required String name,
    required String rpcUrl,
    required String explorerUrl,
    int chainId = 1,
    List<String> backupRpcUrls = const [],
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: 'SUI',
      currencyName: 'Sui',
      explorerUrl: explorerUrl,
      decimals: 9,
      backupRpcUrls: backupRpcUrls,
      isTestnet: isTestnet,
      type: BlockchainType.sui,
      blockTimeSeconds: 0.5,
      supportsEIP1559: false,
      supportsContracts: true,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPLORER URL BUILDERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get transaction URL for block explorer.
  String getTransactionUrl(String txHash) {
    switch (type) {
      case BlockchainType.evm:
        return '$explorerUrl/tx/$txHash';
      case BlockchainType.solana:
        return '$explorerUrl/tx/$txHash';
      case BlockchainType.bitcoin:
        return '$explorerUrl/tx/$txHash';
      case BlockchainType.hedera:
        return '$explorerUrl/transaction/$txHash';
      case BlockchainType.constellation:
        return '$explorerUrl/transactions/$txHash';
      case BlockchainType.sui:
        return '$explorerUrl/txblock/$txHash';
      default:
        return '$explorerUrl/tx/$txHash';
    }
  }

  /// Get address URL for block explorer.
  String getAddressUrl(String address) {
    switch (type) {
      case BlockchainType.evm:
        return '$explorerUrl/address/$address';
      case BlockchainType.solana:
        return '$explorerUrl/account/$address';
      case BlockchainType.bitcoin:
        return '$explorerUrl/address/$address';
      case BlockchainType.hedera:
        return '$explorerUrl/account/$address';
      case BlockchainType.constellation:
        return '$explorerUrl/address/$address';
      case BlockchainType.sui:
        return '$explorerUrl/address/$address';
      default:
        return '$explorerUrl/address/$address';
    }
  }

  /// Get token/contract URL for block explorer.
  String getTokenUrl(String tokenAddress) {
    switch (type) {
      case BlockchainType.evm:
        return '$explorerUrl/token/$tokenAddress';
      case BlockchainType.solana:
        return '$explorerUrl/token/$tokenAddress';
      case BlockchainType.hedera:
        return '$explorerUrl/token/$tokenAddress';
      case BlockchainType.sui:
        return '$explorerUrl/coin/$tokenAddress';
      default:
        return '$explorerUrl/token/$tokenAddress';
    }
  }

  /// Get block URL for block explorer.
  String getBlockUrl(dynamic blockIdentifier) {
    switch (type) {
      case BlockchainType.evm:
        return '$explorerUrl/block/$blockIdentifier';
      case BlockchainType.solana:
        return '$explorerUrl/block/$blockIdentifier';
      case BlockchainType.bitcoin:
        return '$explorerUrl/block/$blockIdentifier';
      case BlockchainType.hedera:
        return '$explorerUrl/block/$blockIdentifier';
      case BlockchainType.sui:
        return '$explorerUrl/checkpoint/$blockIdentifier';
      default:
        return '$explorerUrl/block/$blockIdentifier';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SERIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  @override
  List<Object?> get props => [chainId, type];

  @override
  String toString() => 'Chain($name, chainId: $chainId, type: ${type.name})';

  Map<String, dynamic> toJson() => {
        'chainId': chainId,
        'name': name,
        'shortName': shortName,
        'rpcUrl': rpcUrl,
        'symbol': symbol,
        'currencyName': currencyName,
        'decimals': decimals,
        'explorerUrl': explorerUrl,
        'explorerApiUrl': explorerApiUrl,
        'backupRpcUrls': backupRpcUrls,
        'wsUrl': wsUrl,
        'iconUrl': iconUrl,
        'isTestnet': isTestnet,
        'type': type.name,
        'blockTimeSeconds': blockTimeSeconds,
        'supportsEIP1559': supportsEIP1559,
        'supportsContracts': supportsContracts,
        'metadata': metadata,
      };

  factory Chain.fromJson(Map<String, dynamic> json) => Chain(
        chainId: json['chainId'] as int,
        name: json['name'] as String,
        shortName: json['shortName'] as String?,
        rpcUrl: json['rpcUrl'] as String,
        symbol: json['symbol'] as String,
        currencyName: json['currencyName'] as String?,
        decimals: json['decimals'] as int? ?? 18,
        explorerUrl: json['explorerUrl'] as String,
        explorerApiUrl: json['explorerApiUrl'] as String?,
        backupRpcUrls: (json['backupRpcUrls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        wsUrl: json['wsUrl'] as String?,
        iconUrl: json['iconUrl'] as String?,
        isTestnet: json['isTestnet'] as bool? ?? false,
        type: BlockchainType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => BlockchainType.evm,
        ),
        blockTimeSeconds: (json['blockTimeSeconds'] as num?)?.toDouble() ?? 12.0,
        supportsEIP1559: json['supportsEIP1559'] as bool? ?? true,
        supportsContracts: json['supportsContracts'] as bool? ?? true,
        metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      );

  /// Create a copy with modified properties.
  Chain copyWith({
    int? chainId,
    String? name,
    String? shortName,
    String? rpcUrl,
    String? symbol,
    String? currencyName,
    int? decimals,
    String? explorerUrl,
    String? explorerApiUrl,
    List<String>? backupRpcUrls,
    String? wsUrl,
    String? iconUrl,
    bool? isTestnet,
    BlockchainType? type,
    double? blockTimeSeconds,
    bool? supportsEIP1559,
    bool? supportsContracts,
    Map<String, dynamic>? metadata,
  }) {
    return Chain(
      chainId: chainId ?? this.chainId,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      symbol: symbol ?? this.symbol,
      currencyName: currencyName ?? this.currencyName,
      decimals: decimals ?? this.decimals,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      explorerApiUrl: explorerApiUrl ?? this.explorerApiUrl,
      backupRpcUrls: backupRpcUrls ?? this.backupRpcUrls,
      wsUrl: wsUrl ?? this.wsUrl,
      iconUrl: iconUrl ?? this.iconUrl,
      isTestnet: isTestnet ?? this.isTestnet,
      type: type ?? this.type,
      blockTimeSeconds: blockTimeSeconds ?? this.blockTimeSeconds,
      supportsEIP1559: supportsEIP1559 ?? this.supportsEIP1559,
      supportsContracts: supportsContracts ?? this.supportsContracts,
      metadata: metadata ?? this.metadata,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// BLOCKCHAIN TYPE ENUM
// ════════════════════════════════════════════════════════════════════════════

/// Supported blockchain types.
enum BlockchainType {
  /// Ethereum Virtual Machine compatible chains.
  /// Includes: Ethereum, Polygon, Arbitrum, Optimism, Base, XDC, Avalanche, BSC
  evm,

  /// Bitcoin and Bitcoin-like UTXO chains.
  bitcoin,

  /// Solana blockchain.
  solana,

  /// Hedera Hashgraph.
  hedera,

  /// Constellation DAG network.
  constellation,

  /// Sui blockchain (Move-based).
  sui,

  /// Cosmos SDK-based chains.
  cosmos,

  /// Unknown or unsupported chain type.
  unknown,
}

/// Extension methods for BlockchainType.
extension BlockchainTypeExtension on BlockchainType {
  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case BlockchainType.evm:
        return 'EVM Compatible';
      case BlockchainType.bitcoin:
        return 'Bitcoin';
      case BlockchainType.solana:
        return 'Solana';
      case BlockchainType.hedera:
        return 'Hedera Hashgraph';
      case BlockchainType.constellation:
        return 'Constellation DAG';
      case BlockchainType.sui:
        return 'Sui';
      case BlockchainType.cosmos:
        return 'Cosmos';
      case BlockchainType.unknown:
        return 'Unknown';
    }
  }

  /// Short description of the chain type.
  String get description {
    switch (this) {
      case BlockchainType.evm:
        return 'Ethereum-compatible smart contract platform';
      case BlockchainType.bitcoin:
        return 'Original cryptocurrency, UTXO-based';
      case BlockchainType.solana:
        return 'High-performance blockchain';
      case BlockchainType.hedera:
        return 'Enterprise-grade hashgraph network';
      case BlockchainType.constellation:
        return 'DAG-based feeless network';
      case BlockchainType.sui:
        return 'Move-based Layer 1 blockchain';
      case BlockchainType.cosmos:
        return 'Internet of Blockchains';
      case BlockchainType.unknown:
        return 'Unknown blockchain type';
    }
  }

  /// Whether this blockchain type supports smart contracts.
  bool get supportsSmartContracts {
    switch (this) {
      case BlockchainType.evm:
      case BlockchainType.solana:
      case BlockchainType.hedera:
      case BlockchainType.sui:
      case BlockchainType.constellation:
      case BlockchainType.cosmos:
        return true;
      case BlockchainType.bitcoin:
      case BlockchainType.unknown:
        return false;
    }
  }

  /// Whether this blockchain uses account-based model (vs UTXO).
  bool get isAccountBased {
    return this != BlockchainType.bitcoin;
  }

  /// Whether this blockchain supports EIP-1559 style transactions.
  bool get supportsEIP1559 {
    return this == BlockchainType.evm;
  }

  /// Standard address prefix/format hint.
  String get addressPrefix {
    switch (this) {
      case BlockchainType.evm:
        return '0x';
      case BlockchainType.bitcoin:
        return 'bc1/1/3';
      case BlockchainType.solana:
        return 'Base58';
      case BlockchainType.hedera:
        return '0.0.';
      case BlockchainType.constellation:
        return 'DAG';
      case BlockchainType.sui:
        return '0x';
      case BlockchainType.cosmos:
        return 'cosmos';
      case BlockchainType.unknown:
        return '';
    }
  }
}
