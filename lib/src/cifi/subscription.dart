import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3refi/src/cifi/identity.dart';

/// CiFi Subscription management for recurring payments.
///
/// Enables subscription-based recurring payments using blockchain technology.
/// Supports multiple payment tokens and flexible billing intervals.
///
/// ## Features
///
/// - Recurring payments (monthly, annual, custom)
/// - Multiple payment tokens (USDC, USDT, DAI, etc.)
/// - Automatic renewal
/// - Subscription pausing/cancellation
/// - Payment history tracking
/// - Webhooks for payment events
///
/// ## Usage
///
/// ```dart
/// final subscriptions = CiFiSubscription(
///   apiKey: 'your-api-key',
///   baseUrl: 'https://api.cifi.network',
/// );
///
/// // Create subscription
/// final subscription = await subscriptions.create(
///   userId: 'user-id',
///   planId: 'premium-monthly',
///   paymentToken: 'USDC',
///   chainId: 137,
/// );
///
/// // Cancel subscription
/// await subscriptions.cancel(subscription.id);
/// ```
class CiFiSubscription {
  final String apiKey;
  final String baseUrl;

  CiFiSubscription({
    required this.apiKey,
    required this.baseUrl,
  });

  /// Create a new subscription.
  Future<Subscription> create({
    required String userId,
    required String planId,
    required String paymentToken,
    required int chainId,
    String? paymentAddress,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/subscriptions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'userId': userId,
        'planId': planId,
        'paymentToken': paymentToken,
        'chainId': chainId,
        if (paymentAddress != null) 'paymentAddress': paymentAddress,
        if (metadata != null) 'metadata': metadata,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CiFiException(
        'Failed to create subscription: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Subscription.fromJson(data);
  }

  /// Get subscription by ID.
  Future<Subscription> get(String subscriptionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get subscription: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Subscription.fromJson(data);
  }

  /// List subscriptions for a user.
  Future<List<Subscription>> list({
    required String userId,
    SubscriptionStatus? status,
    int? limit,
    int? offset,
  }) async {
    final queryParams = {
      'userId': userId,
      if (status != null) 'status': status.name,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };

    final uri = Uri.parse('$baseUrl/v1/subscriptions')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to list subscriptions: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final subscriptions = data['subscriptions'] as List;
    return subscriptions
        .map((sub) => Subscription.fromJson(sub as Map<String, dynamic>))
        .toList();
  }

  /// Cancel subscription.
  Future<void> cancel(String subscriptionId, {bool immediate = false}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId/cancel'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'immediate': immediate,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to cancel subscription: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Pause subscription.
  Future<void> pause(String subscriptionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId/pause'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to pause subscription: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Resume paused subscription.
  Future<void> resume(String subscriptionId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId/resume'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to resume subscription: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Update subscription payment method.
  Future<void> updatePaymentMethod({
    required String subscriptionId,
    required String paymentToken,
    required int chainId,
    String? paymentAddress,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId/payment-method'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'paymentToken': paymentToken,
        'chainId': chainId,
        if (paymentAddress != null) 'paymentAddress': paymentAddress,
      }),
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to update payment method: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Get payment history for subscription.
  Future<List<SubscriptionPayment>> getPaymentHistory(String subscriptionId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/subscriptions/$subscriptionId/payments'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get payment history: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final payments = data['payments'] as List;
    return payments
        .map((payment) => SubscriptionPayment.fromJson(payment as Map<String, dynamic>))
        .toList();
  }

  /// Get available subscription plans.
  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/subscription-plans'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get plans: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final plans = data['plans'] as List;
    return plans
        .map((plan) => SubscriptionPlan.fromJson(plan as Map<String, dynamic>))
        .toList();
  }
}

/// Subscription information.
class Subscription {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final BigInt amount;
  final String paymentToken;
  final int chainId;
  final String? paymentAddress;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelAt;
  final DateTime? canceledAt;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  const Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.paymentToken,
    required this.chainId,
    required this.status, required this.currentPeriodStart, required this.currentPeriodEnd, required this.createdAt, this.paymentAddress,
    this.cancelAt,
    this.canceledAt,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'planId': planId,
        'planName': planName,
        'amount': amount.toString(),
        'paymentToken': paymentToken,
        'chainId': chainId,
        if (paymentAddress != null) 'paymentAddress': paymentAddress,
        'status': status.name,
        'currentPeriodStart': currentPeriodStart.toIso8601String(),
        'currentPeriodEnd': currentPeriodEnd.toIso8601String(),
        if (cancelAt != null) 'cancelAt': cancelAt!.toIso8601String(),
        if (canceledAt != null) 'canceledAt': canceledAt!.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String,
      userId: json['userId'] as String,
      planId: json['planId'] as String,
      planName: json['planName'] as String,
      amount: BigInt.parse(json['amount'] as String),
      paymentToken: json['paymentToken'] as String,
      chainId: json['chainId'] as int,
      paymentAddress: json['paymentAddress'] as String?,
      status: SubscriptionStatus.values.byName(json['status'] as String),
      currentPeriodStart: DateTime.parse(json['currentPeriodStart'] as String),
      currentPeriodEnd: DateTime.parse(json['currentPeriodEnd'] as String),
      cancelAt: json['cancelAt'] != null
          ? DateTime.parse(json['cancelAt'] as String)
          : null,
      canceledAt: json['canceledAt'] != null
          ? DateTime.parse(json['canceledAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Subscription status.
enum SubscriptionStatus {
  active,
  paused,
  canceled,
  pastDue,
  expired;
}

/// Subscription payment information.
class SubscriptionPayment {
  final String id;
  final String subscriptionId;
  final BigInt amount;
  final String paymentToken;
  final int chainId;
  final String transactionHash;
  final SubscriptionPaymentStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;

  const SubscriptionPayment({
    required this.id,
    required this.subscriptionId,
    required this.amount,
    required this.paymentToken,
    required this.chainId,
    required this.transactionHash,
    required this.status,
    required this.createdAt,
    this.processedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'subscriptionId': subscriptionId,
        'amount': amount.toString(),
        'paymentToken': paymentToken,
        'chainId': chainId,
        'transactionHash': transactionHash,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        if (processedAt != null) 'processedAt': processedAt!.toIso8601String(),
      };

  factory SubscriptionPayment.fromJson(Map<String, dynamic> json) {
    return SubscriptionPayment(
      id: json['id'] as String,
      subscriptionId: json['subscriptionId'] as String,
      amount: BigInt.parse(json['amount'] as String),
      paymentToken: json['paymentToken'] as String,
      chainId: json['chainId'] as int,
      transactionHash: json['transactionHash'] as String,
      status: SubscriptionPaymentStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] != null
          ? DateTime.parse(json['processedAt'] as String)
          : null,
    );
  }
}

/// Subscription payment status.
enum SubscriptionPaymentStatus {
  pending,
  processing,
  completed,
  failed;
}

/// Subscription plan.
class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final BigInt amount;
  final String currency;
  final BillingInterval interval;
  final int intervalCount;
  final List<String> features;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.currency,
    required this.interval,
    required this.features, this.intervalCount = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'amount': amount.toString(),
        'currency': currency,
        'interval': interval.name,
        'intervalCount': intervalCount,
        'features': features,
      };

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      amount: BigInt.parse(json['amount'] as String),
      currency: json['currency'] as String,
      interval: BillingInterval.values.byName(json['interval'] as String),
      intervalCount: json['intervalCount'] as int? ?? 1,
      features: List<String>.from(json['features'] as List),
    );
  }
}

/// Billing interval.
enum BillingInterval {
  day,
  week,
  month,
  year;
}
