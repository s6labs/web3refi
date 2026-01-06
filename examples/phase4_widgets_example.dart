// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:web3refi/web3refi.dart';

/// Phase 4: Flutter Widgets Examples
///
/// This file demonstrates the production-ready UI components for the
/// Universal Name Service.
///
/// ## Widgets Demonstrated:
///
/// 1. AddressInputField - Auto-resolving address/name input
/// 2. NameDisplay - Display names with avatars and metadata
/// 3. NameRegistrationFlow - Multi-step name registration wizard
/// 4. NameManagementScreen - Complete name management interface
///
/// ## Setup Requirements:
///
/// ```dart
/// await Web3Refi.initialize(
///   mnemonic: 'your mnemonic',
///   rpcUrl: 'https://rpc.xdcrpc.com',
/// );
/// ```

void main() {
  runApp(const Phase4WidgetsApp());
}

class Phase4WidgetsApp extends StatelessWidget {
  const Phase4WidgetsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phase 4: Widgets Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ExamplesHomeScreen(),
    );
  }
}

class ExamplesHomeScreen extends StatelessWidget {
  const ExamplesHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 4: Widget Examples'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExampleCard(
            context,
            title: 'AddressInputField',
            description: 'Auto-resolving address/name input with validation',
            icon: Icons.input,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AddressInputExample(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'NameDisplay',
            description: 'Display names with avatars and metadata',
            icon: Icons.badge,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NameDisplayExample(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'NameRegistrationFlow',
            description: 'Multi-step name registration wizard',
            icon: Icons.app_registration,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NameRegistrationExample(),
              ),
            ),
          ),
          _buildExampleCard(
            context,
            title: 'NameManagementScreen',
            description: 'Complete name management interface',
            icon: Icons.manage_accounts,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => NameManagementScreen(
                  registryAddress: '0x...', // Your registry address
                  resolverAddress: '0x...', // Your resolver address
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXAMPLE 1: AddressInputField
// ══════════════════════════════════════════════════════════════════════════════

class AddressInputExample extends StatefulWidget {
  const AddressInputExample({Key? key}) : super(key: key);

  @override
  State<AddressInputExample> createState() => _AddressInputExampleState();
}

class _AddressInputExampleState extends State<AddressInputExample> {
  String? _resolvedAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AddressInputField Example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Basic usage
          const Text(
            '1. Basic Usage',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Enter an address or name (e.g., vitalik.eth, @alice):'),
          const SizedBox(height: 8),
          AddressInputField(
            onAddressResolved: (address) {
              setState(() => _resolvedAddress = address);
              print('Resolved: $address');
            },
          ),
          const SizedBox(height: 24),

          // With custom label
          const Text(
            '2. Custom Label and Hint',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const AddressInputField(
            label: 'Recipient',
            hint: 'Enter recipient address or name',
          ),
          const SizedBox(height: 24),

          // Without resolved address display
          const Text(
            '3. Without Resolved Address Display',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const AddressInputField(
            showResolvedAddress: false,
          ),
          const SizedBox(height: 24),

          // With custom resolution delay
          const Text(
            '4. Custom Resolution Delay (1 second)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const AddressInputField(
            resolutionDelay: Duration(seconds: 1),
          ),
          const SizedBox(height: 24),

          // Show resolved address
          if (_resolvedAddress != null) ...[
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Last Resolved Address:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              _resolvedAddress!,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXAMPLE 2: NameDisplay
// ══════════════════════════════════════════════════════════════════════════════

class NameDisplayExample extends StatelessWidget {
  const NameDisplayExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NameDisplay Example'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Row layout
          const Text(
            '1. Row Layout (Compact)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            layout: NameDisplayLayout.row,
          ),
          const SizedBox(height: 24),

          // Column layout
          const Text(
            '2. Column Layout (Centered)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            layout: NameDisplayLayout.column,
          ),
          const SizedBox(height: 24),

          // Card layout with metadata
          const Text(
            '3. Card Layout (Full Details)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            layout: NameDisplayLayout.card,
            showMetadata: true,
          ),
          const SizedBox(height: 24),

          // Without avatar
          const Text(
            '4. Without Avatar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            showAvatar: false,
          ),
          const SizedBox(height: 24),

          // Pre-resolved name
          const Text(
            '5. Pre-Resolved Name',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            name: 'alice.xdc',
            layout: NameDisplayLayout.card,
          ),
          const SizedBox(height: 24),

          // With tap callback
          const Text(
            '6. With Tap Callback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          NameDisplay(
            address: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name tapped!')),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXAMPLE 3: NameRegistrationFlow
// ══════════════════════════════════════════════════════════════════════════════

class NameRegistrationExample extends StatefulWidget {
  const NameRegistrationExample({Key? key}) : super(key: key);

  @override
  State<NameRegistrationExample> createState() =>
      _NameRegistrationExampleState();
}

class _NameRegistrationExampleState extends State<NameRegistrationExample> {
  RegistrationResult? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Name Registration Flow'),
      ),
      body: _result == null
          ? NameRegistrationFlow(
              registryAddress: '0x...', // Your registry address
              resolverAddress: '0x...', // Your resolver address
              tld: 'xdc',
              onComplete: (result) {
                setState(() => _result = result);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully registered ${result.name}!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              onCancel: () {
                Navigator.pop(context);
              },
            )
          : _buildSuccessView(),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 80,
            ),
            const SizedBox(height: 24),
            Text(
              'Registration Successful!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              _result!.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Owner: ${_result!.owner}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              'Expires: ${_result!.expiry}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXAMPLE 4: Integration Example - Send Tokens with Name Resolution
// ══════════════════════════════════════════════════════════════════════════════

class SendTokensExample extends StatefulWidget {
  const SendTokensExample({Key? key}) : super(key: key);

  @override
  State<SendTokensExample> createState() => _SendTokensExampleState();
}

class _SendTokensExampleState extends State<SendTokensExample> {
  String? _recipientAddress;
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _sendTokens() async {
    if (_recipientAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid recipient')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    // Send transaction
    try {
      // Implementation would use Web3Refi to send tokens
      print('Sending $amount to $_recipientAddress');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Tokens (with Name Resolution)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This example shows how to integrate AddressInputField into a real application flow.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            AddressInputField(
              label: 'Recipient',
              hint: 'Enter address or name (e.g., @alice, vitalik.eth)',
              onAddressResolved: (address) {
                setState(() => _recipientAddress = address);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.0',
                border: OutlineInputBorder(),
                suffixText: 'XDC',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _recipientAddress != null ? _sendTokens : null,
              child: const Text('Send Tokens'),
            ),
            const SizedBox(height: 16),
            if (_recipientAddress != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Sending to:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              NameDisplay(
                address: _recipientAddress!,
                layout: NameDisplayLayout.card,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EXAMPLE 5: User Profile with Name Display
// ══════════════════════════════════════════════════════════════════════════════

class UserProfileExample extends StatelessWidget {
  final String userAddress;

  const UserProfileExample({
    Key? key,
    required this.userAddress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile header with name display
          NameDisplay(
            address: userAddress,
            layout: NameDisplayLayout.column,
            showMetadata: true,
            avatarSize: 80,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // User stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat(context, 'Names', '3'),
              _buildStat(context, 'Following', '127'),
              _buildStat(context, 'Followers', '45'),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Actions
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add),
            label: const Text('Follow'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () {},
            icon: const Icon(Icons.message),
            label: const Text('Message'),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
        ),
      ],
    );
  }
}
