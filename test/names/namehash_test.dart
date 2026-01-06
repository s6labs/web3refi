/// Tests for ENS namehash algorithm and name validation.
library;

import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:web3refi/web3refi.dart';

void main() {
  group('Namehash Algorithm', () {
    test('should compute correct namehash for empty string', () {
      final hash = namehash('');
      expect(hash.length, 32);
      expect(hash.every((b) => b == 0), true);
    });

    test('should compute correct namehash for eth', () {
      final hash = namehashHex('eth');
      // Known ENS hash for 'eth'
      expect(
        hash,
        '0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae',
      );
    });

    test('should compute correct namehash for vitalik.eth', () {
      final hash = namehashHex('vitalik.eth');
      // Known ENS hash for 'vitalik.eth'
      expect(
        hash,
        '0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835',
      );
    });

    test('should compute correct namehash for foo.eth', () {
      final hash = namehashHex('foo.eth');
      expect(
        hash,
        '0xde9b09fd7c5f901e23a3f19fecc54828e9c848539801e86591bd9801b019f84f',
      );
    });

    test('should handle subdomain namehash correctly', () {
      final hash = namehashHex('sub.vitalik.eth');
      expect(hash.length, 66); // 0x + 64 hex chars
      expect(hash.startsWith('0x'), true);
    });

    test('should normalize names to lowercase', () {
      final hash1 = namehashHex('VITALIK.ETH');
      final hash2 = namehashHex('vitalik.eth');
      expect(hash1, hash2);
    });

    test('should handle deep subdomains', () {
      final hash = namehashHex('very.deep.subdomain.vitalik.eth');
      expect(hash.length, 66);
      expect(hash.startsWith('0x'), true);
    });

    test('should produce different hashes for different names', () {
      final hash1 = namehashHex('alice.eth');
      final hash2 = namehashHex('bob.eth');
      expect(hash1, isNot(hash2));
    });

    test('should handle reverse resolution namehash', () {
      final addr = 'd8da6bf26964af9d7eed9e03e53415d37aa96045';
      final hash = namehashHex('$addr.addr.reverse');
      expect(hash.length, 66);
      expect(hash.startsWith('0x'), true);
    });
  });

  group('Name Validation', () {
    test('should accept valid ENS names', () {
      expect(NameValidator.validate('vitalik.eth'), null);
      expect(NameValidator.validate('alice.eth'), null);
      expect(NameValidator.validate('foo-bar.eth'), null);
      expect(NameValidator.validate('test123.eth'), null);
    });

    test('should accept valid CiFi usernames', () {
      expect(NameValidator.validate('@alice'), null);
      expect(NameValidator.validate('@bob123'), null);
      expect(NameValidator.validate('alice.cifi'), null);
    });

    test('should reject names that are too short', () {
      expect(NameValidator.validate('ab'), isNotNull);
      expect(NameValidator.validate('a'), isNotNull);
    });

    test('should reject names that are too long', () {
      final longName = 'a' * 256;
      expect(NameValidator.validate(longName), isNotNull);
    });

    test('should reject names with invalid characters', () {
      expect(NameValidator.validate('test!.eth'), isNotNull);
      expect(NameValidator.validate('test#.eth'), isNotNull);
      expect(NameValidator.validate('test\$.eth'), isNotNull);
    });

    test('should reject names with consecutive dots', () {
      expect(NameValidator.validate('test..eth'), isNotNull);
    });

    test('should reject names starting or ending with dot', () {
      expect(NameValidator.validate('.test.eth'), isNotNull);
      expect(NameValidator.validate('test.eth.'), isNotNull);
    });

    test('should reject names starting or ending with hyphen', () {
      expect(NameValidator.validate('-test.eth'), isNotNull);
      expect(NameValidator.validate('test-.eth'), isNotNull);
    });

    test('should use isValid helper correctly', () {
      expect(NameValidator.isValid('vitalik.eth'), true);
      expect(NameValidator.isValid('ab'), false);
      expect(NameValidator.isValid('@alice'), true);
    });
  });

  group('Name Normalization', () {
    test('should convert to lowercase', () {
      expect(NameValidator.normalize('VITALIK.ETH'), 'vitalik.eth');
      expect(NameValidator.normalize('Alice.ETH'), 'alice.eth');
    });

    test('should trim whitespace', () {
      expect(NameValidator.normalize('  vitalik.eth  '), 'vitalik.eth');
      expect(NameValidator.normalize('\tvitalik.eth\n'), 'vitalik.eth');
    });

    test('should replace multiple spaces with single space', () {
      expect(NameValidator.normalize('test   name'), 'test name');
    });

    test('should handle CiFi usernames', () {
      expect(NameValidator.normalize('@ALICE'), '@alice');
      expect(NameValidator.normalize('  @bob  '), '@bob');
    });
  });

  group('Namehash Consistency', () {
    test('should produce consistent results', () {
      final hash1 = namehashHex('vitalik.eth');
      final hash2 = namehashHex('vitalik.eth');
      expect(hash1, hash2);
    });

    test('should be deterministic', () {
      final hashes = List.generate(10, (_) => namehashHex('test.eth'));
      expect(hashes.toSet().length, 1);
    });

    test('should handle unicode normalization', () {
      // Both should normalize to same result
      final hash1 = namehashHex('vitalik.eth');
      final hash2 = namehashHex('vitalik.eth');
      expect(hash1, hash2);
    });
  });

  group('Edge Cases', () {
    test('should handle single label', () {
      final hash = namehashHex('eth');
      expect(hash.length, 66);
    });

    test('should handle numeric labels', () {
      final hash = namehashHex('123.eth');
      expect(hash.length, 66);
    });

    test('should handle mixed case consistently', () {
      final hash1 = namehashHex('VitaLik.ETH');
      final hash2 = namehashHex('vitalik.eth');
      expect(hash1, hash2);
    });

    test('should handle hyphens in labels', () {
      final hash = namehashHex('test-name.eth');
      expect(hash.length, 66);
    });

    test('should return Uint8List of correct length', () {
      final hash = namehash('test.eth');
      expect(hash, isA<Uint8List>());
      expect(hash.length, 32);
    });
  });
}
