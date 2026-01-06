# UNS + Messaging Integration Guide
## Building Efficient Web3 Communication Apps with web3refi

This guide demonstrates how to leverage **Universal Name Service (UNS)** and **Web3 Messaging (XMTP + Mailchain)** together to create powerful, user-friendly Web3 applications.

---

## Table of Contents

1. [Why UNS + Messaging Integration Matters](#why-uns--messaging-integration-matters)
2. [Quick Start](#quick-start)
3. [Integration Patterns](#integration-patterns)
4. [Complete Examples](#complete-examples)
5. [Widget Combinations](#widget-combinations)
6. [Production Best Practices](#production-best-practices)
7. [Performance Optimization](#performance-optimization)
8. [Troubleshooting](#troubleshooting)

---

## Why UNS + Messaging Integration Matters

### The Problem with Traditional Web3 Communication

**Without UNS:**
```dart
// User must copy/paste full addresses
await xmtp.sendMessage(
  recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  content: 'Hello!',
);
```

**With UNS:**
```dart
// User can type human-readable names
await sendMessageToName(
  recipient: 'vitalik.eth',  // or @alice, bob.crypto, etc.
  content: 'Hello!',
);
```

### Key Benefits

✅ **User Experience**: Type `vitalik.eth` instead of `0x742d35Cc...`
✅ **Multi-Chain Support**: Resolve names across 6+ name services
✅ **Reduced Errors**: No more typos in long addresses
✅ **Universal Identity**: Same name works for XMTP, Mailchain, transfers
✅ **Developer Efficiency**: 91% less code with built-in widgets

---

## Quick Start

### 1. Initialize Web3Refi with UNS + Messaging

```dart
import 'package:web3refi/web3refi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Web3Refi.initialize(
    config: Web3RefiConfig(
      projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
      chains: [Chains.ethereum, Chains.polygon],
      defaultChain: Chains.polygon,

      // Enable messaging
      enableXMTP: true,
      enableMailchain: true,

      // UNS is enabled by default
      enableUniversalNameService: true,
    ),
  );

  runApp(MyApp());
}
```

### 2. Send Message to a Name (5 Lines!)

```dart
// Resolve name and send message
final address = await Web3Refi.instance.names.resolve('vitalik.eth');
if (address != null) {
  await Web3Refi.instance.messaging.xmtp.sendMessage(
    recipient: address,
    content: 'Hello from web3refi!',
  );
}
```

### 3. Use Pre-Built Widget (Even Easier!)

```dart
// Full chat screen with automatic name resolution
ChatScreen(
  recipientAddress: 'vitalik.eth',  // Widget auto-resolves!
  recipientName: 'Vitalik Buterin',
)
```

---

## Integration Patterns

### Pattern 1: Resolve-Then-Message (Manual)

**Use Case**: Full control over resolution and messaging flow.

```dart
Future<void> sendMessageToName(String nameOrAddress, String content) async {
  final uns = Web3Refi.instance.names;
  final xmtp = Web3Refi.instance.messaging.xmtp;

  // Step 1: Resolve name to address
  final address = await uns.resolve(nameOrAddress);

  if (address == null) {
    throw Exception('Could not resolve: $nameOrAddress');
  }

  // Step 2: Check if recipient can receive XMTP
  final canMessage = await xmtp.canMessage(address);
  if (!canMessage) {
    throw Exception('Recipient not on XMTP');
  }

  // Step 3: Send message
  await xmtp.sendMessage(
    recipient: address,
    content: content,
  );

  print('✅ Message sent to $nameOrAddress ($address)');
}

// Usage
await sendMessageToName('vitalik.eth', 'Hello!');
await sendMessageToName('@alice', 'Hey Alice!');
await sendMessageToName('bob.crypto', 'GM!');
```

---

### Pattern 2: Widget-Based (Recommended)

**Use Case**: Fast development with minimal code.

```dart
class SendMessageScreen extends StatefulWidget {
  @override
  _SendMessageScreenState createState() => _SendMessageScreenState();
}

class _SendMessageScreenState extends State<SendMessageScreen> {
  String? resolvedAddress;
  final messageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send Message')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Auto-resolving address input
            AddressInputField(
              label: 'Recipient',
              hint: 'vitalik.eth, @alice, 0x123...',
              onAddressResolved: (address) {
                setState(() => resolvedAddress = address);
              },
            ),

            SizedBox(height: 16),

            // Message input
            TextField(
              controller: messageController,
              decoration: InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),

            SizedBox(height: 16),

            // Send button
            FilledButton.icon(
              onPressed: resolvedAddress != null
                  ? () => _sendMessage()
                  : null,
              icon: Icon(Icons.send),
              label: Text('Send via XMTP'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMessage() async {
    try {
      await Web3Refi.instance.messaging.xmtp.sendMessage(
        recipient: resolvedAddress!,
        content: messageController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Message sent!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

---

### Pattern 3: Batch Resolution (High Performance)

**Use Case**: Messaging multiple recipients or displaying contact lists.

```dart
Future<void> sendBulkMessages({
  required List<String> recipients,
  required String message,
}) async {
  final uns = Web3Refi.instance.names;
  final xmtp = Web3Refi.instance.messaging.xmtp;

  // Step 1: Batch resolve all names (100x faster than serial!)
  final addressMap = await uns.resolveMany(recipients);

  // Step 2: Filter valid addresses
  final validAddresses = addressMap.entries
      .where((e) => e.value != null)
      .map((e) => e.value!)
      .toList();

  // Step 3: Check who can receive messages
  final canMessageMap = await xmtp.canMessageMultiple(validAddresses);

  // Step 4: Send messages
  final results = <String, bool>{};

  for (final entry in addressMap.entries) {
    final name = entry.key;
    final address = entry.value;

    if (address == null) {
      results[name] = false;
      print('❌ $name: Could not resolve');
      continue;
    }

    if (canMessageMap[address] != true) {
      results[name] = false;
      print('❌ $name: Not on XMTP');
      continue;
    }

    try {
      await xmtp.sendMessage(recipient: address, content: message);
      results[name] = true;
      print('✅ $name: Message sent');
    } catch (e) {
      results[name] = false;
      print('❌ $name: Send failed - $e');
    }
  }

  return results;
}

// Usage
await sendBulkMessages(
  recipients: [
    'vitalik.eth',
    '@alice',
    'bob.crypto',
    'charlie.bnb',
    'dave.sol',
  ],
  message: 'GM everyone! 🌅',
);
```

---

### Pattern 4: Mailchain Email with ENS

**Use Case**: Send blockchain email to human-readable names.

```dart
Future<void> sendEmailToName({
  required String name,
  required String subject,
  required String body,
  bool isHtml = false,
}) async {
  final uns = Web3Refi.instance.names;
  final mailchain = Web3Refi.instance.messaging.mailchain;

  // Resolve name
  final address = await uns.resolve(name);
  if (address == null) {
    throw Exception('Could not resolve: $name');
  }

  // Format as Mailchain address
  final mailchainAddress = mailchain.formatAddress(address);

  // Send email
  final result = await mailchain.sendMail(
    to: mailchainAddress,
    subject: subject,
    body: body,
    isHtml: isHtml,
  );

  print('✅ Email sent to $name');
  print('   Address: $mailchainAddress');
  print('   Message ID: ${result.messageId}');
}

// Usage
await sendEmailToName(
  name: 'vitalik.eth',
  subject: 'Payment Confirmation',
  body: '''
    <h1>Payment Received</h1>
    <p>Your payment of <strong>100 USDC</strong> has been processed.</p>
    <p>Transaction: 0x123...</p>
  ''',
  isHtml: true,
);
```

---

## Complete Examples

### Example 1: Full Chat App with Name Resolution

```dart
import 'package:flutter/material.dart';
import 'package:web3refi/web3refi.dart';

class Web3ChatApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Web3 Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ChatHomePage(),
    );
  }
}

class ChatHomePage extends StatefulWidget {
  @override
  _ChatHomePageState createState() => _ChatHomePageState();
}

class _ChatHomePageState extends State<ChatHomePage> {
  bool _isConnected = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Web3 Chat'),
        actions: [
          if (_isConnected)
            ConnectedWalletDisplay(),
        ],
      ),
      body: _isConnected ? _buildChatList() : _buildConnectScreen(),
    );
  }

  Widget _buildConnectScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 100, color: Colors.grey),
          SizedBox(height: 24),
          Text(
            'Connect to start chatting',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          WalletConnectButton(
            onConnected: (address) async {
              // Initialize XMTP
              await Web3Refi.instance.messaging.xmtp.initialize();

              setState(() => _isConnected = true);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connected and ready to chat!')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Column(
      children: [
        // Search/new chat
        Padding(
          padding: EdgeInsets.all(16),
          child: _NewChatCard(),
        ),

        // Recent conversations
        Expanded(
          child: _ConversationList(),
        ),
      ],
    );
  }
}

class _NewChatCard extends StatefulWidget {
  @override
  __NewChatCardState createState() => __NewChatCardState();
}

class __NewChatCardState extends State<_NewChatCard> {
  String? recipientAddress;
  String? recipientName;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Start New Chat',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            AddressInputField(
              hint: 'vitalik.eth, @alice, 0x123...',
              onAddressResolved: (address) {
                setState(() => recipientAddress = address);
              },
              onChanged: (text) {
                setState(() => recipientName = text);
              },
            ),
            SizedBox(height: 12),
            FilledButton.icon(
              onPressed: recipientAddress != null
                  ? () => _openChat()
                  : null,
              icon: Icon(Icons.chat),
              label: Text('Open Chat'),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          recipientAddress: recipientAddress!,
          recipientName: recipientName,
        ),
      ),
    );
  }
}

