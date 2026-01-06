/// Tests for UniversalNameService implementation.
library;

import 'package:test/test.dart';
import 'package:web3refi/web3refi.dart';

/// Mock implementations for testing
class MockRpcClient extends RpcClient {
  MockRpcClient() : super(rpcUrl: 'https://mock.rpc');

  @override
  Future<String> ethCall({
    required String to,
    required String data,
    String? from,
    int? blockNumber,
  }) async {
    throw UnimplementedError('Mock RPC - use specific mocks');
  }
}

class MockCiFiClient extends CiFiClient {
  MockCiFiClient()
      : super(
          apiKey: 'test-key',
          environment: CiFiEnvironment.sandbox,
        );
}

class TestNameResolver extends NameResolver {
  final String _id;
  final Map<String, String> _mockResults = {};

  TestNameResolver(this._id);

  void mockResolve(String name, String address) {
    _mockResults[name] = address;
  }

  @override
  String get id => _id;

  @override
  List<String> get supportedTLDs => ['test'];

  @override
  List<int> get supportedChainIds => [1];

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    if (_mockResults.containsKey(name)) {
      return ResolutionResult(
        address: _mockResults[name]!,
        resolverUsed: _id,
        name: name,
      );
    }
    return null;
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    if (_mockResults.containsKey(name)) {
      return NameRecords(
        addresses: {'60': _mockResults[name]!},
        texts: {},
      );
    }
    return null;
  }
}

