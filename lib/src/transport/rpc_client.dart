import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3refi/src/core/chain.dart';
import 'package:web3refi/src/errors/rpc_exception.dart';

/// JSON-RPC client for blockchain communication.
///
/// Handles all low-level RPC calls to blockchain nodes with:
/// - Automatic failover to backup endpoints
/// - Request caching
/// - Retry logic
/// - Error normalization
///
/// Example:
/// ```dart
/// final client = RpcClient(chain: Chains.polygon);
/// final blockNumber = await client.getBlockNumber();
/// final balance = await client.getBalance('0x123...');
/// ```
class RpcClient {
  /// The blockchain network this client connects to.
  final Chain chain;

  /// HTTP client for making requests.
  final http.Client _httpClient;

  /// Request timeout duration.
  final Duration timeout;

  /// Enable debug logging.
  final bool enableLogging;

  /// Current RPC endpoint index (for failover).
  int _currentEndpointIndex = 0;

  /// Request ID counter for JSON-RPC.
  int _requestId = 0;

  /// Cache for recent responses.
  final Map<String, _CachedResponse> _cache = {};

  /// Cache TTL for different methods.
  static const _cacheTTL = {
    'eth_chainId': Duration(hours: 1),
    'eth_blockNumber': Duration(seconds: 5),
    'eth_gasPrice': Duration(seconds: 10),
    'eth_getBalance': Duration(seconds: 15),
  };

  RpcClient({
    required this.chain,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
  }) : _httpClient = httpClient ?? http.Client();

  /// Get all available RPC endpoints.
  List<String> get _endpoints => [chain.rpcUrl, ...chain.backupRpcUrls];

  /// Get the current active endpoint.
  String get _currentEndpoint => _endpoints[_currentEndpointIndex];

  /// Make a JSON-RPC call.
  ///
  /// Automatically handles:
  /// - Request formatting
  /// - Response parsing
  /// - Error handling
  /// - Endpoint failover
  ///
  /// Example:
  /// ```dart
  /// final result = await client.call('eth_getBalance', ['0x123...', 'latest']);
  /// ```
  Future<dynamic> call(
    String method,
    List<dynamic> params, {
    bool useCache = true,
  }) async {
    // Check cache first
    final cacheKey = _getCacheKey(method, params);
    if (useCache) {
      final cached = _getFromCache(cacheKey, method);
      if (cached != null) {
        _log('Cache hit for $method');
        return cached;
      }
    }

    // Try each endpoint until one works
    Object? lastError;
    for (var attempt = 0; attempt < _endpoints.length; attempt++) {
      try {
        final result = await _makeRequest(method, params);
        
        // Cache successful response
        if (useCache && _cacheTTL.containsKey(method)) {
          _addToCache(cacheKey, result, _cacheTTL[method]!);
        }
        
        return result;
      } catch (e) {
        lastError = e;
        _log('Request failed on $_currentEndpoint: $e');
        
        // Try next endpoint
        if (attempt < _endpoints.length - 1) {
          _currentEndpointIndex = (_currentEndpointIndex + 1) % _endpoints.length;
          _log('Switching to $_currentEndpoint');
        }
      }
    }

    // All endpoints failed
    throw RpcException.networkError(lastError);
  }

  /// Make the actual HTTP request.
  Future<dynamic> _makeRequest(String method, List<dynamic> params) async {
    final requestId = ++_requestId;
    final body = jsonEncode({
      'jsonrpc': '2.0',
      'method': method,
      'params': params,
      'id': requestId,
    });

    _log('RPC Request: $method $params');

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_currentEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);

      if (response.statusCode == 429) {
        throw RpcException.rateLimited();
      }