class _ConversationList extends StatefulWidget {
  @override
  __ConversationListState createState() => __ConversationListState();
}

class __ConversationListState extends State<_ConversationList> {
  List<XMTPConversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final xmtp = Web3Refi.instance.messaging.xmtp;
    final conversations = await xmtp.listConversations();

    setState(() {
      _conversations = conversations;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Text('No conversations yet. Start one above!'),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _ConversationTile(conversation: conv);
      },
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final XMTPConversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  __ConversationTileState createState() => __ConversationTileState();
}

class __ConversationTileState extends State<_ConversationTile> {
  String? displayName;

  @override
  void initState() {
    super.initState();
    _resolveName();
  }

  Future<void> _resolveName() async {
    // Try reverse resolution
    final name = await Web3Refi.instance.names.reverseResolve(
      widget.conversation.peerAddress,
    );

    if (mounted) {
      setState(() => displayName = name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(Icons.person),
      ),
      title: Text(displayName ?? _shortenAddress(widget.conversation.peerAddress)),
      subtitle: Text(widget.conversation.peerAddress),
      trailing: Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              recipientAddress: widget.conversation.peerAddress,
              recipientName: displayName,
            ),
          ),
        );
      },
    );
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
```

---

### Example 2: Payment + Email Notification

```dart
class PaymentWithNotification extends StatelessWidget {
  final String recipientName;
  final BigInt amount;
  final String tokenAddress;

