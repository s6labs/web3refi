import 'dart:convert';
import 'dart:math';
import 'package:web3refi/src/core/chain.dart';

/// Universal authentication message for "Sign-In with Wallet" flows.
///
/// Inspired by EIP-4361 (Sign-In with Ethereum) but designed to work
/// across all supported blockchains.
///
/// Example:
/// ```dart
/// final message = AuthMessage.create(
///   domain: 'myapp.com',
///   address: '0x742d35Cc...',
///   chainId: '1',
///   statement: 'Sign in to MyApp',
/// );
///
/// final signable = message.toSignableMessage();
/// final signature = await wallet.signMessage(signable);
/// ```
class AuthMessage {
  /// Domain requesting the signature (e.g., 'myapp.com').
  final String domain;

  /// Wallet address being authenticated.
  final String address;

  /// Chain identifier (e.g., '1' for Ethereum mainnet).
  final String chainId;

  /// Blockchain type for format selection.
  final BlockchainType blockchainType;

  /// Unique nonce for replay protection.
  final String nonce;

  /// When the message was created.
  final DateTime issuedAt;

  /// When the message expires (optional).
  final DateTime? expiresAt;

  /// Human-readable statement explaining the request.
  final String? statement;

  /// URI of the resource being accessed.
  final String? uri;

  /// Message format version.
  final String version;

  /// Request ID for tracking.
  final String? requestId;

  /// Additional resources being requested.
  final List<String>? resources;

  const AuthMessage({
    required this.domain,
    required this.address,
    required this.chainId,
    required this.blockchainType,
    required this.nonce,
    required this.issuedAt,
    this.expiresAt,
    this.statement,
    this.uri,
    this.version = '1',
    this.requestId,
    this.resources,
  });

  /// Create a new authentication message with auto-generated nonce.
  factory AuthMessage.create({
    required String domain,
    required String address,
    required String chainId,
    BlockchainType blockchainType = BlockchainType.evm,
    String? statement,
    String? uri,
    Duration? expiresIn,
    List<String>? resources,
  }) {
    final now = DateTime.now().toUtc();
    return AuthMessage(
      domain: domain,
      address: address,
      chainId: chainId,
      blockchainType: blockchainType,
      nonce: _generateNonce(),
      issuedAt: now,
      expiresAt: expiresIn != null ? now.add(expiresIn) : null,
      statement: statement,
      uri: uri ?? 'https://$domain',
      resources: resources,
    );
  }

  /// Create for EVM chains (Ethereum, Polygon, etc.).
  factory AuthMessage.evm({
    required String domain,
    required String address,
    required int chainId,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: address,
      chainId: chainId.toString(),
      blockchainType: BlockchainType.evm,
      statement: statement ?? 'Sign in with Ethereum',
      expiresIn: expiresIn,
    );
  }

  /// Create for Bitcoin.
  factory AuthMessage.bitcoin({
    required String domain,
    required String address,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: address,
      chainId: 'bitcoin-mainnet',
      blockchainType: BlockchainType.bitcoin,
      statement: statement ?? 'Sign in with Bitcoin',
      expiresIn: expiresIn,
    );
  }

  /// Create for Solana.
  factory AuthMessage.solana({
    required String domain,
    required String address,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: address,
      chainId: 'solana-mainnet',
      blockchainType: BlockchainType.solana,
      statement: statement ?? 'Sign in with Solana',
      expiresIn: expiresIn,
    );
  }

  /// Create for Hedera.
  factory AuthMessage.hedera({
    required String domain,
    required String accountId,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: accountId,
      chainId: 'hedera-mainnet',
      blockchainType: BlockchainType.hedera,
      statement: statement ?? 'Sign in with Hedera',
      expiresIn: expiresIn,
    );
  }

  /// Create for Sui.
  factory AuthMessage.sui({
    required String domain,
    required String address,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: address,
      chainId: 'sui-mainnet',
      blockchainType: BlockchainType.sui,
      statement: statement ?? 'Sign in with Sui',
      expiresIn: expiresIn,
    );
  }

