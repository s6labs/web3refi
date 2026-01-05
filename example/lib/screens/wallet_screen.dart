import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web3refi/web3refi.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<Web3Refi>(
      builder: (context, web3, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Wallet Section
              _buildSectionHeader(context, 'Wallet'),
              const SizedBox(height: 12),
              if (web3.isConnected) ...[
                _WalletInfoCard(web3: web3),
              ] else ...[
                _ConnectWalletCard(),
              ],

              const SizedBox(height: 24),

              // Network Section
              _buildSectionHeader(context, 'Network'),
              const SizedBox(height: 12),
              _NetworkCard(web3: web3),

              const SizedBox(height: 24),

              // Session Section
              if (web3.isConnected) ...[
                _buildSectionHeader(context, 'Session'),
                const SizedBox(height: 12),
                _SessionCard(web3: web3),
                const SizedBox(height: 24),
              ],

              // App Info Section
              _buildSectionHeader(context, 'About'),
              const SizedBox(height: 12),
              _AboutCard(),

              const SizedBox(height: 24),

              // Developer Tools
              _buildSectionHeader(context, 'Developer'),
              const SizedBox(height: 12),
              _DeveloperCard(web3: web3),

              const SizedBox(height: 32),

              // Disconnect Button
              if (web3.isConnected)
                _DisconnectButton(
                  onDisconnect: () => _disconnect(context, web3),
                ),

              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Future<void> _disconnect(BuildContext context, Web3Refi web3) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Wallet'),
        content: const Text('Are you sure you want to disconnect your wallet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await web3.disconnect();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet disconnected')),
        );
      }
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// WALLET INFO CARD
// ════════════════════════════════════════════════════════════════════════════

class _WalletInfoCard extends StatelessWidget {
  final Web3Refi web3;

  const _WalletInfoCard({required this.web3});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Connected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatAddress(web3.address ?? ''),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'SpaceMono',
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Full Address',
              web3.address ?? '',
              canCopy: true,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              'Chain ID',
              web3.currentChain.chainId.toString(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _viewOnExplorer(context, web3),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('View on Explorer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    bool canCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
            ),
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
      ],
    );
  }

  void _viewOnExplorer(BuildContext context, Web3Refi web3) {
    final url = web3.currentChain.getAddressUrl(web3.address ?? '');
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CONNECT WALLET CARD
// ════════════════════════════════════════════════════════════════════════════

class _ConnectWalletCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Wallet Connected',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connect your wallet to get started',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await Web3Refi.instance.connect();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Connect Wallet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// NETWORK CARD
// ════════════════════════════════════════════════════════════════════════════

class _NetworkCard extends StatelessWidget {
  final Web3Refi web3;

  const _NetworkCard({required this.web3});

  @override
  Widget build(BuildContext context) {
    final chain = web3.currentChain;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getChainColor(chain).withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.hexagon,
                color: _getChainColor(chain),
              ),
            ),
            title: Text(chain.name),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: chain.isTestnet
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    chain.isTestnet ? 'Testnet' : 'Mainnet',
                    style: TextStyle(
                      fontSize: 11,
                      color: chain.isTestnet ? Colors.orange : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Chain ID: ${chain.chainId}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: web3.isConnected
                ? () => _showNetworkSelector(context)
                : null,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildNetworkInfo('RPC URL', chain.rpcUrl),
                const SizedBox(height: 8),
                _buildNetworkInfo('Symbol', chain.symbol),
                const SizedBox(height: 8),
                _buildNetworkInfo('Block Explorer', chain.explorerUrl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showNetworkSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _NetworkSelectorSheet(),
    );
  }

  Color _getChainColor(Chain chain) {
    switch (chain.chainId) {
      case 1:
        return const Color(0xFF627EEA);
      case 137:
        return const Color(0xFF8247E5);
      case 42161:
        return const Color(0xFF28A0F0);
      case 10:
        return const Color(0xFFFF0420);
      case 8453:
        return const Color(0xFF0052FF);
      default:
        return Colors.grey;
    }
  }
}

class _NetworkSelectorSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final chains = [
      Chains.polygon,
      Chains.ethereum,
      Chains.arbitrum,
      Chains.base,
      Chains.optimism,
      Chains.polygonMumbai,
      Chains.sepolia,
    ];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select Network',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...chains.map((chain) => ListTile(
                title: Text(chain.name),
                subtitle: Text(chain.isTestnet ? 'Testnet' : 'Mainnet'),
                trailing: Web3Refi.instance.currentChain.chainId == chain.chainId
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await Web3Refi.instance.switchChain(chain);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to switch: $e')),
                      );
                    }
                  }
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SESSION CARD
// ════════════════════════════════════════════════════════════════════════════

class _SessionCard extends StatelessWidget {
  final Web3Refi web3;

  const _SessionCard({required this.web3});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Session Management'),
            subtitle: const Text('Active session'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await web3.saveSession();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session saved')),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await web3.clearSession();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Session cleared')),
                        );
                      }
                    },
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ABOUT CARD
// ════════════════════════════════════════════════════════════════════════════

class _AboutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.hexagon, color: Colors.white, size: 20),
            ),
            title: const Text('web3refi'),
            subtitle: const Text('v1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Created by'),
            subtitle: const Text('S6 Labs LLC'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('GitHub'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              launchUrl(
                Uri.parse('https://github.com/web3refi/web3refi'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Documentation'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () {
              launchUrl(
                Uri.parse('https://docs.web3refi.dev'),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DEVELOPER CARD
// ════════════════════════════════════════════════════════════════════════════

class _DeveloperCard extends StatelessWidget {
  final Web3Refi web3;

  const _DeveloperCard({required this.web3});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.bug_report),
            title: const Text('Debug Logging'),
            subtitle: const Text('Enable SDK debug logs'),
            value: true, // Would be controlled by config
            onChanged: (value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restart app to apply')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.science),
            title: const Text('Use Testnet'),
            subtitle: Text(
              web3.currentChain.isTestnet
                  ? 'Currently on testnet'
                  : 'Currently on mainnet',
            ),
            trailing: Switch(
              value: web3.currentChain.isTestnet,
              onChanged: (value) async {
                final targetChain =
                    value ? Chains.polygonMumbai : Chains.polygon;
                try {
                  await web3.switchChain(targetChain);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e')),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DISCONNECT BUTTON
// ════════════════════════════════════════════════════════════════════════════

class _DisconnectButton extends StatelessWidget {
  final VoidCallback onDisconnect;

  const _DisconnectButton({required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onDisconnect,
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Disconnect Wallet'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
