/// Test utilities and helpers for web3refi test suite.
///
/// This file provides common utilities, constants, and helper functions
/// used across all test files.
library test_utils;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';

// ════════════════════════════════════════════════════════════════════════════
// TEST CONSTANTS
// ════════════════════════════════════════════════════════════════════════════

/// Test wallet addresses
class TestAddresses {
  TestAddresses._();

  static const wallet1 = '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb';
  static const wallet2 = '0x8ba1f109551bD432803012645Ac136ddd64DBA72';
  static const wallet3 = '0xdD2FD4581271e230360230F9337D5c0430Bf44C0';
  
  static const contract1 = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC
  static const contract2 = '0xdAC17F958D2ee523a2206206994597C13D831ec7'; // USDT
  
  static const invalid = '0xinvalid';
  static const empty = '';
  static const tooShort = '0x742d35';
  static const checksumInvalid = '0x742D35CC6634C0532925A3B844BC9E7595F0BEB';
}

/// Test transaction hashes
class TestTxHashes {
  TestTxHashes._();

  static const pending = '0xabc123def456789012345678901234567890123456789012345678901234abcd';
  static const confirmed = '0xdef456abc789012345678901234567890123456789012345678901234567ef01';
  static const failed = '0x123456789abcdef012345678901234567890123456789012345678901234dead';
}

/// Test amounts
class TestAmounts {
  TestAmounts._();

  static final zero = BigInt.zero;
  static final oneWei = BigInt.one;
  static final oneGwei = BigInt.from(1000000000);
  static final oneEther = BigInt.from(10).pow(18);
  static final hundredUsdc = BigInt.from(100000000); // 100 USDC (6 decimals)
  static final maxUint256 = BigInt.parse(
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    radix: 16,
  );
}

/// Test chain configurations
class TestChains {
  TestChains._();

  static const testChain = Chain(
    chainId: 31337,
    name: 'Test Chain',
    rpcUrl: 'http://localhost:8545',
    symbol: 'TEST',
    explorerUrl: 'http://localhost:8545/explorer',
    isTestnet: true,
  );

  static const mockEthereum = Chain(
    chainId: 1,
    name: 'Mock Ethereum',
    rpcUrl: 'https://mock-eth-rpc.test',
    symbol: 'ETH',
    explorerUrl: 'https://mock-etherscan.test',
  );

  static const mockPolygon = Chain(
    chainId: 137,
    name: 'Mock Polygon',
    rpcUrl: 'https://mock-polygon-rpc.test',
    symbol: 'MATIC',
    explorerUrl: 'https://mock-polygonscan.test',
  );
}

// ════════════════════════════════════════════════════════════════════════════
// JSON-RPC HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Creates a JSON-RPC response body.
String createRpcResponse(dynamic result, {int id = 1}) {
  return jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'result': result,
  });
}

/// Creates a JSON-RPC error response body.
String createRpcErrorResponse({
  required int code,
  required String message,
  int id = 1,
}) {
  return jsonEncode({
    'jsonrpc': '2.0',
    'id': id,
    'error': {
      'code': code,
      'message': message,
    },
  });
}

/// Creates a mock transaction receipt.
Map<String, dynamic> createMockReceipt({
  required String txHash,
  required bool success,
  int blockNumber = 12345678,
  BigInt? gasUsed,
}) {
  return {
    'transactionHash': txHash,
    'status': success ? '0x1' : '0x0',
    'blockNumber': '0x${blockNumber.toRadixString(16)}',
    'blockHash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, '0')}',
    'gasUsed': '0x${(gasUsed ?? BigInt.from(21000)).toRadixString(16)}',
    'effectiveGasPrice': '0x${BigInt.from(20000000000).toRadixString(16)}',
    'logs': [],
  };
}

// ════════════════════════════════════════════════════════════════════════════
// HEX HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Converts BigInt to hex string with 0x prefix.
String bigIntToHex(BigInt value) {
  return '0x${value.toRadixString(16)}';
}

/// Converts int to hex string with 0x prefix.
String intToHex(int value) {
  return '0x${value.toRadixString(16)}';
}

/// Pads a hex string to 64 characters (32 bytes).
String padHex64(String hex) {
  final clean = hex.replaceFirst('0x', '');
  return '0x${clean.padLeft(64, '0')}';
}

/// Creates a mock ERC20 balance response.
String mockBalanceResponse(BigInt balance) {
  return padHex64(bigIntToHex(balance));
}

/// Creates a mock ERC20 decimals response.
String mockDecimalsResponse(int decimals) {
  return padHex64(intToHex(decimals));
}

/// Creates a mock string response (for name/symbol).
String mockStringResponse(String value) {
  final bytes = utf8.encode(value);
  const offset = '0000000000000000000000000000000000000000000000000000000000000020';
  final length = bytes.length.toRadixString(16).padLeft(64, '0');
  final data = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().padRight(64, '0');
  return '0x$offset$length$data';
}

// ════════════════════════════════════════════════════════════════════════════
// MATCHERS
// ════════════════════════════════════════════════════════════════════════════

/// Matcher for WalletException with specific code.
Matcher throwsWalletException(String code) {
  return throwsA(
    allOf(
      isA<WalletException>(),
      predicate<WalletException>((e) => e.code == code, 'has code "$code"'),
    ),
  );
}

/// Matcher for RpcException with specific code.
Matcher throwsRpcException(String code) {
  return throwsA(
    allOf(
      isA<RpcException>(),
      predicate<RpcException>((e) => e.code == code, 'has code "$code"'),
    ),
  );
}

/// Matcher for TransactionException with specific code.
Matcher throwsTransactionException(String code) {
  return throwsA(
    allOf(
      isA<TransactionException>(),
      predicate<TransactionException>((e) => e.code == code, 'has code "$code"'),
    ),
  );
}

/// Matcher for valid Ethereum address format.
Matcher isValidEthereumAddress = predicate<String>(
  (s) => RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(s),
  'is a valid Ethereum address',
);

/// Matcher for valid transaction hash format.
Matcher isValidTxHash = predicate<String>(
  (s) => RegExp(r'^0x[a-fA-F0-9]{64}$').hasMatch(s),
  'is a valid transaction hash',
);

// ════════════════════════════════════════════════════════════════════════════
// ASYNC HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Waits for a condition to be true, with timeout.
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await Future.delayed(pollInterval);
  }
}

/// Exception for test timeouts.
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => 'TimeoutException: $message';
}

// ════════════════════════════════════════════════════════════════════════════
// TEST SETUP HELPERS
// ════════════════════════════════════════════════════════════════════════════

/// Creates a test Web3RefiConfig.
Web3RefiConfig createTestConfig({
  String projectId = 'test_project_id',
  List<Chain>? chains,
  Chain? defaultChain,
  bool enableLogging = false,
}) {
  return Web3RefiConfig(
    projectId: projectId,
    chains: chains ?? [TestChains.mockEthereum, TestChains.mockPolygon],
    defaultChain: defaultChain,
    enableLogging: enableLogging,
    autoRestoreSession: false,
  );
}

/// Extension to check if a list contains an element matching predicate.
extension ListTestExtension<T> on List<T> {
  bool containsWhere(bool Function(T) test) {
    return any(test);
  }
}
