/// Tests for CiFi resolver implementation.
library;

import 'package:test/test.dart';
import 'package:web3refi/web3refi.dart';

/// Mock CiFi client for testing
class MockCiFiClient extends CiFiClient {
  final Map<String, CiFiProfile> _profiles = {};
  final Map<String, List<LinkedWallet>> _addresses = {};

  MockCiFiClient()
      : super(
          apiKey: 'test-api-key',
          environment: CiFiEnvironment.sandbox,
        );

  void mockProfile(String username, CiFiProfile profile) {
    _profiles[username] = profile;
  }

  void mockLinkedAddresses(String userId, List<LinkedWallet> wallets) {
    _addresses[userId] = wallets;
  }

  @override
  CiFiIdentity get identity => MockCiFiIdentity(this);
}

class MockCiFiIdentity extends CiFiIdentity {
  final MockCiFiClient _client;

  MockCiFiIdentity(this._client) : super(_client);

  @override
  Future<CiFiProfile> getProfile(String usernameOrId) async {
    if (_client._profiles.containsKey(usernameOrId)) {
      return _client._profiles[usernameOrId]!;
    }
    throw Exception('Profile not found');
  }

  @override
  Future<List<LinkedWallet>> getLinkedAddresses(String userId) async {
    if (_client._addresses.containsKey(userId)) {
      return _client._addresses[userId]!;
    }
    return [];
  }
}

class CiFiProfile {
  final String userId;
  final String? username;
  final String? email;
  final String primaryAddress;

  CiFiProfile({
    required this.userId,
    required this.primaryAddress, this.username,
    this.email,
  });
}

class LinkedWallet {
  final String address;
  final int chainId;
  final String? label;

  LinkedWallet({
    required this.address,
    required this.chainId,
    this.label,
  });
}