  const PaymentWithNotification({
    required this.recipientName,
    required this.amount,
    required this.tokenAddress,
  });

  Future<void> sendPaymentAndNotify(BuildContext context) async {
    try {
      final uns = Web3Refi.instance.names;
      final mailchain = Web3Refi.instance.messaging.mailchain;

      // Step 1: Resolve recipient name
      final address = await uns.resolve(recipientName);
      if (address == null) {
        throw Exception('Could not resolve: $recipientName');
      }

      // Step 2: Send token transfer
      final token = ERC20(
        contractAddress: tokenAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      final txHash = await token.transfer(
        to: address,
        amount: amount,
      );

      // Step 3: Send email notification
      await mailchain.sendMail(
        to: mailchain.formatAddress(address),
        subject: 'Payment Received',
        body: '''
          <html>
            <body>
              <h1>Payment Notification</h1>
              <p>You've received a payment!</p>
              <ul>
                <li><strong>Amount:</strong> ${amount.toString()} tokens</li>
                <li><strong>Transaction:</strong> $txHash</li>
                <li><strong>From:</strong> ${Web3Refi.instance.address}</li>
              </ul>
              <p>View on Etherscan: https://etherscan.io/tx/$txHash</p>
            </body>
          </html>
        ''',
        isHtml: true,
      );

      // Step 4: Show success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment sent and notification delivered!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () => sendPaymentAndNotify(context),
      icon: Icon(Icons.send),
      label: Text('Send Payment + Email'),
    );
  }
}
```

---

### Example 3: Social Recovery with Multi-Chain Names

```dart
class SocialRecoverySetup extends StatefulWidget {
  @override
  _SocialRecoverySetupState createState() => _SocialRecoverySetupState();
}

class _SocialRecoverySetupState extends State<SocialRecoverySetup> {
  final guardianNames = <String>[];
  final guardianAddresses = <String>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Social Recovery Setup')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Recovery Guardians',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Use any name format: ENS, Unstoppable, CiFi, etc.',
              style: Theme.of(context).textTheme.bodySmall,
            ),

