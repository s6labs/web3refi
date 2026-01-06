import 'dart:convert';
import 'package:http/http.dart' as http;

/// CiFi Identity management for multi-chain wallet identity.
///
/// Provides unified identity across multiple blockchains, allowing users
/// to maintain a single identity profile linked to multiple wallet addresses.
///
/// ## Features
///
/// - Multi-chain address linking
/// - Identity verification
/// - Cross-chain balance aggregation
/// - Profile management
/// - Address ownership verification
///
/// ## Usage
///
/// ```dart
/// final identity = CiFiIdentity(
///   apiKey: 'your-api-key',
///   baseUrl: 'https://api.cifi.network',
/// );
///
/// // Link new address to identity
/// await identity.linkAddress(
///   userId: 'user-id',
///   address: '0x...',
///   chainId: 137,
///   signature: signature,
/// );
///
/// // Get all linked addresses
/// final addresses = await identity.getLinkedAddresses('user-id');
/// ```
class CiFiIdentity {
  final String apiKey;
  final String baseUrl;

  CiFiIdentity({
    required this.apiKey,
    required this.baseUrl,
  });

  /// Create a new identity profile.
  Future<CiFiProfile> createProfile({
    required String primaryAddress,
    required int chainId,
    String? email,
    String? username,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/identity/profiles'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'primaryAddress': primaryAddress,
        'chainId': chainId,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        if (metadata != null) 'metadata': metadata,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CiFiException(
        'Failed to create profile: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CiFiProfile.fromJson(data);
  }

  /// Get identity profile by user ID.
  Future<CiFiProfile> getProfile(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/identity/profiles/$userId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get profile: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return CiFiProfile.fromJson(data);
  }

  /// Link new address to existing profile.
  Future<void> linkAddress({
    required String userId,
    required String address,
    required int chainId,
    required String signature,
    String? message,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/identity/profiles/$userId/addresses'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
        'chainId': chainId,
        'signature': signature,
        if (message != null) 'message': message,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CiFiException(
        'Failed to link address: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Unlink address from profile.
  Future<void> unlinkAddress({
    required String userId,
    required String address,
    required int chainId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/v1/identity/profiles/$userId/addresses?address=$address&chainId=$chainId',
      ),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to unlink address: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Get all linked addresses for a profile.
  Future<List<CiFiAddress>> getLinkedAddresses(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/identity/profiles/$userId/addresses'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get linked addresses: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final addresses = data['addresses'] as List;
    return addresses
        .map((addr) => CiFiAddress.fromJson(addr as Map<String, dynamic>))
        .toList();
  }

  /// Get aggregated balance across all chains.
  Future<Map<int, BigInt>> getMultiChainBalance(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/identity/profiles/$userId/balances'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get multi-chain balance: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final balances = data['balances'] as Map<String, dynamic>;

    return balances.map(
      (chainId, balance) => MapEntry(
        int.parse(chainId),
        BigInt.parse(balance as String),
      ),
    );
  }

  /// Verify ownership of an address.
  Future<bool> verifyAddressOwnership({
    required String address,
    required String message,
    required String signature,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/identity/verify-ownership'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
        'message': message,
        'signature': signature,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['verified'] as bool? ?? false;
  }

  /// Update profile metadata.
  Future<void> updateProfile({
    required String userId,
    String? email,
    String? username,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/v1/identity/profiles/$userId'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        if (metadata != null) 'metadata': metadata,
      }),
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to update profile: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// CiFi user profile.
class CiFiProfile {
  final String userId;
  final String primaryAddress;
  final int primaryChainId;
  final String? email;
  final String? username;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CiFiProfile({
    required this.userId,
    required this.primaryAddress,
    required this.primaryChainId,
    required this.createdAt, required this.updatedAt, this.email,
    this.username,
    this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'primaryAddress': primaryAddress,
        'primaryChainId': primaryChainId,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        if (metadata != null) 'metadata': metadata,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CiFiProfile.fromJson(Map<String, dynamic> json) {
    return CiFiProfile(
      userId: json['userId'] as String,
      primaryAddress: json['primaryAddress'] as String,
      primaryChainId: json['primaryChainId'] as int,
      email: json['email'] as String?,
      username: json['username'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

/// Linked address information.
class CiFiAddress {
  final String address;
  final int chainId;
  final DateTime linkedAt;
  final bool verified;

  const CiFiAddress({
    required this.address,
    required this.chainId,
    required this.linkedAt,
    required this.verified,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'chainId': chainId,
        'linkedAt': linkedAt.toIso8601String(),
        'verified': verified,
      };

  factory CiFiAddress.fromJson(Map<String, dynamic> json) {
    return CiFiAddress(
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      linkedAt: DateTime.parse(json['linkedAt'] as String),
      verified: json['verified'] as bool? ?? false,
    );
  }
}

/// CiFi exception.
class CiFiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  CiFiException(
    this.message, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'CiFiException ($statusCode): $message';
    }
    return 'CiFiException: $message';
  }
}
