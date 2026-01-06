import 'dart:async';

/// Analytics and metrics system for name service operations
///
/// Tracks usage patterns, performance metrics, and provides insights
/// into name service utilization.
///
/// ## Features
///
/// - Operation counting and timing
/// - Success/failure rate tracking
/// - Resolver performance comparison
/// - Cache effectiveness metrics
/// - Real-time statistics
/// - Historical data tracking
///
/// ## Usage
///
/// ```dart
/// final analytics = NameAnalytics();
///
/// // Track a resolution
/// final stopwatch = analytics.startOperation('resolve');
/// try {
///   final result = await resolve(name);
///   stopwatch.success('ens');
/// } catch (e) {
///   stopwatch.failure('ens', e);
/// }
///
/// // Get statistics
/// final stats = analytics.getStats();
/// print('Total resolutions: ${stats.totalResolutions}');
/// print('Success rate: ${stats.successRate}%');
/// ```
class NameAnalytics {
  // Operation counters
  int _totalResolutions = 0;
  int _successfulResolutions = 0;
  int _failedResolutions = 0;
  int _cachedResolutions = 0;

  int _totalReverseResolutions = 0;
  int _successfulReverseResolutions = 0;

  int _totalRecordFetches = 0;
  int _successfulRecordFetches = 0;

  // Resolver performance
  final Map<String, _ResolverStats> _resolverStats = {};

  // Timing data
  final List<int> _resolutionTimes = [];
  final int _maxTimingSamples = 1000;

  // Error tracking
  final Map<String, int> _errorCounts = {};

  // Enable/disable analytics
  bool _enabled = true;

  /// Enable or disable analytics
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Check if analytics is enabled
  bool get isEnabled => _enabled;

  /// Start tracking an operation
  OperationStopwatch startOperation(String operationType) {
    return OperationStopwatch(
      analytics: this,
      operationType: operationType,
    );
  }

  /// Record a successful resolution
  void _recordResolution({
    required bool success,
    required String? resolverUsed,
    required int durationMs,
    bool fromCache = false,
  }) {
    if (!_enabled) return;

    _totalResolutions++;

    if (success) {
      _successfulResolutions++;

      if (fromCache) {
        _cachedResolutions++;
      }

      if (resolverUsed != null) {
        _getResolverStats(resolverUsed).recordSuccess(durationMs);
      }
    } else {
      _failedResolutions++;

      if (resolverUsed != null) {
        _getResolverStats(resolverUsed).recordFailure();
      }
    }

    // Track timing
    _addTiming(durationMs);
  }

  /// Record a reverse resolution
  void _recordReverseResolution({
    required bool success,
    required int durationMs,
  }) {
    if (!_enabled) return;

    _totalReverseResolutions++;

    if (success) {
      _successfulReverseResolutions++;
    }

    _addTiming(durationMs);
  }

  /// Record a record fetch
  void _recordRecordFetch({
    required bool success,
    required int durationMs,
  }) {
    if (!_enabled) return;

    _totalRecordFetches++;

    if (success) {
      _successfulRecordFetches++;
    }

    _addTiming(durationMs);
  }

  /// Record an error
  void _recordError(String errorType) {
    if (!_enabled) return;

    _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
  }

  /// Get resolver stats (create if doesn't exist)
  _ResolverStats _getResolverStats(String resolver) {
    return _resolverStats.putIfAbsent(
      resolver,
      () => _ResolverStats(resolver),
    );
  }

  /// Add timing sample
  void _addTiming(int durationMs) {
    _resolutionTimes.add(durationMs);

    // Keep only recent samples
    if (_resolutionTimes.length > _maxTimingSamples) {
      _resolutionTimes.removeAt(0);
    }
  }