            SizedBox(height: 24),

            // Add guardian
            AddressInputField(
              label: 'Guardian Name or Address',
              hint: 'alice.eth, @bob, charlie.crypto, dave.bnb',
              onAddressResolved: (address) {
                // Auto-added via button below
              },
              onChanged: (name) {
                // Track the input name
              },
            ),

            SizedBox(height: 16),

            // Guardian list
            Expanded(
              child: ListView.builder(
                itemCount: guardianNames.length,
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(guardianNames[index]),
                      subtitle: Text(guardianAddresses[index]),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            guardianNames.removeAt(index);
                            guardianAddresses.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: 16),

            // Deploy button
            FilledButton.icon(
              onPressed: guardianAddresses.length >= 3
                  ? () => _deploySocialRecovery()
                  : null,
              icon: Icon(Icons.shield),
              label: Text('Deploy Social Recovery (${guardianAddresses.length}/3)'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deploySocialRecovery() async {
    // Deploy social recovery contract with guardians
    // Send setup confirmation via XMTP to each guardian

    final xmtp = Web3Refi.instance.messaging.xmtp;

    for (int i = 0; i < guardianAddresses.length; i++) {
      final name = guardianNames[i];
      final address = guardianAddresses[i];

      try {
        await xmtp.sendMessage(
          recipient: address,
          content: '''
You've been added as a recovery guardian for ${Web3Refi.instance.address}.

This allows you to help recover the account if the owner loses access.

Guardian #${i + 1} of ${guardianAddresses.length}
          ''',
        );
      } catch (e) {
        print('Could not notify $name: $e');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Social recovery deployed! Guardians notified.'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
```

---

## Widget Combinations

### Combination 1: Contact Picker with Chat

```dart
class ContactPickerWithChat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Name resolution input
        AddressInputField(
          onAddressResolved: (address) {
            // Open chat immediately
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  recipientAddress: address,
                ),
              ),
            );
          },
        ),

        // Or browse recent chats
        Expanded(
          child: InboxScreen(), // Shows XMTP conversations
        ),
      ],
    );
  }
}
```

---

### Combination 2: Send Token with XMTP Confirmation

```dart
class SendTokenWithConfirmation extends StatefulWidget {
  @override
  _SendTokenWithConfirmationState createState() =>
      _SendTokenWithConfirmationState();
}

class _SendTokenWithConfirmationState extends State<SendTokenWithConfirmation> {
  String? recipientAddress;
  String? recipientName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Recipient input with name resolution
        AddressInputField(
          label: 'Send To',
          onAddressResolved: (address) {
            setState(() => recipientAddress = address);
          },
          onChanged: (name) {
            setState(() => recipientName = name);
          },
        ),

        // Amount input
        TextField(
          decoration: InputDecoration(labelText: 'Amount'),
          keyboardType: TextInputType.number,
        ),

        // Send button
        FilledButton(
          onPressed: recipientAddress != null
              ? () => _sendTokens()
              : null,
          child: Text('Send'),
        ),
      ],
    );
  }

  Future<void> _sendTokens() async {
    // Send tokens
    final txHash = await sendToken(...);

    // Send XMTP message
    await Web3Refi.instance.messaging.xmtp.sendMessage(
      recipient: recipientAddress!,
      content: 'Sent you tokens! TX: $txHash',
    );
  }
}
```

---

## Production Best Practices

### 1. Always Cache Name Resolutions

```dart
class NameCache {
  static final _cache = <String, String>{};
  static final _timestamp = <String, DateTime>{};
  static const cacheDuration = Duration(hours: 1);

