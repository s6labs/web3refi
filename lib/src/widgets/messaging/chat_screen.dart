import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3refi/src/core/web3refi_base.dart';

/// A complete chat screen for XMTP messaging.
///
/// Provides a full-featured chat interface with:
/// - Message list with timestamps
/// - Message input with send button
/// - Real-time message streaming
/// - Loading states
/// - Error handling
///
/// Example:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => ChatScreen(
///       recipientAddress: '0x742d35Cc...',
///     ),
///   ),
/// );
/// ```
class ChatScreen extends StatefulWidget {
  /// The recipient's wallet address.
  final String recipientAddress;

  /// Optional recipient name to display.
  final String? recipientName;

  /// Custom app bar.
  final PreferredSizeWidget? appBar;

  /// Custom message bubble builder.
  final Widget Function(ChatMessage message, bool isMe)? messageBubbleBuilder;

  /// Custom input field builder.
  final Widget Function(TextEditingController controller, VoidCallback onSend)?
      inputBuilder;

  /// Called when a message is sent.
  final void Function(String content)? onMessageSent;

  /// Called when an error occurs.
  final void Function(String error)? onError;

  /// Enable haptic feedback.
  final bool enableHaptics;

  /// Theme customization.
  final ChatTheme? theme;

  const ChatScreen({
    required this.recipientAddress, super.key,
    this.recipientName,
    this.appBar,
    this.messageBubbleBuilder,
    this.inputBuilder,
    this.onMessageSent,
    this.onError,
    this.enableHaptics = true,
    this.theme,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  StreamSubscription? _messageSubscription;

  ChatTheme get _theme => widget.theme ?? ChatTheme.light();

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    _messageSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final xmtp = Web3Refi.instance.messaging.xmtp;
      
      // Ensure XMTP is initialized
      if (!xmtp.isInitialized) {
        await xmtp.initialize();
      }

      // Get or create conversation
      final conversation = await xmtp.getConversation(widget.recipientAddress);

      // Load existing messages
      final messages = await conversation.listMessages();
      
      if (mounted) {
        setState(() {
          _messages = messages.map((m) => ChatMessage(
            id: m.id,
            content: m.content,
            sender: m.sender,
            timestamp: m.timestamp,
            isMe: m.sender == Web3Refi.instance.address,
          )).toList();
          _isLoading = false;
        });

        // Scroll to bottom
        _scrollToBottom();

        // Start streaming new messages
        _messageSubscription = conversation.streamMessages().listen(
          (message) {
            if (mounted) {
              setState(() {
                _messages.add(ChatMessage(
                  id: message.id,
                  content: message.content,
                  sender: message.sender,
                  timestamp: message.timestamp,
                  isMe: message.sender == Web3Refi.instance.address,
                ));
              });
              _scrollToBottom();
            }
          },
          onError: (e) {
            widget.onError?.call(e.toString());
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
        widget.onError?.call(e.toString());
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    if (widget.enableHaptics) {
      HapticFeedback.lightImpact();
    }

    try {
      final xmtp = Web3Refi.instance.messaging.xmtp;
      await xmtp.sendMessage(
        recipient: widget.recipientAddress,
        content: content,
      );

      _messageController.clear();
      widget.onMessageSent?.call(content);

      // Message will appear via stream
    } catch (e) {
      widget.onError?.call(e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.backgroundColor,
      appBar: widget.appBar ?? _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Messages
            Expanded(child: _buildMessageList()),
            // Input
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _theme.appBarColor,
      elevation: 0,
      title: Row(
        children: [
          // Avatar
          _AddressAvatar(
            address: widget.recipientAddress,
            size: 36,
          ),
          const SizedBox(width: 12),
          // Name/Address
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.recipientName ?? _truncateAddress(widget.recipientAddress),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.recipientName != null)
                  Text(
                    _truncateAddress(widget.recipientAddress),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showOptionsMenu(context),
        ),
      ],
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_messages.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final showTimestamp = _shouldShowTimestamp(index);
        
        return Column(
          children: [
            if (showTimestamp)
              _TimestampDivider(timestamp: message.timestamp),
            widget.messageBubbleBuilder?.call(message, message.isMe) ??
                _MessageBubble(
                  message: message,
                  theme: _theme,
                ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea() {
    if (widget.inputBuilder != null) {
      return widget.inputBuilder!(_messageController, _sendMessage);
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _theme.inputBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _inputFocusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          _SendButton(
            onPressed: _sendMessage,
            isLoading: _isSending,
            theme: _theme,
          ),
        ],
      ),
    );
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
              'Failed to load conversation',
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
              onPressed: _loadConversation,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowTimestamp(int index) {
    if (index == 0) return true;
    final current = _messages[index].timestamp;
    final previous = _messages[index - 1].timestamp;
    return current.difference(previous).inMinutes > 30;
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy Address'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.recipientAddress));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address copied')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('View on Explorer'),
              onTap: () {
                Navigator.pop(context);
                // Open explorer
              },
            ),
            ListTile(
              leading: Icon(Icons.block, color: Colors.red.shade400),
              title: Text('Block User', style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                Navigator.pop(context);
                // Block user
              },
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatTheme theme;

  const _MessageBubble({
    required this.message,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: message.isMe ? 48 : 0,
          right: message.isMe ? 0 : 48,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: message.isMe ? theme.sentBubbleColor : theme.receivedBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isMe ? 16 : 4),
            bottomRight: Radius.circular(message.isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: message.isMe ? theme.sentTextColor : theme.receivedTextColor,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: (message.isMe ? theme.sentTextColor : theme.receivedTextColor)
                    ?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _TimestampDivider extends StatelessWidget {
  final DateTime timestamp;

  const _TimestampDivider({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        _formatDate(timestamp),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[date.weekday - 1];
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  final ChatTheme theme;

  const _SendButton({
    required this.onPressed,
    required this.isLoading,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.sendButtonColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.sendButtonIconColor ?? Colors.white,
                    ),
                  ),
                )
              : Icon(
                  Icons.send,
                  color: theme.sendButtonIconColor,
                  size: 20,
                ),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _generateGradient(address),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          address.substring(2, 4).toUpperCase(),
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

/// A chat message.
class ChatMessage {
  final String id;
  final String content;
  final String sender;
  final DateTime timestamp;
  final bool isMe;

  const ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
    required this.isMe,
  });
}

/// Theme for chat screen.
class ChatTheme {
  final Color? backgroundColor;
  final Color? appBarColor;
  final Color? inputBackgroundColor;
  final Color? sentBubbleColor;
  final Color? receivedBubbleColor;
  final Color? sentTextColor;
  final Color? receivedTextColor;
  final Color? sendButtonColor;
  final Color? sendButtonIconColor;

  const ChatTheme({
    this.backgroundColor,
    this.appBarColor,
    this.inputBackgroundColor,
    this.sentBubbleColor,
    this.receivedBubbleColor,
    this.sentTextColor,
    this.receivedTextColor,
    this.sendButtonColor,
    this.sendButtonIconColor,
  });

  factory ChatTheme.light() => const ChatTheme(
    backgroundColor: Colors.white,
    appBarColor: Colors.white,
    inputBackgroundColor: Colors.white,
    sentBubbleColor: Color(0xFF007AFF),
    receivedBubbleColor: Color(0xFFE9E9EB),
    sentTextColor: Colors.white,
    receivedTextColor: Colors.black87,
    sendButtonColor: Color(0xFF007AFF),
    sendButtonIconColor: Colors.white,
  );

  factory ChatTheme.dark() => const ChatTheme(
    backgroundColor: Color(0xFF1C1C1E),
    appBarColor: Color(0xFF1C1C1E),
    inputBackgroundColor: Color(0xFF1C1C1E),
    sentBubbleColor: Color(0xFF007AFF),
    receivedBubbleColor: Color(0xFF3A3A3C),
    sentTextColor: Colors.white,
    receivedTextColor: Colors.white,
    sendButtonColor: Color(0xFF007AFF),
    sendButtonIconColor: Colors.white,
  );
}
