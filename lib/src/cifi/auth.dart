import 'dart:convert';
import 'package:http/http.dart' as http;
import 'identity.dart';
import '../signing/siwe.dart';

/// CiFi Authentication for wallet-based login.
///
/// Provides OAuth-style authentication using wallet signatures (SIWE).
/// Supports session management, token refresh, and multi-factor authentication.
///
/// ## Features
///
/// - Wallet signature-based auth (SIWE)
/// - JWT token management
/// - Session management
/// - Token refresh
/// - Multi-factor authentication (optional)
/// - OAuth2-compatible flows
///
/// ## Usage
///
/// ```dart
/// final auth = CiFiAuth(
///   apiKey: 'your-api-key',
///   baseUrl: 'https://api.cifi.network',
/// );
///
/// // Login with wallet
/// final session = await auth.login(
///   address: '0x...',
///   signature: signature,
///   message: siweMessage,
/// );
///
/// // Verify token
/// final isValid = await auth.verifyToken(session.accessToken);
/// ```
class CiFiAuth {
  final String apiKey;
  final String baseUrl;

  CiFiAuth({
    required this.apiKey,
    required this.baseUrl,
  });

  /// Request authentication challenge (SIWE message).
  Future<AuthChallenge> requestChallenge({
    required String address,
    int? chainId,
    String? domain,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/challenge'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
        if (chainId != null) 'chainId': chainId,
        if (domain != null) 'domain': domain,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw CiFiException(
        'Failed to request challenge: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthChallenge.fromJson(data);
  }

  /// Login with wallet signature.
  Future<AuthSession> login({
    required String address,
    required String signature,
    required String message,
    int? chainId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/login'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'address': address,
        'signature': signature,
        'message': message,
        if (chainId != null) 'chainId': chainId,
      }),
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to login: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(data);
  }

  /// Login with SIWE message.
  Future<AuthSession> loginWithSiwe({
    required SiweMessage siweMessage,
    required String signature,
  }) async {
    return await login(
      address: siweMessage.address,
      signature: signature,
      message: siweMessage.toMessage(),
      chainId: siweMessage.chainId,
    );
  }

  /// Logout and invalidate session.
  Future<void> logout(String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/logout'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to logout: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }

  /// Refresh access token.
  Future<AuthSession> refreshToken(String refreshToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/refresh'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'refreshToken': refreshToken,
      }),
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to refresh token: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(data);
  }

  /// Verify token validity.
  Future<bool> verifyToken(String accessToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/auth/verify'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    return response.statusCode == 200;
  }

  /// Get current user from token.
  Future<AuthUser> getCurrentUser(String accessToken) async {
    final response = await http.get(
      Uri.parse('$baseUrl/v1/auth/me'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to get current user: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthUser.fromJson(data);
  }

  /// Enable two-factor authentication.
  Future<TwoFactorSetup> enableTwoFactor(String accessToken) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/2fa/enable'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw CiFiException(
        'Failed to enable 2FA: ${response.body}',
        statusCode: response.statusCode,
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return TwoFactorSetup.fromJson(data);
  }

  /// Verify two-factor code.
  Future<bool> verifyTwoFactorCode({
    required String accessToken,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/2fa/verify'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
      }),
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['valid'] as bool? ?? false;
  }

  /// Disable two-factor authentication.
  Future<void> disableTwoFactor({
    required String accessToken,
    required String code,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/v1/auth/2fa/disable'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'code': code,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw CiFiException(
        'Failed to disable 2FA: ${response.body}',
        statusCode: response.statusCode,
      );
    }
  }
}

/// Authentication challenge (SIWE message).
class AuthChallenge {
  final String message;
  final String nonce;
  final DateTime expiresAt;

  const AuthChallenge({
    required this.message,
    required this.nonce,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'message': message,
        'nonce': nonce,
        'expiresAt': expiresAt.toIso8601String(),
      };

  factory AuthChallenge.fromJson(Map<String, dynamic> json) {
    return AuthChallenge(
      message: json['message'] as String,
      nonce: json['nonce'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

/// Authentication session.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final DateTime issuedAt;
  final AuthUser user;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.issuedAt,
    required this.user,
  });

  /// Check if token is expired.
  bool get isExpired {
    final expiryDate = issuedAt.add(Duration(seconds: expiresIn));
    return DateTime.now().isAfter(expiryDate);
  }

  /// Check if token should be refreshed (80% of lifetime).
  bool get shouldRefresh {
    final refreshThreshold = issuedAt.add(
      Duration(seconds: (expiresIn * 0.8).toInt()),
    );
    return DateTime.now().isAfter(refreshThreshold);
  }

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'tokenType': tokenType,
        'expiresIn': expiresIn,
        'issuedAt': issuedAt.toIso8601String(),
        'user': user.toJson(),
      };

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: json['expiresIn'] as int,
      issuedAt: json['issuedAt'] != null
          ? DateTime.parse(json['issuedAt'] as String)
          : DateTime.now(),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

/// Authenticated user information.
class AuthUser {
  final String userId;
  final String address;
  final int chainId;
  final String? email;
  final String? username;
  final bool twoFactorEnabled;
  final DateTime createdAt;

  const AuthUser({
    required this.userId,
    required this.address,
    required this.chainId,
    this.email,
    this.username,
    required this.twoFactorEnabled,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'address': address,
        'chainId': chainId,
        if (email != null) 'email': email,
        if (username != null) 'username': username,
        'twoFactorEnabled': twoFactorEnabled,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String,
      address: json['address'] as String,
      chainId: json['chainId'] as int,
      email: json['email'] as String?,
      username: json['username'] as String?,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Two-factor authentication setup.
class TwoFactorSetup {
  final String secret;
  final String qrCode;
  final List<String> backupCodes;

  const TwoFactorSetup({
    required this.secret,
    required this.qrCode,
    required this.backupCodes,
  });

  Map<String, dynamic> toJson() => {
        'secret': secret,
        'qrCode': qrCode,
        'backupCodes': backupCodes,
      };

  factory TwoFactorSetup.fromJson(Map<String, dynamic> json) {
    return TwoFactorSetup(
      secret: json['secret'] as String,
      qrCode: json['qrCode'] as String,
      backupCodes: List<String>.from(json['backupCodes'] as List),
    );
  }
}