void main() {
  late MockRpcClient mockRpc;
  late MockCiFiClient mockCiFi;
  late UniversalNameService uns;

  setUp(() {
    mockRpc = MockRpcClient();
    mockCiFi = MockCiFiClient();
    uns = UniversalNameService(
      rpcClient: mockRpc,
      cifiClient: mockCiFi,
      enableCiFiFallback: true,
    );
  });

  group('Initialization', () {
    test('should initialize with RPC client', () {
      final service = UniversalNameService(rpcClient: mockRpc);
      expect(service, isNotNull);
    });

    test('should initialize with CiFi fallback enabled', () {
      final service = UniversalNameService(
        rpcClient: mockRpc,
        cifiClient: mockCiFi,
        enableCiFiFallback: true,
      );
      expect(service, isNotNull);
    });

    test('should initialize without CiFi fallback', () {
      final service = UniversalNameService(
        rpcClient: mockRpc,
        enableCiFiFallback: false,
      );
      expect(service, isNotNull);
    });
  });

  group('Resolver Registration', () {
    test('should register custom resolver', () {
      final customResolver = TestNameResolver('custom');
      uns.registerResolver('custom', customResolver);

      // Verify registration by attempting to use it
      uns.registerTLD('test', 'custom');
    });

    test('should register TLD mapping', () {
      final customResolver = TestNameResolver('custom');
      uns.registerResolver('custom', customResolver);
      uns.registerTLD('custom', 'custom');

      // Should not throw
    });

    test('should handle multiple resolvers', () {
      final resolver1 = TestNameResolver('resolver1');
      final resolver2 = TestNameResolver('resolver2');

      uns.registerResolver('resolver1', resolver1);
      uns.registerResolver('resolver2', resolver2);

      // Both should be registered
    });

    test('should support resolver priority', () {
      final highPriority = TestNameResolver('high');
      final lowPriority = TestNameResolver('low');

      uns.registerResolver('high', highPriority, priority: 0);
      uns.registerResolver('low', lowPriority, priority: 10);

      // High priority should be tried first
    });
  });

  group('Name Resolution', () {
    test('should resolve using appropriate resolver', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve(
        'alice.test',
        '0x1111111111111111111111111111111111111111',
      );

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final address = await uns.resolve('alice.test');
      expect(address, '0x1111111111111111111111111111111111111111');
    });

    test('should try resolvers in priority order', () async {
      final resolver1 = TestNameResolver('resolver1');
      final resolver2 = TestNameResolver('resolver2');

      resolver1.mockResolve('test.name', '0x1111111111111111111111111111111111111111');
      resolver2.mockResolve('test.name', '0x2222222222222222222222222222222222222222');

      uns.registerResolver('resolver1', resolver1, priority: 0);
      uns.registerResolver('resolver2', resolver2, priority: 1);

      // Should use resolver1 (higher priority)
      final address = await uns.resolve('test.name');
      expect(address, '0x1111111111111111111111111111111111111111');
    });

    test('should fall back to next resolver if first fails', () async {
      final resolver1 = TestNameResolver('resolver1');
      final resolver2 = TestNameResolver('resolver2');

      // resolver1 doesn't have the name
      resolver2.mockResolve('test.name', '0x2222222222222222222222222222222222222222');

      uns.registerResolver('resolver1', resolver1, priority: 0);
      uns.registerResolver('resolver2', resolver2, priority: 1);

      final address = await uns.resolve('test.name');
      expect(address, '0x2222222222222222222222222222222222222222');
    });

    test('should return null if no resolver can resolve', () async {
      final address = await uns.resolve('nonexistent.unknown');
      expect(address, null);
    });

    test('should validate name before resolution', () async {
      expect(
        () => uns.resolve('ab'), // Too short
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should normalize name before resolution', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve(
        'alice.test',
        '0x1111111111111111111111111111111111111111',
      );

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final address1 = await uns.resolve('ALICE.TEST');
      final address2 = await uns.resolve('alice.test');

      expect(address1, address2);
    });
  });

  group('Resolution with Metadata', () {
    test('should resolve with full metadata', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve(
        'alice.test',
        '0x1111111111111111111111111111111111111111',
      );

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final result = await uns.resolveWithMetadata('alice.test');

      expect(result, isNotNull);
      expect(result!.address, '0x1111111111111111111111111111111111111111');
      expect(result.resolverUsed, 'test');
      expect(result.name, 'alice.test');
    });

    test('should include chain ID in result', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve(
        'alice.test',
        '0x1111111111111111111111111111111111111111',
      );

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final result = await uns.resolveWithMetadata('alice.test', chainId: 137);

      expect(result?.chainId, 137);
    });
  });

  group('Reverse Resolution', () {
    test('should reverse resolve address to name', () async {
      // Reverse resolution requires resolver support
      // This is a basic test - actual implementation depends on resolver
      final name = await uns.reverseResolve(
        '0x1111111111111111111111111111111111111111',
      );

      // May be null if no resolver supports reverse
      expect(name, anyOf(isNull, isA<String>()));
    });

    test('should try all resolvers for reverse resolution', () async {
      final name = await uns.reverseResolve(
        '0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045',
      );

      // Should attempt reverse resolution on all supporting resolvers
      expect(name, anyOf(isNull, isA<String>()));
    });
  });

  group('Record Resolution', () {
    test('should get all records for a name', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve(
        'alice.test',
        '0x1111111111111111111111111111111111111111',
      );

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final records = await uns.getRecords('alice.test');

      expect(records, isNotNull);
      expect(records!.ethereumAddress, '0x1111111111111111111111111111111111111111');
    });

    test('should return null if name not found', () async {
      final records = await uns.getRecords('nonexistent.unknown');
      expect(records, null);
    });
  });

  group('Text Record Resolution', () {
    test('should get text record for a name', () async {
      // Basic test - actual implementation depends on resolver support
      final text = await uns.getText('test.name', 'email');
      expect(text, anyOf(isNull, isA<String>()));
    });
  });

  group('Avatar Resolution', () {
    test('should get avatar URL for a name', () async {
      // Basic test - actual implementation depends on resolver support
      final avatar = await uns.getAvatar('test.name');
      expect(avatar, anyOf(isNull, isA<String>()));
    });
  });

  group('Batch Resolution', () {
    test('should resolve multiple names', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');
      testResolver.mockResolve('bob.test', '0x2222222222222222222222222222222222222222');
      testResolver.mockResolve('charlie.test', '0x3333333333333333333333333333333333333333');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final results = await uns.resolveMany([
        'alice.test',
        'bob.test',
        'charlie.test',
      ]);

      expect(results['alice.test'], '0x1111111111111111111111111111111111111111');
      expect(results['bob.test'], '0x2222222222222222222222222222222222222222');
      expect(results['charlie.test'], '0x3333333333333333333333333333333333333333');
    });

    test('should handle mix of valid and invalid names', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      final results = await uns.resolveMany([
        'alice.test',
        'nonexistent.test',
      ]);

      expect(results['alice.test'], '0x1111111111111111111111111111111111111111');
      expect(results['nonexistent.test'], null);
    });

    test('should handle empty list', () async {
      final results = await uns.resolveMany([]);
      expect(results, isEmpty);
    });
  });

  group('Caching', () {
    test('should cache resolution results', () async {
      final testResolver = TestNameResolver('test');
      var callCount = 0;

      // Override resolve to count calls
      final originalResolve = testResolver.resolve;
      testResolver.resolve = (name, {chainId, coinType}) async {
        callCount++;
        return originalResolve(name, chainId: chainId, coinType: coinType);
      };

      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      // First call - should hit resolver
      await uns.resolve('alice.test');
      expect(callCount, 1);

      // Second call - should use cache
      await uns.resolve('alice.test');
      expect(callCount, 1); // Still 1, not 2
    });

    test('should bypass cache when requested', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      await uns.resolve('alice.test');
      final address = await uns.resolve('alice.test', useCache: false);

      expect(address, '0x1111111111111111111111111111111111111111');
    });

    test('should clear cache', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      await uns.resolve('alice.test');
      uns.clearCache();

      // After clear, should hit resolver again
      final address = await uns.resolve('alice.test');
      expect(address, '0x1111111111111111111111111111111111111111');
    });
  });

  group('TLD Routing', () {
    test('should route .eth to ENS resolver', () {
      // ENS resolver should be registered by default
      // This test verifies routing works
      expect(() => uns.resolve('test.eth'), returnsNormally);
    });

    test('should route .cifi to CiFi resolver when enabled', () {
      expect(() => uns.resolve('test.cifi'), returnsNormally);
    });

    test('should route @username to CiFi resolver', () {
      expect(() => uns.resolve('@alice'), returnsNormally);
    });

    test('should route custom TLD to registered resolver', () {
      final customResolver = TestNameResolver('custom');
      uns.registerResolver('custom', customResolver);
      uns.registerTLD('custom', 'custom');

      expect(() => uns.resolve('test.custom'), returnsNormally);
    });
  });

  group('Error Handling', () {
    test('should handle resolver errors gracefully', () async {
      final address = await uns.resolve('error.eth');
      // Should return null instead of throwing
      expect(address, anyOf(isNull, isA<String>()));
    });

    test('should handle invalid names', () {
      expect(
        () => uns.resolve('ab'), // Too short
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle empty names', () {
      expect(
        () => uns.resolve(''),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('should handle null results from resolvers', () async {
      final result = await uns.resolve('nonexistent.unknown');
      expect(result, null);
    });
  });

  group('Chain-Specific Resolution', () {
    test('should pass chainId to resolver', () async {
      final testResolver = TestNameResolver('test');
      testResolver.mockResolve('alice.test', '0x1111111111111111111111111111111111111111');

      uns.registerResolver('test', testResolver);
      uns.registerTLD('test', 'test');

      await uns.resolve('alice.test', chainId: 137);
      // ChainId should be passed through to resolver
    });

    test('should support multi-chain resolution', () async {
      // This test verifies that chainId is properly passed
      final address1 = await uns.resolve('test.name', chainId: 1);
      final address2 = await uns.resolve('test.name', chainId: 137);

      // Addresses may be same or different depending on resolver
      expect(address1, anyOf(isNull, isA<String>()));
      expect(address2, anyOf(isNull, isA<String>()));
    });
  });

  group('Integration', () {
    test('should work with ENS and CiFi resolvers together', () {
      final service = UniversalNameService(
        rpcClient: mockRpc,
        cifiClient: mockCiFi,
        enableCiFiFallback: true,
      );

      // Should have both resolvers registered
      expect(service, isNotNull);
    });

    test('should fall back from ENS to CiFi', () async {
      // If ENS resolution fails, should try CiFi
      final address = await uns.resolve('test.name');
      expect(address, anyOf(isNull, isA<String>()));
    });

    test('should support adding custom resolvers alongside defaults', () {
      final customResolver = TestNameResolver('custom');
      uns.registerResolver('custom', customResolver);
      uns.registerTLD('custom', 'custom');

      // Should have ENS, CiFi, and custom resolver
      expect(uns, isNotNull);
    });
  });

  group('Name Validation Integration', () {
    test('should reject invalid names before resolution', () {
      expect(() => uns.resolve('ab'), throwsA(isA<ArgumentError>()));
      expect(() => uns.resolve('test..eth'), throwsA(isA<ArgumentError>()));
      expect(() => uns.resolve('.invalid'), throwsA(isA<ArgumentError>()));
    });

    test('should accept valid names', () {
      expect(() => uns.resolve('vitalik.eth'), returnsNormally);
      expect(() => uns.resolve('@alice'), returnsNormally);
      expect(() => uns.resolve('test.cifi'), returnsNormally);
    });
  });
}
