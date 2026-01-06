/// Tests for ENS resolver implementation.
library;

import 'package:test/test.dart';
import 'package:web3refi/web3refi.dart';

/// Mock RPC client for testing ENS resolver
class MockRpcClient extends RpcClient {
  final Map<String, String> _mockResponses = {};

  MockRpcClient() : super(rpcUrl: 'https://mock.rpc');

  void mockEthCall(String to, String data, String response) {
    _mockResponses['$to:$data'] = response;
  }

  @override
  Future<String> ethCall({
    required String to,
    required String data,
    String? from,
    int? blockNumber,
  }) async {
    final key = '$to:$data';
    if (_mockResponses.containsKey(key)) {
      return _mockResponses[key]!;
    }
    throw Exception('No mock response for $key');
  }
}

void main() {
  late MockRpcClient mockRpc;
  late ENSResolver ensResolver;

  setUp(() {
    mockRpc = MockRpcClient();
    ensResolver = ENSResolver(mockRpc);
  });

  group('ENSResolver Configuration', () {
    test('should have correct id', () {
      expect(ensResolver.id, 'ens');
    });

    test('should support .eth TLD', () {
      expect(ensResolver.supportedTLDs, contains('eth'));
    });

    test('should support Ethereum mainnet', () {
      expect(ensResolver.supportedChainIds, contains(1));
    });

    test('should support reverse resolution', () {
      expect(ensResolver.supportsReverse, true);
    });

    test('should not support registration by default', () {
      expect(ensResolver.supportsRegistration, false);
    });
  });

  group('Name Resolution Detection', () {
    test('should detect ENS names', () {
      expect(ensResolver.canResolve('vitalik.eth'), true);
      expect(ensResolver.canResolve('alice.eth'), true);
      expect(ensResolver.canResolve('sub.domain.eth'), true);
    });

    test('should reject non-ENS names', () {
      expect(ensResolver.canResolve('@alice'), false);
      expect(ensResolver.canResolve('alice.cifi'), false);
      expect(ensResolver.canResolve('alice.crypto'), false);
    });

    test('should be case insensitive', () {
      expect(ensResolver.canResolve('VITALIK.ETH'), true);
      expect(ensResolver.canResolve('Vitalik.Eth'), true);
    });
  });

  group('Forward Resolution', () {
    test('should resolve ENS name to address', () async {
      // Mock resolver() call
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock addr() call
      final addrCallData = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        addrCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
        ),
      );

      final result = await ensResolver.resolve('vitalik.eth');

      expect(result, isNotNull);
      expect(result!.address, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
      expect(result.resolverUsed, 'ens');
      expect(result.name, 'vitalik.eth');
    });

    test('should return null for unregistered name', () async {
      // Mock resolver() returning zero address
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('unregistered.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0x0000000000000000000000000000000000000000'],
        ),
      );

      final result = await ensResolver.resolve('unregistered.eth');
      expect(result, null);
    });

    test('should handle subdomain resolution', () async {
      // Mock resolver() call for subdomain
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('sub.vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock addr() call
      final addrCallData = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [namehash('sub.vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        addrCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0x1234567890123456789012345678901234567890'],
        ),
      );

      final result = await ensResolver.resolve('sub.vitalik.eth');

      expect(result, isNotNull);
      expect(result!.address, '0x1234567890123456789012345678901234567890');
    });

    test('should normalize name before resolution', () async {
      // Both should use same namehash
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      final addrCallData = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        addrCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
        ),
      );

      final result1 = await ensResolver.resolve('VITALIK.ETH');
      final result2 = await ensResolver.resolve('vitalik.eth');

      expect(result1?.address, result2?.address);
    });
  });

  group('Reverse Resolution', () {
    test('should resolve address to ENS name', () async {
      const address = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
      const reverseNode = 'd8da6bf26964af9d7eed9e03e53415d37aa96045.addr.reverse';

      // Mock resolver() call for reverse node
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash(reverseNode)],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock name() call
      final nameCallData = AbiCoder.encodeFunctionCall(
        'name(bytes32)',
        [namehash(reverseNode)],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        nameCallData,
        AbiCoder.encodeParameters(['string'], ['vitalik.eth']),
      );

      final name = await ensResolver.reverseResolve(address);

      expect(name, 'vitalik.eth');
    });

    test('should handle address without reverse record', () async {
      const address = '0x1234567890123456789012345678901234567890';
      const reverseNode = '1234567890123456789012345678901234567890.addr.reverse';

      // Mock resolver() returning zero address
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash(reverseNode)],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0x0000000000000000000000000000000000000000'],
        ),
      );

      final name = await ensResolver.reverseResolve(address);
      expect(name, null);
    });

    test('should normalize address before reverse lookup', () async {
      // Should handle both with and without 0x prefix
      const address1 = '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
      const address2 = 'd8dA6BF26964aF9D7eEd9e03E53415D37aA96045';
      const reverseNode = 'd8da6bf26964af9d7eed9e03e53415d37aa96045.addr.reverse';

      // Mock resolver() call
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash(reverseNode)],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock name() call
      final nameCallData = AbiCoder.encodeFunctionCall(
        'name(bytes32)',
        [namehash(reverseNode)],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        nameCallData,
        AbiCoder.encodeParameters(['string'], ['vitalik.eth']),
      );

      final name1 = await ensResolver.reverseResolve(address1);
      final name2 = await ensResolver.reverseResolve(address2);

      expect(name1, name2);
    });
  });

  group('Record Resolution', () {
    test('should get all records for a name', () async {
      // Mock resolver() call
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock addr() call
      final addrCallData = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [namehash('vitalik.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        addrCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045'],
        ),
      );

      // Mock text records
      final textRecords = ['avatar', 'email', 'url', 'description', 'com.twitter', 'com.github'];
      for (final key in textRecords) {
        final textCallData = AbiCoder.encodeFunctionCall(
          'text(bytes32,string)',
          [namehash('vitalik.eth'), key],
        );
        mockRpc.mockEthCall(
          ENSResolver.publicResolverAddress,
          textCallData,
          AbiCoder.encodeParameters(['string'], ['test_$key']),
        );
      }

      final records = await ensResolver.getRecords('vitalik.eth');

      expect(records, isNotNull);
      expect(records!.ethereumAddress, '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
      expect(records.avatar, 'test_avatar');
      expect(records.getText('email'), 'test_email');
      expect(records.getText('url'), 'test_url');
    });

    test('should handle missing text records gracefully', () async {
      // Mock resolver() call
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('minimal.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          [ENSResolver.publicResolverAddress],
        ),
      );

      // Mock addr() call
      final addrCallData = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [namehash('minimal.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.publicResolverAddress,
        addrCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0x1234567890123456789012345678901234567890'],
        ),
      );

      // Mock empty text records
      final textRecords = ['avatar', 'email', 'url', 'description', 'com.twitter', 'com.github'];
      for (final key in textRecords) {
        final textCallData = AbiCoder.encodeFunctionCall(
          'text(bytes32,string)',
          [namehash('minimal.eth'), key],
        );
        mockRpc.mockEthCall(
          ENSResolver.publicResolverAddress,
          textCallData,
          AbiCoder.encodeParameters(['string'], ['']),
        );
      }

      final records = await ensResolver.getRecords('minimal.eth');

      expect(records, isNotNull);
      expect(records!.ethereumAddress, '0x1234567890123456789012345678901234567890');
      expect(records.avatar, null); // Empty strings should be null
      expect(records.getText('email'), null);
    });
  });

  group('Error Handling', () {
    test('should handle RPC errors gracefully', () async {
      // Don't mock any responses - should throw
      final result = await ensResolver.resolve('error.eth');
      expect(result, null);
    });

    test('should return null on resolver lookup failure', () async {
      // Mock resolver() throwing
      final result = await ensResolver.resolve('failed.eth');
      expect(result, null);
    });

    test('should handle empty resolver address', () async {
      final resolverCallData = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [namehash('empty.eth')],
      );
      mockRpc.mockEthCall(
        ENSResolver.registryAddress,
        resolverCallData,
        AbiCoder.encodeParameters(
          ['address'],
          ['0x0000000000000000000000000000000000000000'],
        ),
      );

      final result = await ensResolver.resolve('empty.eth');
      expect(result, null);
    });
  });
}
