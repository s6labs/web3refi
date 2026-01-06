import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'identity.dart';

/// CiFi Webhooks for real-time notifications.
///
/// Receive real-time notifications for payment events, subscription changes,
/// and other important events in your CiFi integration.
///
/// ## Features
///
/// - Real-time event notifications
/// - Secure webhook verification
/// - Event filtering
/// - Retry mechanism
/// - Event history
///
/// ## Supported Events
///
/// - `payment.completed` - Payment successful
/// - `payment.failed` - Payment failed
/// - `subscription.created` - New subscription
/// - `subscription.updated` - Subscription modified
/// - `subscription.canceled` - Subscription canceled
/// - `subscription.renewed` - Subscription renewed
/// - `identity.created` - New identity profile
/// - `identity.updated` - Profile updated
///
/// ## Usage
///
/// ```dart
/// final webhooks = CiFiWebhooks(
///   apiKey: 'your-api-key',
///   baseUrl: 'https://api.cifi.network',
/// );
///
/// // Register webhook endpoint
/// await webhooks.create(
///   url: 'https://your-app.com/webhooks/cifi',
///   events: ['payment.completed', 'subscription.renewed'],
/// );
///
/// // Verify webhook signature
/// final isValid = webhooks.verifySignature(
///   payload: requestBody,
///   signature: signatureHeader,
///   secret: webhookSecret,
/// );
/// ```
class CiFiWebhooks {
  final String apiKey;
  final String baseUrl;

  CiFiWebhooks({
    required this.apiKey,
    required this.baseUrl,
  });

  /// Create new webhook endpoint.
  Future<Webhook> create({
    required String url,
    required List<String> events,
    String? description,
    Map<String, String>? headers,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/webhooks'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'url': url,
        'events': events,
        if (description != null) 'description': description,
        if (headers != null) 'headers': headers,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CiFiException(
        'Failed to create webhook: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Webhook.fromJson(data);
  }

  /// Get webhook by ID.
  Future<Webhook> get(String webhookId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get webhook: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Webhook.fromJson(data);
  }

  /// List all webhooks.
  Future<List<Webhook>> list() async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/webhooks'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to list webhooks: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final webhooks = data['webhooks'] as List;
    return webhooks
        .map((webhook) => Webhook.fromJson(webhook as Map<String, dynamic>))
        .toList();
  }

  /// Update webhook.
  Future<Webhook> update({
    required String webhookId,
    String? url,
    List<String>? events,
    String? description,
    Map<String, String>? headers,
    bool? enabled,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (url != null) 'url': url,
        if (events != null) 'events': events,
        if (description != null) 'description': description,
        if (headers != null) 'headers': headers,
        if (enabled != null) 'enabled': enabled,
      }),
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to update webhook: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Webhook.fromJson(data);
  }

  /// Delete webhook.
  Future<void> delete(String webhookId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to delete webhook: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Verify webhook signature.
  ///
  /// Validates that the webhook request came from CiFi servers.
  bool verifySignature({
    required String payload,
    required String signature,
    required String secret,
  }) {
    // Compute HMAC-SHA256 signature
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    // Compare signatures
    final expectedSignature = 'sha256=${digest.toString()}';
    return signature == expectedSignature;
  }

  /// Get webhook event by ID.
  Future<WebhookEvent> getEvent({
    required String webhookId,
    required String eventId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId/events/$eventId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get webhook event: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return WebhookEvent.fromJson(data);
  }

  /// List webhook events (delivery history).
  Future<List<WebhookEvent>> listEvents({
    required String webhookId,
    String? eventType,
    int? limit,
    int? offset,
  }) async {
    final queryParams = {
      if (eventType != null) 'eventType': eventType,
      if (limit != null) 'limit': limit.toString(),
      if (offset != null) 'offset': offset.toString(),
    };

    final uri = Uri.parse('$baseUrl/v1/webhooks/$webhookId/events')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to list webhook events: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final events = data['events'] as List;
    return events
        .map((event) => WebhookEvent.fromJson(event as Map<String, dynamic>))
        .toList();
  }

  /// Retry failed webhook event.
  Future<void> retryEvent({
    required String webhookId,
    required String eventId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId/events/$eventId/retry'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to retry webhook event: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Test webhook endpoint.
  Future<WebhookTestResult> test(String webhookId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/webhooks/$webhookId/test'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to test webhook: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return WebhookTestResult.fromJson(data);
  }
}

/// Webhook endpoint configuration.
class Webhook {
  final String id;
  final String url;
  final List<String> events;
  final String? description;
  final String secret;
  final Map<String, String>? headers;
  final bool enabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Webhook({
    required this.id,
    required this.url,
    required this.events,
    this.description,
    required this.secret,
    this.headers,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'events': events,
        if (description != null) 'description': description,
        'secret': secret,
        if (headers != null) 'headers': headers,
        'enabled': enabled,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Webhook.fromJson(Map<String, dynamic> json) {
    return Webhook(
      id: json['id'] as String,
      url: json['url'] as String,
      events: List<String>.from(json['events'] as List),
      description: json['description'] as String?,
      secret: json['secret'] as String,
      headers: json['headers'] != null
          ? Map<String, String>.from(json['headers'] as Map)
          : null,
      enabled: json['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Webhook event (delivery record).
class WebhookEvent {
  final String id;
  final String webhookId;
  final String eventType;
  final Map<String, dynamic> data;
  final int attemptCount;
  final WebhookEventStatus status;
  final int? responseCode;
  final String? responseBody;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  const WebhookEvent({
    required this.id,
    required this.webhookId,
    required this.eventType,
    required this.data,
    required this.attemptCount,
    required this.status,
    this.responseCode,
    this.responseBody,
    required this.createdAt,
    this.deliveredAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'webhookId': webhookId,
        'eventType': eventType,
        'data': data,
        'attemptCount': attemptCount,
        'status': status.name,
        if (responseCode != null) 'responseCode': responseCode,
        if (responseBody != null) 'responseBody': responseBody,
        'createdAt': createdAt.toIso8601String(),
        if (deliveredAt != null) 'deliveredAt': deliveredAt!.toIso8601String(),
      };

  factory WebhookEvent.fromJson(Map<String, dynamic> json) {
    return WebhookEvent(
      id: json['id'] as String,
      webhookId: json['webhookId'] as String,
      eventType: json['eventType'] as String,
      data: json['data'] as Map<String, dynamic>,
      attemptCount: json['attemptCount'] as int? ?? 0,
      status: WebhookEventStatus.values.byName(json['status'] as String),
      responseCode: json['responseCode'] as int?,
      responseBody: json['responseBody'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.parse(json['deliveredAt'] as String)
          : null,
    );
  }
}

/// Webhook event status.
enum WebhookEventStatus {
  pending,
  delivered,
  failed;
}

/// Webhook test result.
class WebhookTestResult {
  final bool success;
  final int responseCode;
  final String responseBody;
  final int responseTime;

  const WebhookTestResult({
    required this.success,
    required this.responseCode,
    required this.responseBody,
    required this.responseTime,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'responseCode': responseCode,
        'responseBody': responseBody,
        'responseTime': responseTime,
      };

  factory WebhookTestResult.fromJson(Map<String, dynamic> json) {
    return WebhookTestResult(
      success: json['success'] as bool,
      responseCode: json['responseCode'] as int,
      responseBody: json['responseBody'] as String,
      responseTime: json['responseTime'] as int,
    );
  }
}
