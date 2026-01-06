import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/cifi/client.dart';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';
import 'package:web3refi/src/names/resolvers/ens_resolver.dart';
import 'package:web3refi/src/names/resolvers/cifi_resolver.dart';
import 'package:web3refi/src/names/resolvers/unstoppable_resolver.dart';
import 'package:web3refi/src/names/resolvers/spaceid_resolver.dart';
import 'package:web3refi/src/names/resolvers/sns_resolver.dart';
import 'package:web3refi/src/names/resolvers/suins_resolver.dart';
import 'package:web3refi/src/names/utils/namehash.dart';
import 'package:web3refi/src/names/cache/name_cache.dart';
import 'package:web3refi/src/names/batch/batch_resolver.dart';
import 'package:web3refi/src/core/feature_access.dart';

/// Universal Name Service - One API for all name resolution systems.
///
/// **PREMIUM FEATURE**: Requires CIFI ID (API key + secret) for full access.
///
/// Free tier includes basic ENS resolution only (.eth names).
/// Premium tier includes all name services: ENS, Unstoppable Domains,
/// Space ID, Solana Name Service, Sui Name Service, and CiFi names.
///
/// Provides a unified interface for resolving names across multiple
/// name services (ENS, Unstoppable Domains, Solana Name Service, etc.)
/// with CiFi as a universal fallback.
///
/// ## Supported Name Services
///
/// - **ENS** (.eth) - Ethereum Name Service
/// - **Unstoppable Domains** (.crypto, .nft, .wallet, .x, .bitcoin, .dao, .888, .zil, .blockchain)
/// - **Space ID** (.bnb, .arb) - BNB Chain and Arbitrum names
/// - **Solana Name Service** (.sol) - Solana domains
/// - **Sui Name Service** (.sui) - Sui domains
/// - **CiFi** (@username, .cifi) - Universal multi-chain identity
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Multi-chain support
/// - Automatic fallback (ENS → CiFi → Custom)
/// - Text records (email, url, avatar, etc.)
/// - Batch resolution
/// - Caching
///
/// ## Usage
///
/// ```dart
/// final uns = UniversalNameService(
///   rpcClient: rpcClient,
///   cifiClient: cifiClient,
/// );
///
/// // Resolve any name format
/// final vitalik = await uns.resolve('vitalik.eth');
/// final alice = await uns.resolve('@alice');
/// final bob = await uns.resolve('bob.crypto');
///
/// // Reverse resolve
/// final name = await uns.reverseResolve('0x742d...');
///
/// // Get all records
/// final records = await uns.getRecords('vitalik.eth');
/// print(records?.texts['avatar']);
/// ```
class UniversalNameService with FeatureGuard {
  final RpcClient _rpc;
  final CiFiClient? _cifiClient;
  final Map<String, NameResolver> _resolvers = {};
  final List<String> _resolutionOrder = [];
  final Map<String, String> _tldMappings = {};

  /// Advanced caching layer
  late final NameCache _cache;

  /// Batch resolver for optimized multi-name resolution
  BatchResolver? _batchResolver;

  /// Feature access manager for premium feature gating.
  @override
  final FeatureAccessManager? featureAccess;

