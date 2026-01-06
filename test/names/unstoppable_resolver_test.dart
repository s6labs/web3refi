/// Tests for Unstoppable Domains resolver implementation.
library;

import 'package:test/test.dart';
import 'package:web3refi/web3refi.dart';

/// Mock RPC client for testing Unstoppable Domains resolver
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
  late UnstoppableResolver udResolver;

  setUp(() {
    mockRpc = MockRpcClient();
    udResolver = UnstoppableResolver(mockRpc);
  });

  group('Unstoppable Resolver Configuration', () {
    test('should have correct id', () {
      expect(udResolver.id, 'unstoppable');
    });

    test('should support multiple TLDs', () {
      expect(udResolver.supportedTLDs, contains('crypto'));
      expect(udResolver.supportedTLDs, contains('nft'));
      expect(udResolver.supportedTLDs, contains('wallet'));
      expect(udResolver.supportedTLDs, contains('x'));
      expect(udResolver.supportedTLDs, contains('bitcoin'));
      expect(udResolver.supportedTLDs, contains('dao'));
      expect(udResolver.supportedTLDs, contains('888'));
      expect(udResolver.supportedTLDs, contains('zil'));
      expect(udResolver.supportedTLDs, contains('blockchain'));
    });

    test('should support Ethereum and Polygon', () {
      expect(udResolver.supportedChainIds, contains(1));
      expect(udResolver.supportedChainIds, contains(137));
    });

    test('should support reverse resolution', () {
      expect(udResolver.supportsReverse, true);
    });
  });

  group('Name Resolution Detection', () {
    test('should detect UD names', () {
      expect(udResolver.canResolve('brad.crypto'), true);
      expect(udResolver.canResolve('alice.nft'), true);
      expect(udResolver.canResolve('bob.wallet'), true);
      expect(udResolver.canResolve('charlie.x'), true);
    });

    test('should reject non-UD names', () {
      expect(udResolver.canResolve('vitalik.eth'), false);
      expect(udResolver.canResolve('@alice'), false);
      expect(udResolver.canResolve('alice.bnb'), false);
    });
  });

  group('Forward Resolution', () {
    test('should resolve .crypto name to address', () async {
      final node = namehash('brad.crypto');
      final tokenId = _bytesToBigInt(node);

      // Mock get(string,uint256) call
      final data = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        ['crypto.ETH.address', tokenId],
      );

      mockRpc.mockEthCall(
        UnstoppableResolver.polygonRegistryAddress,
        data,
        AbiCoder.encodeParameters(
          ['string'],
          ['0x8aaD44321A86b170879d7A244c1e8d360c99DdA8'],
        ),
      );

      final result = await udResolver.resolve('brad.crypto');

      expect(result, isNotNull);
      expect(result!.address, '0x8aaD44321A86b170879d7A244c1e8d360c99DdA8');
      expect(result.resolverUsed, 'unstoppable');
      expect(result.name, 'brad.crypto');
    });

    test('should return null for unregistered name', () async {
      final node = namehash('unregistered.crypto');
      final tokenId = _bytesToBigInt(node);

      final data = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        ['crypto.ETH.address', tokenId],
      );

      mockRpc.mockEthCall(
        UnstoppableResolver.polygonRegistryAddress,
        data,
        AbiCoder.encodeParameters(['string'], ['']),
      );

      final result = await udResolver.resolve('unregistered.crypto');
      expect(result, null);
    });

    test('should resolve BTC address with coin type', () async {
      final node = namehash('brad.crypto');
      final tokenId = _bytesToBigInt(node);

      final data = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        ['crypto.BTC.address', tokenId],
      );

      mockRpc.mockEthCall(
        UnstoppableResolver.polygonRegistryAddress,
        data,
        AbiCoder.encodeParameters(
          ['string'],
          ['1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa'],
        ),
      );

      final result = await udResolver.resolve('brad.crypto', coinType: '0');

      expect(result, isNotNull);
      expect(result!.address, '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa');
    });

    test('should handle different UD TLDs', () async {
      final tlds = ['crypto', 'nft', 'wallet', 'x', 'bitcoin'];

      for (final tld in tlds) {
        final name = 'test.$tld';
        final node = namehash(name);
        final tokenId = _bytesToBigInt(node);

        final data = AbiCoder.encodeFunctionCall(
          'get(string,uint256)',
          ['crypto.ETH.address', tokenId],
        );

        mockRpc.mockEthCall(
          UnstoppableResolver.polygonRegistryAddress,
          data,
          AbiCoder.encodeParameters(['string'], ['0x123...']),
        );

        final result = await udResolver.resolve(name);
        expect(result, isNotNull);
        expect(result!.name, name);
      }
    });
  });

  group('Record Resolution', () {
    test('should get all records for a name', () async {
      final node = namehash('brad.crypto');
      final tokenId = _bytesToBigInt(node);

      // Mock multiple record calls
      final records = {
        'crypto.ETH.address': '0x8aaD...',
        'crypto.BTC.address': '1A1zP...',
        'crypto.SOL.address': 'DRpbC...',
        'whois.email.value': 'brad@unstoppable.com',
        'social.twitter.username': '@unstoppable',
        'social.picture.value': 'https://avatar.url',
      };

      for (final entry in records.entries) {
        final data = AbiCoder.encodeFunctionCall(
          'get(string,uint256)',
          [entry.key, tokenId],
        );

        mockRpc.mockEthCall(
          UnstoppableResolver.polygonRegistryAddress,
          data,
          AbiCoder.encodeParameters(['string'], [entry.value]),
        );
      }

      final result = await udResolver.getRecords('brad.crypto');

      expect(result, isNotNull);
      expect(result!.ethereumAddress, '0x8aaD...');
      expect(result.getAddress('0'), '1A1zP...'); // BTC
      expect(result.getAddress('501'), 'DRpbC...'); // SOL
      expect(result.getText('email'), 'brad@unstoppable.com');
      expect(result.getText('com.twitter'), '@unstoppable');
      expect(result.avatar, 'https://avatar.url');
    });

    test('should handle missing records gracefully', () async {
      final node = namehash('minimal.crypto');
      final tokenId = _bytesToBigInt(node);

      // Only ETH address exists
      final ethData = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        ['crypto.ETH.address', tokenId],
      );

      mockRpc.mockEthCall(
        UnstoppableResolver.polygonRegistryAddress,
        ethData,
        AbiCoder.encodeParameters(['string'], ['0x123...']),
      );

      // Other records return empty
      final emptyRecords = [
        'crypto.BTC.address',
        'whois.email.value',
        'social.twitter.username',
      ];

      for (final key in emptyRecords) {
        final data = AbiCoder.encodeFunctionCall(
          'get(string,uint256)',
          [key, tokenId],
        );

        mockRpc.mockEthCall(
          UnstoppableResolver.polygonRegistryAddress,
          data,
          AbiCoder.encodeParameters(['string'], ['']),
        );
      }

      final result = await udResolver.getRecords('minimal.crypto');

      expect(result, isNotNull);
      expect(result!.ethereumAddress, '0x123...');
      expect(result.getAddress('0'), null); // No BTC
      expect(result.getText('email'), null); // No email
    });
  });

  group('Chain Support', () {
    test('should use Polygon registry by default', () {
      final resolver = UnstoppableResolver(mockRpc);
      // This is tested indirectly through resolution calls
      expect(resolver, isNotNull);
    });

    test('should support Ethereum registry', () {
      final resolver = UnstoppableResolver(mockRpc, chainId: 1);
      expect(resolver.supportedChainIds, contains(1));
    });
  });

  group('Error Handling', () {
    test('should handle RPC errors gracefully', () async {
      final result = await udResolver.resolve('error.crypto');
      expect(result, null);
    });

    test('should return null for empty records', () async {
      final node = namehash('empty.crypto');
      final tokenId = _bytesToBigInt(node);

      final data = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        ['crypto.ETH.address', tokenId],
      );

      mockRpc.mockEthCall(
        UnstoppableResolver.polygonRegistryAddress,
        data,
        AbiCoder.encodeParameters(['string'], ['']),
      );

      final result = await udResolver.resolve('empty.crypto');
      expect(result, null);
    });
  });

  group('Multi-Coin Support', () {
    test('should support Ethereum (coin type 60)', () async {
      final result = await _resolveWithCoinType(mockRpc, 'brad.crypto', '60', '0xETH...');
      expect(result?.address, '0xETH...');
    });

    test('should support Bitcoin (coin type 0)', () async {
      final result = await _resolveWithCoinType(mockRpc, 'brad.crypto', '0', '1BTC...');
      expect(result?.address, '1BTC...');
    });

    test('should support Solana (coin type 501)', () async {
      final result = await _resolveWithCoinType(mockRpc, 'brad.crypto', '501', 'SOL...');
      expect(result?.address, 'SOL...');
    });

    test('should support Polygon (coin type 966)', () async {
      final result = await _resolveWithCoinType(mockRpc, 'brad.crypto', '966', '0xMATIC...');
      expect(result?.address, '0xMATIC...');
    });
  });
}

// ══════════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════════

BigInt _bytesToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (var i = 0; i < bytes.length; i++) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

Future<ResolutionResult?> _resolveWithCoinType(
  MockRpcClient mockRpc,
  String name,
  String coinType,
  String address,
) async {
  final resolver = UnstoppableResolver(mockRpc);
  final node = namehash(name);
  final tokenId = _bytesToBigInt(node);

  String recordKey;
  switch (coinType) {
    case '0':
      recordKey = 'crypto.BTC.address';
      break;
    case '60':
      recordKey = 'crypto.ETH.address';
      break;
    case '501':
      recordKey = 'crypto.SOL.address';
      break;
    case '966':
      recordKey = 'crypto.MATIC.address';
      break;
    default:
      recordKey = 'crypto.$coinType.address';
  }

  final data = AbiCoder.encodeFunctionCall(
    'get(string,uint256)',
    [recordKey, tokenId],
  );

  mockRpc.mockEthCall(
    UnstoppableResolver.polygonRegistryAddress,
    data,
    AbiCoder.encodeParameters(['string'], [address]),
  );

  return resolver.resolve(name, coinType: coinType);
}
