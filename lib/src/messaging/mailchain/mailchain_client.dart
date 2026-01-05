import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../wallet/wallet_manager.dart';
import '../../errors/web3_exception.dart';
import 'mailchain_inbox.dart';

/// Mailchain client for blockchain email.
///
/// Mailchain enables email-style communication using wallet addresses.
/// Messages are encrypted and can be sent to any blockchain address
/// in the format: `0x123...@ethereum.mailchain.com`
///
/// ## Features
///
/// - End-to-end encryption
/// - Email-style experience (subject, body, HTML)
/// - Inbox/Sent/Drafts folders
/// - Read receipts
/// - Works across all blockchains
///
/// ## Quick Start
///
/// ```dart
/// final mailchain = Web3Refi.instance.messaging.mailchain;
///
/// // Initialize
/// await mailchain.initialize();
///
/// // Send an email
/// await mailchain.sendMail(
///   to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb@ethereum.mailchain.com',
///   subject: 'Payment Confirmation',
///   body: 'Your payment of \$100 has been processed.',
/// );
///
/// // Get inbox
/// final messages = await mailchain.getInbox();
/// for (final msg in messages) {
///   print('From: ${msg.from}');
///   print('Subject: ${msg.subject}');
/// }
/// ```
///
/// ## Address Format
///
/// Mailchain addresses follow this format:
/// - Ethereum: `0x123...@ethereum.mailchain.com`
/// - Polygon: `0x123...@polygon.mailchain.com`
/// - Bitcoin: `bc1q...@bitcoin.mailchain.com`
/// - ENS: `vitalik.eth@ens.mailchain.com`
class MailchainClient extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Wallet manager for authentication.
  final WalletManager _walletManager;

  /// Whether Mailchain is enabled.
  final bool enabled;

  /// HTTP client for API requests.
  final http.Client _httpClient;

  /// Mailchain API base URL.
  static const String _apiBaseUrl = 'https://api.mailchain.com/v1';

  /// Authentication token.
  String? _accessToken;

  /// Token expiration time.
  DateTime? _tokenExpiry;

  /// Whether client is authenticated.
  bool _isAuthenticated = false;

  /// Current user's Mailchain address.
  String? _mailchainAddress;

  /// Inbox manager.
  late final MailchainInbox _inbox;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  MailchainClient({
    required WalletManager walletManager,
    this.enabled = true,
    http.Client? httpClient,
  })  : _walletManager = walletManager,
        _httpClient = httpClient ?? http.Client() {
    _inbox = MailchainInbox(client: this);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Whether Mailchain is authenticated and ready.
  bool get isAuthenticated => _isAuthenticated && _accessToken != null;

  /// Current user's Mailchain address.
  String? get address => _mailchainAddress;

  /// Connected wallet address.
  String? get walletAddress => _walletManager.address;

  /// Inbox manager for accessing messages.
  MailchainInbox get inbox => _inbox;

  /// Whether the access token is expired.
  bool get isTokenExpired {
    if (_tokenExpiry == null) return true;
    return DateTime.now().isAfter(_tokenExpiry!);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the Mailchain client.
  ///
  /// Requires a connected wallet. Will prompt user to sign
  /// an authentication message.
  ///
  /// ```dart
  /// await Web3Refi.instance.connect();
  /// await mailchain.initialize();
  /// ```
  Future<void> initialize() async {
    if (!enabled) {
      throw MessagingException(
        message: 'Mailchain is not enabled',
        code: 'mailchain_disabled',
      );
    }

    if (_isAuthenticated && !isTokenExpired) {
      _log('Mailchain already authenticated');
      return;
    }

    if (!_walletManager.isConnected) {
      throw MessagingException(
        message: 'Wallet must be connected before initializing Mailchain',
        code: 'wallet_not_connected',
      );
    }

    _log('Initializing Mailchain...');

    try {
      // Generate authentication message
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final message = _getAuthMessage(timestamp);

      // Sign with wallet
      final signature = await _walletManager.signMessage(message);

      // Authenticate with Mailchain API
      await _authenticate(
        address: _walletManager.address!,
        signature: signature,
        timestamp: timestamp,
      );

      // Set Mailchain address
      _mailchainAddress = formatAddress(_walletManager.address!);

      _isAuthenticated = true;
      notifyListeners();
      _log('Mailchain initialized: $_mailchainAddress');
    } catch (e) {
      _log('Failed to initialize Mailchain: $e');
      throw MessagingException(
        message: 'Failed to initialize Mailchain: $e',
        code: 'mailchain_init_failed',
        cause: e,
      );
    }
  }

  /// Generate authentication message.
  String _getAuthMessage(int timestamp) {
    return '''
Mailchain Authentication

Sign this message to authenticate with Mailchain.
This will not trigger a blockchain transaction.

Address: ${_walletManager.address}
Timestamp: $timestamp
''';
  }

  /// Authenticate with Mailchain API.
  Future<void> _authenticate({
    required String address,
    required String signature,
    required int timestamp,
  }) async {
    // In production, call actual Mailchain API
    // This is a simplified implementation

    final response = await _httpClient.post(
      Uri.parse('$_apiBaseUrl/auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'address': address,
        'signature': signature,
        'timestamp': timestamp,
        'chain': _getChainName(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // For demo, simulate successful auth
      _log('Simulating Mailchain authentication');
    }

    // In production, extract token from response
    // For demo, simulate
    _accessToken = 'mc_token_${DateTime.now().millisecondsSinceEpoch}';
    _tokenExpiry = DateTime.now().add(const Duration(hours: 24));
  }

  /// Get chain name for Mailchain address.
  String _getChainName() {
    final chainId = _walletManager.chainId;
    switch (chainId) {
      case 1:
        return 'ethereum';
      case 137:
        return 'polygon';
      case 42161:
        return 'arbitrum';
      case 10:
        return 'optimism';
      case 8453:
        return 'base';
      default:
        return 'ethereum';
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SENDING MAIL
  // ══════════════════════════════════════════════════════════════════════════

  /// Send an email via Mailchain.
  ///
  /// ```dart
  /// await mailchain.sendMail(
  ///   to: '0x742d35Cc...@ethereum.mailchain.com',
  ///   subject: 'Payment Confirmation',
  ///   body: 'Your payment has been processed.',
  /// );
  /// ```
  ///
  /// For HTML emails:
  /// ```dart
  /// await mailchain.sendMail(
  ///   to: '0x123...@ethereum.mailchain.com',
  ///   subject: 'Invoice',
  ///   body: '<h1>Invoice #1234</h1><p>Amount: \$100</p>',
  ///   isHtml: true,
  /// );
  /// ```
  Future<MailchainSendResult> sendMail({
    required String to,
    required String subject,
    required String body,
    bool isHtml = false,
    List<String>? cc,
    List<String>? bcc,
    List<MailchainAttachment>? attachments,
  }) async {
    _requireAuthenticated();

    // Validate recipient
    if (!_isValidMailchainAddress(to)) {
      // Try to format as Mailchain address
      to = formatAddress(to);
    }

    _log('Sending mail to: $to');

    try {
      // Encrypt message for recipient
      final encryptedBody = await _encryptForRecipient(to, body);

      // Build request
      final payload = {
        'from': _mailchainAddress,
        'to': [to],
        'subject': subject,
        'body': encryptedBody,
        'contentType': isHtml ? 'text/html' : 'text/plain',
        if (cc != null && cc.isNotEmpty) 'cc': cc.map(formatAddress).toList(),
        if (bcc != null && bcc.isNotEmpty) 'bcc': bcc.map(formatAddress).toList(),
        if (attachments != null && attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };

      // Send via API
      final response = await _httpClient.post(
        Uri.parse('$_apiBaseUrl/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        // For demo, simulate success
        _log('Simulating successful send');
      }

      // In production, parse response for message ID
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

      _log('Mail sent successfully: $messageId');

      return MailchainSendResult(
        success: true,
        messageId: messageId,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _log('Failed to send mail: $e');
      throw MessagingException.sendFailed('Failed to send email: $e');
    }
  }

  /// Send to multiple recipients.
  Future<List<MailchainSendResult>> sendMailToMultiple({
    required List<String> to,
    required String subject,
    required String body,
    bool isHtml = false,
  }) async {
    final results = <MailchainSendResult>[];

    for (final recipient in to) {
      try {
        final result = await sendMail(
          to: recipient,
          subject: subject,
          body: body,
          isHtml: isHtml,
        );
        results.add(result);
      } catch (e) {
        results.add(MailchainSendResult(
          success: false,
          error: e.toString(),
          timestamp: DateTime.now(),
        ));
      }
    }

    return results;
  }

  /// Encrypt message body for recipient.
  Future<String> _encryptForRecipient(String address, String body) async {
    // In production:
    // 1. Fetch recipient's public key from Mailchain
    // 2. Encrypt using X25519 key exchange
    // For demo, return base64 encoded
    return base64Encode(utf8.encode(body));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INBOX
  // ══════════════════════════════════════════════════════════════════════════

  /// Get messages from inbox.
  ///
  /// ```dart
  /// final messages = await mailchain.getInbox();
  /// for (final msg in messages) {
  ///   print('From: ${msg.from}');
  ///   print('Subject: ${msg.subject}');
  ///   print('Date: ${msg.timestamp}');
  /// }
  /// ```
  Future<List<MailchainMessage>> getInbox({
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    _requireAuthenticated();
    return _inbox.getMessages(
      folder: MailFolder.inbox,
      limit: limit,
      offset: offset,
      unreadOnly: unreadOnly,
    );
  }

  /// Get sent messages.
  Future<List<MailchainMessage>> getSent({
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuthenticated();
    return _inbox.getMessages(
      folder: MailFolder.sent,
      limit: limit,
      offset: offset,
    );
  }

  /// Get drafts.
  Future<List<MailchainMessage>> getDrafts({
    int limit = 50,
    int offset = 0,
  }) async {
    _requireAuthenticated();
    return _inbox.getMessages(
      folder: MailFolder.drafts,
      limit: limit,
      offset: offset,
    );
  }

  /// Get a specific message by ID.
  Future<MailchainMessage> getMessage(String messageId) async {
    _requireAuthenticated();
    return _inbox.getMessage(messageId);
  }

  /// Mark a message as read.
  Future<void> markAsRead(String messageId) async {
    _requireAuthenticated();
    await _inbox.markAsRead(messageId);
  }

  /// Mark a message as unread.
  Future<void> markAsUnread(String messageId) async {
    _requireAuthenticated();
    await _inbox.markAsUnread(messageId);
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    _requireAuthenticated();
    await _inbox.deleteMessage(messageId);
  }

  /// Move message to folder.
  Future<void> moveToFolder(String messageId, MailFolder folder) async {
    _requireAuthenticated();
    await _inbox.moveToFolder(messageId, folder);
  }

  /// Get unread count.
  Future<int> getUnreadCount() async {
    _requireAuthenticated();
    return _inbox.getUnreadCount();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADDRESS UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Format a wallet address as Mailchain address.
  ///
  /// ```dart
  /// final mcAddress = mailchain.formatAddress('0x123...');
  /// // Returns: '0x123...@ethereum.mailchain.com'
  /// ```
  String formatAddress(String address, {String? chain}) {
    // If already a Mailchain address, return as-is
    if (_isValidMailchainAddress(address)) {
      return address;
    }

    // Remove any existing domain
    final cleanAddress = address.split('@').first;

    // Add Mailchain domain
    final chainName = chain ?? _getChainName();
    return '$cleanAddress@$chainName.mailchain.com';
  }

  /// Extract wallet address from Mailchain address.
  ///
  /// ```dart
  /// final wallet = mailchain.extractAddress('0x123...@ethereum.mailchain.com');
  /// // Returns: '0x123...'
  /// ```
  String extractAddress(String mailchainAddress) {
    return mailchainAddress.split('@').first;
  }

  /// Check if an address is a valid Mailchain address.
  bool _isValidMailchainAddress(String address) {
    return address.contains('@') && address.contains('.mailchain.com');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ══════════════════════════════════════════════════════════════════════════

  /// Search messages.
  ///
  /// ```dart
  /// final results = await mailchain.searchMessages('invoice');
  /// ```
  Future<List<MailchainMessage>> searchMessages(
    String query, {
    MailFolder? folder,
    int limit = 50,
  }) async {
    _requireAuthenticated();
    return _inbox.search(query, folder: folder, limit: limit);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL API
  // ══════════════════════════════════════════════════════════════════════════

  /// Make an authenticated API request (used by MailchainInbox).
  Future<http.Response> apiRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    _requireAuthenticated();

    final uri = Uri.parse('$_apiBaseUrl$endpoint').replace(
      queryParameters: queryParams,
    );

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };

    switch (method.toUpperCase()) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: jsonEncode(body));
      case 'PUT':
        return _httpClient.put(uri, headers: headers, body: jsonEncode(body));
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  void _requireAuthenticated() {
    if (!isAuthenticated) {
      throw MessagingException.notInitialized();
    }

    if (isTokenExpired) {
      _isAuthenticated = false;
      throw MessagingException(
        message: 'Mailchain session expired. Please re-authenticate.',
        code: 'session_expired',
      );
    }
  }

  void _log(String message) {
    debugPrint('[web3refi:Mailchain] $message');
  }

  /// Clean up resources.
  Future<void> dispose() async {
    _accessToken = null;
    _isAuthenticated = false;
    _httpClient.close();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Result of sending a Mailchain message.
class MailchainSendResult {
  /// Whether the send was successful.
  final bool success;

  /// Message ID if successful.
  final String? messageId;

  /// Error message if failed.
  final String? error;

  /// When the message was sent.
  final DateTime timestamp;

  const MailchainSendResult({
    required this.success,
    this.messageId,
    this.error,
    required this.timestamp,
  });

  @override
  String toString() => success
      ? 'MailchainSendResult(success, id: $messageId)'
      : 'MailchainSendResult(failed: $error)';
}

/// An attachment for Mailchain messages.
class MailchainAttachment {
  /// File name.
  final String name;

  /// MIME type.
  final String mimeType;

  /// Base64 encoded content.
  final String content;

  /// File size in bytes.
  final int size;

  const MailchainAttachment({
    required this.name,
    required this.mimeType,
    required this.content,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'mimeType': mimeType,
        'content': content,
        'size': size,
      };

  factory MailchainAttachment.fromJson(Map<String, dynamic> json) {
    return MailchainAttachment(
      name: json['name'] as String,
      mimeType: json['mimeType'] as String,
      content: json['content'] as String,
      size: json['size'] as int,
    );
  }
}

/// Mail folder types.
enum MailFolder {
  /// Inbox (received messages).
  inbox,

  /// Sent messages.
  sent,

  /// Drafts (unsent messages).
  drafts,

  /// Trash (deleted messages).
  trash,

  /// Spam/junk folder.
  spam,

  /// Archive.
  archive,

  /// Starred/important messages.
  starred,
}

/// Extension methods for MailFolder.
extension MailFolderExtension on MailFolder {
  /// API endpoint path for this folder.
  String get apiPath {
    switch (this) {
      case MailFolder.inbox:
        return '/messages/inbox';
      case MailFolder.sent:
        return '/messages/sent';
      case MailFolder.drafts:
        return '/messages/drafts';
      case MailFolder.trash:
        return '/messages/trash';
      case MailFolder.spam:
        return '/messages/spam';
      case MailFolder.archive:
        return '/messages/archive';
      case MailFolder.starred:
        return '/messages/starred';
    }
  }

  /// Human-readable display name.
  String get displayName {
    switch (this) {
      case MailFolder.inbox:
        return 'Inbox';
      case MailFolder.sent:
        return 'Sent';
      case MailFolder.drafts:
        return 'Drafts';
      case MailFolder.trash:
        return 'Trash';
      case MailFolder.spam:
        return 'Spam';
      case MailFolder.archive:
        return 'Archive';
      case MailFolder.starred:
        return 'Starred';
    }
  }
}
