import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';
import '../mocks/mock_wallet_manager.dart';

void main() {
  group('WalletManager', () {
    late MockWalletManager walletManager;

    setUp(() {
      walletManager = MockWalletManager(
        chains: [TestChains.mockEthereum, TestChains.mockPolygon],
        defaultChain: TestChains.mockEthereum,
      );
    });

    tearDown(() {
      walletManager.reset();
    });

    // ════════════════════════════════════════════════════════════════════════
    // INITIAL STATE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('initial state', () {
      test('starts disconnected', () {
        expect(walletManager.state, equals(WalletConnectionState.disconnected));
        expect(walletManager.isConnected, isFalse);
      });

      test('address is null when disconnected', () {
        expect(walletManager.address, isNull);
      });

      test('chainId is null when disconnected', () {
        expect(walletManager.chainId, isNull);
      });

      test('currentChain is null when disconnected', () {
        expect(walletManager.currentChain, isNull);
      });

      test('userId is null when disconnected', () {
        expect(walletManager.userId, isNull);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONNECTION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('connect', () {
      test('connects successfully', () async {
        await walletManager.connect();

        expect(walletManager.isConnected, isTrue);
        expect(walletManager.state, equals(WalletConnectionState.connected));
      });

      test('sets address after connection', () async {
        await walletManager.connect();

        expect(walletManager.address, isNotNull);
        expect(walletManager.address, isValidEthereumAddress);
      });

      test('sets chainId after connection', () async {
        await walletManager.connect();

        expect(walletManager.chainId, equals(TestChains.mockEthereum.chainId));
      });

      test('uses preferred chain when specified', () async {
        await walletManager.connect(preferredChain: TestChains.mockPolygon);

        expect(walletManager.chainId, equals(TestChains.mockPolygon.chainId));
      });

      test('notifies listeners on connection', () async {
        var notified = false;
        walletManager.addListener(() => notified = true);

        await walletManager.connect();

        expect(notified, isTrue);
      });

      test('records connect call', () async {
        await walletManager.connect(preferredChain: TestChains.mockPolygon);

        expect(walletManager.wasCalled('connect'), isTrue);
        expect(walletManager.callCount('connect'), equals(1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONNECTION ERROR TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('connection errors', () {
      test('throws WalletException on user rejection', () async {
        walletManager.simulateUserRejection = true;

        expect(
          () => walletManager.connect(),
          throwsWalletException('user_rejected'),
        );
      });

      test('throws WalletException on timeout', () async {
        walletManager.simulateTimeout = true;

        expect(
          () => walletManager.connect(),
          throwsWalletException('connection_timeout'),
        );
      });

      test('throws WalletException when wallet not installed', () async {
        walletManager.simulateWalletNotInstalled = true;

        expect(
          () => walletManager.connect(),
          throwsWalletException('wallet_not_installed'),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // DISCONNECT TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('disconnect', () {
      test('disconnects successfully', () async {
        walletManager.simulateConnected();
        expect(walletManager.isConnected, isTrue);

        await walletManager.disconnect();

        expect(walletManager.isConnected, isFalse);
        expect(walletManager.state, equals(WalletConnectionState.disconnected));
      });

      test('clears address on disconnect', () async {
        walletManager.simulateConnected();

        await walletManager.disconnect();

        expect(walletManager.address, isNull);
      });

      test('clears chainId on disconnect', () async {
        walletManager.simulateConnected();

        await walletManager.disconnect();

        expect(walletManager.chainId, isNull);
      });

      test('notifies listeners on disconnect', () async {
        walletManager.simulateConnected();
        var notified = false;
        walletManager.addListener(() => notified = true);

        await walletManager.disconnect();

        expect(notified, isTrue);
      });

      test('records disconnect call', () async {
        walletManager.simulateConnected();

        await walletManager.disconnect();

        expect(walletManager.wasCalled('disconnect'), isTrue);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CHAIN SWITCHING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('switchChain', () {
      test('switches chain successfully', () async {
        walletManager.simulateConnected();

        await walletManager.switchChain(TestChains.mockPolygon);

        expect(walletManager.chainId, equals(TestChains.mockPolygon.chainId));
      });

      test('throws when not connected', () async {
        expect(
          () => walletManager.switchChain(TestChains.mockPolygon),
          throwsWalletException('not_connected'),
        );
      });

      test('throws for unsupported chain', () async {
        walletManager.simulateConnected();

        expect(
          () => walletManager.switchChain(Chains.arbitrum),
          throwsWalletException('chain_not_supported'),
        );
      });

      test('throws on user rejection', () async {
        walletManager.simulateConnected();
        walletManager.simulateUserRejection = true;

        expect(
          () => walletManager.switchChain(TestChains.mockPolygon),
          throwsWalletException('user_rejected'),
        );
      });

      test('notifies listeners on chain switch', () async {
        walletManager.simulateConnected();
        var notified = false;
        walletManager.addListener(() => notified = true);

        await walletManager.switchChain(TestChains.mockPolygon);

        expect(notified, isTrue);
      });

      test('records switchChain call', () async {
        walletManager.simulateConnected();

        await walletManager.switchChain(TestChains.mockPolygon);

        expect(walletManager.wasCalled('switchChain'), isTrue);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TRANSACTION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('sendTransaction', () {
      test('sends transaction successfully', () async {
        walletManager.simulateConnected();
        walletManager.nextTransactionHash = TestTxHashes.confirmed;

        final txHash = await walletManager.sendTransaction(
          to: TestAddresses.wallet2,
          value: '0x1',
        );

        expect(txHash, equals(TestTxHashes.confirmed));
      });

      test('throws when not connected', () async {
        expect(
          () => walletManager.sendTransaction(
            to: TestAddresses.wallet2,
            value: '0x1',
          ),
          throwsWalletException('not_connected'),
        );
      });

      test('throws on user rejection', () async {
        walletManager.simulateConnected();
        walletManager.simulateUserRejection = true;

        expect(
          () => walletManager.sendTransaction(
            to: TestAddresses.wallet2,
            value: '0x1',
          ),
          throwsWalletException('user_rejected'),
        );
      });

      test('records transaction parameters', () async {
        walletManager.simulateConnected();

        await walletManager.sendTransaction(
          to: TestAddresses.wallet2,
          value: '0x1',
          data: '0xabc',
          gas: '0x5208',
          gasPrice: '0x4a817c800',
        );

        final call = walletManager.callsFor('sendTransaction').first;
        expect(call.params['to'], equals(TestAddresses.wallet2));
        expect(call.params['value'], equals('0x1'));
        expect(call.params['data'], equals('0xabc'));
        expect(call.params['gas'], equals('0x5208'));
        expect(call.params['gasPrice'], equals('0x4a817c800'));
      });

      test('returns valid transaction hash', () async {
        walletManager.simulateConnected();

        final txHash = await walletManager.sendTransaction(
          to: TestAddresses.wallet2,
          value: '0x0',
        );

        expect(txHash, startsWith('0x'));
        expect(txHash.length, greaterThanOrEqualTo(10));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // MESSAGE SIGNING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('signMessage', () {
      test('signs message successfully', () async {
        walletManager.simulateConnected();
        walletManager.nextSignature = '0xsignature123';

        final signature = await walletManager.signMessage('Hello Web3');

        expect(signature, equals('0xsignature123'));
      });

      test('throws when not connected', () async {
        expect(
          () => walletManager.signMessage('Hello'),
          throwsWalletException('not_connected'),
        );
      });

      test('throws on user rejection', () async {
        walletManager.simulateConnected();
        walletManager.simulateUserRejection = true;

        expect(
          () => walletManager.signMessage('Hello'),
          throwsWalletException('user_rejected'),
        );
      });

      test('records message parameter', () async {
        walletManager.simulateConnected();

        await walletManager.signMessage('Test message');

        final call = walletManager.callsFor('signMessage').first;
        expect(call.params['message'], equals('Test message'));
      });

      test('returns valid signature format', () async {
        walletManager.simulateConnected();

        final signature = await walletManager.signMessage('Hello');

        expect(signature, startsWith('0x'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TYPED DATA SIGNING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('signTypedData', () {
      test('signs typed data successfully', () async {
        walletManager.simulateConnected();
        walletManager.nextSignature = '0xtypedsig';

        final signature = await walletManager.signTypedData({
          'domain': {'name': 'Test'},
          'message': {'value': 123},
        });

        expect(signature, equals('0xtypedsig'));
      });

      test('throws when not connected', () async {
        expect(
          () => walletManager.signTypedData({}),
          throwsWalletException('not_connected'),
        );
      });

      test('throws on user rejection', () async {
        walletManager.simulateConnected();
        walletManager.simulateUserRejection = true;

        expect(
          () => walletManager.signTypedData({}),
          throwsWalletException('user_rejected'),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // SESSION MANAGEMENT TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('session management', () {
      test('saveSession records call', () async {
        await walletManager.saveSession();

        expect(walletManager.wasCalled('saveSession'), isTrue);
      });

      test('restoreSession records call', () async {
        await walletManager.restoreSession();

        expect(walletManager.wasCalled('restoreSession'), isTrue);
      });

      test('clearSession records call', () async {
        await walletManager.clearSession();

        expect(walletManager.wasCalled('clearSession'), isTrue);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // SIMULATE CONNECTED TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('simulateConnected', () {
      test('sets connected state', () {
        walletManager.simulateConnected();

        expect(walletManager.isConnected, isTrue);
        expect(walletManager.state, equals(WalletConnectionState.connected));
      });

      test('accepts custom address', () {
        walletManager.simulateConnected(address: TestAddresses.wallet2);

        expect(walletManager.address, equals(TestAddresses.wallet2));
      });

      test('accepts custom chainId', () {
        walletManager.simulateConnected(chainId: 137);

        expect(walletManager.chainId, equals(137));
      });

      test('accepts custom userId', () {
        walletManager.simulateConnected(userId: 'user123');

        expect(walletManager.userId, equals('user123'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ERROR STATE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('error state', () {
      test('simulateError sets error state', () {
        walletManager.simulateError('Test error');

        expect(walletManager.state, equals(WalletConnectionState.error));
        expect(walletManager.errorMessage, equals('Test error'));
      });

      test('error state clears on successful connect', () async {
        walletManager.simulateError('Previous error');

        await walletManager.connect();

        expect(walletManager.state, equals(WalletConnectionState.connected));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // RESET TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('reset', () {
      test('clears all state', () {
        walletManager.simulateConnected();
        walletManager.simulateUserRejection = true;
        walletManager.nextTransactionHash = '0x123';

        walletManager.reset();

        expect(walletManager.isConnected, isFalse);
        expect(walletManager.simulateUserRejection, isFalse);
        expect(walletManager.nextTransactionHash, isNull);
        expect(walletManager.calls, isEmpty);
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // CALL TRACKING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('call tracking', () {
      test('tracks all calls', () async {
        walletManager.simulateConnected();

        await walletManager.switchChain(TestChains.mockPolygon);
        await walletManager.signMessage('Test');
        await walletManager.sendTransaction(to: TestAddresses.wallet2, value: '0x0');

        expect(walletManager.calls.length, equals(3));
      });

      test('callsFor returns filtered calls', () async {
        walletManager.simulateConnected();

        await walletManager.signMessage('Test1');
        await walletManager.signMessage('Test2');
        await walletManager.sendTransaction(to: TestAddresses.wallet2, value: '0x0');

        expect(walletManager.callsFor('signMessage').length, equals(2));
        expect(walletManager.callsFor('sendTransaction').length, equals(1));
      });

      test('callCount returns correct count', () async {
        walletManager.simulateConnected();

        await walletManager.signMessage('Test1');
        await walletManager.signMessage('Test2');
        await walletManager.signMessage('Test3');

        expect(walletManager.callCount('signMessage'), equals(3));
        expect(walletManager.callCount('sendTransaction'), equals(0));
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET EXCEPTION TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('WalletException', () {
    test('userRejected has correct code', () {
      final exception = WalletException.userRejected();

      expect(exception.code, equals('user_rejected'));
    });

    test('walletNotInstalled includes wallet name', () {
      final exception = WalletException.walletNotInstalled('MetaMask');

      expect(exception.message, contains('MetaMask'));
      expect(exception.code, equals('wallet_not_installed'));
    });

    test('sessionExpired has correct code', () {
      final exception = WalletException.sessionExpired();

      expect(exception.code, equals('session_expired'));
    });

    test('notConnected has correct code', () {
      final exception = WalletException.notConnected();

      expect(exception.code, equals('not_connected'));
    });

    test('connectionTimeout has correct code', () {
      final exception = WalletException.connectionTimeout();

      expect(exception.code, equals('connection_timeout'));
    });

    test('chainNotSupported includes chain name', () {
      final exception = WalletException.chainNotSupported('Polygon');

      expect(exception.message, contains('Polygon'));
      expect(exception.code, equals('chain_not_supported'));
    });

    test('toUserMessage returns friendly message', () {
      final exception = WalletException.userRejected();

      final message = exception.toUserMessage();

      expect(message, isNotEmpty);
      expect(message, isNot(contains('user_rejected'))); // Not raw code
    });
  });
}
