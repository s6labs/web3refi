import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:web3refi/web3refi.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedToken = 'native';
  bool _isSending = false;
  BigInt? _balance;
  BigInt? _estimatedGas;
  String? _txHash;
  TransactionStatus? _txStatus;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    if (!Web3Refi.instance.isConnected) return;

    try {
      final balance = await Web3Refi.instance.getNativeBalance();
      setState(() => _balance = balance);
    } catch (e) {
      debugPrint('Error loading balance: $e');
    }
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
            title: const Text('Send'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // From Section
                  _buildFromSection(context, web3),
                  const SizedBox(height: 24),

                  // Token Selector
                  _buildTokenSelector(context, web3),
                  const SizedBox(height: 24),

                  // Recipient
                  _buildRecipientField(context),
                  const SizedBox(height: 24),

                  // Amount
                  _buildAmountField(context, web3),
                  const SizedBox(height: 24),

                  // Gas Estimate
                  if (_estimatedGas != null) _buildGasEstimate(context, web3),
                  const SizedBox(height: 24),

                  // Transaction Status
                  if (_txHash != null) _buildTransactionStatus(context),
                  const SizedBox(height: 24),

                  // Send Button
                  _buildSendButton(context),

                  const SizedBox(height: 32),

                  // Recent Transactions
                  _buildRecentTransactions(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.send_outlined,
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
              'Connect your wallet to send tokens',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                try {
                  await Web3Refi.instance.connect();
                  _loadBalance();
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

  Widget _buildFromSection(BuildContext context, Web3Refi web3) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'From',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAddress(web3.address ?? ''),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Balance: ${_formatBalance(web3)} ${web3.currentChain.symbol}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenSelector(BuildContext context, Web3Refi web3) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Token',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                value: 'native',
                groupValue: _selectedToken,
                onChanged: (value) {
                  setState(() => _selectedToken = value!);
                  _loadBalance();
                },
                title: Text(web3.currentChain.symbol),
                subtitle: Text('Native • ${web3.currentChain.name}'),
                secondary: _buildTokenIcon(web3.currentChain.symbol),
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                value: 'usdc',
                groupValue: _selectedToken,
                onChanged: (value) {
                  setState(() => _selectedToken = value!);
                },
                title: const Text('USDC'),
                subtitle: const Text('USD Coin'),
                secondary: _buildTokenIcon('USDC'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokenIcon(String symbol) {
    Color color;
    switch (symbol) {
      case 'USDC':
        color = const Color(0xFF2775CA);
        break;
      case 'ETH':
        color = const Color(0xFF627EEA);
        break;
      case 'MATIC':
        color = const Color(0xFF8247E5);
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          symbol.length > 3 ? symbol.substring(0, 3) : symbol,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildRecipientField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recipient',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _recipientController,
          decoration: InputDecoration(
            hintText: '0x...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () {
                    // TODO: QR scanner
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('QR Scanner coming soon')),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: _pasteAddress,
                ),
              ],
            ),
          ),
          style: const TextStyle(fontFamily: 'SpaceMono'),
          validator: _validateAddress,
          onChanged: (_) => _estimateGas(),
        ),
      ],
    );
  }

  Widget _buildAmountField(BuildContext context, Web3Refi web3) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Amount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            TextButton(
              onPressed: _setMaxAmount,
              child: const Text('MAX'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountController,
          decoration: InputDecoration(
            hintText: '0.00',
            suffixText: _selectedToken == 'native'
                ? web3.currentChain.symbol
                : 'USDC',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
          validator: _validateAmount,
          onChanged: (_) => _estimateGas(),
        ),
      ],
    );
  }

  Widget _buildGasEstimate(BuildContext context, Web3Refi web3) {
    final gasFormatted = web3.formatNativeAmount(_estimatedGas!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.local_gas_station, size: 20, color: Colors.white54),
              SizedBox(width: 8),
              Text('Estimated Gas', style: TextStyle(color: Colors.white54)),
            ],
          ),
          Text(
            '$gasFormatted ${web3.currentChain.symbol}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionStatus(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (_txStatus) {
      case TransactionStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending...';
        break;
      case TransactionStatus.confirmed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Confirmed!';
        break;
      case TransactionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        statusText = 'Failed';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tx: ${_formatAddress(_txHash!)}',
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              final url =
                  Web3Refi.instance.currentChain.getTransactionUrl(_txHash!);
              // Launch URL
            },
            child: const Text('View on Explorer'),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendTransaction,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
        ),
        child: _isSending
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Sending...'),
                ],
              )
            : const Text('Send'),
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _pasteAddress() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _recipientController.text = data!.text!;
    }
  }

  void _setMaxAmount() {
    if (_balance == null) return;

    // Leave some for gas
    final maxAmount = _balance! - BigInt.from(1e16); // Leave 0.01 for gas
    if (maxAmount > BigInt.zero) {
      final formatted = Web3Refi.instance.formatNativeAmount(maxAmount);
      _amountController.text = formatted;
    }
  }

  Future<void> _estimateGas() async {
    final recipient = _recipientController.text.trim();
    final amount = _amountController.text.trim();

    if (recipient.isEmpty || amount.isEmpty) {
      setState(() => _estimatedGas = null);
      return;
    }

    try {
      final amountWei = Web3Refi.instance.parseNativeAmount(amount);
      final gas = await Web3Refi.instance.estimateGas(
        to: recipient,
        value: '0x${amountWei.toRadixString(16)}',
      );
      setState(() => _estimatedGas = gas * BigInt.from(2e9)); // Approximate gas cost
    } catch (e) {
      debugPrint('Gas estimate error: $e');
    }
  }

  Future<void> _sendTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _txHash = null;
      _txStatus = null;
    });

    try {
      final recipient = _recipientController.text.trim();
      final amount = _amountController.text.trim();

      String txHash;

      if (_selectedToken == 'native') {
        // Send native token
        final amountWei = Web3Refi.instance.parseNativeAmount(amount);
        txHash = await Web3Refi.instance.sendTransaction(
          to: recipient,
          value: '0x${amountWei.toRadixString(16)}',
        );
      } else {
        // Send ERC-20 token
        // This is a placeholder - need actual token address
        final token = Web3Refi.instance.token(
          '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', // USDC Polygon
        );
        final amountParsed = await token.parseAmount(amount);
        txHash = await token.transfer(to: recipient, amount: amountParsed);
      }

      setState(() {
        _txHash = txHash;
        _txStatus = TransactionStatus.pending;
      });

      // Wait for confirmation
      final receipt = await Web3Refi.instance.waitForTransaction(txHash);

      setState(() {
        _txStatus = receipt.status;
      });

      if (receipt.isSuccess) {
        _showSuccessDialog();
        _recipientController.clear();
        _amountController.clear();
        _loadBalance();
      }
    } on WalletException catch (e) {
      _showError(e.toUserMessage());
    } on TransactionException catch (e) {
      _showError(e.toUserMessage());
    } catch (e) {
      _showError('Transaction failed: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Transaction Sent!'),
        content: const Text('Your transaction has been confirmed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // View on explorer
            },
            child: const Text('View Details'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATORS
  // ══════════════════════════════════════════════════════════════════════════

  String? _validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter recipient address';
    }
    if (!value.startsWith('0x') || value.length != 42) {
      return 'Invalid Ethereum address';
    }
    return null;
  }

  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter amount';
    }
    final amount = double.tryParse(value);
    if (amount == null || amount <= 0) {
      return 'Invalid amount';
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  String _formatAddress(String address) {
    if (address.length < 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatBalance(Web3Refi web3) {
    if (_balance == null) return '0.0000';
    return web3.formatNativeAmount(_balance!);
  }
}
