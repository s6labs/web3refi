import 'dart:convert';
import 'dart:math';
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

  /// Verify signature and check validity constraints.
  VerificationResult verifyAndValidate({
    required Signature signature,
    String? expectedDomain,
    String? expectedNonce,
    int? expectedChainId,
  }) {
    // 1. Verify signature is valid
    if (!verify(signature)) {
      return VerificationResult(
        isValid: false,
        error: 'Invalid signature',
      );
    }

    // 2. Check domain matches (anti-phishing)
    if (expectedDomain != null && domain != expectedDomain) {
      return VerificationResult(
        isValid: false,
        error: 'Domain mismatch: expected $expectedDomain, got $domain',
      );
    }

    // 3. Check nonce matches (replay protection)
    if (expectedNonce != null && nonce != expectedNonce) {
      return VerificationResult(
        isValid: false,
        error: 'Nonce mismatch',
      );
    }

    // 4. Check chain ID matches
    if (expectedChainId != null && chainId != expectedChainId) {
      return VerificationResult(
        isValid: false,
        error: 'Chain ID mismatch: expected $expectedChainId, got $chainId',
      );
    }

    // 5. Check not expired
    if (isExpired) {
      return VerificationResult(
        isValid: false,
        error: 'Message expired at ${_formatDateTime(expirationTime!)}',
      );
    }

    // 6. Check valid yet (not-before constraint)
    if (!isValidYet) {
      return VerificationResult(
        isValid: false,
        error: 'Message not valid until ${_formatDateTime(notBefore!)}',
      );
    }

    return VerificationResult(isValid: true);
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
    final lines = message.split('\n');
    int index = 0;

    // Parse header: "${domain} wants you to sign in with your Ethereum account:"
    if (index >= lines.length) {
      throw ArgumentError('Invalid SIWE message: missing header');
    }
    final headerPattern = RegExp(r'^(.+) wants you to sign in with your Ethereum account:$');
    final headerMatch = headerPattern.firstMatch(lines[index]);
    if (headerMatch == null) {
      throw ArgumentError('Invalid SIWE message: malformed header');
    }
    final domain = headerMatch.group(1)!;
    index++;

    // Parse address
    if (index >= lines.length) {
      throw ArgumentError('Invalid SIWE message: missing address');
    }
    final address = lines[index].trim();
    index++;

    // Skip empty line
    if (index < lines.length && lines[index].trim().isEmpty) {
      index++;
    }

    // Parse statement (optional, ends at empty line or field line)
    String? statement;
    final statementLines = <String>[];
    while (index < lines.length &&
           lines[index].trim().isNotEmpty &&
           !lines[index].contains(':')) {
      statementLines.add(lines[index]);
      index++;
    }
    if (statementLines.isNotEmpty) {
      statement = statementLines.join('\n');
    }

    // Skip empty line
    if (index < lines.length && lines[index].trim().isEmpty) {
      index++;
    }

    // Parse fields
    String? uri;
    String? version;
    int? chainId;
    String? nonce;
    DateTime? issuedAt;
    DateTime? expirationTime;
    DateTime? notBefore;
    String? requestId;
    List<String>? resources;

    while (index < lines.length) {
      final line = lines[index].trim();

      if (line.isEmpty) {
        index++;
        continue;
      }

      if (line == 'Resources:') {
        // Parse resources list
        index++;
        resources = [];
        while (index < lines.length && lines[index].startsWith('- ')) {
          resources.add(lines[index].substring(2));
          index++;
        }
        continue;
      }

      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) {
        index++;
        continue;
      }

      final key = line.substring(0, colonIndex).trim();
      final value = line.substring(colonIndex + 1).trim();

      switch (key) {
        case 'URI':
          uri = value;
          break;
        case 'Version':
          version = value;
          break;
        case 'Chain ID':
          chainId = int.tryParse(value);
          break;
        case 'Nonce':
          nonce = value;
          break;
        case 'Issued At':
          issuedAt = DateTime.tryParse(value);
          break;
        case 'Expiration Time':
          expirationTime = DateTime.tryParse(value);
          break;
        case 'Not Before':
          notBefore = DateTime.tryParse(value);
          break;
        case 'Request ID':
          requestId = value;
          break;
      }

      index++;
    }

    // Validate required fields
    if (uri == null || version == null || chainId == null || nonce == null || issuedAt == null) {
      throw ArgumentError('Invalid SIWE message: missing required fields');
    }

    return SiweMessage(
      domain: domain,
      address: address,
      statement: statement,
      uri: uri,
      version: version,
      chainId: chainId,
      nonce: nonce,
      issuedAt: issuedAt,
      expirationTime: expirationTime,
      notBefore: notBefore,
      requestId: requestId,
      resources: resources,
    );
  }

  /// Format DateTime as ISO 8601.
  static String _formatDateTime(DateTime dt) {
    return dt.toUtc().toIso8601String();
  }

  /// Generate cryptographically secure random nonce.
  static String _generateNonce() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
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

  /// Create from JSON.
  factory SiweMessage.fromJson(Map<String, dynamic> json) {
    return SiweMessage(
      domain: json['domain'] as String,
      address: json['address'] as String,
      statement: json['statement'] as String?,
      uri: json['uri'] as String,
      version: json['version'] as String,
      chainId: json['chainId'] as int,
      nonce: json['nonce'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expirationTime: json['expirationTime'] != null
          ? DateTime.parse(json['expirationTime'] as String)
          : null,
      notBefore: json['notBefore'] != null
          ? DateTime.parse(json['notBefore'] as String)
          : null,
      requestId: json['requestId'] as String?,
      resources: json['resources'] != null
          ? List<String>.from(json['resources'] as List)
          : null,
    );
  }

  @override
  String toString() => toMessage();
}

/// Result of SIWE verification.
class VerificationResult {
  final bool isValid;
  final String? error;

  VerificationResult({
    required this.isValid,
    this.error,
  });

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $error';
}

/// Helper for generating secure nonces.
class SiweNonce {
  /// Generate a cryptographically secure random nonce.
  static String generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Generate a nonce with custom length (in bytes).
  static String generateWithLength(int bytes) {
    final random = Random.secure();
    final bytesList = List<int>.generate(bytes, (_) => random.nextInt(256));
    return base64Url.encode(bytesList).replaceAll('=', '');
  }

  /// Validate nonce format (alphanumeric + - and _).
  static bool isValid(String nonce) {
    return RegExp(r'^[A-Za-z0-9\-_]+$').hasMatch(nonce);
  }
}
