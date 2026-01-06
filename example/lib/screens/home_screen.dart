import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web3refi/web3refi.dart';

import 'package:web3refi_example/widgets/custom_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  BigInt? _nativeBalance;
  bool _isLoadingBalance = false;

  @override
  void initState() {
    super.initState();
    _loadBalanceIfConnected();
  }

  Future<void> _loadBalanceIfConnected() async {
    if (Web3Refi.instance.isConnected) {
      await _loadBalance();
    }
  }

  Future<void> _loadBalance() async {
    if (!Web3Refi.instance.isConnected) return;

    setState(() => _isLoadingBalance = true);
    try {
      final balance = await Web3Refi.instance.getNativeBalance();
      setState(() => _nativeBalance = balance);
    } catch (e) {
      debugPrint('Error loading balance: $e');
    } finally {
      setState(() => _isLoadingBalance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Web3Refi>(
      builder: (context, web3, child) {
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadBalance,
              color: Theme.of(context).primaryColor,
              child: CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: _buildHeader(context, web3),
                  ),

                  // Content
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (!web3.isConnected) ...[
                          _buildConnectCard(context),
                        ] else ...[
                          _buildBalanceCard(context, web3),
                          const SizedBox(height: 16),
                          _buildQuickActions(context),
                          const SizedBox(height: 24),
                          _buildChainSelector(context, web3),
                          const SizedBox(height: 24),
                          _buildRecentActivity(context),
                        ],
                        const SizedBox(height: 16),
                        _buildInfoSection(context),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Web3Refi web3) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Logo & Title
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.hexagon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'web3refi',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Example App',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Connection indicator
          if (web3.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Connected',
                    style: TextStyle(
                      color: Colors.green[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectCard(BuildContext context) {
    return GradientCard(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).primaryColor.withOpacity(0.8),
          Theme.of(context).colorScheme.secondary.withOpacity(0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect Your Wallet',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect with MetaMask, Rainbow, Trust Wallet, or any WalletConnect compatible wallet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _connectWallet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).primaryColor,
              ),
              child: const Text('Connect Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context, Web3Refi web3) {
    final chain = web3.currentChain;
    final formattedBalance = _nativeBalance != null
        ? web3.formatNativeAmount(_nativeBalance!)
        : '0.0000';

    return GradientCard(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).primaryColor,
          Theme.of(context).primaryColor.withOpacity(0.7),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white70),
                onPressed: _isLoadingBalance ? null : _loadBalance,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _isLoadingBalance
              ? const ShimmerText(width: 180, height: 36)
              : Text(
                  '$formattedBalance ${chain.symbol}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
          const SizedBox(height: 16),
          // Address
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatAddress(web3.address ?? ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'SpaceMono',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _copyAddress(web3.address),
                  child: const Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.arrow_upward,
            label: 'Send',
            color: Theme.of(context).primaryColor,
            onTap: () => _navigateToTab(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.arrow_downward,
            label: 'Receive',
            color: Theme.of(context).colorScheme.secondary,
            onTap: _showReceiveDialog,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.swap_horiz,
            label: 'Swap',
            color: Colors.orange,
            onTap: () => _showComingSoon('Swap'),
          ),
        ),
      ],
    );
  }

  Widget _buildChainSelector(BuildContext context, Web3Refi web3) {
    final currentChain = web3.currentChain;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Network',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: _ChainIcon(chain: currentChain),
            title: Text(currentChain.name),
            subtitle: Text(
              currentChain.isTestnet ? 'Testnet' : 'Mainnet',
              style: TextStyle(
                color: currentChain.isTestnet ? Colors.orange : Colors.green,
              ),
            ),
            trailing: const Icon(Icons.keyboard_arrow_down),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onTap: () => _showChainSelector(context),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'No recent transactions',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This is an example app demonstrating web3refi SDK features. Built by S6 Labs LLC.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _connectWallet() async {
    try {
      await Web3Refi.instance.connect();
      if (mounted) {
        _showSnackBar('Wallet connected successfully!', isError: false);
        _loadBalance();
      }
    } on WalletException catch (e) {
      _showSnackBar(e.toUserMessage(), isError: true);
    } catch (e) {
      _showSnackBar('Failed to connect: $e', isError: true);
    }
  }

  void _copyAddress(String? address) {
    if (address == null) return;
    Clipboard.setData(ClipboardData(text: address));
    _showSnackBar('Address copied to clipboard', isError: false);
  }

  void _navigateToTab(int index) {
    // Find the MainNavigator state and update the index
    final navigator = context.findAncestorStateOfType<State>();
    if (navigator != null && navigator.mounted) {
      // This is a simplified approach - in production use a proper navigation solution
    }
  }

  void _showReceiveDialog() {
    final address = Web3Refi.instance.address;
    if (address == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
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
              'Receive',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.qr_code,
                size: 180,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              address,
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copyAddress(address),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showChainSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ChainSelectorSheet(
        chains: supportedChains,
        currentChain: Web3Refi.instance.currentChain,
        onChainSelected: (chain) async {
          Navigator.pop(context);
          try {
            await Web3Refi.instance.switchChain(chain);
            _showSnackBar('Switched to ${chain.name}', isError: false);
            _loadBalance();
          } catch (e) {
            _showSnackBar('Failed to switch chain', isError: true);
          }
        },
      ),
    );
  }

  void _showComingSoon(String feature) {
    _showSnackBar('$feature coming soon!', isError: false);
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ════════════════════════════════════════════════════════════════════════════

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChainIcon extends StatelessWidget {
  final Chain chain;

  const _ChainIcon({required this.chain});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _getChainColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          chain.symbol.substring(0, chain.symbol.length.clamp(0, 3)),
          style: TextStyle(
            color: _getChainColor(),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Color _getChainColor() {
    switch (chain.chainId) {
      case 1:
        return const Color(0xFF627EEA); // Ethereum
      case 137:
        return const Color(0xFF8247E5); // Polygon
      case 42161:
        return const Color(0xFF28A0F0); // Arbitrum
      case 10:
        return const Color(0xFFFF0420); // Optimism
      case 8453:
        return const Color(0xFF0052FF); // Base
      default:
        return Colors.grey;
    }
  }
}
