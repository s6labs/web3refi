import 'package:web3refi/src/cifi/identity.dart';
import 'package:web3refi/src/cifi/subscription.dart';
import 'package:web3refi/src/cifi/auth.dart';
import 'package:web3refi/src/cifi/webhooks.dart';

/// CiFi (Circularity Finance) client for unified payment and identity.
///
/// Provides seamless integration with CiFi's infrastructure for:
/// - Multi-chain wallet identity
/// - Subscription payments
/// - Webhook notifications
/// - Authentication
///
/// ## Features
///
/// - Unified identity across multiple blockchains
/// - Subscription-based recurring payments
/// - Real-time webhook notifications
/// - OAuth-style authentication
/// - Payment network support (XDC, Polygon, etc.)
///
/// ## Usage
///
/// ```dart
/// final cifi = CiFiClient(
///   apiKey: 'your-api-key',
///   environment: CiFiEnvironment.production,
/// );
///
/// // Authenticate user
/// final auth = await cifi.auth.login(
///   address: userAddress,
///   signature: signature,
/// );
///
/// // Create subscription
/// final subscription = await cifi.subscriptions.create(
///   plan: 'premium',
///   paymentToken: 'USDC',
/// );
/// ```
class CiFiClient {
  final String apiKey;
  final CiFiEnvironment environment;
  final String? baseUrl;

  /// Identity management
  late final CiFiIdentity identity;

  /// Subscription management
  late final CiFiSubscription subscriptions;

  /// Authentication
  late final CiFiAuth auth;

  /// Webhook management
  late final CiFiWebhooks webhooks;

  CiFiClient({
    required this.apiKey,
    this.environment = CiFiEnvironment.production,
    this.baseUrl,
  }) {
    final url = baseUrl ?? environment.baseUrl;

    identity = CiFiIdentity(
      apiKey: apiKey,
      baseUrl: url,
    );

    subscriptions = CiFiSubscription(
      apiKey: apiKey,
      baseUrl: url,
    );

    auth = CiFiAuth(
      apiKey: apiKey,
      baseUrl: url,
    );

    webhooks = CiFiWebhooks(
      apiKey: apiKey,
      baseUrl: url,
    );
  }

  /// Get CiFi network configuration for a chain.
  ///
  /// Returns payment network details for supported chains.
  Future<CiFiNetwork?> getNetwork(int chainId) async {
    // Map chain IDs to CiFi payment networks
    final networks = {
      50: const CiFiNetwork(
        chainId: 50,
        name: 'XDC Network',
        rpcUrl: 'https://rpc.xdcnetwork.com',
        nativeCurrency: CiFiCurrency(
          name: 'XDC',
          symbol: 'XDC',
          decimals: 18,
        ),
        blockExplorer: 'https://explorer.xdcnetwork.com',
        supportedTokens: ['USDC', 'USDT', 'DAI'],
      ),
      137: const CiFiNetwork(
        chainId: 137,
        name: 'Polygon',
        rpcUrl: 'https://polygon-rpc.com',
        nativeCurrency: CiFiCurrency(
          name: 'MATIC',
          symbol: 'MATIC',
          decimals: 18,
        ),
        blockExplorer: 'https://polygonscan.com',
        supportedTokens: ['USDC', 'USDT', 'DAI'],
      ),
    };

    return networks[chainId];
  }

  /// Verify API key is valid.
  Future<bool> verifyApiKey() async {
    try {
      // Attempt to make a simple API call to verify key
      await auth.verifyToken(apiKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get account balance across all chains.
  Future<Map<int, BigInt>> getMultiChainBalance(String address) async {
    return await identity.getMultiChainBalance(address);
  }

  /// Create a payment request.
  Future<CiFiPaymentRequest> createPaymentRequest({
    required String recipient,
    required BigInt amount,
    required String currency,
    int? chainId,
    String? description,
    DateTime? expiresAt,
  }) async {
    // Implementation for creating payment requests
    throw UnimplementedError('Payment request creation pending');
  }
}

/// CiFi environment configuration.
enum CiFiEnvironment {
  production,
  staging,
  development;

  String get baseUrl {
    switch (this) {
      case CiFiEnvironment.production:
        return 'https://api.cifi.network';
      case CiFiEnvironment.staging:
        return 'https://staging-api.cifi.network';
      case CiFiEnvironment.development:
        return 'http://localhost:3000';
    }
  }
}

/// CiFi network configuration.
class CiFiNetwork {
  final int chainId;
  final String name;
  final String rpcUrl;
  final CiFiCurrency nativeCurrency;
  final String blockExplorer;
  final List<String> supportedTokens;

  const CiFiNetwork({
    required this.chainId,
    required this.name,
    required this.rpcUrl,
    required this.nativeCurrency,
    required this.blockExplorer,
    required this.supportedTokens,
  });

  Map<String, dynamic> toJson() => {
        'chainId': chainId,
        'name': name,
        'rpcUrl': rpcUrl,
        'nativeCurrency': nativeCurrency.toJson(),
        'blockExplorer': blockExplorer,
        'supportedTokens': supportedTokens,
      };

  factory CiFiNetwork.fromJson(Map<String, dynamic> json) {
    return CiFiNetwork(
      chainId: json['chainId'] as int,
      name: json['name'] as String,
      rpcUrl: json['rpcUrl'] as String,
      nativeCurrency: CiFiCurrency.fromJson(
        json['nativeCurrency'] as Map<String, dynamic>,
      ),
      blockExplorer: json['blockExplorer'] as String,
      supportedTokens: List<String>.from(json['supportedTokens'] as List),
    );
  }
}

/// Currency information.
class CiFiCurrency {
  final String name;
  final String symbol;
  final int decimals;

  const CiFiCurrency({
    required this.name,
    required this.symbol,
    required this.decimals,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'symbol': symbol,
        'decimals': decimals,
      };

  factory CiFiCurrency.fromJson(Map<String, dynamic> json) {
    return CiFiCurrency(
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      decimals: json['decimals'] as int,
    );
  }
}

/// Payment request.
class CiFiPaymentRequest {
  final String id;
  final String recipient;
  final BigInt amount;
  final String currency;
  final int chainId;
  final String? description;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final CiFiPaymentStatus status;

  const CiFiPaymentRequest({
    required this.id,
    required this.recipient,
    required this.amount,
    required this.currency,
    required this.chainId,
    required this.createdAt, required this.status, this.description,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'recipient': recipient,
        'amount': amount.toString(),
        'currency': currency,
        'chainId': chainId,
        if (description != null) 'description': description,
        'createdAt': createdAt.toIso8601String(),
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'status': status.name,
      };

  factory CiFiPaymentRequest.fromJson(Map<String, dynamic> json) {
    return CiFiPaymentRequest(
      id: json['id'] as String,
      recipient: json['recipient'] as String,
      amount: BigInt.parse(json['amount'] as String),
      currency: json['currency'] as String,
      chainId: json['chainId'] as int,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      status: CiFiPaymentStatus.values.byName(json['status'] as String),
    );
  }
}

/// Payment status.
enum CiFiPaymentStatus {
  pending,
  processing,
  completed,
  failed,
  expired;
}