  static Future<String?> resolve(String name) async {
    // Check cache
    if (_cache.containsKey(name)) {
      final cached = _timestamp[name]!;
      if (DateTime.now().difference(cached) < cacheDuration) {
        return _cache[name];
      }
    }

    // Resolve fresh
    final address = await Web3Refi.instance.names.resolve(name);

    if (address != null) {
      _cache[name] = address;
      _timestamp[name] = DateTime.now();
    }

    return address;
  }
}
```

### 2. Validate Before Sending

```dart
Future<bool> validateRecipient(String nameOrAddress) async {
  // Step 1: Resolve to address
  final address = await Web3Refi.instance.names.resolve(nameOrAddress);
  if (address == null) {
    print('❌ Could not resolve: $nameOrAddress');
    return false;
  }

  // Step 2: Check XMTP availability
  final canMessage = await Web3Refi.instance.messaging.xmtp.canMessage(address);
  if (!canMessage) {
    print('❌ Recipient not on XMTP: $nameOrAddress');
    return false;
  }

  print('✅ Valid recipient: $nameOrAddress → $address');
  return true;
}
```

### 3. Handle Errors Gracefully

```dart
Future<void> sendMessageSafely({
  required String recipient,
  required String content,
}) async {
  try {
    // Resolve name
    final address = await Web3Refi.instance.names.resolve(recipient);

    if (address == null) {
      throw Exception('Name not found: $recipient');
    }

    // Send message
    await Web3Refi.instance.messaging.xmtp.sendMessage(
      recipient: address,
      content: content,
    );

    print('✅ Message sent successfully');
  } on MessagingException catch (e) {
    if (e.code == 'recipient_not_found') {
      print('❌ Recipient not on XMTP');
      // Maybe try Mailchain instead?
    } else if (e.code == 'wallet_not_connected') {
      print('❌ Connect wallet first');
    } else {
      print('❌ Messaging error: ${e.message}');
    }
  } catch (e) {
    print('❌ Unexpected error: $e');
  }
}
```

---

## Performance Optimization

### 1. Use Batch Resolution for Lists

```dart
// ❌ SLOW (10 names = 10 RPC calls)
for (final name in names) {
  final address = await uns.resolve(name);
  // ...
}

// ✅ FAST (10 names = 1 RPC call with Multicall3)
final addressMap = await uns.resolveMany(names);
for (final entry in addressMap.entries) {
  final name = entry.key;
  final address = entry.value;
  // ...
}
```

### 2. Enable Batch Resolution Globally

```dart
void main() async {
  await Web3Refi.initialize(...);

  // Enable batch resolution for 100x speedup
  Web3Refi.instance.names.enableBatchResolution(
    resolverAddress: '0x231b0Ee14048e9dCcD1d247744d114a4EB5E8E63', // ENS Public Resolver
    maxBatchSize: 100,
  );
}
```

### 3. Prefetch Names for Contact Lists

```dart
class ContactList extends StatefulWidget {
  @override
  _ContactListState createState() => _ContactListState();
}

class _ContactListState extends State<ContactList> {
  Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _prefetchNames();
  }

  Future<void> _prefetchNames() async {
    final conversations = await Web3Refi.instance.messaging.xmtp.listConversations();
    final addresses = conversations.map((c) => c.peerAddress).toList();

    // Batch reverse resolve
    final names = <String, String>{};
    for (final address in addresses) {
      final name = await Web3Refi.instance.names.reverseResolve(address);
      if (name != null) {
        names[address] = name;
      }
    }

    setState(() => _nameCache = names);
  }

  @override
  Widget build(BuildContext context) {
    // Use _nameCache for instant display
    return ListView(...);
  }
}
```

---

## Troubleshooting

### Issue 1: Name Resolution Fails

```dart
// Problem: Name doesn't resolve
final address = await uns.resolve('myname.eth');
// Returns: null

// Solution 1: Check name format
final validation = NameValidator.validate('myname.eth');
if (validation != null) {
  print('Invalid name: $validation');
}