  /// Get current statistics
  AnalyticsStats getStats() {
    return AnalyticsStats(
      totalResolutions: _totalResolutions,
      successfulResolutions: _successfulResolutions,
      failedResolutions: _failedResolutions,
      cachedResolutions: _cachedResolutions,
      totalReverseResolutions: _totalReverseResolutions,
      successfulReverseResolutions: _successfulReverseResolutions,
      totalRecordFetches: _totalRecordFetches,
      successfulRecordFetches: _successfulRecordFetches,
      resolverStats: Map.from(_resolverStats),
      errorCounts: Map.from(_errorCounts),
      averageResolutionTime: _calculateAverage(_resolutionTimes),
      medianResolutionTime: _calculateMedian(_resolutionTimes),
      p95ResolutionTime: _calculatePercentile(_resolutionTimes, 0.95),
      p99ResolutionTime: _calculatePercentile(_resolutionTimes, 0.99),
    );
  }

  /// Reset all statistics
  void reset() {
    _totalResolutions = 0;
    _successfulResolutions = 0;
    _failedResolutions = 0;
    _cachedResolutions = 0;
    _totalReverseResolutions = 0;
    _successfulReverseResolutions = 0;
    _totalRecordFetches = 0;
    _successfulRecordFetches = 0;
    _resolverStats.clear();
    _resolutionTimes.clear();
    _errorCounts.clear();
  }

  /// Calculate average
  double _calculateAverage(List<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate median
  double _calculateMedian(List<int> values) {
    if (values.isEmpty) return 0.0;

    final sorted = List<int>.from(values)..sort();
    final middle = sorted.length ~/ 2;

    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    } else {
      return sorted[middle].toDouble();
    }
  }

  /// Calculate percentile
  double _calculatePercentile(List<int> values, double percentile) {
    if (values.isEmpty) return 0.0;

    final sorted = List<int>.from(values)..sort();
    final index = (sorted.length * percentile).ceil() - 1;

    if (index < 0) return sorted[0].toDouble();
    if (index >= sorted.length) return sorted.last.toDouble();

    return sorted[index].toDouble();
  }
}

/// Operation stopwatch for tracking operation timing
class OperationStopwatch {
  final NameAnalytics analytics;
  final String operationType;
  final Stopwatch _stopwatch = Stopwatch();

  OperationStopwatch({
    required this.analytics,
    required this.operationType,
  }) {
    _stopwatch.start();
  }

  /// Record successful operation
  void success(String? resolverUsed, {bool fromCache = false}) {
    _stopwatch.stop();

    switch (operationType) {
      case 'resolve':
        analytics._recordResolution(
          success: true,
          resolverUsed: resolverUsed,
          durationMs: _stopwatch.elapsedMilliseconds,
          fromCache: fromCache,
        );
        break;
      case 'reverse':
        analytics._recordReverseResolution(
          success: true,
          durationMs: _stopwatch.elapsedMilliseconds,
        );
        break;
      case 'records':
        analytics._recordRecordFetch(
          success: true,
          durationMs: _stopwatch.elapsedMilliseconds,
        );
        break;
    }
  }

  /// Record failed operation
  void failure(String? resolverUsed, Object error) {
    _stopwatch.stop();

    switch (operationType) {
      case 'resolve':
        analytics._recordResolution(
          success: false,
          resolverUsed: resolverUsed,
          durationMs: _stopwatch.elapsedMilliseconds,
        );
        break;
      case 'reverse':
        analytics._recordReverseResolution(
          success: false,
          durationMs: _stopwatch.elapsedMilliseconds,
        );
        break;
      case 'records':
        analytics._recordRecordFetch(
          success: false,
          durationMs: _stopwatch.elapsedMilliseconds,
        );
        break;
    }

    analytics._recordError(error.runtimeType.toString());
  }
}

/// Analytics statistics snapshot
class AnalyticsStats {
  final int totalResolutions;
  final int successfulResolutions;
  final int failedResolutions;
  final int cachedResolutions;
  final int totalReverseResolutions;
  final int successfulReverseResolutions;
  final int totalRecordFetches;
  final int successfulRecordFetches;
  final Map<String, _ResolverStats> resolverStats;
  final Map<String, int> errorCounts;
  final double averageResolutionTime;
  final double medianResolutionTime;
  final double p95ResolutionTime;
  final double p99ResolutionTime;

