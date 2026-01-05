import 'dart:async';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';

/// Mock RPC client for testing without network calls.
///
/// Allows setting up predefined responses and tracking calls.
///
/// Example:
/// ```dart
/// final mockRpc = MockRpcClient();
/// mockRpc.whenCall('eth_blockNumber').thenReturn('0x123');
/// mockRpc.whenCall('eth_getBalance').thenReturn('0x1234567890');
///
/// final blockNumber = await mockRpc.getBlockNumber();
/// expect(blockNumber, equals(0x123));
/// expect(mockRpc.callCount('eth_blockNumber'), equals(1));
/// ```
class MockRpcClient implements RpcClient {
  /// Stores mock responses for each method.
  final Map<String, _MockResponse> _responses = {};

  /// Tracks all calls made to this mock.
  final List<MockRpcCall> _calls = [];

  /// Default chain for this mock.
  @override
  final Chain chain;

  /// Default timeout.
  @override
  final Duration timeout;

  /// Enable logging (usually false in tests).
  @override
  final bool enableLogging;

  /// Optional delay to simulate network latency.
  Duration? simulatedDelay;

  /// Whether to fail all calls (for testing error handling).
  bool failAllCalls = false;

  /// Error to throw when failAllCalls is true.
  Exception? failureException;

  MockRpcClient({
    Chain? chain,
    this.timeout = const Duration(seconds: 30),
    this.enableLogging = false,
    this.simulatedDelay,
  }) : chain = chain ?? TestChains.mockEthereum;

  // ══════════════════════════════════════════════════════════════════════════
  // MOCK SETUP
  // ══════════════════════════════════════════════════════════════════════════

  /// Set up a mock response for a method.
  MockResponseBuilder whenCall(String method) {
    return MockResponseBuilder(this, method);
  }

  /// Set up response internally.
  void _setResponse(String method, _MockResponse response) {
    _responses[method] = response;
  }

  /// Clear all mock responses and call history.
  void reset() {
    _responses.clear();
    _calls.clear();
    failAllCalls = false;
    failureException = null;
  }

