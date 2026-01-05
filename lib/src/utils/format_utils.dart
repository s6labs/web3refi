import 'package:intl/intl.dart';

/// Utilities for formatting blockchain values for display.
///
/// Handles formatting of:
/// - Token amounts with proper decimals
/// - Currency values (USD, EUR, etc.)
/// - Gas prices (gwei, wei)
/// - Large numbers (compact notation)
/// - Dates and timestamps
/// - Relative time ("5 minutes ago")
///
/// Example:
/// ```dart
/// // Format token amount
/// FormatUtils.formatTokenAmount(BigInt.parse('1000000000000000000'), 18);
/// // '1.0'
///
/// // Format with symbol
/// FormatUtils.formatTokenWithSymbol(balance, 18, 'ETH');
/// // '1.5 ETH'
///
/// // Format USD value
/// FormatUtils.formatCurrency(1234.56);
/// // '$1,234.56'
///
/// // Relative time
/// FormatUtils.timeAgo(DateTime.now().subtract(Duration(minutes: 5)));
/// // '5 minutes ago'
/// ```
abstract class FormatUtils {
  FormatUtils._();

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTANTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Wei per Ether (10^18).
  static final BigInt weiPerEther = BigInt.from(10).pow(18);

  /// Wei per Gwei (10^9).
  static final BigInt weiPerGwei = BigInt.from(10).pow(9);

  /// Common decimal places for different tokens.
  static const int ethDecimals = 18;
  static const int usdcDecimals = 6;
  static const int btcDecimals = 8;
  static const int solDecimals = 9;

  // ══════════════════════════════════════════════════════════════════════════
  // TOKEN AMOUNTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a raw token amount with the given decimals.
  ///
  /// [amount] is the raw amount (e.g., in wei for ETH).
  /// [decimals] is the number of decimal places for the token.
  /// [displayDecimals] is how many decimals to show (default: auto).
  /// [trimTrailingZeros] removes unnecessary trailing zeros.
  ///
  /// Example:
  /// ```dart
  /// // 1 ETH in wei
  /// FormatUtils.formatTokenAmount(
  ///   BigInt.parse('1000000000000000000'),
  ///   18,
  /// ); // '1.0'
  ///
  /// // 100.50 USDC
  /// FormatUtils.formatTokenAmount(
  ///   BigInt.from(100500000),
  ///   6,
  /// ); // '100.5'
  /// ```
  static String formatTokenAmount(
    BigInt amount,
    int decimals, {
    int? displayDecimals,
    bool trimTrailingZeros = true,
    bool useGrouping = false,
  }) {
    if (amount == BigInt.zero) return '0';

    final isNegative = amount.isNegative;
    final absAmount = amount.abs();

    final divisor = BigInt.from(10).pow(decimals);
    final wholePart = absAmount ~/ divisor;
    final fractionPart = absAmount % divisor;

    // Determine display decimals
    final showDecimals = displayDecimals ?? _autoDecimals(decimals);

    // Format whole part
    String wholeStr = wholePart.toString();
    if (useGrouping) {
      wholeStr = _addThousandsSeparator(wholeStr);
    }

    // Format fraction part
    String fractionStr = fractionPart.toString().padLeft(decimals, '0');
    if (showDecimals < decimals) {
      fractionStr = fractionStr.substring(0, showDecimals);
    }

    // Trim trailing zeros if requested
    if (trimTrailingZeros) {
      fractionStr = fractionStr.replaceAll(RegExp(r'0+$'), '');
    }

    // Build result
    final prefix = isNegative ? '-' : '';
    if (fractionStr.isEmpty) {
      return '$prefix$wholeStr';
    }
    return '$prefix$wholeStr.$fractionStr';
  }

  /// Formats a token amount with its symbol.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatTokenWithSymbol(balance, 18, 'ETH');
  /// // '1.5 ETH'
  /// ```
  static String formatTokenWithSymbol(
    BigInt amount,
    int decimals,
    String symbol, {
    int? displayDecimals,
    bool symbolFirst = false,
  }) {
    final formatted = formatTokenAmount(
      amount,
      decimals,
      displayDecimals: displayDecimals,
    );

    if (symbolFirst) {
      return '$symbol $formatted';
    }
    return '$formatted $symbol';
  }