  /// Convert to signable message string.
  ///
  /// Format varies by blockchain type to match expected wallet formats.
  String toSignableMessage() {
    switch (blockchainType) {
      case BlockchainType.evm:
        return _toEIP4361Message();
      case BlockchainType.bitcoin:
        return _toBitcoinMessage();
      case BlockchainType.solana:
        return _toSolanaMessage();
      case BlockchainType.hedera:
        return _toHederaMessage();
      case BlockchainType.sui:
        return _toSuiMessage();
      default:
        return _toGenericMessage();
    }
  }

  /// EIP-4361 compliant message for EVM chains.
  String _toEIP4361Message() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('$domain wants you to sign in with your Ethereum account:');
    buffer.writeln(address);
    buffer.writeln();

    // Statement
    if (statement != null && statement!.isNotEmpty) {
      buffer.writeln(statement);
      buffer.writeln();
    }

    // Fields
    if (uri != null) {
      buffer.writeln('URI: $uri');
    }
    buffer.writeln('Version: $version');
    buffer.writeln('Chain ID: $chainId');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued At: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expiration Time: ${expiresAt!.toIso8601String()}');
    }

    if (requestId != null) {
      buffer.writeln('Request ID: $requestId');
    }

    if (resources != null && resources!.isNotEmpty) {
      buffer.writeln('Resources:');
      for (final resource in resources!) {
        buffer.writeln('- $resource');
      }
    }

    return buffer.toString().trim();
  }

  /// Bitcoin message format (BIP-137 compatible).
  String _toBitcoinMessage() {
    final buffer = StringBuffer();

    buffer.writeln('$domain wants you to sign in with your Bitcoin wallet.');
    buffer.writeln();
    buffer.writeln('Address: $address');
    buffer.writeln('Network: ${_getBitcoinNetwork()}');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expires: ${expiresAt!.toIso8601String()}');
    }

    if (statement != null) {
      buffer.writeln();
      buffer.writeln(statement);
    }

    buffer.writeln();
    buffer.writeln('This request will not trigger a blockchain transaction');
    buffer.writeln('or cost any fees.');

    return buffer.toString().trim();
  }

  String _getBitcoinNetwork() {
    if (chainId.contains('testnet')) return 'Bitcoin Testnet';
    return 'Bitcoin Mainnet';
  }

  /// Solana message format.
  String _toSolanaMessage() {
    final buffer = StringBuffer();

    buffer.writeln('$domain wants you to sign in with your Solana wallet.');
    buffer.writeln();
    buffer.writeln('Wallet: $address');
    buffer.writeln('Cluster: ${_getSolanaCluster()}');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expires: ${expiresAt!.toIso8601String()}');
    }

    if (statement != null) {
      buffer.writeln();
      buffer.writeln(statement);
    }

    buffer.writeln();
    buffer.writeln('This will not trigger a transaction or cost SOL.');

    return buffer.toString().trim();
  }

  String _getSolanaCluster() {
    if (chainId.contains('devnet')) return 'Devnet';
    if (chainId.contains('testnet')) return 'Testnet';
    return 'Mainnet-Beta';
  }

  /// Hedera message format.
  String _toHederaMessage() {
    final buffer = StringBuffer();

    buffer.writeln('$domain wants you to sign in with your Hedera account.');
    buffer.writeln();
    buffer.writeln('Account ID: $address');
    buffer.writeln('Network: ${_getHederaNetwork()}');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expires: ${expiresAt!.toIso8601String()}');
    }

    if (statement != null) {
      buffer.writeln();
      buffer.writeln(statement);
    }

    buffer.writeln();
    buffer.writeln('This will not trigger a transaction or cost HBAR.');

    return buffer.toString().trim();
  }

  String _getHederaNetwork() {
    if (chainId.contains('testnet')) return 'Hedera Testnet';
    return 'Hedera Mainnet';
  }

  /// Sui message format.
  String _toSuiMessage() {
    final buffer = StringBuffer();

    buffer.writeln('$domain wants you to sign in with your Sui wallet.');
    buffer.writeln();
    buffer.writeln('Address: $address');
    buffer.writeln('Network: ${_getSuiNetwork()}');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expires: ${expiresAt!.toIso8601String()}');
    }

    if (statement != null) {
      buffer.writeln();
      buffer.writeln(statement);
    }

    buffer.writeln();
    buffer.writeln('This will not trigger a transaction or cost SUI.');

    return buffer.toString().trim();
  }

  String _getSuiNetwork() {
    if (chainId.contains('testnet')) return 'Sui Testnet';
    if (chainId.contains('devnet')) return 'Sui Devnet';
    return 'Sui Mainnet';
  }

  /// Generic message format for unsupported chains.
  String _toGenericMessage() {
    final buffer = StringBuffer();

    buffer.writeln('$domain wants you to sign in with your wallet.');
    buffer.writeln();
    buffer.writeln('Address: $address');
    buffer.writeln('Chain: $chainId');
    buffer.writeln('Nonce: $nonce');
    buffer.writeln('Issued: ${issuedAt.toIso8601String()}');

    if (expiresAt != null) {
      buffer.writeln('Expires: ${expiresAt!.toIso8601String()}');
    }

    if (statement != null) {
      buffer.writeln();
      buffer.writeln(statement);
    }

    buffer.writeln();
    buffer.writeln('This request will not trigger a blockchain transaction');
    buffer.writeln('or cost any fees.');

    return buffer.toString().trim();
  }

  /// Check if the message has expired.
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isAfter(expiresAt!);
  }

  /// Check if the message is valid (not expired and properly formed).
  bool get isValid {
    if (isExpired) return false;
    if (domain.isEmpty) return false;
    if (address.isEmpty) return false;
    if (nonce.isEmpty) return false;
    return true;
  }

  /// Convert to JSON for storage/transmission.
  Map<String, dynamic> toJson() => {
        'domain': domain,
        'address': address,
        'chainId': chainId,
        'blockchainType': blockchainType.name,
        'nonce': nonce,
        'issuedAt': issuedAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (statement != null) 'statement': statement,
        if (uri != null) 'uri': uri,
        'version': version,
        if (requestId != null) 'requestId': requestId,
        if (resources != null) 'resources': resources,
      };

  /// Create from JSON.
  factory AuthMessage.fromJson(Map<String, dynamic> json) {
    return AuthMessage(
      domain: json['domain'] as String,
      address: json['address'] as String,
      chainId: json['chainId'] as String,
      blockchainType: BlockchainType.values.firstWhere(
        (e) => e.name == json['blockchainType'],
        orElse: () => BlockchainType.evm,
      ),
      nonce: json['nonce'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      statement: json['statement'] as String?,
      uri: json['uri'] as String?,
      version: json['version'] as String? ?? '1',
      requestId: json['requestId'] as String?,
      resources: (json['resources'] as List<dynamic>?)?.cast<String>(),
    );
  }

  /// Generate a cryptographically secure random nonce.
  static String _generateNonce({int length = 16}) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  /// Generate a new nonce (public utility method).
  static String generateNonce({int length = 16}) => _generateNonce(length: length);

  @override
  String toString() => 'AuthMessage($domain, $address, nonce: $nonce)';
}

/// Extension for creating auth messages from Chain objects.
extension ChainAuthMessage on Chain {
  /// Create an auth message for this chain.
  AuthMessage createAuthMessage({
    required String domain,
    required String address,
    String? statement,
    Duration expiresIn = const Duration(minutes: 10),
  }) {
    return AuthMessage.create(
      domain: domain,
      address: address,
      chainId: chainId.toString(),
      blockchainType: type,
      statement: statement ?? 'Sign in to $domain',
      expiresIn: expiresIn,
    );
  }
}
