import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web3refi/src/messaging/mailchain/mailchain_client.dart';

/// Manages Mailchain inbox, messages, and folders.
///
/// Provides methods to fetch, read, delete, and organize email messages.
///
/// ## Usage
///
/// ```dart
/// final inbox = mailchain.inbox;
///
/// // Get messages
/// final messages = await inbox.getMessages(folder: MailFolder.inbox);
///
/// // Read a message
/// final message = await inbox.getMessage(messageId);
///
/// // Mark as read
/// await inbox.markAsRead(messageId);
///
/// // Delete
/// await inbox.deleteMessage(messageId);
/// ```
class MailchainInbox {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Reference to parent Mailchain client.
  final MailchainClient _client;

  /// Cached messages by folder.
  final Map<MailFolder, List<MailchainMessage>> _messageCache = {};

  /// Cached message details by ID.
  final Map<String, MailchainMessage> _messageDetails = {};

  /// Unread count by folder.
  final Map<MailFolder, int> _unreadCounts = {};

  /// Last fetch time by folder.
  final Map<MailFolder, DateTime> _lastFetch = {};

  /// Cache expiry duration.
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  MailchainInbox({required MailchainClient client}) : _client = client;

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGE RETRIEVAL
  // ══════════════════════════════════════════════════════════════════════════

  /// Get messages from a folder.
  ///
  /// ```dart
  /// // Get inbox messages
  /// final inbox = await mailchainInbox.getMessages(folder: MailFolder.inbox);
  ///
  /// // Get only unread messages
  /// final unread = await mailchainInbox.getMessages(
  ///   folder: MailFolder.inbox,
  ///   unreadOnly: true,
  /// );
  ///
  /// // Pagination
  /// final page2 = await mailchainInbox.getMessages(
  ///   folder: MailFolder.inbox,
  ///   limit: 20,
  ///   offset: 20,
  /// );
  /// ```
  Future<List<MailchainMessage>> getMessages({
    required MailFolder folder,
    int limit = 50,
    int offset = 0,
    bool unreadOnly = false,
    bool forceRefresh = false,
  }) async {
    // Check cache
    if (!forceRefresh && _isCacheValid(folder)) {
      var cached = _messageCache[folder] ?? [];
      if (unreadOnly) {
        cached = cached.where((m) => !m.read).toList();
      }
      return cached.skip(offset).take(limit).toList();
    }

    _log('Fetching messages from ${folder.displayName}...');

    try {
      // In production, call actual API
      final response = await _client.apiRequest(
        'GET',
        folder.apiPath,
        queryParams: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (unreadOnly) 'unread': 'true',
        },
      );

      List<MailchainMessage> messages;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        messages = (data['messages'] as List?)
                ?.map((m) => MailchainMessage.fromJson(m))
                .toList() ??
            [];
      } else {
        // For demo, return simulated messages
        messages = _generateDemoMessages(folder, limit);
      }

      // Update cache
      _messageCache[folder] = messages;
      _lastFetch[folder] = DateTime.now();

      // Update unread count
      _unreadCounts[folder] = messages.where((m) => !m.read).length;