  /// Parses a human-readable amount to raw token units.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.parseTokenAmount('1.5', 18);
  /// // BigInt: 1500000000000000000
  /// ```
  static BigInt parseTokenAmount(String amount, int decimals) {
    if (amount.isEmpty) return BigInt.zero;

    // Handle negative numbers
    final isNegative = amount.startsWith('-');
    var cleanAmount = isNegative ? amount.substring(1) : amount;

    // Remove commas and spaces
    cleanAmount = cleanAmount.replaceAll(',', '').replaceAll(' ', '');

    final parts = cleanAmount.split('.');
    final wholePart = parts[0].isEmpty ? BigInt.zero : BigInt.parse(parts[0]);

    BigInt fractionPart = BigInt.zero;
    if (parts.length > 1) {
      var fractionStr = parts[1];
      if (fractionStr.length > decimals) {
        fractionStr = fractionStr.substring(0, decimals);
      }
      fractionStr = fractionStr.padRight(decimals, '0');
      fractionPart = BigInt.parse(fractionStr);
    }

    final multiplier = BigInt.from(10).pow(decimals);
    var result = wholePart * multiplier + fractionPart;

    if (isNegative) {
      result = -result;
    }

    return result;
  }

  /// Formats a compact token amount for display.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatCompactToken(BigInt.from(1500000), 6);
  /// // '1.5M'
  /// ```
  static String formatCompactToken(
    BigInt amount,
    int decimals, {
    String? symbol,
  }) {
    final doubleValue = amount / BigInt.from(10).pow(decimals);
    final compact = formatCompactNumber(doubleValue);

    if (symbol != null) {
      return '$compact $symbol';
    }
    return compact;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CURRENCY (FIAT)
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a value as currency.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatCurrency(1234.56);           // '$1,234.56'
  /// FormatUtils.formatCurrency(1234.56, 'EUR');    // '€1,234.56'
  /// FormatUtils.formatCurrency(1234567.89, 'USD'); // '$1,234,567.89'
  /// ```
  static String formatCurrency(
    double value, {
    String currency = 'USD',
    String? locale,
    int? decimalDigits,
  }) {
    final format = NumberFormat.currency(
      locale: locale,
      symbol: _getCurrencySymbol(currency),
      decimalDigits: decimalDigits ?? 2,
    );
    return format.format(value);
  }

  /// Formats a value as compact currency.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatCompactCurrency(1500000);    // '$1.5M'
  /// FormatUtils.formatCompactCurrency(2500000000); // '$2.5B'
  /// ```
  static String formatCompactCurrency(
    double value, {
    String currency = 'USD',
    String? locale,
  }) {
    final format = NumberFormat.compactCurrency(
      locale: locale,
      symbol: _getCurrencySymbol(currency),
    );
    return format.format(value);
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CNY':
        return '¥';
      case 'KRW':
        return '₩';
      case 'INR':
        return '₹';
      case 'BTC':
        return '₿';
      case 'ETH':
        return 'Ξ';
      default:
        return currency;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAS PRICES
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats gas price from wei to gwei.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatGasPrice(BigInt.from(20000000000)); // '20 Gwei'
  /// ```
  static String formatGasPrice(BigInt weiValue, {bool includeUnit = true}) {
    final gwei = weiValue / weiPerGwei;
    final formatted = gwei.toStringAsFixed(gwei < 1 ? 4 : (gwei < 10 ? 2 : 1));

    // Remove trailing zeros
    var result = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (result.isEmpty || result == '-') result = '0';

    if (includeUnit) {
      return '$result Gwei';
    }
    return result;
  }

  /// Formats wei to ETH with appropriate precision.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatWei(BigInt.parse('1500000000000000000')); // '1.5 ETH'
  /// ```
  static String formatWei(BigInt weiValue, {String symbol = 'ETH'}) {
    return formatTokenWithSymbol(weiValue, 18, symbol);
  }

  /// Parses a gwei string to wei.
  static BigInt parseGwei(String gwei) {
    final value = double.parse(gwei);
    return BigInt.from(value * 1e9);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NUMBERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a number with thousand separators.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatNumber(1234567.89); // '1,234,567.89'
  /// ```
  static String formatNumber(
    num value, {
    int? decimalDigits,
    String? locale,
  }) {
    final format = NumberFormat.decimalPattern(locale);
    if (decimalDigits != null) {
      format.minimumFractionDigits = decimalDigits;
      format.maximumFractionDigits = decimalDigits;
    }
    return format.format(value);
  }

  /// Formats a number in compact notation.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatCompactNumber(1500);     // '1.5K'
  /// FormatUtils.formatCompactNumber(1500000);  // '1.5M'
  /// FormatUtils.formatCompactNumber(1500000000); // '1.5B'
  /// ```
  static String formatCompactNumber(num value, {String? locale}) {
    final format = NumberFormat.compact(locale: locale);
    return format.format(value);
  }

  /// Formats a percentage.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatPercent(0.1234);        // '12.34%'
  /// FormatUtils.formatPercent(0.1234, decimals: 1); // '12.3%'
  /// FormatUtils.formatPercent(-0.05);         // '-5%'
  /// ```
  static String formatPercent(
    double value, {
    int decimals = 2,
    bool includeSign = false,
  }) {
    final percent = value * 100;
    final formatted = percent.toStringAsFixed(decimals);

    // Remove trailing zeros after decimal
    var result = formatted.replaceAll(RegExp(r'\.?0+$'), '');
    if (result.isEmpty || result == '-') result = '0';

    if (includeSign && value > 0) {
      return '+$result%';
    }
    return '$result%';
  }

  /// Formats a BigInt with thousand separators.
  static String formatBigInt(BigInt value) {
    return _addThousandsSeparator(value.toString());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATES & TIME
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a DateTime to a standard date string.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatDate(DateTime.now()); // 'Jan 5, 2025'
  /// ```
  static String formatDate(DateTime date, {String? pattern, String? locale}) {
    final format = DateFormat(pattern ?? 'MMM d, yyyy', locale);
    return format.format(date);
  }

  /// Formats a DateTime to a date and time string.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatDateTime(DateTime.now()); // 'Jan 5, 2025 10:30 AM'
  /// ```
  static String formatDateTime(DateTime date, {String? pattern, String? locale}) {
    final format = DateFormat(pattern ?? 'MMM d, yyyy h:mm a', locale);
    return format.format(date);
  }

  /// Formats a DateTime to a time string.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatTime(DateTime.now()); // '10:30 AM'
  /// ```
  static String formatTime(DateTime date, {String? pattern, String? locale}) {
    final format = DateFormat(pattern ?? 'h:mm a', locale);
    return format.format(date);
  }

  /// Formats a DateTime as relative time ("5 minutes ago").
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.timeAgo(DateTime.now().subtract(Duration(minutes: 5)));
  /// // '5 minutes ago'
  ///
  /// FormatUtils.timeAgo(DateTime.now().subtract(Duration(days: 2)));
  /// // '2 days ago'
  /// ```
  static String timeAgo(DateTime date, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative) {
      return _timeFromNow(difference.abs());
    }

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${_pluralize(mins, 'minute')} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${_pluralize(hours, 'hour')} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${_pluralize(days, 'day')} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${_pluralize(weeks, 'week')} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${_pluralize(months, 'month')} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${_pluralize(years, 'year')} ago';
    }
  }

  static String _timeFromNow(Duration difference) {
    if (difference.inSeconds < 60) {
      return 'in a moment';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return 'in $mins ${_pluralize(mins, 'minute')}';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return 'in $hours ${_pluralize(hours, 'hour')}';
    } else {
      final days = difference.inDays;
      return 'in $days ${_pluralize(days, 'day')}';
    }
  }

  /// Formats a Unix timestamp (seconds) to DateTime string.
  static String formatTimestamp(int timestamp, {String? pattern}) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return formatDateTime(date, pattern: pattern);
  }

  /// Formats a duration to a human-readable string.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatDuration(Duration(hours: 2, minutes: 30));
  /// // '2h 30m'
  /// ```
  static String formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}s';
    } else if (duration.inMinutes < 60) {
      final secs = duration.inSeconds % 60;
      if (secs == 0) {
        return '${duration.inMinutes}m';
      }
      return '${duration.inMinutes}m ${secs}s';
    } else if (duration.inHours < 24) {
      final mins = duration.inMinutes % 60;
      if (mins == 0) {
        return '${duration.inHours}h';
      }
      return '${duration.inHours}h ${mins}m';
    } else {
      final hours = duration.inHours % 24;
      if (hours == 0) {
        return '${duration.inDays}d';
      }
      return '${duration.inDays}d ${hours}h';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOCKCHAIN SPECIFIC
  // ══════════════════════════════════════════════════════════════════════════

  /// Formats a block number with thousand separators.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatBlockNumber(18500000); // '#18,500,000'
  /// ```
  static String formatBlockNumber(int blockNumber) {
    return '#${_addThousandsSeparator(blockNumber.toString())}';
  }

  /// Formats a transaction hash for display.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatTxHash('0x1234567890abcdef...');
  /// // '0x1234...cdef'
  /// ```
  static String formatTxHash(
    String hash, {
    int prefixLength = 6,
    int suffixLength = 4,
  }) {
    if (hash.length <= prefixLength + suffixLength + 2) {
      return hash;
    }
    return '${hash.substring(0, prefixLength)}...${hash.substring(hash.length - suffixLength)}';
  }

  /// Formats bytes to human-readable size.
  ///
  /// Example:
  /// ```dart
  /// FormatUtils.formatBytes(1536); // '1.5 KB'
  /// FormatUtils.formatBytes(1048576); // '1 MB'
  /// ```
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  static int _autoDecimals(int tokenDecimals) {
    if (tokenDecimals <= 6) return tokenDecimals;
    if (tokenDecimals <= 8) return 6;
    return 4; // For 18 decimal tokens, show 4 by default
  }

  static String _addThousandsSeparator(String number) {
    final buffer = StringBuffer();
    final chars = number.split('').reversed.toList();

    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 3 == 0 && chars[i] != '-') {
        buffer.write(',');
      }
      buffer.write(chars[i]);
    }

    return buffer.toString().split('').reversed.join();
  }

  static String _pluralize(int count, String word) {
    return count == 1 ? word : '${word}s';
  }
}

