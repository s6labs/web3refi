import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web3refi/web3refi.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Web3Refi>(
      builder: (context, web3, child) {
        if (!web3.isConnected) {
          return _buildNotConnected(context);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Chat', icon: Icon(Icons.chat_bubble_outline)),
                Tab(text: 'Email', icon: Icon(Icons.mail_outline)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: const [
              _XMTPChatTab(),
              _MailchainTab(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Connect Wallet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect your wallet to access Web3 messaging',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Web3Refi.instance.connect();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: const Text('Connect Wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// XMTP CHAT TAB
// ════════════════════════════════════════════════════════════════════════════

class _XMTPChatTab extends StatefulWidget {
  const _XMTPChatTab();

  @override
  State<_XMTPChatTab> createState() => _XMTPChatTabState();
}

class _XMTPChatTabState extends State<_XMTPChatTab> {
  bool _isInitialized = false;
  bool _isInitializing = false;
  List<_MockConversation> _conversations = [];

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildInitializeScreen(context);
    }

    return Column(
      children: [
        // Conversations list or empty state
        Expanded(
          child: _conversations.isEmpty
              ? _buildEmptyConversations(context)
              : _buildConversationsList(context),
        ),
      ],
    );
  }

  Widget _buildInitializeScreen(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble,
                size: 40,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'XMTP Messaging',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Secure, encrypted messaging between wallet addresses. Like iMessage for Web3.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 14, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'End-to-end encrypted',
                    style: TextStyle(color: Colors.green, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isInitializing ? null : _initializeXMTP,
                child: _isInitializing
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Initializing...'),
                        ],
                      )
                    : const Text('Enable XMTP'),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will be asked to sign a message to create your XMTP identity.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white54,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyConversations(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No conversations yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new conversation with any Ethereum address',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showNewConversationDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('New Conversation'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length + 1, // +1 for FAB space
      itemBuilder: (context, index) {
        if (index == _conversations.length) {
          return const SizedBox(height: 80); // Space for FAB
        }

        final conv = _conversations[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
              child: Text(
                conv.peerAddress.substring(2, 4).toUpperCase(),
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            title: Text(_formatAddress(conv.peerAddress)),
            subtitle: Text(
              conv.lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatTime(conv.lastMessageTime),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => _openChat(context, conv),
          ),
        );
      },
    );
  }

  Future<void> _initializeXMTP() async {
    setState(() => _isInitializing = true);

    try {
      // Simulate XMTP initialization
      await Future.delayed(const Duration(seconds: 2));

      // In production:
      // await Web3Refi.instance.messaging.xmtp.initialize();

      setState(() {
        _isInitialized = true;
        // Add mock conversations for demo
        _conversations = [
          _MockConversation(
            peerAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            lastMessage: 'Hey, did you receive the payment?',
            lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          _MockConversation(
            peerAddress: '0x8ba1f109551bD432803012645Ac136ddd64DBA72',
            lastMessage: 'Thanks for the quick transfer!',
            lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('XMTP initialized successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to initialize XMTP: $e')),
        );
      }
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  void _showNewConversationDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Conversation'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Recipient Address',
            hintText: '0x...',
          ),
          style: const TextStyle(fontFamily: 'SpaceMono'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.isNotEmpty) {
                _openChat(
                  context,
                  _MockConversation(
                    peerAddress: controller.text,
                    lastMessage: '',
                    lastMessageTime: DateTime.now(),
                  ),
                );
              }
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  void _openChat(BuildContext context, _MockConversation conv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _ChatDetailScreen(conversation: conv),
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h';
    } else {
      return '${diff.inDays}d';
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CHAT DETAIL SCREEN
// ════════════════════════════════════════════════════════════════════════════

class _ChatDetailScreen extends StatefulWidget {
  final _MockConversation conversation;

  const _ChatDetailScreen({required this.conversation});

  @override
  State<_ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<_ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _messages = <_MockMessage>[];

  @override
  void initState() {
    super.initState();
    // Load mock messages
    _messages.addAll([
      _MockMessage(
        content: 'Hey! How are you?',
        isMe: false,
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      _MockMessage(
        content: 'I\'m good! Just sent you 100 USDC.',
        isMe: true,
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      _MockMessage(
        content: widget.conversation.lastMessage,
        isMe: false,
        timestamp: widget.conversation.lastMessageTime,
      ),
    ]);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_formatAddress(widget.conversation.peerAddress)),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index];
                return _MessageBubble(message: message);
              },
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    setState(() {
      _messages.add(_MockMessage(
        content: _messageController.text,
        isMe: true,
        timestamp: DateTime.now(),
      ));
    });

    _messageController.clear();
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

class _MessageBubble extends StatelessWidget {
  final _MockMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isMe
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isMe ? Colors.white : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MAILCHAIN TAB
// ════════════════════════════════════════════════════════════════════════════

class _MailchainTab extends StatefulWidget {
  const _MailchainTab();

  @override
  State<_MailchainTab> createState() => _MailchainTabState();
}

class _MailchainTabState extends State<_MailchainTab> {
  bool _isInitialized = false;
  final _emails = <_MockEmail>[];

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return _buildInitializeScreen(context);
    }

    return Scaffold(
      body: _emails.isEmpty
          ? _buildEmptyInbox(context)
          : _buildEmailList(context),
      floatingActionButton: _isInitialized
          ? FloatingActionButton(
              onPressed: () => _showComposeDialog(context),
              child: const Icon(Icons.edit),
            )
          : null,
    );
  }

  Widget _buildInitializeScreen(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.mail,
                size: 40,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Mailchain',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Send and receive encrypted emails to any blockchain address. Your Web3 inbox.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Your address:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_formatAddress(Web3Refi.instance.address ?? '')}@ethereum.mailchain.com',
                style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _initializeMailchain,
                child: const Text('Enable Mailchain'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyInbox(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'Your inbox is empty',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Emails sent to your wallet address will appear here',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _emails.length,
      itemBuilder: (context, index) {
        final email = _emails[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: email.read
                  ? Colors.white.withOpacity(0.1)
                  : Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              child: Icon(
                email.read ? Icons.mail_outline : Icons.mail,
                color: email.read
                    ? Colors.white54
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            title: Text(
              email.subject,
              style: TextStyle(
                fontWeight: email.read ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Text(
              email.sender,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _formatDate(email.timestamp),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {},
          ),
        );
      },
    );
  }

  void _initializeMailchain() {
    setState(() {
      _isInitialized = true;
      _emails.addAll([
        _MockEmail(
          sender: '0x742d...0bEb@ethereum.mailchain.com',
          subject: 'Payment Confirmation',
          body: 'Your payment of 100 USDC has been received.',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          read: false,
        ),
        _MockEmail(
          sender: '0x8ba1...DBA72@polygon.mailchain.com',
          subject: 'Welcome to web3refi!',
          body: 'Thank you for trying out web3refi.',
          timestamp: DateTime.now().subtract(const Duration(days: 1)),
          read: true,
        ),
      ]);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mailchain initialized!')),
    );
  }

  void _showComposeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _ComposeEmailSheet(),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}

class _ComposeEmailSheet extends StatefulWidget {
  const _ComposeEmailSheet();

  @override
  State<_ComposeEmailSheet> createState() => _ComposeEmailSheetState();
}

class _ComposeEmailSheetState extends State<_ComposeEmailSheet> {
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const Text(
                'New Email',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              TextButton(
                onPressed: _isSending ? null : _sendEmail,
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Send'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _toController,
            decoration: const InputDecoration(
              labelText: 'To',
              hintText: '0x...@ethereum.mailchain.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(
              labelText: 'Subject',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
            maxLines: 6,
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    setState(() => _isSending = true);

    // Simulate sending
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email sent!')),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// MOCK DATA CLASSES
// ════════════════════════════════════════════════════════════════════════════

class _MockConversation {
  final String peerAddress;
  final String lastMessage;
  final DateTime lastMessageTime;

  _MockConversation({
    required this.peerAddress,
    required this.lastMessage,
    required this.lastMessageTime,
  });
}

class _MockMessage {
  final String content;
  final bool isMe;
  final DateTime timestamp;

  _MockMessage({
    required this.content,
    required this.isMe,
    required this.timestamp,
  });
}

class _MockEmail {
  final String sender;
  final String subject;
  final String body;
  final DateTime timestamp;
  final bool read;

  _MockEmail({
    required this.sender,
    required this.subject,
    required this.body,
    required this.timestamp,
    this.read = false,
  });
}
