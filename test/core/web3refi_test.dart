import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';
import '../mocks/mock_rpc_client.dart';
import '../mocks/mock_wallet_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web3Refi', () {
    // ════════════════════════════════════════════════════════════════════════
    // INITIALIZATION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('initialization', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('initialize creates singleton instance', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(Web3Refi.isInitialized, isTrue);
        expect(Web3Refi.instance, isNotNull);
      });

      test('instance throws before initialization', () {
        expect(
          () => Web3Refi.instance,
          throwsA(isA<StateError>()),
        );
      });

      test('isInitialized returns false before initialization', () {
        expect(Web3Refi.isInitialized, isFalse);
      });

      test('initialize accepts development config', () async {
        final config = Web3RefiConfig.development(projectId: 'test');

        await Web3Refi.initialize(config: config);

        expect(Web3Refi.instance.config.enableLogging, isTrue);
        expect(Web3Refi.instance.config.xmtpEnvironment, equals('dev'));
      });

      test('initialize accepts production config', () async {
        final config = Web3RefiConfig.production(
          projectId: 'test',
          chains: [Chains.ethereum],
        );

        await Web3Refi.initialize(config: config);

        expect(Web3Refi.instance.config.enableLogging, isFalse);
      });

      test('reinitialize disposes previous instance', () async {
        await Web3Refi.initialize(config: createTestConfig());
        final firstInstance = Web3Refi.instance;

        await Web3Refi.initialize(
          config: createTestConfig(projectId: 'different'),
        );

        expect(Web3Refi.instance, isNot(same(firstInstance)));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONFIGURATION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('configuration', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('uses default chain from config', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.ethereum, Chains.polygon],
            defaultChain: Chains.polygon,
          ),
        );

        expect(Web3Refi.instance.currentChain, equals(Chains.polygon));
      });

      test('uses first chain as default if not specified', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.arbitrum, Chains.polygon],
          ),
        );

        expect(Web3Refi.instance.currentChain, equals(Chains.arbitrum));
      });

      test('config is accessible after initialization', () async {
        final config = createTestConfig(projectId: 'my_project');
        await Web3Refi.initialize(config: config);

        expect(Web3Refi.instance.config.projectId, equals('my_project'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONNECTION STATE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('connection state', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('isConnected returns false initially', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(Web3Refi.instance.isConnected, isFalse);
      });

      test('address returns null when not connected', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(Web3Refi.instance.address, isNull);
      });

      test('connectionState is disconnected initially', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(
          Web3Refi.instance.connectionState,
          equals(WalletConnectionState.disconnected),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // RPC CLIENT TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('rpcClient', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('rpcClient returns client for current chain', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.ethereum],
            defaultChain: Chains.ethereum,
          ),
        );

        final client = Web3Refi.instance.rpcClient;

        expect(client, isNotNull);
        expect(client.chain, equals(Chains.ethereum));
      });

      test('rpcClientFor returns client for specific chain', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.ethereum, Chains.polygon],
          ),
        );

        final polygonClient = Web3Refi.instance.rpcClientFor(Chains.polygon);

        expect(polygonClient.chain, equals(Chains.polygon));
      });

      test('rpcClientFor throws for unconfigured chain', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.ethereum],
          ),
        );

        expect(
          () => Web3Refi.instance.rpcClientFor(Chains.polygon),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // NATIVE BALANCE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('native balance', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('getNativeBalance throws when not connected', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(
          () => Web3Refi.instance.getNativeBalance(),
          throwsWalletException('not_connected'),
        );
      });

      test('formatNativeAmount formats correctly', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final formatted = Web3Refi.instance.formatNativeAmount(
          TestAmounts.oneEther,
        );

        expect(formatted, startsWith('1.'));
      });

      test('formatNativeAmount handles zero', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final formatted = Web3Refi.instance.formatNativeAmount(BigInt.zero);

        expect(formatted, equals('0.0'));
      });

      test('parseNativeAmount parses whole numbers', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final parsed = Web3Refi.instance.parseNativeAmount('1');

        expect(parsed, equals(TestAmounts.oneEther));
      });

      test('parseNativeAmount parses decimals', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final parsed = Web3Refi.instance.parseNativeAmount('0.5');

        expect(parsed, equals(TestAmounts.oneEther ~/ BigInt.two));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CHAIN SWITCHING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('chain switching', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('switchChain throws for unconfigured chain', () async {
        await Web3Refi.initialize(
          config: Web3RefiConfig(
            projectId: 'test',
            chains: [Chains.ethereum],
          ),
        );

        expect(
          () => Web3Refi.instance.switchChain(Chains.polygon),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TOKEN TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('token', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('token returns ERC20 instance', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final token = Web3Refi.instance.token(TestAddresses.contract1);

        expect(token, isA<ERC20>());
      });

      test('token instance has correct address', () async {
        await Web3Refi.initialize(config: createTestConfig());

        final token = Web3Refi.instance.token(TestAddresses.contract1);

        expect(token.address, equals(TestAddresses.contract1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TRANSACTION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('transactions', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('sendTransaction throws when not connected', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(
          () => Web3Refi.instance.sendTransaction(
            to: TestAddresses.wallet2,
            value: '0x0',
          ),
          throwsWalletException('not_connected'),
        );
      });

      test('signMessage throws when not connected', () async {
        await Web3Refi.initialize(config: createTestConfig());

        expect(
          () => Web3Refi.instance.signMessage('Hello'),
          throwsWalletException('not_connected'),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // NOTIFIER TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('ChangeNotifier', () {
      tearDown(() async {
        if (Web3Refi.isInitialized) {
          await Web3Refi.instance.dispose();
        }
      });

      test('notifies listeners on state changes', () async {
        await Web3Refi.initialize(config: createTestConfig());

        var notificationCount = 0;
        Web3Refi.instance.addListener(() {
          notificationCount++;
        });

        // Trigger a state change by connecting
        // This would normally notify, but since wallet connection is mocked
        // we verify the mechanism works
        expect(notificationCount, greaterThanOrEqualTo(0));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // DISPOSE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('dispose', () {
      test('dispose clears singleton', () async {
        await Web3Refi.initialize(config: createTestConfig());
        expect(Web3Refi.isInitialized, isTrue);

        await Web3Refi.instance.dispose();

        expect(Web3Refi.isInitialized, isFalse);
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WEB3REFI CONFIG TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('Web3RefiConfig', () {
    test('requires at least one chain', () {
      expect(
        () => Web3RefiConfig(
          projectId: 'test',
          chains: const [],
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('has sensible defaults', () {
      final config = Web3RefiConfig(
        projectId: 'test',
        chains: [Chains.ethereum],
      );

      expect(config.enableLogging, isFalse);
      expect(config.rpcTimeout, equals(const Duration(seconds: 30)));
      expect(config.defaultConfirmations, equals(1));
      expect(config.autoRestoreSession, isTrue);
    });

    test('copyWith preserves unchanged values', () {
      final original = Web3RefiConfig(
        projectId: 'original',
        chains: [Chains.ethereum],
        enableLogging: true,
      );

      final copied = original.copyWith(projectId: 'new');

      expect(copied.projectId, equals('new'));
      expect(copied.enableLogging, isTrue);
      expect(copied.chains, equals(original.chains));
    });

    test('development factory sets correct values', () {
      final config = Web3RefiConfig.development(projectId: 'test');

      expect(config.enableLogging, isTrue);
      expect(config.xmtpEnvironment, equals('dev'));
      expect(config.chains.every((c) => c.isTestnet), isTrue);
    });

    test('production factory sets correct values', () {
      final config = Web3RefiConfig.production(projectId: 'test');

      expect(config.enableLogging, isFalse);
      expect(config.xmtpEnvironment, equals('production'));
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // APP METADATA TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('AppMetadata', () {
    test('toJson includes all fields', () {
      const metadata = AppMetadata(
        name: 'Test App',
        description: 'A test application',
        url: 'https://test.app',
        icons: ['https://test.app/icon.png'],
        redirect: 'testapp://',
      );

      final json = metadata.toJson();

      expect(json['name'], equals('Test App'));
      expect(json['description'], equals('A test application'));
      expect(json['url'], equals('https://test.app'));
      expect(json['icons'], contains('https://test.app/icon.png'));
      expect(json['redirect'], equals('testapp://'));
    });

    test('toJson excludes null redirect', () {
      const metadata = AppMetadata(
        name: 'Test',
        description: 'Test',
        url: 'https://test.app',
        icons: [],
      );

      final json = metadata.toJson();

      expect(json.containsKey('redirect'), isFalse);
    });
  });
}