  AnalyticsStats({
    required this.totalResolutions,
    required this.successfulResolutions,
    required this.failedResolutions,
    required this.cachedResolutions,
    required this.totalReverseResolutions,
    required this.successfulReverseResolutions,
    required this.totalRecordFetches,
    required this.successfulRecordFetches,
    required this.resolverStats,
    required this.errorCounts,
    required this.averageResolutionTime,
    required this.medianResolutionTime,
    required this.p95ResolutionTime,
    required this.p99ResolutionTime,
  });

  /// Success rate (0.0 - 1.0)
  double get successRate {
    if (totalResolutions == 0) return 0.0;
    return successfulResolutions / totalResolutions;
  }

  /// Cache hit rate (0.0 - 1.0)
  double get cacheHitRate {
    if (totalResolutions == 0) return 0.0;
    return cachedResolutions / totalResolutions;
  }

  /// Reverse resolution success rate
  double get reverseSuccessRate {
    if (totalReverseResolutions == 0) return 0.0;
    return successfulReverseResolutions / totalReverseResolutions;
  }

  /// Record fetch success rate
  double get recordFetchSuccessRate {
    if (totalRecordFetches == 0) return 0.0;
    return successfulRecordFetches / totalRecordFetches;
  }

  /// Get most used resolver
  String? get mostUsedResolver {
    if (resolverStats.isEmpty) return null;

    return resolverStats.entries
        .reduce((a, b) => a.value.totalCalls > b.value.totalCalls ? a : b)
        .key;
  }

  /// Get fastest resolver
  String? get fastestResolver {
    if (resolverStats.isEmpty) return null;

    final successful = resolverStats.entries
        .where((e) => e.value.successfulCalls > 0)
        .toList();

    if (successful.isEmpty) return null;

    return successful
        .reduce((a, b) =>
            a.value.averageResponseTime < b.value.averageResponseTime ? a : b)
        .key;
  }

  @override
  String toString() {
    return 'AnalyticsStats{\n'
        '  totalResolutions: $totalResolutions,\n'
        '  successRate: ${(successRate * 100).toStringAsFixed(2)}%,\n'
        '  cacheHitRate: ${(cacheHitRate * 100).toStringAsFixed(2)}%,\n'
        '  avgResponseTime: ${averageResolutionTime.toStringAsFixed(2)}ms,\n'
        '  p95ResponseTime: ${p95ResolutionTime.toStringAsFixed(2)}ms,\n'
        '  mostUsedResolver: $mostUsedResolver,\n'
        '  fastestResolver: $fastestResolver\n'
        '}';
  }
}

/// Per-resolver statistics
class _ResolverStats {
  final String name;
  int totalCalls = 0;
  int successfulCalls = 0;
  int failedCalls = 0;
  final List<int> responseTimes = [];

  _ResolverStats(this.name);

  void recordSuccess(int durationMs) {
    totalCalls++;
    successfulCalls++;
    responseTimes.add(durationMs);

    // Keep only recent samples
    if (responseTimes.length > 100) {
      responseTimes.removeAt(0);
    }
  }

  void recordFailure() {
    totalCalls++;
    failedCalls++;
  }

  double get successRate {
    if (totalCalls == 0) return 0.0;
    return successfulCalls / totalCalls;
  }

  double get averageResponseTime {
    if (responseTimes.isEmpty) return 0.0;
    return responseTimes.reduce((a, b) => a + b) / responseTimes.length;
  }

  @override
  String toString() {
    return '$name: ${(successRate * 100).toStringAsFixed(1)}% success, '
        '${averageResponseTime.toStringAsFixed(1)}ms avg';
  }
}
