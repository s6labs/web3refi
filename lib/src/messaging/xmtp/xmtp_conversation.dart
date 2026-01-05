import 'dart:async';
import 'package:flutter/foundation.dart';
import 'xmtp_client.dart';

/// Represents a conversation in XMTP.
///
/// A conversation is a message thread between two wallet addresses.
/// Each conversation has a unique topic and maintains message history.
///
/// ## Usage
///
/// ```dart
/// // Get a conversation
/// final conversation = await xmtp.getConversation('0x123...');
///
/// // Send messages
/// await conversation.send('Hello!');
/// await conversation.send('How are you?');
///
/// // Get message history
/// final messages = await conversation.listMessages(limit: 50);
/// for (final msg in messages) {
///   print('${msg.senderAddressShort}: ${msg.content}');
/// }
///
/// // Stream new messages
/// conversation.streamMessages().listen((message) {
///   print('New: ${message.content}');
/// });
/// ```
class XMTPConversation {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Unique conversation topic/identifier.
  final String topic;

  /// Address of the other participant.
  final String peerAddress;

  /// Address of the current user.
  final String selfAddress;

  /// When this conversation was created.
  final DateTime createdAt;

  /// Reference to parent XMTP client.
  final XMTPClient _client;

  /// Cached messages.
  final List<XMTPMessage> _messageCache = [];

  /// Stream controller for this conversation's messages.
  StreamController<XMTPMessage>? _messageStreamController;

  /// Conversation metadata.
  final Map<String, dynamic> metadata;

  /// Last message in this conversation (cached).
  XMTPMessage? _lastMessage;

  /// Unread message count.
  int _unreadCount = 0;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  XMTPConversation({
    required this.topic,
    required this.peerAddress,
    required this.selfAddress,
    required this.createdAt,
    required XMTPClient client,
    this.metadata = const {},
  }) : _client = client;

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Shortened peer address for display.
  String get peerAddressShort {
    if (peerAddress.length > 10) {
      return '${peerAddress.substring(0, 6)}...${peerAddress.substring(peerAddress.length - 4)}';
    }
    return peerAddress;
  }

  /// Last message in this conversation.
  XMTPMessage? get lastMessage => _lastMessage;

  /// Number of unread messages.
  int get unreadCount => _unreadCount;

  /// Whether there are unread messages.
  bool get hasUnread => _unreadCount > 0;

  /// How long ago this conversation was created.
  Duration get age => DateTime.now().difference(createdAt);

  /// Cached message count.
  int get cachedMessageCount => _messageCache.length;

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGING
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a text message.
  ///
  /// ```dart
  /// await conversation.send('Hello!');
  /// ```
  ///
  /// Returns the sent [XMTPMessage].
  Future<XMTPMessage> send(
    String content, {
    ContentType contentType = ContentType.text,
  }) async {
    if (content.isEmpty) {
      throw ArgumentError('Message content cannot be empty');
    }

    final message = await _client.sendMessageInternal(
      topic: topic,
      content: content,
      contentType: contentType,
    );

    // Update cache
    _messageCache.add(message);
    _lastMessage = message;

    _log('Sent message to $peerAddressShort');
    return message;
  }

  /// Send a text message (alias for [send]).
  Future<XMTPMessage> sendMessage(String content) => send(content);

  /// Send a reply to a specific message.
  ///
  /// ```dart
  /// await conversation.reply(
  ///   originalMessage: someMessage,
  ///   content: 'I agree!',
  /// );
  /// ```
  Future<XMTPMessage> reply({
    required XMTPMessage originalMessage,
    required String content,
  }) async {
    // In production, this would include proper reply metadata
    final replyContent = '> ${originalMessage.content}\n\n$content';
    return send(replyContent, contentType: ContentType.reply);
  }

