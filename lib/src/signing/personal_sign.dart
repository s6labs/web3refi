import 'dart:convert';
import 'dart:typed_data';
import 'package:web3refi/src/crypto/keccak.dart';
import 'package:web3refi/src/crypto/signature.dart';
import 'package:web3refi/src/crypto/address.dart';
import 'package:web3refi/src/signers/hd_wallet.dart';

/// Personal sign implementation (EIP-191).
///
/// Ethereum signed message format that prevents transaction replay attacks
/// by prefixing messages with "\x19Ethereum Signed Message:\n".
///
/// ## Usage
///
/// ```dart
/// // Sign a message
/// final signature = PersonalSign.sign(
///   message: 'Hello, Ethereum!',
///   signer: mySigner,
/// );
///
/// // Verify signature
/// final isValid = PersonalSign.verify(
///   message: 'Hello, Ethereum!',
///   signature: signature,
///   address: signerAddress,
/// );
/// ```
class PersonalSign {
  PersonalSign._();

  /// Message prefix per EIP-191.
  static const String prefix = '\x19Ethereum Signed Message:\n';

  /// Create personal sign message hash.
  ///
  /// Format: keccak256("\x19Ethereum Signed Message:\n" + len(message) + message)
  static Uint8List hashMessage(String message) {
    final messageBytes = utf8.encode(message);
    final length = messageBytes.length.toString();
    final prefixBytes = utf8.encode(prefix + length);

    final combined = Uint8List(prefixBytes.length + messageBytes.length);
    combined.setAll(0, prefixBytes);
    combined.setAll(prefixBytes.length, messageBytes);

    return Keccak.keccak256(combined);
  }

  /// Sign a message.
  static Signature sign({
    required String message,
    required Signer signer,
  }) {
    final hash = hashMessage(message);
    return signer.sign(hash);
  }

  /// Sign message with raw bytes.
  static Signature signBytes({
    required Uint8List messageBytes,
    required Signer signer,
  }) {
    final message = utf8.decode(messageBytes);
    return sign(message: message, signer: signer);
  }

  /// Verify a signature.
  static bool verify({
    required String message,
    required Signature signature,
    required String address,
  }) {
    try {
      final recovered = recoverAddress(message: message, signature: signature);
      return EthereumAddress.equals(recovered, address);
    } catch (_) {
      return false;
    }
  }

  /// Recover signer address from signature.
  static String recoverAddress({
    required String message,
    required Signature signature,
  }) {
    final hash = hashMessage(message);

    // Recover public key from signature
    final publicKey = signature.recoverPublicKey(hash);

    // Derive address from public key
    return EthereumAddress.fromPublicKey(publicKey);
  }

  /// Recover signer address from compact signature.
  static String recoverAddressFromCompact({
    required String message,
    required Uint8List compactSignature,
  }) {
    final signature = Signature.fromCompact(compactSignature);
    return recoverAddress(message: message, signature: signature);
  }

  /// Recover from hex signature.
  static String recoverAddressFromHex({
    required String message,
    required String signatureHex,
  }) {
    final signature = Signature.fromHex(signatureHex);
    return recoverAddress(message: message, signature: signature);
  }

  /// Sign and return hex string.
  static String signToHex({
    required String message,
    required Signer signer,
  }) {
    final signature = sign(message: message, signer: signer);
    return signature.toHex();
  }

  /// Verify hex signature.
  static bool verifyHex({
    required String message,
    required String signatureHex,
    required String address,
  }) {
    final signature = Signature.fromHex(signatureHex);
    return verify(message: message, signature: signature, address: address);
  }
}
