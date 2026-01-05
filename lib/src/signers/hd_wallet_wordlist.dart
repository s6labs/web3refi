import 'dart:typed_data';

/// Helper class for derived key data.
class DerivedKey {
  final Uint8List key;
  final Uint8List chainCode;

  DerivedKey(this.key, this.chainCode);
}

/// BIP-39 English wordlist.
///
/// This is a subset for demonstration. For production use,
/// consider using the 'bip39' package from pub.dev which includes
/// the complete official wordlist.
const List<String> bip39WordlistEnglish = [
  'abandon', 'ability', 'able', 'about', 'above', 'absent', 'absorb', 'abstract',
  'absurd', 'abuse', 'access', 'accident', 'account', 'accuse', 'achieve', 'acid',
  // ... (2048 words total - use bip39 package for complete list)
  'zone', 'zoo',
];
