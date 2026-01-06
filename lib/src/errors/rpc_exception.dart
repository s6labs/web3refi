import 'package:web3refi/src/errors/web3_exception.dart';

/// Exception for RPC, network, and blockchain communication errors.
///
/// Thrown when:
/// - Network requests fail or timeout
/// - RPC endpoints return errors
/// - Rate limits are exceeded
/// - Invalid responses are received
/// - Blockchain nodes are unreachable
///
/// ## Common Error Codes
///
/// | Code | Description |
/// |------|-------------|
/// | `network_error` | General network connectivity issue |
/// | `rpc_timeout` | Request timed out |
/// | `rate_limited` | Too many requests (429) |
/// | `invalid_response` | Malformed response from node |
/// | `rpc_error` | JSON-RPC error from node |
/// | `endpoint_unavailable` | RPC endpoint is down |
///
/// ## JSON-RPC Error Codes
///
/// Standard Ethereum JSON-RPC errors:
/// - `-32700`: Parse error
/// - `-32600`: Invalid request
/// - `-32601`: Method not found
/// - `-32602`: Invalid params
/// - `-32603`: Internal error
/// - `-32000` to `-32099`: Server errors
///
/// ## Usage Example
///
/// ```dart
/// try {
///   final balance = await rpcClient.getBalance(address);
/// } on RpcException catch (e) {
///   if (e.isRetryable) {
///     await Future.delayed(e.retryDelay);
///     // Retry the request
///   } else {
///     showError(e.toUserMessage());
///   }
/// }
/// ```
class RpcException extends Web3Exception with RetryableException {
  /// JSON-RPC error code, if this came from an RPC response.
  final int? rpcCode;

  /// HTTP status code, if applicable.
  final int? httpStatusCode;

  /// The RPC endpoint URL that returned the error.
  final String? endpoint;

  /// The RPC method that was called.
  final String? method;

