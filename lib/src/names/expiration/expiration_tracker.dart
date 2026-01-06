import 'dart:async';
import 'package:web3refi/src/names/registry/registration_controller.dart';

/// Expiration tracking and notification system for owned names
///
/// Monitors name expirations and provides notifications when names
/// are approaching expiration.
///
/// ## Features
///
/// - Automatic expiration checking
/// - Configurable notification thresholds
/// - Grace period tracking
/// - Batch expiration checking
/// - Event-based notifications
///
/// ## Usage
///
/// ```dart
/// final tracker = ExpirationTracker(
///   controller: registrationController,
/// );
///
/// // Add names to track
/// tracker.trackName('alice.xdc');
/// tracker.trackName('bob.xdc');
///
/// // Listen for expiration events
/// tracker.onExpiring.listen((event) {
///   print('${event.name} expires in ${event.daysUntilExpiration} days');
/// });
///
/// // Start tracking
/// await tracker.start();
/// ```
class ExpirationTracker {
  final RegistrationController _controller;
  final Duration _checkInterval;
  final List<Duration> _notificationThresholds;

  final Set<String> _trackedNames = {};
  final Map<String, DateTime> _expirations = {};
  final Map<String, Set<Duration>> _notifiedThresholds = {};

  Timer? _checkTimer;
  bool _isRunning = false;

  // Event streams
  final _expiringController = StreamController<ExpirationEvent>.broadcast();
  final _expiredController = StreamController<ExpirationEvent>.broadcast();
  final _renewedController = StreamController<String>.broadcast();

  /// Stream of names approaching expiration
  Stream<ExpirationEvent> get onExpiring => _expiringController.stream;

  /// Stream of expired names
  Stream<ExpirationEvent> get onExpired => _expiredController.stream;

  /// Stream of renewed names
  Stream<String> get onRenewed => _renewedController.stream;

  ExpirationTracker({
    required RegistrationController controller,
    Duration checkInterval = const Duration(hours: 6),
    List<Duration>? notificationThresholds,
  })  : _controller = controller,
        _checkInterval = checkInterval,
        _notificationThresholds = notificationThresholds ??
            [
              const Duration(days: 30),
              const Duration(days: 14),
              const Duration(days: 7),
              const Duration(days: 3),
              const Duration(days: 1),
            ];

  /// Start tracking expirations
  Future<void> start() async {
    if (_isRunning) return;

    _isRunning = true;

    // Initial check
    await _checkExpirations();

    // Start periodic checks
    _checkTimer = Timer.periodic(_checkInterval, (_) => _checkExpirations());
  }

