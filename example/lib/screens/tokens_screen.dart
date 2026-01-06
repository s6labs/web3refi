import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web3refi/web3refi.dart';

import 'package:web3refi_example/widgets/custom_widgets.dart';

// ════════════════════════════════════════════════════════════════════════════
// TOKEN DATA
// ════════════════════════════════════════════════════════════════════════════

class TokenData {
  final String name;
  final String symbol;
  final String address;
  final int chainId;
  final String? iconUrl;
  final int decimals;

  const TokenData({
    required this.name,
    required this.symbol,
    required this.address,
    required this.chainId,
    this.iconUrl,
    this.decimals = 18,
  });
}

// Common tokens for display
const _commonTokens = [
  // Polygon
  TokenData(
    name: 'USD Coin',
    symbol: 'USDC',
    address: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
    chainId: 137,
    decimals: 6,
  ),
  TokenData(
    name: 'Tether',
    symbol: 'USDT',
    address: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
    chainId: 137,
    decimals: 6,
  ),
  TokenData(
    name: 'Wrapped MATIC',
    symbol: 'WMATIC',
    address: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
    chainId: 137,
    decimals: 18,
  ),
  TokenData(
    name: 'Dai',
    symbol: 'DAI',
    address: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063',
    chainId: 137,
    decimals: 18,
  ),
  // Ethereum
  TokenData(
    name: 'USD Coin',
    symbol: 'USDC',
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    chainId: 1,
    decimals: 6,
  ),
  TokenData(
    name: 'Tether',
    symbol: 'USDT',
    address: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
    chainId: 1,
    decimals: 6,
  ),
];

// ════════════════════════════════════════════════════════════════════════════
// TOKENS SCREEN
// ════════════════════════════════════════════════════════════════════════════

class TokensScreen extends StatefulWidget {
  const TokensScreen({super.key});

  @override
  State<TokensScreen> createState() => _TokensScreenState();
}

class _TokensScreenState extends State<TokensScreen> {
  final Map<String, BigInt> _balances = {};
  final Map<String, bool> _loading = {};
  bool _isRefreshing = false;
  BigInt? _nativeBalance;

  @override
  void initState() {
    super.initState();
    _loadAllBalances();
  }