/// Extension methods for BigInt formatting.
extension BigIntFormatExtension on BigInt {
  /// Formats this BigInt as a token amount.
  String formatAsToken(int decimals, {String? symbol}) {
    if (symbol != null) {
      return FormatUtils.formatTokenWithSymbol(this, decimals, symbol);
    }
    return FormatUtils.formatTokenAmount(this, decimals);
  }

  /// Formats this BigInt as wei to ETH.
  String formatAsEth() => FormatUtils.formatWei(this);

  /// Formats this BigInt as gas price in gwei.
  String formatAsGwei() => FormatUtils.formatGasPrice(this);
}

/// Extension methods for DateTime formatting.
extension DateTimeFormatExtension on DateTime {
  /// Formats this DateTime as relative time.
  String get timeAgo => FormatUtils.timeAgo(this);

  /// Formats this DateTime to a date string.
  String get formattedDate => FormatUtils.formatDate(this);

  /// Formats this DateTime to a date and time string.
  String get formattedDateTime => FormatUtils.formatDateTime(this);
}

/// Extension methods for num formatting.
extension NumFormatExtension on num {
  /// Formats this number with thousand separators.
  String get formatted => FormatUtils.formatNumber(this);

  /// Formats this number in compact notation.
  String get compact => FormatUtils.formatCompactNumber(this);

  /// Formats this number as a percentage.
  String formatAsPercent({int decimals = 2}) =>
      FormatUtils.formatPercent(toDouble(), decimals: decimals);

  /// Formats this number as currency.
  String formatAsCurrency({String currency = 'USD'}) =>
      FormatUtils.formatCurrency(toDouble(), currency: currency);
}