  UniversalNameService({
    required RpcClient rpcClient,
    CiFiClient? cifiClient,
    this.featureAccess,
    bool enableCiFiFallback = true,
    bool enableUnstoppableDomains = true,
    bool enableSpaceId = true,
    bool enableSolanaNameService = true,
    bool enableSuiNameService = true,
    int unstoppableDomainsChainId = 137, // Polygon by default
    int spaceIdChainId = 56, // BNB Chain by default
    String? solanaRpcUrl,
    String? suiRpcUrl,
    int cacheMaxSize = 1000,
    Duration cacheTtl = const Duration(hours: 1),
    bool enableCacheStats = true,
  })  : _rpc = rpcClient,
        _cifiClient = cifiClient {
    // Initialize cache
    _cache = NameCache(
      maxSize: cacheMaxSize,
      defaultTtl: cacheTtl,
      enableStats: enableCacheStats,
    );

    _registerDefaultResolvers(
      enableCiFiFallback: enableCiFiFallback,
      enableUnstoppableDomains: enableUnstoppableDomains,
      enableSpaceId: enableSpaceId,
      enableSolanaNameService: enableSolanaNameService,
      enableSuiNameService: enableSuiNameService,
      unstoppableDomainsChainId: unstoppableDomainsChainId,
      spaceIdChainId: spaceIdChainId,
      solanaRpcUrl: solanaRpcUrl,
      suiRpcUrl: suiRpcUrl,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // PRIMARY API
  // ══════════════════════════════════════════════════════════════════════

  /// Resolve a name to an address.
  ///
  /// Supports multiple formats:
  /// - ENS: "vitalik.eth" (FREE - available without CIFI ID)
  /// - CiFi: "@alice" or "alice.cifi" (PREMIUM)
  /// - Unstoppable: "bob.crypto" (PREMIUM)
  /// - Space ID: "alice.bnb" (PREMIUM)
  /// - SNS: "alice.sol" (PREMIUM)
  /// - SuiNS: "alice.sui" (PREMIUM)
  ///
  /// [name] - The name to resolve
  /// [chainId] - Optional chain ID for multi-chain resolution
  /// [coinType] - Optional coin type (SLIP-0044) for multi-coin addresses
  /// [useCache] - Whether to use cached results (default: true)
  ///
  /// Throws [PremiumFeatureException] for non-ENS names without CIFI ID.
  Future<String?> resolve(
    String name, {
    int? chainId,
    String? coinType,
    bool useCache = true,
  }) async {
    final normalized = NameValidator.normalize(name);

    // Validate name
    final validation = NameValidator.validate(normalized);
    if (validation != null) {
      throw ArgumentError(validation);
    }

    // Check feature access based on name type
    _requireFeatureForName(normalized);

    // Check cache
    if (useCache) {
      final cached = _cache.getForward(normalized);
      if (cached != null) {
        return cached.address;
      }
    }

    // Determine resolution order based on name
    final resolvers = _getResolversForName(normalized);

    // Try each resolver
    for (final resolverId in resolvers) {
      final resolver = _resolvers[resolverId];
      if (resolver == null) continue;

      try {
        final result = await resolver.resolve(
          normalized,
          chainId: chainId,
          coinType: coinType,
        );

        if (result != null) {
          // Cache result
          _cache.setForward(normalized, result);

          return result.address;
        }
      } catch (e) {
        // Continue to next resolver
        continue;
      }
    }

    return null;
  }

  /// Check feature access based on name type.
  /// ENS (.eth) is free, all others require premium.
  void _requireFeatureForName(String name) {
    // ENS names are free tier
    if (name.endsWith('.eth')) {
      return; // Free - no feature check needed
    }

    // CiFi names (@username, .cifi)
    if (name.startsWith('@') || name.endsWith('.cifi')) {
      requireFeature(SdkFeature.cifiNameResolution);
      return;
    }

    // Unstoppable Domains
    final udTlds = ['crypto', 'nft', 'wallet', 'x', 'bitcoin', 'dao', '888', 'zil', 'blockchain'];
    for (final tld in udTlds) {
      if (name.endsWith('.$tld')) {
        requireFeature(SdkFeature.unstoppableDomainsResolution);
        return;
      }
    }

    // Space ID
    if (name.endsWith('.bnb') || name.endsWith('.arb')) {
      requireFeature(SdkFeature.spaceIdResolution);
      return;
    }

    // Solana Name Service
    if (name.endsWith('.sol')) {
      requireFeature(SdkFeature.solanaNameService);
      return;
    }

    // Sui Name Service
    if (name.endsWith('.sui')) {
      requireFeature(SdkFeature.suiNameService);
      return;
    }

    // Default: require full UNS access for unknown TLDs
    requireFeature(SdkFeature.universalNameService);
  }

  /// Resolve a name and return full result with metadata.
  Future<ResolutionResult?> resolveWithMetadata(
    String name, {
    int? chainId,
    String? coinType,
    bool useCache = true,
  }) async {
    final normalized = NameValidator.normalize(name);

    // Check cache
    if (useCache) {
      final cached = _cache.getForward(normalized);
      if (cached != null) {
        return cached;
      }
    }

    // Determine resolution order
    final resolvers = _getResolversForName(normalized);

    // Try each resolver
    for (final resolverId in resolvers) {
      final resolver = _resolvers[resolverId];
      if (resolver == null) continue;

      try {
        final result = await resolver.resolve(
          normalized,
          chainId: chainId,
          coinType: coinType,
        );

        if (result != null) {
          // Cache result
          _cache.setForward(normalized, result);

          return result;
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// Reverse resolve an address to a name.
  Future<String?> reverseResolve(
    String address, {
    int? chainId,
    bool useCache = true,
  }) async {
    // Check cache
    if (useCache) {
      final cached = _cache.getReverse(address);
      if (cached != null) {
        return cached;
      }
    }

    // Try each resolver that supports reverse resolution
    for (final resolverId in _resolutionOrder) {
      final resolver = _resolvers[resolverId];
      if (resolver == null || !resolver.supportsReverse) continue;

      try {
        final name = await resolver.reverseResolve(
          address,
          chainId: chainId,
        );

        if (name != null) {
          // Cache result
          _cache.setReverse(address, name);
          return name;
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  /// Get all records for a name.
  Future<NameRecords?> getRecords(
    String name, {
    bool useCache = true,
  }) async {
    final normalized = NameValidator.normalize(name);

    // Check cache
    if (useCache) {
      final cached = _cache.getRecords(normalized);
      if (cached != null) {
        return _recordsMapToNameRecords(cached);
      }
    }

    final resolverId = _getResolverIdForName(normalized);
    final resolver = _resolvers[resolverId];

    if (resolver == null) return null;

    final records = await resolver.getRecords(normalized);

    // Cache the records
    if (records != null) {
      _cache.setRecords(normalized, records.texts);
    }

    return records;
  }

  /// Convert cached records map to NameRecords
  NameRecords _recordsMapToNameRecords(Map<String, String> texts) {
    return NameRecords(
      texts: texts,
      avatar: texts['avatar'],
      email: texts['email'],
      url: texts['url'],
    );
  }

  /// Get specific text record.
  Future<String?> getText(String name, String key) async {
    final records = await getRecords(name);
    return records?.getText(key);
  }

  /// Get avatar URL for a name.
  Future<String?> getAvatar(String name) async {
    final records = await getRecords(name);
    return records?.avatar ?? records?.getText('avatar');
  }

  /// Resolve multiple names in batch.
  ///
  /// Uses optimized batch resolution with Multicall3 when possible,
  /// falling back to serial resolution for mixed name types.
  Future<Map<String, String?>> resolveMany(
    List<String> names, {
    int? chainId,
    bool useBatchOptimization = true,
  }) async {
    if (names.isEmpty) return {};

    // Check cache first
    final results = <String, String?>{};
    final uncachedNames = <String>[];

    for (final name in names) {
      final normalized = NameValidator.normalize(name);
      final cached = _cache.getForward(normalized);

      if (cached != null) {
        results[normalized] = cached.address;
      } else {
        uncachedNames.add(normalized);
      }
    }

    if (uncachedNames.isEmpty) {
      return results;
    }

    // Try batch resolution for ENS names
    if (useBatchOptimization && _batchResolver != null) {
      // Separate ENS names from others
      final ensNames = <String>[];
      final otherNames = <String>[];

      for (final name in uncachedNames) {
        if (name.endsWith('.eth')) {
          ensNames.add(name);
        } else {
          otherNames.add(name);
        }
      }

      // Batch resolve ENS names
      if (ensNames.isNotEmpty) {
        try {
          final batchResults = await _batchResolver!.resolveMany(ensNames);

          for (final entry in batchResults.entries) {
            if (entry.value != null) {
              // Cache and store result
              final result = ResolutionResult(
                name: entry.key,
                address: entry.value!,
                resolverUsed: 'ens',
                chainId: chainId ?? 1,
              );
              _cache.setForward(entry.key, result);
              results[entry.key] = entry.value;
            } else {
              results[entry.key] = null;
            }
          }
        } catch (e) {
          // Fall back to serial resolution
          ensNames.addAll(otherNames);
          otherNames.clear();
        }
      }

      // Serially resolve other names
      for (final name in otherNames) {
        results[name] = await resolve(name, chainId: chainId);
      }
    } else {
      // Serial resolution fallback
      for (final name in uncachedNames) {
        results[name] = await resolve(name, chainId: chainId);
      }
    }

    return results;
  }

  /// Enable batch resolution optimization
  ///
  /// Requires a resolver address (typically ENS Public Resolver)
  void enableBatchResolution({
    required String resolverAddress,
    String? multicallAddress,
    int maxBatchSize = 100,
  }) {
    _batchResolver = BatchResolver(
      rpcClient: _rpc,
      resolverAddress: resolverAddress,
      multicallAddress: multicallAddress,
      maxBatchSize: maxBatchSize,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // CUSTOM RESOLVER REGISTRATION
  // ══════════════════════════════════════════════════════════════════════

  /// Register a custom name resolver.
  ///
  /// [id] - Unique identifier for the resolver
  /// [resolver] - The resolver implementation
  /// [priority] - Resolution order (lower = higher priority)
  void registerResolver(
    String id,
    NameResolver resolver, {
    int? priority,
  }) {
    _resolvers[id] = resolver;

    if (priority != null) {
      _resolutionOrder.insert(priority, id);
    } else {
      _resolutionOrder.add(id);
    }
  }

  /// Register a TLD → resolver mapping.
  void registerTLD(String tld, String resolverId) {
    _tldMappings[tld.toLowerCase()] = resolverId;
  }

  /// Clear resolution cache.
  void clearCache() {
    _cache.clear();
  }

  /// Get cache statistics.
  CacheStats getCacheStats() {
    return _cache.getStats();
  }

  /// Reset cache statistics.
  void resetCacheStats() {
    _cache.resetStats();
  }

  /// Clear forward resolution cache for a specific name.
  void clearForwardCache(String name) {
    _cache.clearForward(name);
  }

  /// Clear reverse resolution cache for a specific address.
  void clearReverseCache(String address) {
    _cache.clearReverse(address);
  }

  /// Clear records cache for a specific name.
  void clearRecordsCache(String name) {
    _cache.clearRecords(name);
  }

  /// Dispose and cleanup resources.
  void dispose() {
    _cache.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL
  // ══════════════════════════════════════════════════════════════════════

  void _registerDefaultResolvers({
    required bool enableCiFiFallback,
    required bool enableUnstoppableDomains,
    required bool enableSpaceId,
    required bool enableSolanaNameService,
    required bool enableSuiNameService,
    required int unstoppableDomainsChainId,
    required int spaceIdChainId,
    String? solanaRpcUrl,
    String? suiRpcUrl,
  }) {
    var priorityCounter = 0;

    // Register ENS (priority 0)
    registerResolver('ens', ENSResolver(_rpc), priority: priorityCounter++);
    _tldMappings['eth'] = 'ens';

    // Register Unstoppable Domains if enabled
    if (enableUnstoppableDomains) {
      final udResolver = UnstoppableResolver(_rpc, chainId: unstoppableDomainsChainId);
      registerResolver('unstoppable', udResolver, priority: priorityCounter++);

      for (final tld in udResolver.supportedTLDs) {
        _tldMappings[tld] = 'unstoppable';
      }
    }

    // Register Space ID if enabled
    if (enableSpaceId) {
      final spaceIdResolver = SpaceIdResolver(_rpc, chainId: spaceIdChainId);
      registerResolver('spaceid', spaceIdResolver, priority: priorityCounter++);

      for (final tld in spaceIdResolver.supportedTLDs) {
        _tldMappings[tld] = 'spaceid';
      }
    }

    // Register Solana Name Service if enabled
    if (enableSolanaNameService) {
      final snsResolver = SnsResolver(solanaRpcUrl: solanaRpcUrl ?? 'https://api.mainnet-beta.solana.com');
      registerResolver('sns', snsResolver, priority: priorityCounter++);

      for (final tld in snsResolver.supportedTLDs) {
        _tldMappings[tld] = 'sns';
      }
    }

    // Register Sui Name Service if enabled
    if (enableSuiNameService) {
      final suinsResolver = SuiNsResolver(suiRpcUrl: suiRpcUrl ?? 'https://fullnode.mainnet.sui.io');
      registerResolver('suins', suinsResolver, priority: priorityCounter++);

      for (final tld in suinsResolver.supportedTLDs) {
        _tldMappings[tld] = 'suins';
      }
    }

    // Register CiFi as universal fallback (lowest priority)
    if (enableCiFiFallback && _cifiClient != null) {
      registerResolver('cifi', CiFiResolver(_cifiClient!), priority: priorityCounter++);
      _tldMappings['cifi'] = 'cifi';
    }
  }

  /// Get resolvers to try for a given name.
  List<String> _getResolversForName(String name) {
    // CiFi names (@alice, alice.cifi)
    if (name.startsWith('@') || name.endsWith('.cifi')) {
      return ['cifi'];
    }

    // Check TLD mapping
    final parts = name.split('.');
    if (parts.length >= 2) {
      final tld = parts.last.toLowerCase();
      final resolverId = _tldMappings[tld];
      if (resolverId != null) {
        return [resolverId, if (_resolvers.containsKey('cifi')) 'cifi'];
      }
    }

    // Default: try all resolvers in order
    return List.from(_resolutionOrder);
  }

  /// Get the best resolver ID for a name.
  String _getResolverIdForName(String name) {
    if (name.startsWith('@') || name.endsWith('.cifi')) {
      return 'cifi';
    }

    final parts = name.split('.');
    if (parts.length >= 2) {
      final tld = parts.last.toLowerCase();
      return _tldMappings[tld] ?? _resolutionOrder.first;
    }

    return _resolutionOrder.first;
  }
}

