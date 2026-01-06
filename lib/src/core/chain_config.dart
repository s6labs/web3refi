/// Chain configuration for Web3ReFi SDK
///
/// Provides configuration for blockchain networks including RPC endpoints,
/// chain IDs, native currencies, and block explorers.
library;

/// Configuration for a blockchain network
class ChainConfig {
  /// Unique chain identifier (EIP-155)
  final int chainId;

  /// Human-readable chain name
  final String name;

  /// Native currency symbol (e.g., 'ETH', 'MATIC')
  final String nativeCurrency;

  /// RPC endpoint URL
  final String rpcUrl;

  /// Optional WebSocket RPC endpoint
  final String? wsRpcUrl;

  /// Block explorer URL (e.g., Etherscan)
  final String? blockExplorerUrl;

  /// Whether this is a testnet
  final bool isTestnet;

  const ChainConfig({
    required this.chainId,
    required this.name,
    required this.nativeCurrency,
    required this.rpcUrl,
    this.wsRpcUrl,
    this.blockExplorerUrl,
    this.isTestnet = false,
  });

  /// Create ChainConfig from JSON
  factory ChainConfig.fromJson(Map<String, dynamic> json) {
    return ChainConfig(
      chainId: json['chainId'] as int,
      name: json['name'] as String,
      nativeCurrency: json['nativeCurrency'] as String,
      rpcUrl: json['rpcUrl'] as String,
      wsRpcUrl: json['wsRpcUrl'] as String?,
      blockExplorerUrl: json['blockExplorerUrl'] as String?,
      isTestnet: json['isTestnet'] as bool? ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'chainId': chainId,
      'name': name,
      'nativeCurrency': nativeCurrency,
      'rpcUrl': rpcUrl,
      if (wsRpcUrl != null) 'wsRpcUrl': wsRpcUrl,
      if (blockExplorerUrl != null) 'blockExplorerUrl': blockExplorerUrl,
      'isTestnet': isTestnet,
    };
  }

  @override
  String toString() => 'ChainConfig($name, chainId: $chainId)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChainConfig && other.chainId == chainId;
  }

  @override
  int get hashCode => chainId.hashCode;
}

/// Predefined chain configurations
class ChainConfigs {
  ChainConfigs._();

  /// Ethereum Mainnet
  static const ethereum = ChainConfig(
    chainId: 1,
    name: 'Ethereum',
    nativeCurrency: 'ETH',
    rpcUrl: 'https://eth.llamarpc.com',
    blockExplorerUrl: 'https://etherscan.io',
  );

  /// Polygon Mainnet
  static const polygon = ChainConfig(
    chainId: 137,
    name: 'Polygon',
    nativeCurrency: 'MATIC',
    rpcUrl: 'https://polygon-rpc.com',
    blockExplorerUrl: 'https://polygonscan.com',
  );

  /// Arbitrum One
  static const arbitrum = ChainConfig(
    chainId: 42161,
    name: 'Arbitrum One',
    nativeCurrency: 'ETH',
    rpcUrl: 'https://arb1.arbitrum.io/rpc',
    blockExplorerUrl: 'https://arbiscan.io',
  );

  /// Optimism Mainnet
  static const optimism = ChainConfig(
    chainId: 10,
    name: 'Optimism',
    nativeCurrency: 'ETH',
    rpcUrl: 'https://mainnet.optimism.io',
    blockExplorerUrl: 'https://optimistic.etherscan.io',
  );

  /// Base Mainnet
  static const base = ChainConfig(
    chainId: 8453,
    name: 'Base',
    nativeCurrency: 'ETH',
    rpcUrl: 'https://mainnet.base.org',
    blockExplorerUrl: 'https://basescan.org',
  );

  /// BNB Smart Chain
  static const bnb = ChainConfig(
    chainId: 56,
    name: 'BNB Chain',
    nativeCurrency: 'BNB',
    rpcUrl: 'https://bsc-dataseed1.binance.org',
    blockExplorerUrl: 'https://bscscan.com',
  );

  /// Avalanche C-Chain
  static const avalanche = ChainConfig(
    chainId: 43114,
    name: 'Avalanche',
    nativeCurrency: 'AVAX',
    rpcUrl: 'https://api.avax.network/ext/bc/C/rpc',
    blockExplorerUrl: 'https://snowtrace.io',
  );

  /// Sepolia Testnet (Ethereum)
  static const sepolia = ChainConfig(
    chainId: 11155111,
    name: 'Sepolia',
    nativeCurrency: 'ETH',
    rpcUrl: 'https://rpc.sepolia.org',
    blockExplorerUrl: 'https://sepolia.etherscan.io',
    isTestnet: true,
  );

  /// Mumbai Testnet (Polygon)
  static const mumbai = ChainConfig(
    chainId: 80001,
    name: 'Mumbai',
    nativeCurrency: 'MATIC',
    rpcUrl: 'https://rpc-mumbai.maticvigil.com',
    blockExplorerUrl: 'https://mumbai.polygonscan.com',
    isTestnet: true,
  );

  /// All predefined mainnet configurations
  static const List<ChainConfig> mainnets = [
    ethereum,
    polygon,
    arbitrum,
    optimism,
    base,
    bnb,
    avalanche,
  ];

  /// All predefined testnet configurations
  static const List<ChainConfig> testnets = [
    sepolia,
    mumbai,
  ];

  /// All predefined configurations
  static const List<ChainConfig> all = [
    ...mainnets,
    ...testnets,
  ];

  /// Get chain config by chain ID
  static ChainConfig? getByChainId(int chainId) {
    try {
      return all.firstWhere((config) => config.chainId == chainId);
    } catch (_) {
      return null;
    }
  }

  /// Get chain config by name (case-insensitive)
  static ChainConfig? getByName(String name) {
    try {
      return all.firstWhere(
        (config) => config.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
