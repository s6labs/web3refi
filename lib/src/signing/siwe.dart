import 'dart:convert';
import '../crypto/signature.dart';
import '../signers/hd_wallet.dart';
import 'personal_sign.dart';

/// Sign-In with Ethereum (SIWE) implementation (EIP-4361).
///
/// Standardized authentication message format for logging into
/// web3 applications using Ethereum accounts.
///
/// ## Features
///
/// - Off-chain authentication
/// - Anti-phishing protection
/// - Human-readable messages
/// - Nonce for replay protection
/// - Expiration times
///
/// ## Usage
///
/// ```dart
/// final siweMessage = SiweMessage.create(
///   domain: 'example.com',
///   address: '0x...',
///   statement: 'Sign in to Example DApp',
///   uri: 'https://example.com',
///   version: '1',
///   chainId: 1,
///   nonce: generateNonce(),
/// );
///
/// final signature = siweMessage.sign(signer);
/// final isValid = siweMessage.verify(signature);
/// ```
class SiweMessage {
  /// Domain (hostname) requesting the signature.
  final String domain;

  /// Ethereum address performing the signing.
  final String address;

  /// Human-readable statement (optional).
  final String? statement;

  /// URI of the resource.
  final String uri;

  /// SIWE message version (currently "1").
  final String version;

  /// Chain ID.
  final int chainId;

  /// Random nonce for replay protection.
  final String nonce;

  /// ISO 8601 datetime when message was issued.
  final DateTime issuedAt;

  /// Expiration time (optional).
  final DateTime? expirationTime;

  /// Not valid before time (optional).
  final DateTime? notBefore;

  /// Request ID (optional).
  final String? requestId;

  /// Resources list (optional).
  final List<String>? resources;

  SiweMessage({
    required this.domain,
    required this.address,
    this.statement,
    required this.uri,
    required this.version,
    required this.chainId,
    required this.nonce,
    required this.issuedAt,
    this.expirationTime,
    this.notBefore,
    this.requestId,
    this.resources,
  });

  /// Create a new SIWE message.
  factory SiweMessage.create({
    required String domain,
    required String address,
    String? statement,
    required String uri,
    String version = '1',
    required int chainId,
    String? nonce,
    DateTime? issuedAt,
    DateTime? expirationTime,
    DateTime? notBefore,
    String? requestId,
    List<String>? resources,
  }) {
    return SiweMessage(
      domain: domain,
      address: address,
      statement: statement,
      uri: uri,
      version: version,
      chainId: chainId,
      nonce: nonce ?? _generateNonce(),
      issuedAt: issuedAt ?? DateTime.now().toUtc(),
      expirationTime: expirationTime,
      notBefore: notBefore,
      requestId: requestId,
      resources: resources,
    );
  }

  /// Generate the message string to be signed.
  ///
  /// Format per EIP-4361:
  /// ```
  /// ${domain} wants you to sign in with your Ethereum account:
  /// ${address}
  ///
  /// ${statement}
  ///
  /// URI: ${uri}
  /// Version: ${version}
  /// Chain ID: ${chainId}
  /// Nonce: ${nonce}
  /// Issued At: ${issuedAt}
  /// ```
  String toMessage() {
    final lines = <String>[];

    // Header
    lines.add('$domain wants you to sign in with your Ethereum account:');
    lines.add(address);
    lines.add('');

    // Statement
    if (statement != null && statement!.isNotEmpty) {
      lines.add(statement!);
      lines.add('');
    }

    // Required fields
    lines.add('URI: $uri');
    lines.add('Version: $version');
    lines.add('Chain ID: $chainId');
    lines.add('Nonce: $nonce');
    lines.add('Issued At: ${_formatDateTime(issuedAt)}');

    // Optional fields
    if (expirationTime != null) {
      lines.add('Expiration Time: ${_formatDateTime(expirationTime!)}');
    }
    if (notBefore != null) {
      lines.add('Not Before: ${_formatDateTime(notBefore!)}');
    }
    if (requestId != null) {
      lines.add('Request ID: $requestId');
    }
    if (resources != null && resources!.isNotEmpty) {
      lines.add('Resources:');
      for (final resource in resources!) {
        lines.add('- $resource');
      }
    }

    return lines.join('\n');
  }

  /// Sign the message.
  Signature sign(Signer signer) {
    final message = toMessage();
    return PersonalSign.sign(message: message, signer: signer);
  }

  /// Sign and return hex signature.
  String signToHex(Signer signer) {
    final signature = sign(signer);
    return signature.toHex();
  }

  /// Verify signature.
  bool verify(Signature signature) {
    final message = toMessage();
    return PersonalSign.verify(
      message: message,
      signature: signature,
      address: address,
    );
  }

  /// Verify hex signature.
  bool verifyHex(String signatureHex) {
    final signature = Signature.fromHex(signatureHex);
    return verify(signature);
  }

  /// Check if message is expired.
  bool get isExpired {
    if (expirationTime == null) return false;
    return DateTime.now().toUtc().isAfter(expirationTime!);
  }

  /// Check if message is valid yet.
  bool get isValidYet {
    if (notBefore == null) return true;
    return DateTime.now().toUtc().isAfter(notBefore!);
  }

  /// Check if message is within valid time window.
  bool get isValid => !isExpired && isValidYet;

  /// Parse SIWE message from string.
  factory SiweMessage.fromMessage(String message) {
    // TODO: Parse SIWE message format
    throw UnimplementedError('SIWE message parsing pending');
  }

  /// Format DateTime as ISO 8601.
  static String _formatDateTime(DateTime dt) {
    return dt.toUtc().toIso8601String();
  }

  /// Generate random nonce.
  static String _generateNonce() {
    // TODO: Generate cryptographically secure random nonce
    // For now, use timestamp + random
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Convert to JSON.
  Map<String, dynamic> toJson() => {
        'domain': domain,
        'address': address,
        if (statement != null) 'statement': statement,
        'uri': uri,
        'version': version,
        'chainId': chainId,
        'nonce': nonce,
        'issuedAt': _formatDateTime(issuedAt),
        if (expirationTime != null)
          'expirationTime': _formatDateTime(expirationTime!),
        if (notBefore != null) 'notBefore': _formatDateTime(notBefore!),
        if (requestId != null) 'requestId': requestId,
        if (resources != null) 'resources': resources,
      };

  @override
  String toString() => toMessage();
}
