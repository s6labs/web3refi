import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';

void main() {
  group('RpcClient', () {
    late RpcClient rpcClient;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient((request) async {
        return http.Response('{"jsonrpc":"2.0","id":1,"result":"0x1"}', 200);
      });
    });

    tearDown(() {
      rpcClient.dispose();
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('constructor', () {
      test('creates client with required chain parameter', () {
        rpcClient = RpcClient(chain: Chains.ethereum);
        
        expect(rpcClient.chain, equals(Chains.ethereum));
        expect(rpcClient.timeout, equals(const Duration(seconds: 30)));
        expect(rpcClient.enableLogging, isFalse);
      });

      test('accepts custom timeout', () {
        rpcClient = RpcClient(
          chain: Chains.ethereum,
          timeout: const Duration(seconds: 60),
        );
        
        expect(rpcClient.timeout, equals(const Duration(seconds: 60)));
      });

      test('accepts custom http client', () {
        rpcClient = RpcClient(
          chain: Chains.ethereum,
          httpClient: mockHttpClient,
        );
        
        // Should not throw
        expect(rpcClient, isNotNull);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // getBlockNumber TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('getBlockNumber', () {
      test('returns current block number', () async {
        mockHttpClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], equals('eth_blockNumber'));
          expect(body['params'], isEmpty);
          
          return http.Response(
            createRpcResponse('0xbc614e'), // 12345678
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final blockNumber = await rpcClient.getBlockNumber();
        
        expect(blockNumber, equals(12345678));
      });

      test('handles large block numbers', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcResponse('0xffffffff'), // 4294967295
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final blockNumber = await rpcClient.getBlockNumber();
        
        expect(blockNumber, equals(4294967295));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // getBalance TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('getBalance', () {
      test('returns balance for address', () async {
        mockHttpClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], equals('eth_getBalance'));
          expect(body['params'][0], equals(TestAddresses.wallet1));
          expect(body['params'][1], equals('latest'));
          
          return http.Response(
            createRpcResponse('0xde0b6b3a7640000'), // 1 ETH
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final balance = await rpcClient.getBalance(TestAddresses.wallet1);
        
        expect(balance, equals(TestAmounts.oneEther));
      });

      test('accepts custom block parameter', () async {
        mockHttpClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['params'][1], equals('0xbc614e'));
          
          return http.Response(
            createRpcResponse('0x0'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        await rpcClient.getBalance(TestAddresses.wallet1, block: '0xbc614e');
      });

      test('returns zero for empty balance', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcResponse('0x0'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final balance = await rpcClient.getBalance(TestAddresses.wallet1);
        
        expect(balance, equals(BigInt.zero));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // getGasPrice TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('getGasPrice', () {
      test('returns current gas price', () async {
        mockHttpClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], equals('eth_gasPrice'));
          
          return http.Response(
            createRpcResponse('0x4a817c800'), // 20 Gwei
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final gasPrice = await rpcClient.getGasPrice();
        
        expect(gasPrice, equals(BigInt.from(20000000000)));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ethCall TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('ethCall', () {
      test('calls contract with correct parameters', () async {
        mockHttpClient = MockClient((request) async {
          final body = jsonDecode(request.body);
          expect(body['method'], equals('eth_call'));
          expect(body['params'][0]['to'], equals(TestAddresses.contract1));
          expect(body['params'][0]['data'], startsWith('0x'));
          expect(body['params'][1], equals('latest'));
          
          return http.Response(
            createRpcResponse('0x0000000000000000000000000000000000000000000000000000000005f5e100'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final result = await rpcClient.ethCall({
          'to': TestAddresses.contract1,
          'data': '0x70a08231000000000000000000000000742d35cc6634c0532925a3b844bc9e7595f0beb',
        });
        
        expect(result, isA<String>());
        expect(result, startsWith('0x'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // getTransactionReceipt TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('getTransactionReceipt', () {
      test('returns receipt for confirmed transaction', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcResponse(createMockReceipt(
              txHash: TestTxHashes.confirmed,
              success: true,
            )),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final receipt = await rpcClient.getTransactionReceipt(TestTxHashes.confirmed);
        
        expect(receipt, isNotNull);
        expect(receipt!['status'], equals('0x1'));
        expect(receipt['transactionHash'], equals(TestTxHashes.confirmed));
      });

      test('returns null for pending transaction', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcResponse(null),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final receipt = await rpcClient.getTransactionReceipt(TestTxHashes.pending);
        
        expect(receipt, isNull);
      });

      test('returns receipt with failed status', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcResponse(createMockReceipt(
              txHash: TestTxHashes.failed,
              success: false,
            )),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        final receipt = await rpcClient.getTransactionReceipt(TestTxHashes.failed);
        
        expect(receipt, isNotNull);
        expect(receipt!['status'], equals('0x0'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ERROR HANDLING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('error handling', () {
      test('throws RpcException on JSON-RPC error', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response(
            createRpcErrorResponse(code: -32000, message: 'execution reverted'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        expect(
          () => rpcClient.getBlockNumber(),
          throwsA(isA<RpcException>()),
        );
      });

      test('throws RpcException on rate limit (429)', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response('Rate limited', 429);
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        expect(
          () => rpcClient.getBlockNumber(),
          throwsRpcException('rate_limited'),
        );
      });

      test('throws RpcException on HTTP error', () async {
        mockHttpClient = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        expect(
          () => rpcClient.getBlockNumber(),
          throwsA(isA<RpcException>()),
        );
      });

      test('tries backup RPC on primary failure', () async {
        var callCount = 0;
        mockHttpClient = MockClient((request) async {
          callCount++;
          if (callCount == 1) {
            throw http.ClientException('Connection failed');
          }
          return http.Response(
            createRpcResponse('0x1'),
            200,
          );
        });
        
        const chainWithBackup = Chain(
          chainId: 1,
          name: 'Test',
          rpcUrl: 'https://primary.test',
          symbol: 'TEST',
          explorerUrl: 'https://explorer.test',
          backupRpcUrls: ['https://backup.test'],
        );
        
        rpcClient = RpcClient(
          chain: chainWithBackup,
          httpClient: mockHttpClient,
        );
        
        final blockNumber = await rpcClient.getBlockNumber();
        
        expect(blockNumber, equals(1));
        expect(callCount, equals(2));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CACHING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('caching', () {
      test('caches eth_blockNumber response', () async {
        var callCount = 0;
        mockHttpClient = MockClient((request) async {
          callCount++;
          return http.Response(
            createRpcResponse('0x1'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        // First call
        await rpcClient.getBlockNumber();
        // Second call (should use cache)
        await rpcClient.getBlockNumber();
        
        expect(callCount, equals(1));
      });

      test('does not cache when useCache is false', () async {
        var callCount = 0;
        mockHttpClient = MockClient((request) async {
          callCount++;
          return http.Response(
            createRpcResponse('0x1'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        await rpcClient.call('eth_blockNumber', [], useCache: false);
        await rpcClient.call('eth_blockNumber', [], useCache: false);
        
        expect(callCount, equals(2));
      });

      test('clearCache removes all cached responses', () async {
        var callCount = 0;
        mockHttpClient = MockClient((request) async {
          callCount++;
          return http.Response(
            createRpcResponse('0x$callCount'),
            200,
          );
        });
        
        rpcClient = RpcClient(
          chain: TestChains.mockEthereum,
          httpClient: mockHttpClient,
        );
        
        await rpcClient.getBlockNumber();
        rpcClient.clearCache();
        final secondCall = await rpcClient.getBlockNumber();
        
        expect(callCount, equals(2));
        expect(secondCall, equals(2));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // STATIC HELPER TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('static helpers', () {
      test('bigIntToHex converts correctly', () {
        expect(RpcClient.bigIntToHex(BigInt.zero), equals('0x0'));
        expect(RpcClient.bigIntToHex(BigInt.from(255)), equals('0xff'));
        expect(RpcClient.bigIntToHex(TestAmounts.oneEther), equals('0xde0b6b3a7640000'));
      });

      test('padAddress pads to 64 characters', () {
        final padded = RpcClient.padAddress(TestAddresses.wallet1);
        
        expect(padded.length, equals(64));
        expect(padded, startsWith('000000000000000000000000'));
        expect(padded.toLowerCase(), contains('742d35cc6634c0532925a3b844bc9e7595f0beb'));
      });

      test('padUint256 pads to 64 characters', () {
        final padded = RpcClient.padUint256(BigInt.from(100));
        
        expect(padded.length, equals(64));
        expect(padded, equals('0000000000000000000000000000000000000000000000000000000000000064'));
      });
    });
  });
}