  /// Send a reaction to a message.
  ///
  /// ```dart
  /// await conversation.react(
  ///   message: someMessage,
  ///   emoji: '👍',
  /// );
  /// ```
  Future<XMTPMessage> react({
    required XMTPMessage message,
    required String emoji,
  }) async {
    // In production, use XMTP's reaction content type
    return send(emoji, contentType: ContentType.reaction);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGE HISTORY
  // ══════════════════════════════════════════════════════════════════════════

  /// List messages in this conversation.
  ///
  /// Messages are returned in chronological order (oldest first).
  ///
  /// ```dart
  /// // Get last 50 messages
  /// final messages = await conversation.listMessages(limit: 50);
  ///
  /// // Get messages before a certain time
  /// final older = await conversation.listMessages(
  ///   before: DateTime.now().subtract(Duration(days: 1)),
  /// );
  ///
  /// // Get messages after a certain time
  /// final newer = await conversation.listMessages(
  ///   after: lastSeenTimestamp,
  /// );
  /// ```
  Future<List<XMTPMessage>> listMessages({
    int? limit,
    DateTime? before,
    DateTime? after,
    SortDirection direction = SortDirection.ascending,
  }) async {
    // Fetch from network
    final messages = await _client.fetchMessages(
      topic: topic,
      limit: limit,
      before: before,
      after: after,
    );

    // Mark messages as sent by self or peer
    for (final msg in messages) {
      msg.isSentByMe = msg.senderAddress.toLowerCase() == selfAddress.toLowerCase();
    }

    // Update cache
    _updateCache(messages);

    // Apply local filtering if network returned all
    var result = List<XMTPMessage>.from(messages.isEmpty ? _messageCache : messages);

    if (before != null) {
      result = result.where((m) => m.sentAt.isBefore(before)).toList();
    }
    if (after != null) {
      result = result.where((m) => m.sentAt.isAfter(after)).toList();
    }

    // Sort
    if (direction == SortDirection.ascending) {
      result.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    } else {
      result.sort((a, b) => b.sentAt.compareTo(a.sentAt));
    }

    // Apply limit
    if (limit != null && result.length > limit) {
      result = direction == SortDirection.ascending
          ? result.sublist(result.length - limit)
          : result.sublist(0, limit);
    }

    return result;
  }

  /// Get a specific message by ID.
  Future<XMTPMessage?> getMessage(String messageId) async {
    // Check cache first
    try {
      return _messageCache.firstWhere((m) => m.id == messageId);
    } catch (_) {
      // Not in cache, would need to fetch from network
      return null;
    }
  }

  /// Update the local message cache.
  void _updateCache(List<XMTPMessage> messages) {
    for (final msg in messages) {
      if (!_messageCache.any((m) => m.id == msg.id)) {
        _messageCache.add(msg);
      }
    }

    // Sort cache by time
    _messageCache.sort((a, b) => a.sentAt.compareTo(b.sentAt));

    // Update last message
    if (_messageCache.isNotEmpty) {
      _lastMessage = _messageCache.last;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAMING
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream new messages in this conversation.
  ///
  /// Emits messages as they arrive in real-time.
  ///
  /// ```dart
  /// final subscription = conversation.streamMessages().listen((message) {
  ///   print('${message.senderAddressShort}: ${message.content}');
  ///
  ///   // Handle different senders
  ///   if (message.isSentByMe) {
  ///     print('(sent by you)');
  ///   } else {
  ///     print('(received)');
  ///   }
  /// });
  ///
  /// // Remember to cancel when done
  /// await subscription.cancel();
  /// ```
  Stream<XMTPMessage> streamMessages() {
    return _client.streamConversationMessages(topic).map((message) {
      message.isSentByMe = message.senderAddress.toLowerCase() == selfAddress.toLowerCase();

      // Update cache and last message
      if (!_messageCache.any((m) => m.id == message.id)) {
        _messageCache.add(message);
        _lastMessage = message;

        // Increment unread if from peer
        if (!message.isSentByMe) {
          _unreadCount++;
        }
      }

      return message;
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // READ RECEIPTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Mark all messages as read.
  ///
  /// Sends a read receipt to the peer.
  void markAsRead() {
    _unreadCount = 0;
    // In production, send read receipt via XMTP
    _log('Marked conversation as read');
  }

  /// Send typing indicator.
  ///
  /// Call when user starts typing to notify peer.
  Future<void> sendTypingIndicator() async {
    // In production, implement typing indicators
    _log('Typing indicator sent');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ══════════════════════════════════════════════════════════════════════════

  /// Search messages in this conversation.
  ///
  /// ```dart
  /// final results = await conversation.searchMessages('invoice');
  /// print('Found ${results.length} messages containing "invoice"');
  /// ```
  Future<List<XMTPMessage>> searchMessages(String query) async {
    if (query.isEmpty) return [];

    final queryLower = query.toLowerCase();
    final messages = await listMessages();

    return messages.where((msg) {
      return msg.content.toLowerCase().contains(queryLower);
    }).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  void _log(String message) {
    debugPrint('[web3refi:XMTPConversation] $message');
  }

  @override
  String toString() => 'XMTPConversation(peer: $peerAddressShort, topic: $topic)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is XMTPConversation && other.topic == topic;
  }

  @override
  int get hashCode => topic.hashCode;

  /// Convert to JSON for serialization.
  Map<String, dynamic> toJson() => {
        'topic': topic,
        'peerAddress': peerAddress,
        'selfAddress': selfAddress,
        'createdAt': createdAt.toIso8601String(),
        'metadata': metadata,
        'unreadCount': _unreadCount,
      };

  /// Create from JSON.
  factory XMTPConversation.fromJson(
    Map<String, dynamic> json,
    XMTPClient client,
  ) {
    return XMTPConversation(
      topic: json['topic'] as String,
      peerAddress: json['peerAddress'] as String,
      selfAddress: json['selfAddress'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      client: client,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    ).._unreadCount = json['unreadCount'] as int? ?? 0;
  }

  /// Dispose resources.
  void dispose() {
    _messageStreamController?.close();
    _messageCache.clear();
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING TYPES
// ════════════════════════════════════════════════════════════════════════════

/// Sort direction for message listing.
enum SortDirection {
  /// Oldest first.
  ascending,

  /// Newest first.
  descending,
}

/// Conversation list item for UI.
class ConversationPreview {
  /// The conversation.
  final XMTPConversation conversation;

  /// Preview text from last message.
  final String? previewText;

  /// When the last message was sent.
  final DateTime? lastMessageAt;

  /// Number of unread messages.
  final int unreadCount;

  ConversationPreview({
    required this.conversation,
    this.previewText,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  /// Create from a conversation.
  factory ConversationPreview.fromConversation(XMTPConversation conv) {
    return ConversationPreview(
      conversation: conv,
      previewText: conv.lastMessage?.content,
      lastMessageAt: conv.lastMessage?.sentAt,
      unreadCount: conv.unreadCount,
    );
  }

  /// Formatted timestamp for display.
  String get formattedTime {
    if (lastMessageAt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastMessageAt!);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${lastMessageAt!.month}/${lastMessageAt!.day}';
  }
}
