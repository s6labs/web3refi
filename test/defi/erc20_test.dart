import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';
import '../mocks/mock_rpc_client.dart';
import '../mocks/mock_wallet_manager.dart';

void main() {
  group('ERC20', () {
    late MockRpcClient mockRpc;
    late MockWalletManager mockWallet;
    late ERC20 token;

    setUp(() {
      mockRpc = MockRpcClient();
      mockWallet = MockWalletManager();
      
      // Setup common ERC20 responses
      mockRpc.setupErc20Token(
        address: TestAddresses.contract1,
        name: 'USD Coin',
        symbol: 'USDC',
        decimals: 6,
      );
      
      token = ERC20(
        address: TestAddresses.contract1,
        rpcClient: mockRpc,
        walletManager: mockWallet,
      );
    });

    tearDown(() {
      mockRpc.reset();
      mockWallet.reset();
    });

    // ════════════════════════════════════════════════════════════════════════
    // CONSTRUCTOR TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('constructor', () {
      test('creates token with address', () {
        expect(token.address, equals(TestAddresses.contract1));
      });

      test('stores rpc client reference', () {
        expect(token.rpcClient, equals(mockRpc));
      });

      test('stores wallet manager reference', () {
        expect(token.walletManager, equals(mockWallet));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // NAME TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('name', () {
      test('returns token name', () async {
        mockRpc.whenCall('eth_call').thenAnswer((params) {
          final data = (params[0] as Map)['data'] as String;
          if (data.startsWith('0x06fdde03')) {
            return mockStringResponse('USD Coin');
          }
          return '0x';
        });

        final name = await token.name();

        expect(name, equals('USD Coin'));
      });

      test('caches name after first call', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockStringResponse('Test Token'));

        await token.name();
        await token.name();

        // Should only call RPC once due to caching
        expect(mockRpc.callCount('eth_call'), equals(1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // SYMBOL TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('symbol', () {
      test('returns token symbol', () async {
        mockRpc.whenCall('eth_call').thenAnswer((params) {
          final data = (params[0] as Map)['data'] as String;
          if (data.startsWith('0x95d89b41')) {
            return mockStringResponse('USDC');
          }
          return '0x';
        });

        final symbol = await token.symbol();

        expect(symbol, equals('USDC'));
      });

      test('caches symbol after first call', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockStringResponse('TEST'));

        await token.symbol();
        await token.symbol();

        expect(mockRpc.callCount('eth_call'), equals(1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // DECIMALS TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('decimals', () {
      test('returns 6 for USDC-like tokens', () async {
        mockRpc.whenCall('eth_call').thenAnswer((params) {
          final data = (params[0] as Map)['data'] as String;
          if (data.startsWith('0x313ce567')) {
            return mockDecimalsResponse(6);
          }
          return '0x';
        });

        final decimals = await token.decimals();

        expect(decimals, equals(6));
      });

      test('returns 18 for ETH-like tokens', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(18));

        final decimals = await token.decimals();

        expect(decimals, equals(18));
      });

      test('caches decimals after first call', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        await token.decimals();
        await token.decimals();

        expect(mockRpc.callCount('eth_call'), equals(1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // BALANCE OF TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('balanceOf', () {
      test('returns balance for address', () async {
        final expectedBalance = BigInt.from(1000000000); // 1000 USDC
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(expectedBalance),
        );

        final balance = await token.balanceOf(TestAddresses.wallet1);

        expect(balance, equals(expectedBalance));
      });

      test('returns zero for empty balance', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(BigInt.zero));

        final balance = await token.balanceOf(TestAddresses.wallet1);

        expect(balance, equals(BigInt.zero));
      });

      test('calls eth_call with correct parameters', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(BigInt.zero));

        await token.balanceOf(TestAddresses.wallet1);

        expect(mockRpc.wasCalled('eth_call'), isTrue);
        final call = mockRpc.lastCallFor('eth_call')!;
        final params = call.params[0] as Map;
        expect(params['to'], equals(TestAddresses.contract1));
        expect(params['data'], startsWith('0x70a08231')); // balanceOf selector
      });

      test('handles large balances', () async {
        final largeBalance = BigInt.parse('999999999999999999999999999');
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(largeBalance));

        final balance = await token.balanceOf(TestAddresses.wallet1);

        expect(balance, equals(largeBalance));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ALLOWANCE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('allowance', () {
      test('returns allowance between owner and spender', () async {
        final expectedAllowance = BigInt.from(500000000);
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(expectedAllowance),
        );

        final allowance = await token.allowance(
          TestAddresses.wallet1,
          TestAddresses.wallet2,
        );

        expect(allowance, equals(expectedAllowance));
      });

      test('returns zero for no allowance', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(BigInt.zero));

        final allowance = await token.allowance(
          TestAddresses.wallet1,
          TestAddresses.wallet2,
        );

        expect(allowance, equals(BigInt.zero));
      });

      test('calls eth_call with correct selector', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(BigInt.zero));

        await token.allowance(TestAddresses.wallet1, TestAddresses.wallet2);

        final call = mockRpc.lastCallFor('eth_call')!;
        final params = call.params[0] as Map;
        expect(params['data'], startsWith('0xdd62ed3e')); // allowance selector
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TOTAL SUPPLY TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('totalSupply', () {
      test('returns total supply', () async {
        final supply = BigInt.from(10).pow(15); // 1 billion with 6 decimals
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(supply));

        final totalSupply = await token.totalSupply();

        expect(totalSupply, equals(supply));
      });

      test('calls eth_call with correct selector', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockBalanceResponse(BigInt.zero));

        await token.totalSupply();

        final call = mockRpc.lastCallFor('eth_call')!;
        final params = call.params[0] as Map;
        expect(params['data'], startsWith('0x18160ddd')); // totalSupply selector
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TRANSFER TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('transfer', () {
      setUp(() {
        mockWallet.simulateConnected();
        mockWallet.nextTransactionHash = TestTxHashes.confirmed;
        
        // Mock balance check
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(BigInt.from(1000000000)), // 1000 tokens
        );
      });

      test('sends transfer transaction', () async {
        final txHash = await token.transfer(
          to: TestAddresses.wallet2,
          amount: BigInt.from(100000000), // 100 tokens
        );

        expect(txHash, equals(TestTxHashes.confirmed));
      });

      test('throws when not connected', () async {
        mockWallet.simulateDisconnected();

        expect(
          () => token.transfer(
            to: TestAddresses.wallet2,
            amount: BigInt.from(100),
          ),
          throwsWalletException('not_connected'),
        );
      });

      test('throws on insufficient balance', () async {
        // Mock low balance
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(BigInt.from(50)), // Only 50 tokens
        );

        expect(
          () => token.transfer(
            to: TestAddresses.wallet2,
            amount: BigInt.from(100), // Trying to send 100
          ),
          throwsTransactionException('insufficient_balance'),
        );
      });

      test('calls wallet sendTransaction with correct data', () async {
        await token.transfer(
          to: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        expect(mockWallet.wasCalled('sendTransaction'), isTrue);
        final call = mockWallet.callsFor('sendTransaction').first;
        expect(call.params['to'], equals(TestAddresses.contract1));
        expect(call.params['data'], startsWith('0xa9059cbb')); // transfer selector
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // APPROVE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('approve', () {
      setUp(() {
        mockWallet.simulateConnected();
        mockWallet.nextTransactionHash = TestTxHashes.confirmed;
      });

      test('sends approve transaction', () async {
        final txHash = await token.approve(
          spender: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        expect(txHash, equals(TestTxHashes.confirmed));
      });

      test('throws when not connected', () async {
        mockWallet.simulateDisconnected();

        expect(
          () => token.approve(
            spender: TestAddresses.wallet2,
            amount: BigInt.from(100),
          ),
          throwsWalletException('not_connected'),
        );
      });

      test('calls wallet with correct data', () async {
        await token.approve(
          spender: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        final call = mockWallet.callsFor('sendTransaction').first;
        expect(call.params['data'], startsWith('0x095ea7b3')); // approve selector
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ENSURE APPROVAL TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('ensureApproval', () {
      setUp(() {
        mockWallet.simulateConnected();
        mockWallet.nextTransactionHash = TestTxHashes.confirmed;
      });

      test('returns null if already approved', () async {
        // Mock sufficient allowance
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(BigInt.from(1000)),
        );

        final txHash = await token.ensureApproval(
          spender: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        expect(txHash, isNull);
        expect(mockWallet.wasCalled('sendTransaction'), isFalse);
      });

      test('sends approval if insufficient allowance', () async {
        // Mock zero allowance
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(BigInt.zero),
        );

        final txHash = await token.ensureApproval(
          spender: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        expect(txHash, isNotNull);
        expect(mockWallet.wasCalled('sendTransaction'), isTrue);
      });

      test('throws when not connected', () async {
        mockWallet.simulateDisconnected();

        expect(
          () => token.ensureApproval(
            spender: TestAddresses.wallet2,
            amount: BigInt.from(100),
          ),
          throwsWalletException('not_connected'),
        );
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // APPROVE INFINITE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('approveInfinite', () {
      setUp(() {
        mockWallet.simulateConnected();
        mockWallet.nextTransactionHash = TestTxHashes.confirmed;
      });

      test('approves max uint256', () async {
        await token.approveInfinite(TestAddresses.wallet2);

        final call = mockWallet.callsFor('sendTransaction').first;
        final data = call.params['data'] as String;
        
        // Should contain max uint256 (all f's)
        expect(data, contains('ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // FORMAT AMOUNT TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('formatAmount', () {
      test('formats 6 decimal token correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final formatted = await token.formatAmount(BigInt.from(1000000));

        expect(formatted, equals('1.0'));
      });

      test('formats 18 decimal token correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(18));

        final formatted = await token.formatAmount(TestAmounts.oneEther);

        expect(formatted, startsWith('1.'));
      });

      test('formats zero correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final formatted = await token.formatAmount(BigInt.zero);

        expect(formatted, equals('0.0'));
      });

      test('handles fractional amounts', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final formatted = await token.formatAmount(BigInt.from(1500000));

        expect(formatted, equals('1.5'));
      });

      test('handles small amounts', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final formatted = await token.formatAmount(BigInt.from(1));

        expect(formatted, isNotEmpty);
      });

      test('respects displayDecimals parameter', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(18));

        final formatted = await token.formatAmount(
          BigInt.from(12345678901234567890),
          displayDecimals: 2,
        );

        // Should only show 2 decimal places
        final parts = formatted.split('.');
        expect(parts.length, equals(2));
        expect(parts[1].length, lessThanOrEqualTo(2));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // PARSE AMOUNT TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('parseAmount', () {
      test('parses whole number correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final parsed = await token.parseAmount('100');

        expect(parsed, equals(BigInt.from(100000000)));
      });

      test('parses decimal correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final parsed = await token.parseAmount('100.50');

        expect(parsed, equals(BigInt.from(100500000)));
      });

      test('parses zero correctly', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final parsed = await token.parseAmount('0');

        expect(parsed, equals(BigInt.zero));
      });

      test('handles 18 decimals', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(18));

        final parsed = await token.parseAmount('1');

        expect(parsed, equals(TestAmounts.oneEther));
      });

      test('handles many decimal places', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final parsed = await token.parseAmount('1.123456789');

        // Should truncate to 6 decimals
        expect(parsed, equals(BigInt.from(1123456)));
      });

      test('handles no decimal places', () async {
        mockRpc.whenCall('eth_call').thenReturn(mockDecimalsResponse(6));

        final parsed = await token.parseAmount('1000');

        expect(parsed, equals(BigInt.from(1000000000)));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // WATCH BALANCE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('watchBalance', () {
      test('emits balance updates', () async {
        var callCount = 0;
        mockRpc.whenCall('eth_call').thenAnswer((_) {
          callCount++;
          return mockBalanceResponse(BigInt.from(callCount * 100));
        });

        final balances = <BigInt>[];
        final subscription = token
            .watchBalance(
              TestAddresses.wallet1,
              interval: const Duration(milliseconds: 50),
            )
            .take(3)
            .listen((balance) => balances.add(balance));

        await Future.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        expect(balances, isNotEmpty);
        // Each balance should be different (increasing)
        for (var i = 1; i < balances.length; i++) {
          expect(balances[i], greaterThan(balances[i - 1]));
        }
      });

      test('only emits when balance changes', () async {
        mockRpc.whenCall('eth_call').thenReturn(
          mockBalanceResponse(BigInt.from(100)),
        );

        final balances = <BigInt>[];
        final subscription = token
            .watchBalance(
              TestAddresses.wallet1,
              interval: const Duration(milliseconds: 50),
            )
            .take(2)
            .listen((balance) => balances.add(balance));

        await Future.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        // Should only emit once since balance doesn't change
        expect(balances.length, equals(1));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // TRANSFER FROM TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('transferFrom', () {
      setUp(() {
        mockWallet.simulateConnected();
        mockWallet.nextTransactionHash = TestTxHashes.confirmed;
      });

      test('sends transferFrom transaction', () async {
        final txHash = await token.transferFrom(
          from: TestAddresses.wallet1,
          to: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        expect(txHash, equals(TestTxHashes.confirmed));
      });

      test('calls wallet with correct selector', () async {
        await token.transferFrom(
          from: TestAddresses.wallet1,
          to: TestAddresses.wallet2,
          amount: BigInt.from(100),
        );

        final call = mockWallet.callsFor('sendTransaction').first;
        expect(call.params['data'], startsWith('0x23b872dd')); // transferFrom selector
      });

      test('throws when not connected', () async {
        mockWallet.simulateDisconnected();

        expect(
          () => token.transferFrom(
            from: TestAddresses.wallet1,
            to: TestAddresses.wallet2,
            amount: BigInt.from(100),
          ),
          throwsWalletException('not_connected'),
        );
      });
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSACTION EXCEPTION TESTS
  // ══════════════════════════════════════════════════════════════════════════

  group('TransactionException', () {
    test('insufficientBalance has correct code', () {
      final exception = TransactionException.insufficientBalance(
        required: '100',
        available: '50',
        symbol: 'USDC',
      );

      expect(exception.code, equals('insufficient_balance'));
      expect(exception.message, contains('100'));
      expect(exception.message, contains('50'));
      expect(exception.message, contains('USDC'));
    });

    test('insufficientGas has correct code', () {
      final exception = TransactionException.insufficientGas(
        required: '0.01',
        available: '0.001',
        symbol: 'ETH',
      );

      expect(exception.code, equals('insufficient_gas'));
    });

    test('reverted has correct code', () {
      final exception = TransactionException.reverted(TestTxHashes.failed);

      expect(exception.code, equals('tx_reverted'));
      expect(exception.txHash, equals(TestTxHashes.failed));
    });

    test('toUserMessage returns friendly message', () {
      final exception = TransactionException.insufficientBalance(
        required: '100',
        available: '50',
      );

      final message = exception.toUserMessage();

      expect(message, isNotEmpty);
      expect(message.toLowerCase(), contains('balance'));
    });
  });
}