  Future<void> _loadAllBalances() async {
    if (!Web3Refi.instance.isConnected) return;

    setState(() => _isRefreshing = true);

    try {
      // Load native balance
      _nativeBalance = await Web3Refi.instance.getNativeBalance();

      // Load token balances
      final currentChainId = Web3Refi.instance.currentChain.chainId;
      final tokensOnChain =
          _commonTokens.where((t) => t.chainId == currentChainId);

      for (final token in tokensOnChain) {
        await _loadTokenBalance(token);
      }
    } catch (e) {
      debugPrint('Error loading balances: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadTokenBalance(TokenData token) async {
    if (!Web3Refi.instance.isConnected) return;

    setState(() => _loading[token.address] = true);

    try {
      final erc20 = Web3Refi.instance.token(token.address);
      final balance = await erc20.balanceOf(Web3Refi.instance.address!);
      setState(() => _balances[token.address] = balance);
    } catch (e) {
      debugPrint('Error loading ${token.symbol} balance: $e');
    } finally {
      setState(() => _loading[token.address] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Web3Refi>(
      builder: (context, web3, child) {
        if (!web3.isConnected) {
          return _buildNotConnected(context);
        }

        final currentChainId = web3.currentChain.chainId;
        final tokensOnChain =
            _commonTokens.where((t) => t.chainId == currentChainId).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tokens'),
            actions: [
              IconButton(
                icon: _isRefreshing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: _isRefreshing ? null : _loadAllBalances,
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadAllBalances,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Portfolio Summary
                _buildPortfolioSummary(context, web3),
                const SizedBox(height: 24),

                // Native Token
                _buildSectionHeader(context, 'Native Token'),
                const SizedBox(height: 12),
                _NativeTokenCard(
                  chain: web3.currentChain,
                  balance: _nativeBalance,
                  isLoading: _isRefreshing,
                ),
                const SizedBox(height: 24),

                // Tokens
                _buildSectionHeader(context, 'Tokens'),
                const SizedBox(height: 12),
                if (tokensOnChain.isEmpty)
                  _buildNoTokens(context)
                else
                  ...tokensOnChain.map((token) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TokenCard(
                          token: token,
                          balance: _balances[token.address],
                          isLoading: _loading[token.address] ?? false,
                          onTap: () => _showTokenDetails(context, token),
                        ),
                      )),

                const SizedBox(height: 24),

                // Add Custom Token
                _AddTokenButton(onTap: () => _showAddToken(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tokens')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
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
              'Connect your wallet to view tokens',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Web3Refi.instance.connect();
                  _loadAllBalances();
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

  Widget _buildPortfolioSummary(BuildContext context, Web3Refi web3) {
    return GradientCard(
      gradient: LinearGradient(
        colors: [
          Theme.of(context).primaryColor.withOpacity(0.8),
          Theme.of(context).colorScheme.secondary.withOpacity(0.5),
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
                'Portfolio',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  web3.currentChain.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _calculateTotalValue(),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.trending_up,
                size: 16,
                color: Colors.greenAccent[200],
              ),
              const SizedBox(width: 4),
              Text(
                '+0.00% today',
                style: TextStyle(
                  color: Colors.greenAccent[200],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildNoTokens(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.token_outlined,
              size: 48,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text('No tokens on this network'),
            const SizedBox(height: 8),
            Text(
              'Switch to a network with your tokens',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _calculateTotalValue() {
    // In production, you'd calculate actual USD value
    if (_nativeBalance == null) return '\$0.00';

    final formatted =
        Web3Refi.instance.formatNativeAmount(_nativeBalance!);
    return '\$${double.tryParse(formatted)?.toStringAsFixed(2) ?? '0.00'}';
  }

  void _showTokenDetails(BuildContext context, TokenData token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _TokenDetailsSheet(
        token: token,
        balance: _balances[token.address],
      ),
    );
  }

  void _showAddToken(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => const _AddTokenSheet(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// NATIVE TOKEN CARD
// ════════════════════════════════════════════════════════════════════════════

class _NativeTokenCard extends StatelessWidget {
  final Chain chain;
  final BigInt? balance;
  final bool isLoading;

  const _NativeTokenCard({
    required this.chain,
    this.balance,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final formattedBalance = balance != null
        ? Web3Refi.instance.formatNativeAmount(balance!)
        : '0.0000';

    return Card(
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getChainColor(chain).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              chain.symbol,
              style: TextStyle(
                color: _getChainColor(chain),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(chain.currencyName),
        subtitle: Text(chain.symbol),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formattedBalance,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    chain.symbol,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
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
      default:
        return Colors.grey;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOKEN CARD
// ════════════════════════════════════════════════════════════════════════════

class _TokenCard extends StatelessWidget {
  final TokenData token;
  final BigInt? balance;
  final bool isLoading;
  final VoidCallback onTap;

  const _TokenCard({
    required this.token,
    required this.onTap, this.balance,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: _TokenIcon(symbol: token.symbol),
        title: Text(token.name),
        subtitle: Text(token.symbol),
        trailing: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatBalance(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    token.symbol,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatBalance() {
    if (balance == null) return '0.00';

    final divisor = BigInt.from(10).pow(token.decimals);
    final whole = balance! ~/ divisor;
    final fraction = (balance! % divisor).abs();
    final fractionStr = fraction.toString().padLeft(token.decimals, '0');
    final displayFraction = fractionStr.substring(0, 2.clamp(0, fractionStr.length));

    return '$whole.$displayFraction';
  }
}

class _TokenIcon extends StatelessWidget {
  final String symbol;

  const _TokenIcon({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getTokenColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          symbol.length > 3 ? symbol.substring(0, 3) : symbol,
          style: TextStyle(
            color: _getTokenColor(),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Color _getTokenColor() {
    switch (symbol) {
      case 'USDC':
        return const Color(0xFF2775CA);
      case 'USDT':
        return const Color(0xFF26A17B);
      case 'DAI':
        return const Color(0xFFF5AC37);
      case 'WMATIC':
        return const Color(0xFF8247E5);
      case 'WETH':
        return const Color(0xFF627EEA);
      default:
        return Colors.grey;
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TOKEN DETAILS SHEET
// ════════════════════════════════════════════════════════════════════════════

class _TokenDetailsSheet extends StatelessWidget {
  final TokenData token;
  final BigInt? balance;

  const _TokenDetailsSheet({
    required this.token,
    this.balance,
  });

  @override
  Widget build(BuildContext context) {
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
          _TokenIcon(symbol: token.symbol),
          const SizedBox(height: 16),
          Text(
            token.name,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            token.symbol,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Contract', token.address),
          _buildDetailRow('Decimals', token.decimals.toString()),
          _buildDetailRow('Chain ID', token.chainId.toString()),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  child: const Text('View on Explorer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Navigate to transfer with this token
                  },
                  child: const Text('Send'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'SpaceMono', fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ADD TOKEN SHEET
// ════════════════════════════════════════════════════════════════════════════

class _AddTokenSheet extends StatefulWidget {
  const _AddTokenSheet();

  @override
  State<_AddTokenSheet> createState() => _AddTokenSheetState();
}

class _AddTokenSheetState extends State<_AddTokenSheet> {
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
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
            'Add Custom Token',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Token Contract Address',
              hintText: '0x...',
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addToken,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Token'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToken() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final token = Web3Refi.instance.token(address);
      final name = await token.name();
      final symbol = await token.symbol();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added $name ($symbol)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid token: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
}

// ════════════════════════════════════════════════════════════════════════════
// ADD TOKEN BUTTON
// ════════════════════════════════════════════════════════════════════════════

class _AddTokenButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddTokenButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.add),
      label: const Text('Add Custom Token'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