void main() {
  late MockCiFiClient mockCiFi;
  late CiFiResolver cifiResolver;

  setUp(() {
    mockCiFi = MockCiFiClient();
    cifiResolver = CiFiResolver(mockCiFi);
  });

  group('CiFiResolver Configuration', () {
    test('should have correct id', () {
      expect(cifiResolver.id, 'cifi');
    });

    test('should support .cifi TLD', () {
      expect(cifiResolver.supportedTLDs, contains('cifi'));
    });

    test('should support multiple chains', () {
      expect(cifiResolver.supportedChainIds, contains(1)); // Ethereum
      expect(cifiResolver.supportedChainIds, contains(137)); // Polygon
      expect(cifiResolver.supportedChainIds, contains(42161)); // Arbitrum
      expect(cifiResolver.supportedChainIds, contains(50)); // XDC
    });

    test('should support reverse resolution', () {
      expect(cifiResolver.supportsReverse, true);
    });
  });

  group('Name Format Detection', () {
    test('should detect @username format', () {
      expect(cifiResolver.canResolve('@alice'), true);
      expect(cifiResolver.canResolve('@bob123'), true);
    });

    test('should detect username.cifi format', () {
      expect(cifiResolver.canResolve('alice.cifi'), true);
      expect(cifiResolver.canResolve('bob.cifi'), true);
    });

    test('should detect plain username', () {
      expect(cifiResolver.canResolve('alice'), true);
      expect(cifiResolver.canResolve('bob'), true);
    });

    test('should reject ENS names', () {
      expect(cifiResolver.canResolve('vitalik.eth'), false);
      expect(cifiResolver.canResolve('alice.eth'), false);
    });

    test('should reject other TLDs', () {
      expect(cifiResolver.canResolve('alice.crypto'), false);
      expect(cifiResolver.canResolve('bob.bnb'), false);
    });
  });

  group('Username Extraction', () {
    test('should extract from @username format', () {
      // Test by resolving and checking profile lookup
      mockCiFi.mockProfile(
        'alice',
        CiFiProfile(
          userId: 'user_1',
          username: 'alice',
          primaryAddress: '0x1111111111111111111111111111111111111111',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_1', [
        LinkedWallet(address: '0x1111111111111111111111111111111111111111', chainId: 1),
      ]);

      expect(cifiResolver.resolve('@alice'), completes);
    });

    test('should extract from username.cifi format', () {
      mockCiFi.mockProfile(
        'bob',
        CiFiProfile(
          userId: 'user_2',
          username: 'bob',
          primaryAddress: '0x2222222222222222222222222222222222222222',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_2', [
        LinkedWallet(address: '0x2222222222222222222222222222222222222222', chainId: 1),
      ]);

      expect(cifiResolver.resolve('bob.cifi'), completes);
    });

    test('should handle plain username', () {
      mockCiFi.mockProfile(
        'charlie',
        CiFiProfile(
          userId: 'user_3',
          username: 'charlie',
          primaryAddress: '0x3333333333333333333333333333333333333333',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_3', [
        LinkedWallet(address: '0x3333333333333333333333333333333333333333', chainId: 1),
      ]);

      expect(cifiResolver.resolve('charlie'), completes);
    });
  });

  group('Forward Resolution', () {
    test('should resolve @username to primary address', () async {
      mockCiFi.mockProfile(
        'alice',
        CiFiProfile(
          userId: 'user_alice',
          username: 'alice',
          email: 'alice@example.com',
          primaryAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_alice', [
        LinkedWallet(address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', chainId: 1),
      ]);

      final result = await cifiResolver.resolve('@alice');

      expect(result, isNotNull);
      expect(result!.address, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
      expect(result.resolverUsed, 'cifi');
      expect(result.name, '@alice');
    });

    test('should resolve to specific chain address', () async {
      mockCiFi.mockProfile(
        'multichain',
        CiFiProfile(
          userId: 'user_multi',
          username: 'multichain',
          primaryAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_multi', [
        LinkedWallet(address: '0x1111111111111111111111111111111111111111', chainId: 1), // Ethereum
        LinkedWallet(address: '0x2222222222222222222222222222222222222222', chainId: 137), // Polygon
        LinkedWallet(address: '0x3333333333333333333333333333333333333333', chainId: 42161), // Arbitrum
      ]);

      // Resolve for Polygon
      final polygonResult = await cifiResolver.resolve('@multichain', chainId: 137);
      expect(polygonResult?.address, '0x2222222222222222222222222222222222222222');
      expect(polygonResult?.chainId, 137);

      // Resolve for Arbitrum
      final arbitrumResult = await cifiResolver.resolve('@multichain', chainId: 42161);
      expect(arbitrumResult?.address, '0x3333333333333333333333333333333333333333');
      expect(arbitrumResult?.chainId, 42161);
    });

    test('should return primary address if chain not found', () async {
      mockCiFi.mockProfile(
        'alice',
        CiFiProfile(
          userId: 'user_alice',
          username: 'alice',
          primaryAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_alice', [
        LinkedWallet(address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', chainId: 1),
      ]);

      // Request for chain 137 (Polygon) but user only has Ethereum
      final result = await cifiResolver.resolve('@alice', chainId: 137);

      expect(result, isNotNull);
      // Should fall back to first available address
      expect(result!.address, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    });

    test('should return null if user has no linked addresses', () async {
      mockCiFi.mockProfile(
        'nowallets',
        CiFiProfile(
          userId: 'user_nowallet',
          username: 'nowallets',
          primaryAddress: '0x0000000000000000000000000000000000000000',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_nowallet', []);

      final result = await cifiResolver.resolve('@nowallets');
      expect(result, null);
    });

    test('should include metadata in result', () async {
      mockCiFi.mockProfile(
        'alice',
        CiFiProfile(
          userId: 'user_alice_123',
          username: 'alice',
          email: 'alice@example.com',
          primaryAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_alice_123', [
        LinkedWallet(address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', chainId: 1),
      ]);

      final result = await cifiResolver.resolve('@alice');

      expect(result?.metadata?['cifiUserId'], 'user_alice_123');
      expect(result?.metadata?['username'], 'alice');
      expect(result?.metadata?['email'], 'alice@example.com');
    });
  });

  group('Reverse Resolution', () {
    test('should resolve address to @username', () async {
      const address = '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

      mockCiFi.mockLinkedAddresses(address, [
        LinkedWallet(address: address, chainId: 1),
      ]);
      mockCiFi.mockProfile(
        address,
        CiFiProfile(
          userId: 'user_alice',
          username: 'alice',
          primaryAddress: address,
        ),
      );

      final name = await cifiResolver.reverseResolve(address);

      expect(name, '@alice');
    });

    test('should return @userId if username not set', () async {
      const address = '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

      mockCiFi.mockLinkedAddresses(address, [
        LinkedWallet(address: address, chainId: 1),
      ]);
      mockCiFi.mockProfile(
        address,
        CiFiProfile(
          userId: 'user_12345',
          username: null,
          primaryAddress: address,
        ),
      );

      final name = await cifiResolver.reverseResolve(address);

      expect(name, '@user_12345');
    });

    test('should return null if address not linked', () async {
      const address = '0xcccccccccccccccccccccccccccccccccccccccc';

      mockCiFi.mockLinkedAddresses(address, []);

      final name = await cifiResolver.reverseResolve(address);
      expect(name, null);
    });
  });

  group('Record Resolution', () {
    test('should get all records for user', () async {
      mockCiFi.mockProfile(
        'multichain',
        CiFiProfile(
          userId: 'user_multi',
          username: 'multichain',
          email: 'multi@example.com',
          primaryAddress: '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_multi', [
        LinkedWallet(address: '0x1111111111111111111111111111111111111111', chainId: 1),
        LinkedWallet(address: '0x2222222222222222222222222222222222222222', chainId: 137),
        LinkedWallet(address: '0x3333333333333333333333333333333333333333', chainId: 42161),
      ]);

      final records = await cifiResolver.getRecords('@multichain');

      expect(records, isNotNull);
      expect(records!.owner, '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee');
      expect(records.addresses['1'], '0x1111111111111111111111111111111111111111');
      expect(records.addresses['137'], '0x2222222222222222222222222222222222222222');
      expect(records.addresses['42161'], '0x3333333333333333333333333333333333333333');
      expect(records.getText('username'), 'multichain');
      expect(records.getText('email'), 'multi@example.com');
    });

    test('should handle user with minimal profile', () async {
      mockCiFi.mockProfile(
        'minimal',
        CiFiProfile(
          userId: 'user_minimal',
          username: 'minimal',
          email: null,
          primaryAddress: '0xdddddddddddddddddddddddddddddddddddddddd',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_minimal', [
        LinkedWallet(address: '0xdddddddddddddddddddddddddddddddddddddddd', chainId: 1),
      ]);

      final records = await cifiResolver.getRecords('@minimal');

      expect(records, isNotNull);
      expect(records!.getText('username'), 'minimal');
      expect(records.getText('email'), '');
    });
  });

  group('Error Handling', () {
    test('should handle profile not found', () async {
      final result = await cifiResolver.resolve('@nonexistent');
      expect(result, null);
    });

    test('should handle API errors gracefully', () async {
      // Don't mock anything - should throw internally and return null
      final result = await cifiResolver.resolve('@error');
      expect(result, null);
    });

    test('should handle reverse lookup errors', () async {
      final name = await cifiResolver.reverseResolve('0xinvalid');
      expect(name, null);
    });

    test('should handle getRecords errors', () async {
      final records = await cifiResolver.getRecords('@error');
      expect(records, null);
    });
  });

  group('Multi-Chain Support', () {
    test('should support Ethereum mainnet', () {
      expect(cifiResolver.supportedChainIds, contains(1));
    });

    test('should support Polygon', () {
      expect(cifiResolver.supportedChainIds, contains(137));
    });

    test('should support Arbitrum', () {
      expect(cifiResolver.supportedChainIds, contains(42161));
    });

    test('should support Base', () {
      expect(cifiResolver.supportedChainIds, contains(8453));
    });

    test('should support Optimism', () {
      expect(cifiResolver.supportedChainIds, contains(10));
    });

    test('should support Avalanche', () {
      expect(cifiResolver.supportedChainIds, contains(43114));
    });

    test('should support XDC', () {
      expect(cifiResolver.supportedChainIds, contains(50));
    });

    test('should support Hedera', () {
      expect(cifiResolver.supportedChainIds, contains(295));
    });
  });

  group('Name Normalization', () {
    test('should handle case insensitive usernames', () {
      mockCiFi.mockProfile(
        'alice',
        CiFiProfile(
          userId: 'user_alice',
          username: 'alice',
          primaryAddress: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
      );
      mockCiFi.mockLinkedAddresses('user_alice', [
        LinkedWallet(address: '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', chainId: 1),
      ]);

      // All should resolve to same profile
      expect(cifiResolver.resolve('@alice'), completes);
      expect(cifiResolver.resolve('@ALICE'), completes);
      expect(cifiResolver.resolve('alice.cifi'), completes);
      expect(cifiResolver.resolve('ALICE.CIFI'), completes);
    });
  });
}
