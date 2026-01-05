import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/web3refi_base.dart';

/// A complete inbox screen for Mailchain blockchain email.
///
/// Provides a full-featured email inbox with:
/// - Message list with read/unread status
/// - Pull to refresh
/// - Compose button
/// - Message detail view
/// - Delete and archive actions
///
/// Example:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(builder: (context) => InboxScreen()),
/// );
/// ```
class InboxScreen extends StatefulWidget {
  /// Custom app bar.
  final PreferredSizeWidget? appBar;

  /// Called when compose button is pressed.
  final VoidCallback? onCompose;

  /// Called when a message is tapped.
  final void Function(MailMessage message)? onMessageTap;

  /// Custom message item builder.
  final Widget Function(MailMessage message)? messageItemBuilder;

  /// Enable pull to refresh.
  final bool enableRefresh;

  /// Theme customization.
  final InboxTheme? theme;

  const InboxScreen({
    super.key,
    this.appBar,
    this.onCompose,
    this.onMessageTap,
    this.messageItemBuilder,
    this.enableRefresh = true,
    this.theme,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  List<MailMessage> _inbox = [];
  List<MailMessage> _sent = [];
  bool _isLoading = true;
  String? _error;

  InboxTheme get _theme => widget.theme ?? InboxTheme.light();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadMessages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mailchain = Web3Refi.instance.messaging.mailchain;
      
      // Ensure Mailchain is initialized
      if (!mailchain.isAuthenticated) {
        await mailchain.initialize();
      }

      // Load inbox and sent messages
      final inboxMessages = await mailchain.getInbox();
      final sentMessages = await mailchain.getSent();

      if (mounted) {
        setState(() {
          _inbox = inboxMessages.map((m) => MailMessage(
            id: m.id,
            from: m.from,
            to: m.to,
            subject: m.subject,
            body: m.body,
            timestamp: m.timestamp,
            isRead: m.read,
          )).toList();
          
          _sent = sentMessages.map((m) => MailMessage(
            id: m.id,
            from: m.from,
            to: m.to,
            subject: m.subject,
            body: m.body,
            timestamp: m.timestamp,
            isRead: true,
          )).toList();
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(MailMessage message) async {
    if (message.isRead) return;

    try {
      final mailchain = Web3Refi.instance.messaging.mailchain;
      await mailchain.markAsRead(message.id);
      
      setState(() {
        final index = _inbox.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _inbox[index] = message.copyWith(isRead: true);
        }
      });
    } catch (e) {
      // Ignore errors
    }
  }

  Future<void> _deleteMessage(MailMessage message) async {
    try {
      final mailchain = Web3Refi.instance.messaging.mailchain;
      await mailchain.deleteMessage(message.id);
      
      setState(() {
        _inbox.removeWhere((m) => m.id == message.id);
        _sent.removeWhere((m) => m.id == message.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      appBar: widget.appBar ?? _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: widget.onCompose ?? () => _showCompose(context),
        backgroundColor: _theme.accentColor,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _theme.appBarColor,
      elevation: 0,
      title: const Text('Mailchain'),
      bottom: TabBar(
        controller: _tabController,
        labelColor: _theme.accentColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _theme.accentColor,
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inbox, size: 18),
                const SizedBox(width: 8),
                const Text('Inbox'),
                if (_unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  _Badge(count: _unreadCount),
                ],
              ],
            ),
          ),
          const Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.send, size: 18),
                SizedBox(width: 8),
                Text('Sent'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildMessageList(_inbox, isInbox: true),
        _buildMessageList(_sent, isInbox: false),
      ],
    );
  }

  Widget _buildMessageList(List<MailMessage> messages, {required bool isInbox}) {
    if (messages.isEmpty) {
      return _buildEmptyState(isInbox);
    }

    final list = ListView.separated(
      itemCount: messages.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: Colors.grey.shade200,
      ),
      itemBuilder: (context, index) {
        final message = messages[index];
        return widget.messageItemBuilder?.call(message) ??
            _MessageListItem(
              message: message,
              isInbox: isInbox,
              theme: _theme,
              onTap: () {
                if (isInbox) _markAsRead(message);
                widget.onMessageTap?.call(message) ??
                    _showMessageDetail(context, message);
              },
              onDelete: () => _deleteMessage(message),
            );
      },
    );

    if (widget.enableRefresh) {
      return RefreshIndicator(
        onRefresh: _loadMessages,
        color: _theme.accentColor,
        child: list,
      );
    }

    return list;
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load messages',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadMessages,
              style: ElevatedButton.styleFrom(
                backgroundColor: _theme.accentColor,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isInbox) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isInbox ? Icons.inbox_outlined : Icons.send_outlined,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            isInbox ? 'No messages in inbox' : 'No sent messages',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          if (isInbox) ...[
            const SizedBox(height: 8),
            Text(
              'Messages you receive will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  int get _unreadCount => _inbox.where((m) => !m.isRead).length;

  void _showMessageDetail(BuildContext context, MailMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MessageDetailScreen(
          message: message,
          theme: _theme,
          onReply: () {
            Navigator.pop(context);
            _showCompose(context, replyTo: message);
          },
          onDelete: () {
            Navigator.pop(context);
            _deleteMessage(message);
          },
        ),
      ),
    );
  }

  void _showCompose(BuildContext context, {MailMessage? replyTo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ComposeScreen(
          replyTo: replyTo,
          theme: _theme,
          onSent: () {
            Navigator.pop(context);
            _loadMessages();
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MESSAGE LIST ITEM
// ═══════════════════════════════════════════════════════════════════════════

class _MessageListItem extends StatelessWidget {
  final MailMessage message;
  final bool isInbox;
  final InboxTheme theme;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _MessageListItem({
    required this.message,
    required this.isInbox,
    required this.theme,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(message.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _AddressAvatar(
          address: isInbox ? message.from : message.to,
          size: 48,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                _truncateAddress(isInbox ? message.from : message.to),
                style: TextStyle(
                  fontWeight: message.isRead ? FontWeight.normal : FontWeight.w600,
                  fontSize: 15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _formatDate(message.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message.subject.isEmpty ? '(No subject)' : message.subject,
              style: TextStyle(
                fontWeight: message.isRead ? FontWeight.normal : FontWeight.w500,
                color: message.isRead ? Colors.grey.shade600 : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              message.body,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: !message.isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: theme.accentColor,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  String _truncateAddress(String address) {
    // Remove @mailchain.com suffix if present
    final clean = address.replaceAll(RegExp(r'@.*$'), '');
    if (clean.length <= 12) return clean;
    return '${clean.substring(0, 6)}...${clean.substring(clean.length - 4)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    return '${date.month}/${date.day}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MESSAGE DETAIL SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _MessageDetailScreen extends StatelessWidget {
  final MailMessage message;
  final InboxTheme theme;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const _MessageDetailScreen({
    required this.message,
    required this.theme,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.reply),
            onPressed: onReply,
            tooltip: 'Reply',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject
            Text(
              message.subject.isEmpty ? '(No subject)' : message.subject,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            // Sender info
            Row(
              children: [
                _AddressAvatar(address: message.from, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _truncateAddress(message.from),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'to ${_truncateAddress(message.to)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatFullDate(message.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            // Body
            SelectableText(
              message.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: onReply,
            icon: const Icon(Icons.reply),
            label: const Text('Reply'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    final clean = address.replaceAll(RegExp(r'@.*$'), '');
    if (clean.length <= 14) return clean;
    return '${clean.substring(0, 6)}...${clean.substring(clean.length - 4)}';
  }

  String _formatFullDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPOSE SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class _ComposeScreen extends StatefulWidget {
  final MailMessage? replyTo;
  final InboxTheme theme;
  final VoidCallback onSent;

  const _ComposeScreen({
    this.replyTo,
    required this.theme,
    required this.onSent,
  });

  @override
  State<_ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<_ComposeScreen> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.replyTo != null) {
      _toController.text = widget.replyTo!.from;
      _subjectController.text = widget.replyTo!.subject.startsWith('Re:')
          ? widget.replyTo!.subject
          : 'Re: ${widget.replyTo!.subject}';
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final to = _toController.text.trim();
    final subject = _subjectController.text.trim();
    final body = _bodyController.text.trim();

    if (to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipient')),
      );
      return;
    }

    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final mailchain = Web3Refi.instance.messaging.mailchain;
      
      // Add @ethereum.mailchain.com if not present
      final recipient = to.contains('@') ? to : '$to@ethereum.mailchain.com';
      
      await mailchain.sendMail(
        to: recipient,
        subject: subject,
        body: body,
      );

      widget.onSent();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.appBarColor,
        elevation: 0,
        title: const Text('Compose'),
        actions: [
          TextButton(
            onPressed: _isSending ? null : _send,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Send',
                    style: TextStyle(
                      color: widget.theme.accentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // To field
            TextField(
              controller: _toController,
              decoration: InputDecoration(
                labelText: 'To',
                hintText: '0x... or address@ethereum.mailchain.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Subject field
            TextField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Body field
            TextField(
              controller: _bodyController,
              maxLines: 12,
              decoration: InputDecoration(
                labelText: 'Message',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _AddressAvatar extends StatelessWidget {
  final String address;
  final double size;

  const _AddressAvatar({
    required this.address,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final cleanAddress = address.replaceAll(RegExp(r'@.*$'), '');
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _generateGradient(cleanAddress),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          cleanAddress.length > 2 
              ? cleanAddress.substring(2, 4).toUpperCase()
              : cleanAddress.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  List<Color> _generateGradient(String address) {
    final hash = address.hashCode;
    return [
      Color((hash & 0xFFFFFF) | 0xFF000000),
      Color(((hash >> 8) & 0xFFFFFF) | 0xFF000000),
    ];
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════

/// A mail message.
class MailMessage {
  final String id;
  final String from;
  final String to;
  final String subject;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  const MailMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.subject,
    required this.body,
    required this.timestamp,
    required this.isRead,
  });

  MailMessage copyWith({
    String? id,
    String? from,
    String? to,
    String? subject,
    String? body,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return MailMessage(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Theme for inbox screen.
class InboxTheme {
  final Color? backgroundColor;
  final Color? appBarColor;
  final Color? accentColor;

  const InboxTheme({
    this.backgroundColor,
    this.appBarColor,
    this.accentColor,
  });

  factory InboxTheme.light() => const InboxTheme(
    backgroundColor: Colors.white,
    appBarColor: Colors.white,
    accentColor: Color(0xFF007AFF),
  );

  factory InboxTheme.dark() => const InboxTheme(
    backgroundColor: Color(0xFF1C1C1E),
    appBarColor: Color(0xFF1C1C1E),
    accentColor: Color(0xFF0A84FF),
  );
}