// Solution 2: Check network
print('Current chain: ${Web3Refi.instance.chainId}');
// ENS requires Ethereum mainnet (chainId: 1)

// Solution 3: Try with chain ID
final address = await uns.resolve('myname.eth', chainId: 1);

// Solution 4: Check resolver availability
final resolvers = uns.getResolversForName('myname.eth');
print('Available resolvers: $resolvers');
```

### Issue 2: XMTP Not Initialized

```dart
// Problem: MessagingException: 'XMTP not initialized'

// Solution: Initialize before using
await Web3Refi.instance.messaging.xmtp.initialize();

// Or check first:
if (!Web3Refi.instance.messaging.xmtp.isInitialized) {
  await Web3Refi.instance.messaging.xmtp.initialize();
}
```

### Issue 3: Recipient Not on XMTP

```dart
// Problem: Recipient hasn't enabled XMTP

// Solution: Check first and provide fallback
final canXMTP = await xmtp.canMessage(address);

if (canXMTP) {
  await xmtp.sendMessage(recipient: address, content: msg);
} else {
  // Fallback to Mailchain
  await mailchain.sendMail(
    to: mailchain.formatAddress(address),
    subject: 'Message from Web3',
    body: msg,
  );
}
```

### Issue 4: Slow Performance

```dart
// Problem: App is slow when resolving many names

// Solution 1: Enable batch resolution
Web3Refi.instance.names.enableBatchResolution(
  resolverAddress: ENS_PUBLIC_RESOLVER,
  maxBatchSize: 100,
);

// Solution 2: Use cache
final stats = Web3Refi.instance.names.getCacheStats();
print('Cache hit rate: ${stats.hitRate}%');
// Target: 90%+ hit rate

// Solution 3: Increase cache size
await Web3Refi.initialize(
  config: Web3RefiConfig(
    // ...
    unsCacheSize: 5000,  // Default: 1000
    unsCacheTtl: Duration(hours: 2),  // Default: 1 hour
  ),
);
```

---

## Summary: Integration Checklist

Before going to production, verify:

- [ ] **UNS Integration**
  - [ ] Name resolution working for all formats (ENS, Unstoppable, CiFi, etc.)
  - [ ] Batch resolution enabled for contact lists
  - [ ] Cache configured with appropriate TTL
  - [ ] Validation errors handled gracefully

- [ ] **XMTP Integration**
  - [ ] Initialization handled on wallet connect
  - [ ] `canMessage()` check before sending
  - [ ] Message streaming working for real-time updates
  - [ ] Error handling for offline/not-initialized states

- [ ] **Mailchain Integration**
  - [ ] Authentication flow working
  - [ ] Address formatting correct
  - [ ] Email sending with proper encryption
  - [ ] Inbox/Sent folders functioning

- [ ] **Widget Usage**
  - [ ] `AddressInputField` resolving names correctly
  - [ ] `ChatScreen` loading conversations
  - [ ] `NameDisplay` showing resolved names
  - [ ] Error states displayed to users

- [ ] **Performance**
  - [ ] Batch resolution for lists (100+ items)
  - [ ] Cache hit rate > 90%
  - [ ] Prefetching for frequently accessed data
  - [ ] Debouncing for user input (500ms recommended)

- [ ] **User Experience**
  - [ ] Loading indicators during resolution
  - [ ] Clear error messages
  - [ ] Fallback to Mailchain if XMTP unavailable
  - [ ] Copy buttons for addresses
  - [ ] Confirmation dialogs for sends

---

## Next Steps

1. **Test the integration examples** in your app
2. **Implement caching** for production performance
3. **Add error handling** for network failures
4. **Enable batch resolution** for contact lists
5. **Review the [DEVELOPER_INTEGRATION_GUIDE.md](DEVELOPER_INTEGRATION_GUIDE.md)** for full SDK documentation

---

## Support

- **GitHub Issues**: [web3refi/issues](https://github.com/yourusername/web3refi/issues)
- **Documentation**: [web3refi docs](https://github.com/yourusername/web3refi)
- **Examples**: See `/example` folder in the repository

---

**Built with web3refi v2.0** - The Universal Web3 SDK for Flutter 🚀