  /// Stop tracking
  void stop() {
    _isRunning = false;
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Add a name to track
  Future<void> trackName(String name) async {
    _trackedNames.add(name);
    await _updateExpiration(name);
  }

  /// Remove a name from tracking
  void untrackName(String name) {
    _trackedNames.remove(name);
    _expirations.remove(name);
    _notifiedThresholds.remove(name);
  }

  /// Track multiple names
  Future<void> trackNames(List<String> names) async {
    for (final name in names) {
      await trackName(name);
    }
  }

  /// Get all tracked names
  List<String> getTrackedNames() {
    return List.from(_trackedNames);
  }

  /// Get expiration info for a name
  ExpirationInfo? getExpirationInfo(String name) {
    final expiry = _expirations[name];
    if (expiry == null) return null;

    final now = DateTime.now();
    final timeUntilExpiration = expiry.difference(now);
    final daysUntilExpiration = timeUntilExpiration.inDays;

    return ExpirationInfo(
      name: name,
      expiry: expiry,
      daysUntilExpiration: daysUntilExpiration,
      isExpired: expiry.isBefore(now),
      isExpiringSoon: daysUntilExpiration <= 30 && daysUntilExpiration > 0,
    );
  }

  /// Get all names expiring within a duration
  List<ExpirationInfo> getNamesExpiringWithin(Duration duration) {
    final threshold = DateTime.now().add(duration);
    final expiring = <ExpirationInfo>[];

    for (final name in _trackedNames) {
      final info = getExpirationInfo(name);
      if (info != null &&
          info.expiry.isBefore(threshold) &&
          !info.isExpired) {
        expiring.add(info);
      }
    }

    // Sort by expiration date (soonest first)
    expiring.sort((a, b) => a.expiry.compareTo(b.expiry));

    return expiring;
  }

  /// Get all expired names
  List<ExpirationInfo> getExpiredNames() {
    final expired = <ExpirationInfo>[];

    for (final name in _trackedNames) {
      final info = getExpirationInfo(name);
      if (info != null && info.isExpired) {
        expired.add(info);
      }
    }

    return expired;
  }

  /// Mark name as renewed
  Future<void> markRenewed(String name) async {
    await _updateExpiration(name);
    _notifiedThresholds.remove(name);
    _renewedController.add(name);
  }

  /// Update expiration for a name
  Future<void> _updateExpiration(String name) async {
    try {
      final expiry = await _controller.getExpiry(name);
      if (expiry != null) {
        _expirations[name] = expiry;
      }
    } catch (e) {
      // Handle error
    }
  }

  /// Check all tracked names for expirations
  Future<void> _checkExpirations() async {
    if (_trackedNames.isEmpty) return;

    // Update all expirations
    for (final name in _trackedNames) {
      await _updateExpiration(name);
    }

    // Check for notifications
    final now = DateTime.now();

    for (final name in _trackedNames) {
      final expiry = _expirations[name];
      if (expiry == null) continue;

      final timeUntilExpiration = expiry.difference(now);

      // Check if expired
      if (expiry.isBefore(now)) {
        _expiredController.add(ExpirationEvent(
          name: name,
          expiry: expiry,
          daysUntilExpiration: timeUntilExpiration.inDays,
        ));
        continue;
      }

      // Check notification thresholds
      _notifiedThresholds[name] ??= {};

      for (final threshold in _notificationThresholds) {
        // Skip if already notified for this threshold
        if (_notifiedThresholds[name]!.contains(threshold)) {
          continue;
        }

        // Check if within threshold
        if (timeUntilExpiration <= threshold) {
          _notifiedThresholds[name]!.add(threshold);
          _expiringController.add(ExpirationEvent(
            name: name,
            expiry: expiry,
            daysUntilExpiration: timeUntilExpiration.inDays,
          ));
        }
      }
    }
  }

  /// Dispose and cleanup
  void dispose() {
    stop();
    _expiringController.close();
    _expiredController.close();
    _renewedController.close();
  }
}

/// Expiration event
class ExpirationEvent {
  final String name;
  final DateTime expiry;
  final int daysUntilExpiration;

  ExpirationEvent({
    required this.name,
    required this.expiry,
    required this.daysUntilExpiration,
  });

  @override
  String toString() {
    return 'ExpirationEvent{name: $name, expiresIn: $daysUntilExpiration days}';
  }
}

/// Expiration info for a name
class ExpirationInfo {
  final String name;
  final DateTime expiry;
  final int daysUntilExpiration;
  final bool isExpired;
  final bool isExpiringSoon;

  ExpirationInfo({
    required this.name,
    required this.expiry,
    required this.daysUntilExpiration,
    required this.isExpired,
    required this.isExpiringSoon,
  });

  /// Get urgency level (0-3)
  ///
  /// - 0: Not urgent (> 30 days)
  /// - 1: Low urgency (15-30 days)
  /// - 2: Medium urgency (7-14 days)
  /// - 3: High urgency (< 7 days)
  int get urgency {
    if (isExpired) return 3;
    if (daysUntilExpiration <= 7) return 3;
    if (daysUntilExpiration <= 14) return 2;
    if (daysUntilExpiration <= 30) return 1;
    return 0;
  }

  /// Get urgency label
  String get urgencyLabel {
    switch (urgency) {
      case 0:
        return 'None';
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  /// Get formatted time until expiration
  String get formattedTimeUntilExpiration {
    if (isExpired) {
      return 'Expired ${daysUntilExpiration.abs()} days ago';
    }

    if (daysUntilExpiration == 0) {
      return 'Expires today';
    }

    if (daysUntilExpiration == 1) {
      return 'Expires tomorrow';
    }

    return 'Expires in $daysUntilExpiration days';
  }

  @override
  String toString() {
    return 'ExpirationInfo{name: $name, $formattedTimeUntilExpiration}';
  }
}