  /// Set up common ERC20 responses for a token.
  void setupErc20Token({
    required String address,
    String name = 'Mock Token',
    String symbol = 'MOCK',
    int decimals = 18,
    BigInt? totalSupply,
  }) {
    // These will be matched by the 'to' address in eth_call
    whenCall('eth_call').thenAnswer((params) {
      final callData = params[0] as Map<String, dynamic>;
      final data = callData['data'] as String? ?? '';
      
      // balanceOf(address) - 0x70a08231
      if (data.startsWith('0x70a08231')) {
        return mockBalanceResponse(BigInt.from(1000000000000000000));
      }
      // name() - 0x06fdde03
      if (data.startsWith('0x06fdde03')) {
        return mockStringResponse(name);
      }
      // symbol() - 0x95d89b41
      if (data.startsWith('0x95d89b41')) {
        return mockStringResponse(symbol);
      }
      // decimals() - 0x313ce567
      if (data.startsWith('0x313ce567')) {
        return mockDecimalsResponse(decimals);
      }
      // totalSupply() - 0x18160ddd
      if (data.startsWith('0x18160ddd')) {
        return mockBalanceResponse(totalSupply ?? BigInt.from(10).pow(27));
      }
      // allowance(address,address) - 0xdd62ed3e
      if (data.startsWith('0xdd62ed3e')) {
        return mockBalanceResponse(BigInt.zero);
      }
      
      return '0x';
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CALL TRACKING
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all calls made to this mock.
  List<MockRpcCall> get calls => List.unmodifiable(_calls);

  /// Get calls for a specific method.
  List<MockRpcCall> callsFor(String method) {
    return _calls.where((c) => c.method == method).toList();
  }

  /// Get number of times a method was called.
  int callCount(String method) {
    return callsFor(method).length;
  }

  /// Check if a method was called.
  bool wasCalled(String method) {
    return callCount(method) > 0;
  }

  /// Check if a method was never called.
  bool wasNeverCalled(String method) {
    return callCount(method) == 0;
  }

  /// Get the last call for a method.
  MockRpcCall? lastCallFor(String method) {
    final methodCalls = callsFor(method);
    return methodCalls.isEmpty ? null : methodCalls.last;
  }

  /// Verify a method was called with specific params.
  bool wasCalledWith(String method, List<dynamic> params) {
    return callsFor(method).any((c) => _listEquals(c.params, params));
  }

  bool _listEquals(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RPC CLIENT IMPLEMENTATION
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<dynamic> call(
    String method,
    List<dynamic> params, {
    bool useCache = true,
  }) async {
    // Record the call
    _calls.add(MockRpcCall(
      method: method,
      params: params,
      timestamp: DateTime.now(),
    ));

    // Simulate delay if configured
    if (simulatedDelay != null) {
      await Future.delayed(simulatedDelay!);
    }

    // Fail if configured to fail
    if (failAllCalls) {
      throw failureException ?? RpcException.networkError();
    }

    // Get mock response
    final response = _responses[method];
    if (response == null) {
      throw StateError('No mock response configured for method: $method');
    }

    return response.getResponse(params);
  }

  @override
  Future<int> getBlockNumber() async {
    final result = await call('eth_blockNumber', []);
    return int.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<int> getChainId() async {
    final result = await call('eth_chainId', []);
    return int.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<BigInt> getBalance(String address, {String block = 'latest'}) async {
    final result = await call('eth_getBalance', [address, block]);
    return BigInt.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<BigInt> getGasPrice() async {
    final result = await call('eth_gasPrice', []);
    return BigInt.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<BigInt> estimateGas(Map<String, String> transaction) async {
    final result = await call('eth_estimateGas', [transaction]);
    return BigInt.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<String> ethCall(
    Map<String, String> transaction, {
    String block = 'latest',
  }) async {
    final result = await call('eth_call', [transaction, block]);
    return result as String;
  }

  @override
  Future<int> getTransactionCount(
    String address, {
    String block = 'latest',
  }) async {
    final result = await call('eth_getTransactionCount', [address, block]);
    return int.parse((result as String).substring(2), radix: 16);
  }

  @override
  Future<String> sendRawTransaction(String signedTx) async {
    final result = await call('eth_sendRawTransaction', [signedTx]);
    return result as String;
  }

  @override
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    final result = await call('eth_getTransactionReceipt', [txHash]);
    return result as Map<String, dynamic>?;
  }

  @override
  Future<Map<String, dynamic>?> getTransaction(String txHash) async {
    final result = await call('eth_getTransactionByHash', [txHash]);
    return result as Map<String, dynamic>?;
  }

  @override
  Future<Map<String, dynamic>?> getBlockByNumber(
    int blockNumber, {
    bool includeTransactions = false,
  }) async {
    final result = await call(
      'eth_getBlockByNumber',
      [intToHex(blockNumber), includeTransactions],
    );
    return result as Map<String, dynamic>?;
  }

  @override
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
    ]);
    return (result as List).cast<Map<String, dynamic>>();
  }

  @override
  void clearCache() {
    // No-op for mock
  }

  @override
  void dispose() {
    // No-op for mock
  }

  // Static helpers from RpcClient
  static String bigIntToHex(BigInt value) => '0x${value.toRadixString(16)}';
  static String padAddress(String address) {
    final clean = address.toLowerCase().replaceFirst('0x', '');
    return clean.padLeft(64, '0');
  }
  static String padUint256(BigInt value) => value.toRadixString(16).padLeft(64, '0');
}

/// Builder for setting up mock responses.
class MockResponseBuilder {
  final MockRpcClient _client;
  final String _method;

  MockResponseBuilder(this._client, this._method);

  /// Return a fixed value.
  void thenReturn(dynamic value) {
    _client._setResponse(_method, _MockResponse.fixed(value));
  }

  /// Return values in sequence.
  void thenReturnInOrder(List<dynamic> values) {
    _client._setResponse(_method, _MockResponse.sequence(values));
  }

  /// Return based on params.
  void thenAnswer(dynamic Function(List<dynamic> params) answer) {
    _client._setResponse(_method, _MockResponse.dynamic(answer));
  }

  /// Throw an exception.
  void thenThrow(Exception exception) {
    _client._setResponse(_method, _MockResponse.error(exception));
  }
}

/// Internal mock response representation.
class _MockResponse {
  final dynamic Function(List<dynamic>) _handler;

  _MockResponse._(this._handler);

  factory _MockResponse.fixed(dynamic value) {
    return _MockResponse._((_) => value);
  }

  factory _MockResponse.sequence(List<dynamic> values) {
    var index = 0;
    return _MockResponse._((_) {
      if (index >= values.length) {
        throw StateError('Mock sequence exhausted');
      }
      return values[index++];
    });
  }

  factory _MockResponse.dynamic(dynamic Function(List<dynamic>) handler) {
    return _MockResponse._(handler);
  }

  factory _MockResponse.error(Exception exception) {
    return _MockResponse._((_) => throw exception);
  }

  dynamic getResponse(List<dynamic> params) => _handler(params);
}

/// Record of an RPC call made to the mock.
class MockRpcCall {
  final String method;
  final List<dynamic> params;
  final DateTime timestamp;

  MockRpcCall({
    required this.method,
    required this.params,
    required this.timestamp,
  });

  @override
  String toString() => 'MockRpcCall($method, $params)';
}
