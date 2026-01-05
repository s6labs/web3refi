import 'package:equatable/equatable.dart';

/// Represents a blockchain network configuration.
///
/// Example:
/// ```dart
/// final polygon = Chain(
///   chainId: 137,
///   name: 'Polygon',
///   rpcUrl: 'https://polygon-rpc.com',
///   symbol: 'MATIC',
///   explorerUrl: 'https://polygonscan.com',
/// );
/// ```
class Chain extends Equatable {
  /// Unique chain identifier (e.g., 1 for Ethereum, 137 for Polygon).
  final int chainId;

  /// Human-readable chain name.
  final String name;

  /// Short name for display (e.g., "ETH", "MATIC").
  final String shortName;

  /// Primary RPC endpoint URL.
  final String rpcUrl;

  /// Native currency symbol (e.g., "ETH", "MATIC").
  final String symbol;

  /// Native currency name (e.g., "Ether", "Matic").
  final String currencyName;

  /// Number of decimals for native currency (typically 18).
  final int decimals;

  /// Block explorer URL.
  final String explorerUrl;

  /// Backup RPC endpoints for failover.
  final List<String> backupRpcUrls;

  /// Chain icon asset path or URL.
  final String? iconUrl;

  /// Whether this is a testnet.
  final bool isTestnet;

  /// The blockchain type (EVM, Bitcoin, Solana, etc.).
  final BlockchainType type;

  /// Average block time in seconds.
  final double blockTimeSeconds;

  /// EIP-155 chain ID in hex format (e.g., "0x89" for Polygon).
  String get chainIdHex => '0x${chainId.toRadixString(16)}';

  /// CAIP-2 chain identifier (e.g., "eip155:137").
  String get caip2Id {
    switch (type) {
      case BlockchainType.evm:
        return 'eip155:$chainId';
      case BlockchainType.solana:
        return 'solana:$chainId';
      case BlockchainType.bitcoin:
        return 'bip122:$chainId';
      default:
        return '$type:$chainId';
    }
  }

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
    this.iconUrl,
    this.isTestnet = false,
    this.type = BlockchainType.evm,
    this.blockTimeSeconds = 12.0,
  })  : shortName = shortName ?? symbol,
        currencyName = currencyName ?? symbol;

  /// Creates an EVM-compatible chain.
  factory Chain.evm({
    required int chainId,
    required String name,
    required String rpcUrl,
    required String symbol,
    required String explorerUrl,
    String? shortName,
    List<String> backupRpcUrls = const [],
    String? iconUrl,
    bool isTestnet = false,
  }) {
    return Chain(
      chainId: chainId,
      name: name,
      rpcUrl: rpcUrl,
      symbol: symbol,
      explorerUrl: explorerUrl,
      shortName: shortName,
      backupRpcUrls: backupRpcUrls,
      iconUrl: iconUrl,
      isTestnet: isTestnet,
      type: BlockchainType.evm,
    );
  }

  /// Get transaction URL for block explorer.
  String getTransactionUrl(String txHash) {
    return '$explorerUrl/tx/$txHash';
  }

  /// Get address URL for block explorer.
  String getAddressUrl(String address) {
    return '$explorerUrl/address/$address';
  }

  /// Get token URL for block explorer.
  String getTokenUrl(String tokenAddress) {
    return '$explorerUrl/token/$tokenAddress';
  }

  /// Get block URL for block explorer.
  String getBlockUrl(int blockNumber) {
    return '$explorerUrl/block/$blockNumber';
  }

  @override
  List<Object?> get props => [chainId, type];

  @override
  String toString() => 'Chain($name, chainId: $chainId)';

  Map<String, dynamic> toJson() => {
        'chainId': chainId,
        'name': name,
        'shortName': shortName,
        'rpcUrl': rpcUrl,
        'symbol': symbol,
        'currencyName': currencyName,
        'decimals': decimals,
        'explorerUrl': explorerUrl,
        'backupRpcUrls': backupRpcUrls,
        'iconUrl': iconUrl,
        'isTestnet': isTestnet,
        'type': type.name,
        'blockTimeSeconds': blockTimeSeconds,
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
        backupRpcUrls: (json['backupRpcUrls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        iconUrl: json['iconUrl'] as String?,
        isTestnet: json['isTestnet'] as bool? ?? false,
        type: BlockchainType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => BlockchainType.evm,
        ),
        blockTimeSeconds: (json['blockTimeSeconds'] as num?)?.toDouble() ?? 12.0,
      );
}

/// Supported blockchain types.
enum BlockchainType {
  /// Ethereum Virtual Machine compatible chains.
  evm,

  /// Bitcoin and Bitcoin-like chains.
  bitcoin,

  /// Solana blockchain.
  solana,

  /// Hedera Hashgraph.
  hedera,

  /// Constellation DAG network.
  constellation,

  /// Sui blockchain.
  sui,

  /// Cosmos-based chains.
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
        return 'EVM';
      case BlockchainType.bitcoin:
        return 'Bitcoin';
      case BlockchainType.solana:
        return 'Solana';
      case BlockchainType.hedera:
        return 'Hedera';
      case BlockchainType.constellation:
        return 'Constellation';
      case BlockchainType.sui:
        return 'Sui';
      case BlockchainType.cosmos:
        return 'Cosmos';
      case BlockchainType.unknown:
        return 'Unknown';
    }
  }

  /// Whether this blockchain type supports EIP-1559 transactions.
  bool get supportsEIP1559 {
    return this == BlockchainType.evm;
  }

  /// Whether this blockchain type uses account-based model.
  bool get isAccountBased {
    return this != BlockchainType.bitcoin;
  }
}