      if (response.statusCode != 200) {
        throw RpcException(
          message: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
          code: 'http_error',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // Check for JSON-RPC error
      if (json.containsKey('error')) {
        final error = json['error'] as Map<String, dynamic>;
        final code = error['code'] as int? ?? -1;
        final message = error['message'] as String? ?? 'Unknown error';
        
        _log('RPC Error: $code - $message');
        throw RpcException.fromRpcError(code, message);
      }

      final result = json['result'];
      _log('RPC Response: ${result.toString().substring(0, 100.clamp(0, result.toString().length))}...');
      
      return result;
    } on TimeoutException {
      throw RpcException.timeout(endpoint: _currentEndpoint);
    } on http.ClientException catch (e) {
      throw RpcException.networkError(e);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVENIENCE METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get the current block number.
  Future<int> getBlockNumber() async {
    final result = await call('eth_blockNumber', []);
    return _hexToInt(result as String);
  }

  /// Get the chain ID.
  Future<int> getChainId() async {
    final result = await call('eth_chainId', []);
    return _hexToInt(result as String);
  }

  /// Get native currency balance for an address.
  ///
  /// Returns balance in wei as BigInt.
  Future<BigInt> getBalance(String address, {String block = 'latest'}) async {
    final result = await call('eth_getBalance', [address, block]);
    return _hexToBigInt(result as String);
  }

  /// Get current gas price in wei.
  Future<BigInt> getGasPrice() async {
    final result = await call('eth_gasPrice', []);
    return _hexToBigInt(result as String);
  }

  /// Estimate gas for a transaction.
  Future<BigInt> estimateGas(Map<String, String> transaction) async {
    final result = await call('eth_estimateGas', [transaction]);
    return _hexToBigInt(result as String);
  }

  /// Call a smart contract (read-only).
  ///
  /// Can be called with either a transaction map or named parameters:
  /// ```dart
  /// // Using map
  /// await ethCall({'to': address, 'data': data});
  ///
  /// // Using named parameters
  /// await ethCall(to: address, data: data);
  /// ```
  Future<String> ethCall({
    String? to,
    String? data,
    String? from,
    String? value,
    Map<String, String>? transaction,
    String block = 'latest',
  }) async {
    // Build transaction map from named parameters or use provided map
    final tx = transaction ?? <String, String>{
      if (to != null) 'to': to,
      if (data != null) 'data': data,
      if (from != null) 'from': from,
      if (value != null) 'value': value,
    };

    final result = await call('eth_call', [tx, block]);
    return result as String;
  }

  /// Get transaction count (nonce) for an address.
  Future<int> getTransactionCount(String address, {String block = 'latest'}) async {
    final result = await call('eth_getTransactionCount', [address, block]);
    return _hexToInt(result as String);
  }

  /// Send a raw signed transaction.
  Future<String> sendRawTransaction(String signedTx) async {
    final result = await call('eth_sendRawTransaction', [signedTx], useCache: false);
    return result as String;
  }

  /// Get transaction receipt.
  ///
  /// Returns null if transaction is still pending.
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    final result = await call('eth_getTransactionReceipt', [txHash], useCache: false);
    return result as Map<String, dynamic>?;
  }

  /// Get transaction by hash.
  Future<Map<String, dynamic>?> getTransaction(String txHash) async {
    final result = await call('eth_getTransactionByHash', [txHash], useCache: false);
    return result as Map<String, dynamic>?;
  }

  /// Get block by number.
  Future<Map<String, dynamic>?> getBlockByNumber(
    int blockNumber, {
    bool includeTransactions = false,
  }) async {
    final result = await call(
      'eth_getBlockByNumber',
      [_intToHex(blockNumber), includeTransactions],
    );
    return result as Map<String, dynamic>?;
  }

  /// Get logs matching a filter.
  Future<List<Map<String, dynamic>>> getLogs({
    required String address,
    List<String>? topics,
    String fromBlock = 'latest',
    String toBlock = 'latest',
  }) async {
    final result = await call('eth_getLogs', [
      {
        'address': address,
        if (topics != null) 'topics': topics,
        'fromBlock': fromBlock,
        'toBlock': toBlock,
      }
    ], useCache: false);
    
    return (result as List).cast<Map<String, dynamic>>();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  /// Convert hex string to int.
  static int _hexToInt(String hex) {
    return int.parse(hex.substring(2), radix: 16);
  }

  /// Convert hex string to BigInt.
  static BigInt _hexToBigInt(String hex) {
    return BigInt.parse(hex.substring(2), radix: 16);
  }

  /// Convert int to hex string.
  static String _intToHex(int value) {
    return '0x${value.toRadixString(16)}';
  }

  /// Convert BigInt to hex string.
  static String bigIntToHex(BigInt value) {
    return '0x${value.toRadixString(16)}';
  }

  /// Pad address to 32 bytes (for ABI encoding).
  static String padAddress(String address) {
    final clean = address.toLowerCase().replaceFirst('0x', '');
    return clean.padLeft(64, '0');
  }

  /// Pad uint256 to 32 bytes (for ABI encoding).
  static String padUint256(BigInt value) {
    return value.toRadixString(16).padLeft(64, '0');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  String _getCacheKey(String method, List<dynamic> params) {
    return '$method:${jsonEncode(params)}';
  }

  dynamic _getFromCache(String key, String method) {
    final cached = _cache[key];
    if (cached == null) return null;
    
    if (DateTime.now().isAfter(cached.expiresAt)) {
      _cache.remove(key);
      return null;
    }
    
    return cached.value;
  }

  void _addToCache(String key, dynamic value, Duration ttl) {
    _cache[key] = _CachedResponse(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
    
    // Limit cache size
    if (_cache.length > 100) {
      final oldest = _cache.entries.first.key;
      _cache.remove(oldest);
    }
  }

  /// Clear all cached responses.
  void clearCache() {
    _cache.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGGING
  // ══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    if (enableLogging) {
      print('[web3refi:RPC] $message');
    }
  }

  /// Close the HTTP client.
  void dispose() {
    _httpClient.close();
  }
}

/// Cached RPC response.
class _CachedResponse {
  final dynamic value;
  final DateTime expiresAt;

  _CachedResponse({required this.value, required this.expiresAt});
}
