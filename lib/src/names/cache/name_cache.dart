import 'dart:async';
import 'package:web3refi/src/names/resolution_result.dart';

/// Cache entry for name resolution results
class CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  final Duration ttl;

  CacheEntry({
    required this.value,
    required this.timestamp,
    required this.ttl,
  });

  /// Check if this cache entry has expired
  bool get isExpired {
    return DateTime.now().difference(timestamp) > ttl;
  }

  /// Get remaining time until expiration
  Duration get timeUntilExpiration {
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = ttl - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

/// Multi-level cache for name resolution
///
/// Provides fast, memory-efficient caching with:
/// - Configurable TTL (time-to-live)
/// - Automatic cache invalidation
/// - LRU eviction policy
/// - Cache statistics
/// - Manual cache control
///
/// ## Usage
///
/// ```dart
/// final cache = NameCache(
///   maxSize: 1000,
///   defaultTtl: Duration(hours: 1),
/// );
///
/// // Store result
/// cache.set('vitalik.eth', result);
///
/// // Retrieve result
/// final cached = cache.get('vitalik.eth');
/// ```
class NameCache {
  final Map<String, CacheEntry<ResolutionResult>> _forwardCache = {};
  final Map<String, CacheEntry<String>> _reverseCache = {};
  final Map<String, CacheEntry<Map<String, String>>> _recordsCache = {};

  final int maxSize;
  final Duration defaultTtl;
  final bool enableStats;

  // Statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;

  Timer? _cleanupTimer;

  NameCache({
    this.maxSize = 1000,
    this.defaultTtl = const Duration(hours: 1),
    this.enableStats = true,
    Duration? cleanupInterval,
  }) {
    // Start periodic cleanup
    final interval = cleanupInterval ?? const Duration(minutes: 5);
    _cleanupTimer = Timer.periodic(interval, (_) => _cleanup());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORWARD RESOLUTION CACHE (name → address)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get cached forward resolution result
  ResolutionResult? getForward(String name) {
    final normalized = _normalizeKey(name);
    final entry = _forwardCache[normalized];

    if (entry == null) {
      if (enableStats) _misses++;
      return null;
    }

    if (entry.isExpired) {
      _forwardCache.remove(normalized);
      if (enableStats) {
        _misses++;
        _expirations++;
      }
      return null;
    }

    if (enableStats) _hits++;
    return entry.value;
  }

  /// Store forward resolution result
  void setForward(
    String name,
    ResolutionResult result, {
    Duration? ttl,
  }) {
    final normalized = _normalizeKey(name);

    // Check size limit
    if (_forwardCache.length >= maxSize) {
      _evictLru(_forwardCache);
    }

    _forwardCache[normalized] = CacheEntry(
      value: result,
      timestamp: DateTime.now(),
      ttl: ttl ?? defaultTtl,
    );
  }

  /// Clear forward resolution cache for a specific name
  void clearForward(String name) {
    final normalized = _normalizeKey(name);
    _forwardCache.remove(normalized);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REVERSE RESOLUTION CACHE (address → name)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get cached reverse resolution result
  String? getReverse(String address) {
    final normalized = _normalizeAddress(address);
    final entry = _reverseCache[normalized];

    if (entry == null) {
      if (enableStats) _misses++;
      return null;
    }

    if (entry.isExpired) {
      _reverseCache.remove(normalized);
      if (enableStats) {
        _misses++;
        _expirations++;
      }
      return null;
    }

    if (enableStats) _hits++;
    return entry.value;
  }

  /// Store reverse resolution result
  void setReverse(
    String address,
    String name, {
    Duration? ttl,
  }) {
    final normalized = _normalizeAddress(address);

    // Check size limit
    if (_reverseCache.length >= maxSize) {
      _evictLru(_reverseCache);
    }

    _reverseCache[normalized] = CacheEntry(
      value: name,
      timestamp: DateTime.now(),
      ttl: ttl ?? defaultTtl,
    );
  }

  /// Clear reverse resolution cache for a specific address
  void clearReverse(String address) {
    final normalized = _normalizeAddress(address);
    _reverseCache.remove(normalized);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECORDS CACHE
  // ══════════════════════════════════════════════════════════════════════════

  /// Get cached records
  Map<String, String>? getRecords(String name) {
    final normalized = _normalizeKey(name);
    final entry = _recordsCache[normalized];

    if (entry == null) {
      if (enableStats) _misses++;
      return null;
    }

    if (entry.isExpired) {
      _recordsCache.remove(normalized);
      if (enableStats) {
        _misses++;
        _expirations++;
      }
      return null;
    }

    if (enableStats) _hits++;
    return Map.from(entry.value);
  }

  /// Store records
  void setRecords(
    String name,
    Map<String, String> records, {
    Duration? ttl,
  }) {
    final normalized = _normalizeKey(name);

    // Check size limit
    if (_recordsCache.length >= maxSize) {
      _evictLru(_recordsCache);
    }

    _recordsCache[normalized] = CacheEntry(
      value: Map.from(records),
      timestamp: DateTime.now(),
      ttl: ttl ?? defaultTtl,
    );
  }

  /// Clear records cache for a specific name
  void clearRecords(String name) {
    final normalized = _normalizeKey(name);
    _recordsCache.remove(normalized);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Clear all caches
  void clear() {
    _forwardCache.clear();
    _reverseCache.clear();
    _recordsCache.clear();

    if (enableStats) {
      _hits = 0;
      _misses = 0;
      _evictions = 0;
      _expirations = 0;
    }
  }

  /// Clear expired entries from all caches
  void _cleanup() {
    _cleanupCache(_forwardCache);
    _cleanupCache(_reverseCache);
    _cleanupCache(_recordsCache);
  }

  /// Remove expired entries from a specific cache
  void _cleanupCache<T>(Map<String, CacheEntry<T>> cache) {
    final keysToRemove = <String>[];

    for (final entry in cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      cache.remove(key);
      if (enableStats) _expirations++;
    }
  }

  /// Evict least recently used entry (LRU)
  void _evictLru<T>(Map<String, CacheEntry<T>> cache) {
    if (cache.isEmpty) return;

    // Find oldest entry
    String? oldestKey;
    DateTime? oldestTime;

    for (final entry in cache.entries) {
      if (oldestTime == null || entry.value.timestamp.isBefore(oldestTime)) {
        oldestTime = entry.value.timestamp;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      cache.remove(oldestKey);
      if (enableStats) _evictions++;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get cache statistics
  CacheStats getStats() {
    return CacheStats(
      hits: _hits,
      misses: _misses,
      evictions: _evictions,
      expirations: _expirations,
      forwardCacheSize: _forwardCache.length,
      reverseCacheSize: _reverseCache.length,
      recordsCacheSize: _recordsCache.length,
      totalSize: _forwardCache.length + _reverseCache.length + _recordsCache.length,
      hitRate: _hits + _misses > 0 ? _hits / (_hits + _misses) : 0.0,
    );
  }

  /// Reset statistics
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Normalize cache key (lowercase)
  String _normalizeKey(String key) {
    return key.toLowerCase().trim();
  }

  /// Normalize address (lowercase, with 0x prefix)
  String _normalizeAddress(String address) {
    final normalized = address.toLowerCase().trim();
    return normalized.startsWith('0x') ? normalized : '0x$normalized';
  }

  /// Dispose and cleanup
  void dispose() {
    _cleanupTimer?.cancel();
    clear();
  }
}

/// Cache statistics
class CacheStats {
  final int hits;
  final int misses;
  final int evictions;
  final int expirations;
  final int forwardCacheSize;
  final int reverseCacheSize;
  final int recordsCacheSize;
  final int totalSize;
  final double hitRate;

  CacheStats({
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.expirations,
    required this.forwardCacheSize,
    required this.reverseCacheSize,
    required this.recordsCacheSize,
    required this.totalSize,
    required this.hitRate,
  });

  @override
  String toString() {
    return 'CacheStats{\n'
        '  hits: $hits,\n'
        '  misses: $misses,\n'
        '  evictions: $evictions,\n'
        '  expirations: $expirations,\n'
        '  hitRate: ${(hitRate * 100).toStringAsFixed(2)}%,\n'
        '  forwardCache: $forwardCacheSize,\n'
        '  reverseCache: $reverseCacheSize,\n'
        '  recordsCache: $recordsCacheSize,\n'
        '  totalSize: $totalSize\n'
        '}';
  }

  /// Get cache efficiency score (0.0 - 1.0)
  double get efficiency {
    if (hits + misses == 0) return 0.0;
    return hitRate;
  }

  /// Check if cache is performing well (>70% hit rate)
  bool get isPerformingWell {
    return hitRate > 0.7;
  }

  /// Get recommendation based on stats
  String get recommendation {
    if (hitRate < 0.3) {
      return 'Low hit rate. Consider increasing cache size or TTL.';
    } else if (hitRate < 0.7) {
      return 'Moderate hit rate. Cache is working but could be optimized.';
    } else {
      return 'Good hit rate. Cache is performing well.';
    }
  }
}
