import 'dart:typed_data';
import 'dart:convert';
import '../../crypto/keccak.dart';

/// Compute the ENS namehash for a domain name.
///
/// Namehash is a recursive process that generates a unique hash for a domain name.
/// It's used by ENS and many other name services.
///
/// ## Algorithm
///
/// ```
/// namehash('') = 0x0000000000000000000000000000000000000000000000000000000000000000
/// namehash(label.parent) = keccak256(namehash(parent) + keccak256(label))
/// ```
///
/// ## Examples
///
/// ```dart
/// namehash('eth')
/// // → 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae
///
/// namehash('vitalik.eth')
/// // → 0xee6c4522aab0003e8d14cd40a6af439055fd2577951148c14b6cea9a53475835
/// ```
Uint8List namehash(String name) {
  // Empty name returns zero hash
  if (name.isEmpty) {
    return Uint8List(32);
  }

  // Normalize name to lowercase
  name = name.toLowerCase();

  // Split into labels
  final labels = name.split('.');

  // Start with zero hash
  var node = Uint8List(32);

  // Process labels from right to left (TLD first)
  for (var i = labels.length - 1; i >= 0; i--) {
    final label = labels[i];

    // Hash the label
    final labelHash = Keccak.keccak256(Uint8List.fromList(utf8.encode(label)));

    // Combine node + labelHash and hash again
    final combined = Uint8List(64);
    combined.setAll(0, node);
    combined.setAll(32, labelHash);

    node = Keccak.keccak256(combined);
  }

  return node;
}

/// Compute namehash and return as hex string with 0x prefix.
String namehashHex(String name) {
  final hash = namehash(name);
  return '0x${hash.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
}

/// Validate a domain name.
///
/// Checks for invalid characters and structure.
class NameValidator {
  /// Minimum name length
  static const minLength = 3;

  /// Maximum name length
  static const maxLength = 255;

  /// Validate a name and return error message if invalid.
  ///
  /// Returns null if the name is valid.
  static String? validate(String name) {
    // Check length
    if (name.length < minLength) {
      return 'Name too short (minimum $minLength characters)';
    }

    if (name.length > maxLength) {
      return 'Name too long (maximum $maxLength characters)';
    }

    // Check for invalid characters (allow letters, numbers, hyphens, dots, @)
    if (!RegExp(r'^[a-z0-9.-@]+$').hasMatch(name.toLowerCase())) {
      return 'Name contains invalid characters';
    }

    // Check that dots aren't at start or end
    if (name.startsWith('.') || name.endsWith('.')) {
      return 'Name cannot start or end with a dot';
    }

    // Check for consecutive dots
    if (name.contains('..')) {
      return 'Name cannot contain consecutive dots';
    }

    return null;
  }

  /// Check if a name is valid (returns true/false).
  static bool isValid(String name) => validate(name) == null;

  /// Normalize a name.
  ///
  /// - Converts to lowercase
  /// - Trims whitespace
  /// - Removes extra spaces
  static String normalize(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '');
  }
}
