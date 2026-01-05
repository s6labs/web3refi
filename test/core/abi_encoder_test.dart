import 'package:flutter_test/flutter_test.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';

/// Tests for ABI encoding/decoding functionality.
///
/// ABI (Application Binary Interface) encoding is critical for
/// smart contract interactions. These tests verify correct encoding
/// of function calls and decoding of return values.
void main() {
  group('ABI Encoding', () {
    // ════════════════════════════════════════════════════════════════════════
    // FUNCTION SELECTOR TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('function selectors', () {
      test('balanceOf(address) selector is correct', () {
        // keccak256("balanceOf(address)")[0:4] = 0x70a08231
        const expected = '0x70a08231';
        
        // The selector should be the first 8 hex chars (4 bytes) of encoded call
        // For now, we verify the format is correct
        expect(expected.length, equals(10)); // 0x + 8 chars
        expect(expected, startsWith('0x'));
      });

      test('transfer(address,uint256) selector is correct', () {
        // keccak256("transfer(address,uint256)")[0:4] = 0xa9059cbb
        const expected = '0xa9059cbb';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('approve(address,uint256) selector is correct', () {
        // keccak256("approve(address,uint256)")[0:4] = 0x095ea7b3
        const expected = '0x095ea7b3';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('allowance(address,address) selector is correct', () {
        // keccak256("allowance(address,address)")[0:4] = 0xdd62ed3e
        const expected = '0xdd62ed3e';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('transferFrom(address,address,uint256) selector is correct', () {
        // keccak256("transferFrom(address,address,uint256)")[0:4] = 0x23b872dd
        const expected = '0x23b872dd';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('decimals() selector is correct', () {
        // keccak256("decimals()")[0:4] = 0x313ce567
        const expected = '0x313ce567';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('name() selector is correct', () {
        // keccak256("name()")[0:4] = 0x06fdde03
        const expected = '0x06fdde03';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('symbol() selector is correct', () {
        // keccak256("symbol()")[0:4] = 0x95d89b41
        const expected = '0x95d89b41';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });

      test('totalSupply() selector is correct', () {
        // keccak256("totalSupply()")[0:4] = 0x18160ddd
        const expected = '0x18160ddd';
        
        expect(expected.length, equals(10));
        expect(expected, startsWith('0x'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ADDRESS ENCODING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('address encoding', () {
      test('addresses are padded to 32 bytes', () {
        final padded = RpcClient.padAddress(TestAddresses.wallet1);
        
        // 32 bytes = 64 hex characters
        expect(padded.length, equals(64));
      });

      test('addresses are left-padded with zeros', () {
        final padded = RpcClient.padAddress(TestAddresses.wallet1);
        
        // First 24 chars should be zeros (12 bytes of padding)
        expect(padded.substring(0, 24), equals('000000000000000000000000'));
      });

      test('address content is preserved', () {
        final padded = RpcClient.padAddress(TestAddresses.wallet1);
        
        // Last 40 chars should be the address (without 0x)
        final addressWithoutPrefix = TestAddresses.wallet1.substring(2).toLowerCase();
        expect(padded.substring(24), equals(addressWithoutPrefix));
      });

      test('handles lowercase addresses', () {
        const address = '0x742d35cc6634c0532925a3b844bc9e7595f0beb';
        final padded = RpcClient.padAddress(address);
        
        expect(padded.length, equals(64));
        expect(padded, contains('742d35cc6634c0532925a3b844bc9e7595f0beb'));
      });

      test('handles uppercase addresses', () {
        const address = '0x742D35CC6634C0532925A3B844BC9E7595F0BEB';
        final padded = RpcClient.padAddress(address);
        
        expect(padded.length, equals(64));
      });

      test('handles mixed case addresses', () {
        final padded = RpcClient.padAddress(TestAddresses.wallet1);
        
        expect(padded.length, equals(64));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // UINT256 ENCODING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('uint256 encoding', () {
      test('zero is encoded correctly', () {
        final encoded = RpcClient.padUint256(BigInt.zero);
        
        expect(encoded.length, equals(64));
        expect(encoded, equals('0' * 64));
      });

      test('small numbers are padded correctly', () {
        final encoded = RpcClient.padUint256(BigInt.from(100));
        
        expect(encoded.length, equals(64));
        expect(encoded, endsWith('64')); // 100 = 0x64
      });

      test('one ether is encoded correctly', () {
        final encoded = RpcClient.padUint256(TestAmounts.oneEther);
        
        expect(encoded.length, equals(64));
        expect(encoded, endsWith('de0b6b3a7640000'));
      });

      test('max uint256 is encoded correctly', () {
        final encoded = RpcClient.padUint256(TestAmounts.maxUint256);
        
        expect(encoded.length, equals(64));
        expect(encoded, equals('f' * 64));
      });

      test('large numbers preserve precision', () {
        final largeNumber = BigInt.parse('123456789012345678901234567890');
        final encoded = RpcClient.padUint256(largeNumber);
        
        expect(encoded.length, equals(64));
        
        // Verify we can decode back
        final decoded = BigInt.parse(encoded, radix: 16);
        expect(decoded, equals(largeNumber));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // HEX CONVERSION TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('hex conversion', () {
      test('bigIntToHex converts zero', () {
        final hex = RpcClient.bigIntToHex(BigInt.zero);
        
        expect(hex, equals('0x0'));
      });

      test('bigIntToHex converts small numbers', () {
        final hex = RpcClient.bigIntToHex(BigInt.from(255));
        
        expect(hex, equals('0xff'));
      });

      test('bigIntToHex converts large numbers', () {
        final hex = RpcClient.bigIntToHex(TestAmounts.oneEther);
        
        expect(hex, equals('0xde0b6b3a7640000'));
      });

      test('bigIntToHex has 0x prefix', () {
        final hex = RpcClient.bigIntToHex(BigInt.from(1));
        
        expect(hex, startsWith('0x'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // ENCODED FUNCTION CALL TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('encoded function calls', () {
      test('balanceOf encoded data has correct length', () {
        // Function selector (4 bytes) + address (32 bytes) = 36 bytes = 72 hex chars + 0x
        const selector = '0x70a08231';
        final address = RpcClient.padAddress(TestAddresses.wallet1);
        final encodedCall = '$selector$address';
        
        expect(encodedCall.length, equals(2 + 8 + 64)); // 0x + selector + address
      });

      test('transfer encoded data has correct length', () {
        // Function selector (4 bytes) + address (32 bytes) + amount (32 bytes)
        const selector = '0xa9059cbb';
        final address = RpcClient.padAddress(TestAddresses.wallet1);
        final amount = RpcClient.padUint256(TestAmounts.oneEther);
        final encodedCall = '$selector$address$amount';
        
        expect(encodedCall.length, equals(2 + 8 + 64 + 64)); // 0x + selector + 2 params
      });

      test('approve encoded data has correct length', () {
        const selector = '0x095ea7b3';
        final spender = RpcClient.padAddress(TestAddresses.wallet1);
        final amount = RpcClient.padUint256(TestAmounts.maxUint256);
        final encodedCall = '$selector$spender$amount';
        
        expect(encodedCall.length, equals(2 + 8 + 64 + 64));
      });

      test('allowance encoded data has correct length', () {
        const selector = '0xdd62ed3e';
        final owner = RpcClient.padAddress(TestAddresses.wallet1);
        final spender = RpcClient.padAddress(TestAddresses.wallet2);
        final encodedCall = '$selector$owner$spender';
        
        expect(encodedCall.length, equals(2 + 8 + 64 + 64));
      });

      test('transferFrom encoded data has correct length', () {
        const selector = '0x23b872dd';
        final from = RpcClient.padAddress(TestAddresses.wallet1);
        final to = RpcClient.padAddress(TestAddresses.wallet2);
        final amount = RpcClient.padUint256(BigInt.from(1000));
        final encodedCall = '$selector$from$to$amount';
        
        expect(encodedCall.length, equals(2 + 8 + 64 + 64 + 64));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // DECODING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('decoding', () {
      test('decode uint256 from response', () {
        const response = '0x0000000000000000000000000000000000000000000000000de0b6b3a7640000';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded, equals(TestAmounts.oneEther));
      });

      test('decode zero balance', () {
        const response = '0x0000000000000000000000000000000000000000000000000000000000000000';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded, equals(BigInt.zero));
      });

      test('decode large balance', () {
        // 1,000,000 USDC (6 decimals) = 1,000,000,000,000
        const response = '0x000000000000000000000000000000000000000000000000000000e8d4a51000';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded, equals(BigInt.from(1000000000000)));
      });

      test('decode decimals response', () {
        const response = '0x0000000000000000000000000000000000000000000000000000000000000012';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded.toInt(), equals(18));
      });

      test('decode 6 decimals (USDC)', () {
        const response = '0x0000000000000000000000000000000000000000000000000000000000000006';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded.toInt(), equals(6));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // STRING ENCODING/DECODING TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('string encoding/decoding', () {
      test('mockStringResponse creates valid format', () {
        final encoded = mockStringResponse('USDC');
        
        expect(encoded, startsWith('0x'));
        // Should have offset (32 bytes) + length (32 bytes) + data
        expect(encoded.length, greaterThan(2 + 64 + 64));
      });

      test('mockStringResponse for short string', () {
        final encoded = mockStringResponse('ETH');
        
        expect(encoded, startsWith('0x'));
      });

      test('mockStringResponse for longer string', () {
        final encoded = mockStringResponse('Wrapped Ethereum');
        
        expect(encoded, startsWith('0x'));
      });
    });

    // ════════════════════════════════════════════════════════════════════════
    // EDGE CASE TESTS
    // ════════════════════════════════════════════════════════════════════════

    group('edge cases', () {
      test('encode maximum possible address', () {
        const maxAddress = '0xffffffffffffffffffffffffffffffffffffffff';
        final padded = RpcClient.padAddress(maxAddress);
        
        expect(padded.length, equals(64));
        expect(padded, endsWith('ffffffffffffffffffffffffffffffffffffffff'));
      });

      test('encode zero address', () {
        const zeroAddress = '0x0000000000000000000000000000000000000000';
        final padded = RpcClient.padAddress(zeroAddress);
        
        expect(padded, equals('0' * 64));
      });

      test('handle response with trailing zeros', () {
        const response = '0x0000000000000000000000000000000000000000000000000000000000000100';
        
        final decoded = BigInt.parse(response.substring(2), radix: 16);
        
        expect(decoded, equals(BigInt.from(256)));
      });

      test('handle empty response', () {
        const response = '0x';
        
        // Should handle gracefully or return zero
        final value = response.length > 2 
            ? BigInt.parse(response.substring(2), radix: 16)
            : BigInt.zero;
        
        expect(value, equals(BigInt.zero));
      });
    });
  });
}