      _log('Fetched ${messages.length} messages from ${folder.displayName}');
      return messages;
    } catch (e) {
      _log('Error fetching messages: $e');
      // Return cached if available
      return _messageCache[folder] ?? [];
    }
  }

  /// Get a specific message by ID.
  ///
  /// Returns the full message content including body.
  ///
  /// ```dart
  /// final message = await inbox.getMessage('msg_123');
  /// print('Body: ${message.body}');
  /// ```
  Future<MailchainMessage> getMessage(String messageId) async {
    // Check cache
    if (_messageDetails.containsKey(messageId)) {
      return _messageDetails[messageId]!;
    }

    _log('Fetching message: $messageId');

    try {
      final response = await _client.apiRequest(
        'GET',
        '/messages/$messageId',
      );

      MailchainMessage message;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        message = MailchainMessage.fromJson(data);
      } else {
        // For demo, return a simulated message
        message = _generateDemoMessage(messageId);
      }

      // Decrypt body
      message = message.copyWith(
        body: await _decryptBody(message.body ?? ''),
      );

      // Cache the message
      _messageDetails[messageId] = message;

      return message;
    } catch (e) {
      _log('Error fetching message: $e');
      throw Exception('Failed to fetch message: $e');
    }
  }

  /// Decrypt message body.
  Future<String> _decryptBody(String encryptedBody) async {
    // In production, use proper decryption
    // For demo, decode base64
    try {
      return utf8.decode(base64Decode(encryptedBody));
    } catch (_) {
      return encryptedBody;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MESSAGE ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Mark a message as read.
  ///
  /// ```dart
  /// await inbox.markAsRead('msg_123');
  /// ```
  Future<void> markAsRead(String messageId) async {
    _log('Marking message as read: $messageId');

    try {
      await _client.apiRequest(
        'PUT',
        '/messages/$messageId/read',
        body: {'read': true},
      );

      // Update cache
      _updateMessageReadStatus(messageId, true);
    } catch (e) {
      _log('Error marking as read: $e');
    }
  }

  /// Mark a message as unread.
  ///
  /// ```dart
  /// await inbox.markAsUnread('msg_123');
  /// ```
  Future<void> markAsUnread(String messageId) async {
    _log('Marking message as unread: $messageId');

    try {
      await _client.apiRequest(
        'PUT',
        '/messages/$messageId/read',
        body: {'read': false},
      );

      // Update cache
      _updateMessageReadStatus(messageId, false);
    } catch (e) {
      _log('Error marking as unread: $e');
    }
  }

  /// Mark multiple messages as read.
  Future<void> markMultipleAsRead(List<String> messageIds) async {
    for (final id in messageIds) {
      await markAsRead(id);
    }
  }

  /// Delete a message.
  ///
  /// Moves the message to trash (soft delete).
  ///
  /// ```dart
  /// await inbox.deleteMessage('msg_123');
  /// ```
  Future<void> deleteMessage(String messageId) async {
    _log('Deleting message: $messageId');

    try {
      await _client.apiRequest(
        'DELETE',
        '/messages/$messageId',
      );

      // Remove from cache
      _removeFromCache(messageId);
    } catch (e) {
      _log('Error deleting message: $e');
    }
  }

  /// Permanently delete a message.
  ///
  /// Only works for messages in trash.
  Future<void> permanentlyDelete(String messageId) async {
    _log('Permanently deleting message: $messageId');

    try {
      await _client.apiRequest(
        'DELETE',
        '/messages/$messageId/permanent',
      );

      // Remove from cache
      _removeFromCache(messageId);
    } catch (e) {
      _log('Error permanently deleting: $e');
    }
  }

  /// Move message to a folder.
  ///
  /// ```dart
  /// await inbox.moveToFolder('msg_123', MailFolder.archive);
  /// ```
  Future<void> moveToFolder(String messageId, MailFolder folder) async {
    _log('Moving message $messageId to ${folder.displayName}');

    try {
      await _client.apiRequest(
        'PUT',
        '/messages/$messageId/folder',
        body: {'folder': folder.name},
      );

      // Update cache - remove from all folders and add to target
      _removeFromCache(messageId);
      _invalidateCache(folder);
    } catch (e) {
      _log('Error moving message: $e');
    }
  }

  /// Star/unstar a message.
  Future<void> toggleStar(String messageId, bool starred) async {
    _log('${starred ? 'Starring' : 'Unstarring'} message: $messageId');

    try {
      await _client.apiRequest(
        'PUT',
        '/messages/$messageId/star',
        body: {'starred': starred},
      );

      // Update cache
      _updateMessageStar(messageId, starred);
    } catch (e) {
      _log('Error toggling star: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEARCH
  // ══════════════════════════════════════════════════════════════════════════

  /// Search messages.
  ///
  /// Searches subject, body, and sender/recipient addresses.
  ///
  /// ```dart
  /// final results = await inbox.search('invoice');
  /// ```
  Future<List<MailchainMessage>> search(
    String query, {
    MailFolder? folder,
    int limit = 50,
  }) async {
    _log('Searching for: "$query"');

    try {
      final response = await _client.apiRequest(
        'GET',
        '/messages/search',
        queryParams: {
          'q': query,
          if (folder != null) 'folder': folder.name,
          'limit': limit.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['results'] as List?)
                ?.map((m) => MailchainMessage.fromJson(m))
                .toList() ??
            [];
      }

      // For demo, search cached messages
      return _searchCached(query, folder, limit);
    } catch (e) {
      _log('Error searching: $e');
      return _searchCached(query, folder, limit);
    }
  }

  /// Search through cached messages.
  List<MailchainMessage> _searchCached(
    String query,
    MailFolder? folder,
    int limit,
  ) {
    final queryLower = query.toLowerCase();
    final results = <MailchainMessage>[];

    final foldersToSearch = folder != null ? [folder] : _messageCache.keys;

    for (final f in foldersToSearch) {
      final messages = _messageCache[f] ?? [];
      for (final msg in messages) {
        if (msg.subject.toLowerCase().contains(queryLower) ||
            msg.from.toLowerCase().contains(queryLower) ||
            (msg.body?.toLowerCase().contains(queryLower) ?? false)) {
          results.add(msg);
          if (results.length >= limit) break;
        }
      }
      if (results.length >= limit) break;
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COUNTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get unread message count.
  ///
  /// ```dart
  /// final count = await inbox.getUnreadCount();
  /// print('You have $count unread messages');
  /// ```
  Future<int> getUnreadCount({MailFolder folder = MailFolder.inbox}) async {
    // Use cached count if available
    if (_unreadCounts.containsKey(folder)) {
      return _unreadCounts[folder]!;
    }

    try {
      final response = await _client.apiRequest(
        'GET',
        '${folder.apiPath}/count',
        queryParams: {'unread': 'true'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final count = data['count'] as int? ?? 0;
        _unreadCounts[folder] = count;
        return count;
      }

      // For demo, count from cache
      final messages = _messageCache[folder] ?? [];
      return messages.where((m) => !m.read).length;
    } catch (e) {
      _log('Error getting unread count: $e');
      return 0;
    }
  }

  /// Get total message count for a folder.
  Future<int> getMessageCount({MailFolder folder = MailFolder.inbox}) async {
    try {
      final response = await _client.apiRequest(
        'GET',
        '${folder.apiPath}/count',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] as int? ?? 0;
      }

      return _messageCache[folder]?.length ?? 0;
    } catch (e) {
      _log('Error getting message count: $e');
      return 0;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CACHE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  bool _isCacheValid(MailFolder folder) {
    final lastFetch = _lastFetch[folder];
    if (lastFetch == null) return false;
    return DateTime.now().difference(lastFetch) < _cacheExpiry;
  }

  void _invalidateCache(MailFolder folder) {
    _lastFetch.remove(folder);
  }

  void _removeFromCache(String messageId) {
    for (final folder in _messageCache.keys) {
      _messageCache[folder]?.removeWhere((m) => m.id == messageId);
    }
    _messageDetails.remove(messageId);
  }

  void _updateMessageReadStatus(String messageId, bool read) {
    _messageDetails[messageId] = _messageDetails[messageId]?.copyWith(read: read);

    for (final folder in _messageCache.keys) {
      final index = _messageCache[folder]?.indexWhere((m) => m.id == messageId) ?? -1;
      if (index >= 0) {
        final msg = _messageCache[folder]![index];
        _messageCache[folder]![index] = msg.copyWith(read: read);
      }
    }
  }

  void _updateMessageStar(String messageId, bool starred) {
    _messageDetails[messageId] = _messageDetails[messageId]?.copyWith(starred: starred);

    for (final folder in _messageCache.keys) {
      final index = _messageCache[folder]?.indexWhere((m) => m.id == messageId) ?? -1;
      if (index >= 0) {
        final msg = _messageCache[folder]![index];
        _messageCache[folder]![index] = msg.copyWith(starred: starred);
      }
    }
  }

  /// Clear all caches.
  void clearCache() {
    _messageCache.clear();
    _messageDetails.clear();
    _unreadCounts.clear();
    _lastFetch.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEMO DATA
  // ══════════════════════════════════════════════════════════════════════════

  /// Generate demo messages for testing.
  List<MailchainMessage> _generateDemoMessages(MailFolder folder, int count) {
    final messages = <MailchainMessage>[];
    final now = DateTime.now();

    for (var i = 0; i < count; i++) {
      messages.add(MailchainMessage(
        id: 'msg_${folder.name}_$i',
        from: '0x${(i * 12345).toRadixString(16).padLeft(40, '0')}@ethereum.mailchain.com',
        to: [_client.address ?? ''],
        subject: 'Demo message #${i + 1}',
        preview: 'This is a preview of demo message ${i + 1}...',
        body: 'This is the full body of demo message ${i + 1}. Lorem ipsum dolor sit amet.',
        timestamp: now.subtract(Duration(hours: i * 2)),
        read: i % 3 != 0, // Every 3rd message is unread
        starred: i % 5 == 0, // Every 5th message is starred
        folder: folder,
      ));
    }

    return messages;
  }

  /// Generate a single demo message.
  MailchainMessage _generateDemoMessage(String messageId) {
    return MailchainMessage(
      id: messageId,
      from: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb@ethereum.mailchain.com',
      to: [_client.address ?? ''],
      subject: 'Demo Message',
      preview: 'This is a demo message preview...',
      body: '''
Hello!

This is a demo message for testing the Mailchain integration.

Best regards,
Demo Sender
      ''',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      read: false,
      starred: false,
      folder: MailFolder.inbox,
    );
  }

  void _log(String message) {
    debugPrint('[web3refi:MailchainInbox] $message');
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MAILCHAIN MESSAGE
// ════════════════════════════════════════════════════════════════════════════

/// A Mailchain email message.
class MailchainMessage {
  /// Unique message identifier.
  final String id;

  /// Sender's Mailchain address.
  final String from;

  /// Recipient Mailchain addresses.
  final List<String> to;

  /// CC recipients.
  final List<String>? cc;

  /// BCC recipients.
  final List<String>? bcc;

  /// Email subject line.
  final String subject;

  /// Preview text (truncated body).
  final String? preview;

  /// Full message body.
  final String? body;

  /// Whether the body is HTML.
  final bool isHtml;

  /// When the message was sent.
  final DateTime timestamp;

  /// Whether message has been read.
  final bool read;

  /// Whether message is starred/important.
  final bool starred;

  /// Folder this message is in.
  final MailFolder folder;

  /// Message attachments.
  final List<MailchainAttachment>? attachments;

  /// Reply-to address.
  final String? replyTo;

  /// Message ID this is replying to.
  final String? inReplyTo;

  /// Conversation/thread ID.
  final String? threadId;

  const MailchainMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.timestamp,
    this.cc,
    this.bcc,
    this.preview,
    this.body,
    this.isHtml = false,
    this.read = false,
    this.starred = false,
    this.folder = MailFolder.inbox,
    this.attachments,
    this.replyTo,
    this.inReplyTo,
    this.threadId,
  });

  /// Whether this message has attachments.
  bool get hasAttachments => attachments != null && attachments!.isNotEmpty;

  /// Number of attachments.
  int get attachmentCount => attachments?.length ?? 0;

  /// Shortened sender address for display.
  String get fromShort {
    final addr = from.split('@').first;
    if (addr.length > 10) {
      return '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}';
    }
    return addr;
  }

  /// Formatted timestamp for display.
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.month}/${timestamp.day}/${timestamp.year}';
  }

  /// How long ago this message was received.
  Duration get age => DateTime.now().difference(timestamp);

  /// Create a copy with modified fields.
  MailchainMessage copyWith({
    String? id,
    String? from,
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    String? subject,
    String? preview,
    String? body,
    bool? isHtml,
    DateTime? timestamp,
    bool? read,
    bool? starred,
    MailFolder? folder,
    List<MailchainAttachment>? attachments,
    String? replyTo,
    String? inReplyTo,
    String? threadId,
  }) {
    return MailchainMessage(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      subject: subject ?? this.subject,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      isHtml: isHtml ?? this.isHtml,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      starred: starred ?? this.starred,
      folder: folder ?? this.folder,
      attachments: attachments ?? this.attachments,
      replyTo: replyTo ?? this.replyTo,
      inReplyTo: inReplyTo ?? this.inReplyTo,
      threadId: threadId ?? this.threadId,
    );
  }

  @override
  String toString() => 'MailchainMessage($id, from: $fromShort, subject: $subject)';

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'to': to,
        'cc': cc,
        'bcc': bcc,
        'subject': subject,
        'preview': preview,
        'body': body,
        'isHtml': isHtml,
        'timestamp': timestamp.toIso8601String(),
        'read': read,
        'starred': starred,
        'folder': folder.name,
        'attachments': attachments?.map((a) => a.toJson()).toList(),
        'replyTo': replyTo,
        'inReplyTo': inReplyTo,
        'threadId': threadId,
      };

  factory MailchainMessage.fromJson(Map<String, dynamic> json) {
    return MailchainMessage(
      id: json['id'] as String,
      from: json['from'] as String,
      to: (json['to'] as List).cast<String>(),
      cc: (json['cc'] as List?)?.cast<String>(),
      bcc: (json['bcc'] as List?)?.cast<String>(),
      subject: json['subject'] as String,
      preview: json['preview'] as String?,
      body: json['body'] as String?,
      isHtml: json['isHtml'] as bool? ?? false,
      timestamp: DateTime.parse(json['timestamp'] as String),
      read: json['read'] as bool? ?? false,
      starred: json['starred'] as bool? ?? false,
      folder: MailFolder.values.firstWhere(
        (f) => f.name == json['folder'],
        orElse: () => MailFolder.inbox,
      ),
      attachments: (json['attachments'] as List?)
          ?.map((a) => MailchainAttachment.fromJson(a))
          .toList(),
      replyTo: json['replyTo'] as String?,
      inReplyTo: json['inReplyTo'] as String?,
      threadId: json['threadId'] as String?,
    );
  }
}
