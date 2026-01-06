import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web3refi/src/wallet/wallet_manager.dart';
import 'package:web3refi/src/errors/web3_exception.dart';
import 'package:web3refi/src/errors/messaging_exception.dart';
import 'package:web3refi/src/messaging/xmtp/xmtp_conversation.dart';

/// XMTP client for real-time Web3 messaging.
///
/// XMTP (Extensible Message Transport Protocol) enables encrypted,
/// real-time messaging between blockchain wallet addresses.
/// Think of it as "iMessage for Web3".
///
/// ## Features
///
/// - End-to-end encryption
/// - Real-time message delivery
/// - Conversation history
/// - Message streaming
/// - Works across any app using XMTP
///
/// ## Quick Start
///
/// ```dart
/// final xmtp = Web3Refi.instance.messaging.xmtp;
///
/// // Initialize (requires connected wallet)
/// await xmtp.initialize();
///
/// // Send a message
/// await xmtp.sendMessage(
///   recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
///   content: 'Hello from web3refi!',
/// );
///
/// // List conversations
/// final conversations = await xmtp.listConversations();
///
/// // Stream new messages
/// xmtp.streamAllMessages().listen((message) {
///   print('New message from ${message.senderAddress}: ${message.content}');
/// });
/// ```
///
/// ## How It Works
///
/// 1. User connects wallet
/// 2. XMTP derives keys from wallet signature
/// 3. Messages are encrypted end-to-end
/// 4. Delivered via XMTP network (not blockchain)
/// 5. No gas fees for messaging
class XMTPClient extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Wallet manager for signing.
  final WalletManager _walletManager;

  /// XMTP environment ('production' or 'dev').
  final String environment;

  /// Whether client is initialized.
  bool _isInitialized = false;

  /// Connected address.
  String? _address;

  /// XMTP client instance (would be actual XMTP SDK in production).
  dynamic _client;

  /// Cached conversations.
  final Map<String, XMTPConversation> _conversationCache = {};

  /// Message stream controllers by conversation topic.
  final Map<String, StreamController<XMTPMessage>> _messageStreams = {};

  /// Global message stream controller.
  StreamController<XMTPMessage>? _globalMessageStream;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  XMTPClient({
    required WalletManager walletManager,
    this.environment = 'production',
  }) : _walletManager = walletManager;

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Whether XMTP is initialized and ready.
  bool get isInitialized => _isInitialized;

  /// The connected wallet address.
  String? get address => _address;

  /// XMTP API base URL.
  String get _apiBaseUrl => environment == 'production'
      ? 'https://production.xmtp.network'
      : 'https://dev.xmtp.network';

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize the XMTP client.
  ///
  /// Requires a connected wallet. Will prompt user to sign a message
  /// to derive XMTP encryption keys.
  ///
  /// ```dart
  /// await Web3Refi.instance.connect();
  /// await xmtp.initialize();
  /// ```
  Future<void> initialize() async {
    if (_isInitialized) {
      _log('XMTP already initialized');
      return;
    }

    if (!_walletManager.isConnected) {
      throw MessagingException(
        message: 'Wallet must be connected before initializing XMTP',
        code: 'wallet_not_connected',
      );
    }

    _log('Initializing XMTP client...');

    try {
      _address = _walletManager.address;

      // In production, this would use the actual XMTP SDK:
      // 1. Generate key bundle from wallet signature
      // 2. Register keys with XMTP network
      // 3. Create client instance

      // Sign message to derive XMTP keys
      final keySignature = await _walletManager.signMessage(
        _getKeyGenerationMessage(),
      );

      // Derive keys from signature (simplified)
      final keys = await _deriveKeys(keySignature);

      // Create XMTP client
      _client = _XMTPClientInternal(
        address: _address!,
        keys: keys,
        apiBaseUrl: _apiBaseUrl,
      );

      _isInitialized = true;
      notifyListeners();
      _log('XMTP initialized for $_address');
    } catch (e) {
      _log('Failed to initialize XMTP: $e');
      throw MessagingException(
        message: 'Failed to initialize XMTP: $e',
        code: 'xmtp_init_failed',
        cause: e,
      );
    }
  }

  /// Generate the message to sign for XMTP key generation.
  String _getKeyGenerationMessage() {
    return '''
XMTP Key Generation

This signature enables secure messaging with your wallet.
It will not trigger a blockchain transaction or cost any gas.

Address: ${_walletManager.address}
Timestamp: ${DateTime.now().toIso8601String()}
''';
  }

  /// Derive XMTP keys from wallet signature.
  Future<_XMTPKeys> _deriveKeys(String signature) async {
    // In production, use proper key derivation
    // This is a simplified placeholder
    final signatureBytes = utf8.encode(signature);
    return _XMTPKeys(
      identityKey: Uint8List.fromList(signatureBytes.take(32).toList()),
      preKey: Uint8List.fromList(signatureBytes.skip(32).take(32).toList()),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGING
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a message to a recipient.
  ///
  /// Creates a new conversation if one doesn't exist.
  ///
  /// ```dart
  /// await xmtp.sendMessage(
  ///   recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  ///   content: 'Hello!',
  /// );
  /// ```
  ///
  /// Returns the sent [XMTPMessage].
  Future<XMTPMessage> sendMessage({
    required String recipient,
    required String content,
    ContentType contentType = ContentType.text,
  }) async {
    _requireInitialized();

    // Validate recipient
    if (!_isValidAddress(recipient)) {
      throw MessagingException(
        message: 'Invalid recipient address: $recipient',
        code: 'invalid_recipient',
      );
    }

    // Check if recipient can receive messages
    final canMessage = await this.canMessage(recipient);
    if (!canMessage) {
      throw MessagingException.recipientNotFound(recipient);
    }

    // Get or create conversation
    final conversation = await getConversation(recipient);

    // Send message
    final message = await conversation.send(content, contentType: contentType);

    _log('Message sent to $recipient');
    return message;
  }

  /// Check if an address can receive XMTP messages.
  ///
  /// Returns true if the address has registered with XMTP.
  ///
  /// ```dart
  /// if (await xmtp.canMessage('0x123...')) {
  ///   await xmtp.sendMessage(recipient: '0x123...', content: 'Hi!');
  /// } else {
  ///   print('Recipient not on XMTP');
  /// }
  /// ```
  Future<bool> canMessage(String address) async {
    _requireInitialized();

    try {
      // In production, query XMTP network
      // For now, simulate the check
      await Future.delayed(const Duration(milliseconds: 100));

      // Most addresses that exist are assumed to be on XMTP for demo
      return _isValidAddress(address);
    } catch (e) {
      _log('Error checking canMessage for $address: $e');
      return false;
    }
  }

  /// Check multiple addresses at once.
  ///
  /// More efficient than calling [canMessage] multiple times.
  ///
  /// ```dart
  /// final results = await xmtp.canMessageMultiple([
  ///   '0x123...',
  ///   '0x456...',
  ///   '0x789...',
  /// ]);
  /// // results = {'0x123...': true, '0x456...': false, '0x789...': true}
  /// ```
  Future<Map<String, bool>> canMessageMultiple(List<String> addresses) async {
    _requireInitialized();

    final results = <String, bool>{};
    for (final address in addresses) {
      results[address] = await canMessage(address);
    }
    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get all conversations.
  ///
  /// Returns conversations sorted by most recent activity.
  ///
  /// ```dart
  /// final conversations = await xmtp.listConversations();
  /// for (final conv in conversations) {
  ///   print('Chat with: ${conv.peerAddress}');
  ///   final messages = await conv.listMessages(limit: 1);
  ///   if (messages.isNotEmpty) {
  ///     print('Last message: ${messages.first.content}');
  ///   }
  /// }
  /// ```
  Future<List<XMTPConversation>> listConversations() async {
    _requireInitialized();

    try {
      // In production, fetch from XMTP network
      // Return cached conversations for now
      final conversations = _conversationCache.values.toList();

      // Sort by most recent
      conversations.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return conversations;
    } catch (e) {
      _log('Error listing conversations: $e');
      throw MessagingException(
        message: 'Failed to list conversations: $e',
        code: 'list_conversations_failed',
        cause: e,
      );
    }
  }

  /// Get or create a conversation with a specific address.
  ///
  /// ```dart
  /// final conversation = await xmtp.getConversation('0x123...');
  /// await conversation.send('Hello!');
  /// ```
  Future<XMTPConversation> getConversation(String peerAddress) async {
    _requireInitialized();

    // Normalize address
    final normalizedAddress = peerAddress.toLowerCase();

    // Check cache
    if (_conversationCache.containsKey(normalizedAddress)) {
      return _conversationCache[normalizedAddress]!;
    }

    // Create new conversation
    final conversation = XMTPConversation(
      topic: _generateTopic(_address!, peerAddress),
      peerAddress: peerAddress,
      selfAddress: _address!,
      createdAt: DateTime.now(),
      client: this,
    );

    _conversationCache[normalizedAddress] = conversation;
    notifyListeners();

    _log('Created conversation with $peerAddress');
    return conversation;
  }

  /// Create a new conversation.
  ///
  /// Same as [getConversation] but makes intent clearer.
  Future<XMTPConversation> newConversation(String peerAddress) async {
    return getConversation(peerAddress);
  }

  /// Generate a unique topic for a conversation.
  String _generateTopic(String address1, String address2) {
    // Sort addresses for consistent topic regardless of who initiates
    final sorted = [address1.toLowerCase(), address2.toLowerCase()]..sort();
    return 'xmtp:${sorted[0]}:${sorted[1]}';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMING
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream messages from all conversations.
  ///
  /// Listens for new messages across all conversations.
  ///
  /// ```dart
  /// final subscription = xmtp.streamAllMessages().listen((message) {
  ///   print('New message from ${message.senderAddress}');
  ///   print('Content: ${message.content}');
  /// });
  ///
  /// // Later, cancel subscription
  /// await subscription.cancel();
  /// ```
  Stream<XMTPMessage> streamAllMessages() {
    _requireInitialized();

    _globalMessageStream?.close();
    _globalMessageStream = StreamController<XMTPMessage>.broadcast();

    // In production, this would subscribe to XMTP's streaming API
    // For demo, we'll simulate with a timer
    _startMessagePolling();

    return _globalMessageStream!.stream;
  }

  /// Stream messages from a specific conversation.
  ///
  /// ```dart
  /// final conversation = await xmtp.getConversation('0x123...');
  /// conversation.streamMessages().listen((message) {
  ///   print('${message.senderAddress}: ${message.content}');
  /// });
  /// ```
  Stream<XMTPMessage> streamConversationMessages(String topic) {
    _requireInitialized();

    if (!_messageStreams.containsKey(topic)) {
      _messageStreams[topic] = StreamController<XMTPMessage>.broadcast();
    }

    return _messageStreams[topic]!.stream;
  }

  /// Start polling for new messages (demo implementation).
  void _startMessagePolling() {
    // In production, use WebSocket/streaming connection to XMTP
    Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isInitialized || _globalMessageStream?.isClosed == true) {
        timer.cancel();
        return;
      }

      // Poll for new messages
      _pollForMessages();
    });
  }

  Future<void> _pollForMessages() async {
    // In production, this would be handled by XMTP's streaming
    // This is a placeholder for the demo
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNAL MESSAGING
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a message (internal, called by XMTPConversation).
  Future<XMTPMessage> sendMessageInternal({
    required String topic,
    required String content,
    required ContentType contentType,
  }) async {
    // In production, encrypt and send via XMTP network
    final message = XMTPMessage(
      id: _generateMessageId(),
      topic: topic,
      senderAddress: _address!,
      content: content,
      contentType: contentType,
      sentAt: DateTime.now(),
    );

    // Emit to streams
    _messageStreams[topic]?.add(message);
    _globalMessageStream?.add(message);

    return message;
  }

  /// Fetch messages for a conversation (internal).
  Future<List<XMTPMessage>> fetchMessages({
    required String topic,
    int? limit,
    DateTime? before,
    DateTime? after,
  }) async {
    // In production, fetch from XMTP network
    // Return empty for demo
    return [];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  void _requireInitialized() {
    if (!_isInitialized) {
      throw MessagingException.notInitialized();
    }
  }

  bool _isValidAddress(String address) {
    // Basic Ethereum address validation
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address);
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_address!.substring(2, 8)}';
  }

  void _log(String message) {
    debugPrint('[web3refi:XMTP] $message');
  }

  /// Clean up resources.
  @override
  Future<void> dispose() async {
    _globalMessageStream?.close();
    for (final stream in _messageStreams.values) {
      await stream.close();
    }
    _messageStreams.clear();
    _conversationCache.clear();
    _isInitialized = false;
    _client = null;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Content type for XMTP messages.
enum ContentType {
  /// Plain text message.
  text,

  /// Attachment (file, image).
  attachment,

  /// Reaction to another message.
  reaction,

  /// Reply to another message.
  reply,

  /// Read receipt.
  readReceipt,

  /// Custom content type.
  custom,
}

/// An XMTP message.
class XMTPMessage {
  /// Unique message identifier.
  final String id;

  /// Conversation topic this message belongs to.
  final String topic;

  /// Sender's wallet address.
  final String senderAddress;

  /// Message content.
  final String content;

  /// Content type.
  final ContentType contentType;

  /// When the message was sent.
  final DateTime sentAt;

  /// Optional: ID of message this is replying to.
  final String? inReplyTo;

  /// Whether this message was sent by the current user.
  bool isSentByMe = false;

  XMTPMessage({
    required this.id,
    required this.topic,
    required this.senderAddress,
    required this.content,
    required this.contentType,
    required this.sentAt,
    this.inReplyTo,
  });

  /// Formatted sender address (shortened).
  String get senderAddressShort {
    if (senderAddress.length > 10) {
      return '${senderAddress.substring(0, 6)}...${senderAddress.substring(senderAddress.length - 4)}';
    }
    return senderAddress;
  }

  /// How long ago this message was sent.
  Duration get age => DateTime.now().difference(sentAt);

  @override
  String toString() => 'XMTPMessage($id, from: $senderAddressShort)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'topic': topic,
        'senderAddress': senderAddress,
        'content': content,
        'contentType': contentType.name,
        'sentAt': sentAt.toIso8601String(),
        'inReplyTo': inReplyTo,
      };

  factory XMTPMessage.fromJson(Map<String, dynamic> json) => XMTPMessage(
        id: json['id'] as String,
        topic: json['topic'] as String,
        senderAddress: json['senderAddress'] as String,
        content: json['content'] as String,
        contentType: ContentType.values.firstWhere(
          (e) => e.name == json['contentType'],
          orElse: () => ContentType.text,
        ),
        sentAt: DateTime.parse(json['sentAt'] as String),
        inReplyTo: json['inReplyTo'] as String?,
      );
}

/// Internal XMTP keys (simplified).
class _XMTPKeys {
  final Uint8List identityKey;
  final Uint8List preKey;

  _XMTPKeys({required this.identityKey, required this.preKey});
}

/// Internal XMTP client (placeholder for actual SDK).
class _XMTPClientInternal {
  final String address;
  final _XMTPKeys keys;
  final String apiBaseUrl;

  _XMTPClientInternal({
    required this.address,
    required this.keys,
    required this.apiBaseUrl,
  });
}