  /// Creates a new RpcException.
  const RpcException({
    required super.message,
    required super.code,
    this.rpcCode,
    this.httpStatusCode,
    this.endpoint,
    this.method,
    super.cause,
    super.stackTrace,
    super.data,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // NETWORK ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// General network connectivity error.
  factory RpcException.networkError([Object? cause]) {
    return RpcException(
      message: 'Network error. Please check your internet connection.',
      code: 'network_error',
      cause: cause,
    );
  }

  /// No internet connection available.
  factory RpcException.noInternet() {
    return const RpcException(
      message: 'No internet connection',
      code: 'no_internet',
    );
  }

  /// DNS resolution failed.
  factory RpcException.dnsError(String host, [Object? cause]) {
    return RpcException(
      message: 'Failed to resolve host: $host',
      code: 'dns_error',
      cause: cause,
      data: {'host': host},
    );
  }

  /// SSL/TLS certificate error.
  factory RpcException.sslError([Object? cause]) {
    return RpcException(
      message: 'SSL certificate error',
      code: 'ssl_error',
      cause: cause,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TIMEOUT ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Request timed out.
  factory RpcException.timeout({String? endpoint, String? method, Duration? timeout}) {
    return RpcException(
      message: 'Request timed out${endpoint != null ? ' for $endpoint' : ''}',
      code: 'rpc_timeout',
      endpoint: endpoint,
      method: method,
      data: {
        if (timeout != null) 'timeoutMs': timeout.inMilliseconds,
      },
    );
  }

  /// Connection timed out (couldn't establish connection).
  factory RpcException.connectionTimeout({String? endpoint}) {
    return RpcException(
      message: 'Connection timed out${endpoint != null ? ' to $endpoint' : ''}',
      code: 'connection_timeout',
      endpoint: endpoint,
    );
  }

  /// Read/receive timed out (connected but response took too long).
  factory RpcException.readTimeout({String? endpoint, String? method}) {
    return RpcException(
      message: 'Read timed out waiting for response',
      code: 'read_timeout',
      endpoint: endpoint,
      method: method,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HTTP ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Rate limited by RPC provider (HTTP 429).
  factory RpcException.rateLimited({String? endpoint, Duration? retryAfter}) {
    return RpcException(
      message: 'Too many requests. Please wait and try again.',
      code: 'rate_limited',
      httpStatusCode: 429,
      endpoint: endpoint,
      data: {
        if (retryAfter != null) 'retryAfterMs': retryAfter.inMilliseconds,
      },
    );
  }

  /// HTTP error response.
  factory RpcException.httpError(int statusCode, {String? message, String? endpoint}) {
    final msg = message ?? _httpStatusMessage(statusCode);
    return RpcException(
      message: msg,
      code: 'http_error',
      httpStatusCode: statusCode,
      endpoint: endpoint,
    );
  }

  /// Server error (5xx).
  factory RpcException.serverError({int? statusCode, String? endpoint, Object? cause}) {
    return RpcException(
      message: 'Server error. Please try again later.',
      code: 'server_error',
      httpStatusCode: statusCode ?? 500,
      endpoint: endpoint,
      cause: cause,
    );
  }

  /// Bad gateway (502) - often means node is syncing or overloaded.
  factory RpcException.badGateway({String? endpoint}) {
    return RpcException(
      message: 'Bad gateway. The node may be syncing or overloaded.',
      code: 'bad_gateway',
      httpStatusCode: 502,
      endpoint: endpoint,
    );
  }

  /// Service unavailable (503).
  factory RpcException.serviceUnavailable({String? endpoint}) {
    return RpcException(
      message: 'Service temporarily unavailable',
      code: 'service_unavailable',
      httpStatusCode: 503,
      endpoint: endpoint,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // JSON-RPC ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Generic JSON-RPC error from the node.
  factory RpcException.fromRpcError(int code, String message, {String? endpoint, String? method}) {
    return RpcException(
      message: message,
      code: 'rpc_error',
      rpcCode: code,
      endpoint: endpoint,
      method: method,
    );
  }

  /// Parse error (-32700) - Invalid JSON.
  factory RpcException.parseError({String? details}) {
    return RpcException(
      message: details ?? 'Invalid JSON received',
      code: 'parse_error',
      rpcCode: -32700,
    );
  }

  /// Invalid request (-32600).
  factory RpcException.invalidRequest({String? details}) {
    return RpcException(
      message: details ?? 'Invalid RPC request',
      code: 'invalid_request',
      rpcCode: -32600,
    );
  }

  /// Method not found (-32601).
  factory RpcException.methodNotFound(String method) {
    return RpcException(
      message: 'RPC method not found: $method',
      code: 'method_not_found',
      rpcCode: -32601,
      method: method,
    );
  }

  /// Invalid params (-32602).
  factory RpcException.invalidParams({String? details, String? method}) {
    return RpcException(
      message: details ?? 'Invalid parameters',
      code: 'invalid_params',
      rpcCode: -32602,
      method: method,
    );
  }

  /// Internal error (-32603).
  factory RpcException.internalError({String? details, String? method}) {
    return RpcException(
      message: details ?? 'Internal JSON-RPC error',
      code: 'internal_error',
      rpcCode: -32603,
      method: method,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESPONSE ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Invalid or malformed response from RPC.
  factory RpcException.invalidResponse(String details, {String? endpoint}) {
    return RpcException(
      message: 'Invalid response from blockchain: $details',
      code: 'invalid_response',
      endpoint: endpoint,
    );
  }

  /// Empty response received.
  factory RpcException.emptyResponse({String? method, String? endpoint}) {
    return RpcException(
      message: 'Empty response received from node',
      code: 'empty_response',
      method: method,
      endpoint: endpoint,
    );
  }

  /// Response missing expected field.
  factory RpcException.missingField(String field, {String? method}) {
    return RpcException(
      message: 'Response missing expected field: $field',
      code: 'missing_field',
      method: method,
      data: {'field': field},
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ENDPOINT ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// RPC endpoint is unavailable.
  factory RpcException.endpointUnavailable(String endpoint, [Object? cause]) {
    return RpcException(
      message: 'RPC endpoint unavailable: $endpoint',
      code: 'endpoint_unavailable',
      endpoint: endpoint,
      cause: cause,
    );
  }

  /// All RPC endpoints failed.
  factory RpcException.allEndpointsFailed(List<String> endpoints) {
    return RpcException(
      message: 'All RPC endpoints failed',
      code: 'all_endpoints_failed',
      data: {'endpoints': endpoints},
    );
  }

  /// Invalid endpoint URL.
  factory RpcException.invalidEndpoint(String endpoint) {
    return RpcException(
      message: 'Invalid RPC endpoint URL: $endpoint',
      code: 'invalid_endpoint',
      endpoint: endpoint,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BLOCKCHAIN-SPECIFIC ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Node is syncing and cannot process requests.
  factory RpcException.nodeSyncing({String? endpoint}) {
    return RpcException(
      message: 'Node is syncing. Please try again later.',
      code: 'node_syncing',
      endpoint: endpoint,
    );
  }

  /// Block not found.
  factory RpcException.blockNotFound(dynamic blockId) {
    return RpcException(
      message: 'Block not found: $blockId',
      code: 'block_not_found',
      data: {'blockId': blockId.toString()},
    );
  }

  /// Transaction not found.
  factory RpcException.transactionNotFound(String txHash) {
    return RpcException(
      message: 'Transaction not found: $txHash',
      code: 'transaction_not_found',
      data: {'txHash': txHash},
    );
  }

  /// Resource not found (generic).
  factory RpcException.resourceNotFound(String resource) {
    return RpcException(
      message: 'Resource not found: $resource',
      code: 'resource_not_found',
      data: {'resource': resource},
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RETRY CONFIGURATION
  // ══════════════════════════════════════════════════════════════════════════

  @override
  bool get isRetryable {
    // Retryable error codes
    if (const [
      'network_error',
      'rpc_timeout',
      'connection_timeout',
      'read_timeout',
      'rate_limited',
      'server_error',
      'bad_gateway',
      'service_unavailable',
      'endpoint_unavailable',
      'node_syncing',
    ].contains(code)) {
      return true;
    }

    // Retryable HTTP status codes
    if (httpStatusCode != null) {
      return const [408, 429, 500, 502, 503, 504].contains(httpStatusCode);
    }

    return false;
  }

  @override
  Duration get retryDelay {
    // Check if we have a specific retry-after value
    final retryAfterMs = data?['retryAfterMs'] as int?;
    if (retryAfterMs != null) {
      return Duration(milliseconds: retryAfterMs);
    }

    // Default delays based on error type
    switch (code) {
      case 'rate_limited':
        return const Duration(seconds: 5);
      case 'server_error':
      case 'bad_gateway':
      case 'service_unavailable':
        return const Duration(seconds: 3);
      case 'node_syncing':
        return const Duration(seconds: 10);
      default:
        return const Duration(seconds: 2);
    }
  }

  @override
  int get maxRetries {
    switch (code) {
      case 'rate_limited':
        return 5;
      case 'node_syncing':
        return 2;
      default:
        return 3;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER MESSAGES
  // ══════════════════════════════════════════════════════════════════════════

  @override
  String toUserMessage() {
    switch (code) {
      case 'network_error':
        return 'Network error. Please check your internet connection.';

      case 'no_internet':
        return 'No internet connection. Please check your network.';

      case 'dns_error':
        return 'Could not reach the server. Please try again.';

      case 'ssl_error':
        return 'Security error. Please try again later.';

      case 'rpc_timeout':
      case 'connection_timeout':
      case 'read_timeout':
        return 'Request timed out. Please try again.';

      case 'rate_limited':
        return 'Too many requests. Please wait a moment and try again.';

      case 'http_error':
      case 'server_error':
      case 'bad_gateway':
      case 'service_unavailable':
        return 'Server error. Please try again later.';

      case 'endpoint_unavailable':
      case 'all_endpoints_failed':
        return 'Service temporarily unavailable. Please try again.';

      case 'invalid_response':
      case 'empty_response':
      case 'missing_field':
        return 'Received invalid data. Please try again.';

      case 'node_syncing':
        return 'The network is syncing. Please try again in a few minutes.';

      case 'block_not_found':
        return 'Block not found on the network.';

      case 'transaction_not_found':
        return 'Transaction not found. It may still be processing.';

      case 'method_not_found':
        return 'This operation is not supported by the current network.';

      case 'invalid_params':
        return 'Invalid request parameters.';

      default:
        return 'Network error. Please try again.';
    }
  }

  @override
  String toString() {
    final parts = ['RpcException($code): $message'];
    if (rpcCode != null) parts.add('rpcCode: $rpcCode');
    if (httpStatusCode != null) parts.add('http: $httpStatusCode');
    if (endpoint != null) parts.add('endpoint: $endpoint');
    return parts.join(', ');
  }

  /// Helper to get HTTP status message.
  static String _httpStatusMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 408:
        return 'Request Timeout';
      case 429:
        return 'Too Many Requests';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      case 504:
        return 'Gateway Timeout';
      default:
        return 'HTTP Error $statusCode';
    }
  }
}

/// Extension for categorizing RPC exceptions.
extension RpcExceptionType on RpcException {
  /// Whether this is a network connectivity error.
  bool get isNetworkError => const [
        'network_error',
        'no_internet',
        'dns_error',
        'ssl_error',
      ].contains(code);

  /// Whether this is a timeout error.
  bool get isTimeout => const [
        'rpc_timeout',
        'connection_timeout',
        'read_timeout',
      ].contains(code);

  /// Whether this is a server-side error.
  bool get isServerError =>
      const ['server_error', 'bad_gateway', 'service_unavailable'].contains(code) ||
      (httpStatusCode != null && httpStatusCode! >= 500);

  /// Whether this is a client-side error.
  bool get isClientError =>
      const ['invalid_request', 'invalid_params', 'invalid_endpoint'].contains(code) ||
      (httpStatusCode != null && httpStatusCode! >= 400 && httpStatusCode! < 500);

  /// Whether we should try a different endpoint.
  bool get shouldTryNextEndpoint => const [
        'endpoint_unavailable',
        'rpc_timeout',
        'connection_timeout',
        'server_error',
        'bad_gateway',
        'service_unavailable',
        'node_syncing',
      ].contains(code);
}
