/// Base exception class for all web3refi errors.
///
/// All specific exceptions in the library extend this class, allowing you to:
/// 1. Catch all web3refi errors with a single catch block
/// 2. Access consistent error information (message, code, cause)
/// 3. Get user-friendly error messages for UI display
///
/// ## Exception Hierarchy
///
/// ```
/// Web3Exception (base)
/// ├── WalletException      - Wallet connection & signing errors
/// ├── RpcException         - Network & RPC communication errors
/// ├── TransactionException - Transaction-specific errors
/// ├── ContractException    - Smart contract interaction errors
/// └── MessagingException   - XMTP & Mailchain errors
/// ```
///
/// ## Usage Example
///
/// ```dart
/// try {
///   await Web3Refi.instance.connect();
///   await token.transfer(to: recipient, amount: amount);
/// } on WalletException catch (e) {
///   // Handle wallet-specific errors
///   print('Wallet error: ${e.toUserMessage()}');
/// } on TransactionException catch (e) {
///   // Handle transaction-specific errors
///   print('Transaction failed: ${e.toUserMessage()}');
/// } on Web3Exception catch (e) {
///   // Catch-all for any web3refi error
///   print('Error [${e.code}]: ${e.message}');
/// }
/// ```
///
/// ## Creating Custom Exceptions
///
/// ```dart
/// class MyCustomException extends Web3Exception {
///   const MyCustomException({
///     required super.message,
///     required super.code,
///     super.cause,
///   });
/// }
/// ```
library;

/// Severity level of an error.
///
/// Used to categorize errors by their impact and urgency.
enum ErrorSeverity {
  /// Informational message, not an actual error.
  info,

  /// Warning that doesn't prevent operation but should be addressed.
  warning,

  /// Error that prevents the operation from completing.
  error,

  /// Critical error that may affect system stability.
  critical,
}

/// Base exception for all web3refi errors.
///
/// Provides a consistent interface for error handling across the library.
class Web3Exception implements Exception {
  /// Human-readable error message describing what went wrong.
  ///
  /// This message is intended for developers and logging.
  /// For user-facing messages, use [toUserMessage].
  final String message;

  /// Machine-readable error code for programmatic handling.
  ///
  /// Error codes follow a consistent naming convention:
  /// - `snake_case` format
  /// - Domain-prefixed when needed (e.g., `wallet_not_connected`)
  ///
  /// Common codes include:
  /// - `user_rejected` - User cancelled an action
  /// - `not_connected` - No wallet connected
  /// - `network_error` - Network communication failed
  /// - `timeout` - Operation timed out
  /// - `invalid_parameter` - Invalid input provided
  final String code;

  /// The original error that caused this exception, if any.
  ///
  /// Useful for debugging and logging the root cause.
  final Object? cause;

  /// Stack trace from the original error.
  ///
  /// Preserved when wrapping lower-level exceptions.
  final StackTrace? stackTrace;

  /// Optional additional data related to the error.
  ///
  /// Can contain context-specific information like:
  /// - Transaction hash for transaction errors
  /// - Contract address for contract errors
  /// - Chain ID for network errors
  final Map<String, dynamic>? data;

  /// Severity level of the error.
  ///
  /// Used to categorize errors by impact for logging and handling.
  final ErrorSeverity? severity;

  /// Additional context information about the error.
  ///
  /// Contains structured data that helps debug or display the error,
  /// such as parameter values, addresses, or amounts involved.
  final Map<String, dynamic>? context;

  /// Creates a new Web3Exception.
  ///
  /// Parameters:
  /// - [message]: Human-readable error description
  /// - [code]: Machine-readable error code
  /// - [cause]: Original exception that caused this error
  /// - [stackTrace]: Stack trace from the original error
  /// - [data]: Additional context data
  /// - [severity]: Error severity level
  /// - [context]: Structured context information
  const Web3Exception({
    required this.message,
    required this.code,
    this.cause,
    this.stackTrace,
    this.data,
    this.severity,
    this.context,
  });

  /// Creates a generic web3refi exception.
  factory Web3Exception.generic(String message, [Object? cause]) {
    return Web3Exception(
      message: message,
      code: 'web3_error',
      cause: cause,
    );
  }

  /// Creates an exception for invalid parameters.
  factory Web3Exception.invalidParameter(String paramName, [String? details]) {
    return Web3Exception(
      message: details ?? 'Invalid parameter: $paramName',
      code: 'invalid_parameter',
      data: {'parameter': paramName},
    );
  }

  /// Creates an exception for unsupported operations.
  factory Web3Exception.unsupported(String operation, [String? reason]) {
    return Web3Exception(
      message: reason ?? 'Operation not supported: $operation',
      code: 'unsupported_operation',
      data: {'operation': operation},
    );
  }

  /// Creates an exception for initialization errors.
  factory Web3Exception.notInitialized([String? component]) {
    final target = component ?? 'Web3Refi';
    return Web3Exception(
      message: '$target not initialized. Call initialize() first.',
      code: 'not_initialized',
      data: {'component': target},
    );
  }

  /// Creates an exception for configuration errors.
  factory Web3Exception.configuration(String message) {
    return Web3Exception(
      message: message,
      code: 'configuration_error',
    );
  }

  @override
  String toString() => 'Web3Exception($code): $message';

  /// Creates a user-friendly error message suitable for UI display.
  ///
  /// Override in subclasses to provide domain-specific user messages.
  /// These messages should be:
  /// - Non-technical
  /// - Actionable when possible
  /// - Localization-ready
  String toUserMessage() {
    switch (code) {
      case 'not_initialized':
        return 'The app is not ready yet. Please restart and try again.';
      case 'invalid_parameter':
        return 'Invalid input provided. Please check and try again.';
      case 'unsupported_operation':
        return 'This action is not supported.';
      case 'configuration_error':
        return 'There was a configuration problem. Please contact support.';
      default:
        return message;
    }
  }

  /// Converts the exception to a JSON-serializable map.
  ///
  /// Useful for logging and error reporting.
  Map<String, dynamic> toJson() => {
        'type': runtimeType.toString(),
        'code': code,
        'message': message,
        if (data != null) 'data': data,
        if (cause != null) 'cause': cause.toString(),
      };

  /// Creates an exception from a JSON map.
  factory Web3Exception.fromJson(Map<String, dynamic> json) {
    return Web3Exception(
      message: json['message'] as String? ?? 'Unknown error',
      code: json['code'] as String? ?? 'unknown',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

/// Mixin for exceptions that can be retried.
///
/// Implement this on exceptions where retrying the operation
/// might succeed (e.g., network timeouts, rate limits).
mixin RetryableException on Web3Exception {
  /// Whether this error is retryable.
  bool get isRetryable => true;

  /// Suggested delay before retrying.
  Duration get retryDelay => const Duration(seconds: 2);

  /// Maximum number of retry attempts.
  int get maxRetries => 3;
}

/// Mixin for exceptions with associated transactions.
mixin TransactionRelated on Web3Exception {
  /// The transaction hash associated with this error, if any.
  String? get txHash => data?['txHash'] as String?;

  /// The chain ID where the transaction occurred.
  int? get chainId => data?['chainId'] as int?;
}
