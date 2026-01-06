import 'package:flutter/material.dart';
import '../core/invoice.dart';
import '../payment/invoice_payment_handler.dart';
import '../manager/invoice_calculator.dart';

/// One-click payment interface for invoices
class InvoicePaymentWidget extends StatefulWidget {
  final Invoice invoice;
  final InvoicePaymentHandler paymentHandler;
  final Function(String txHash)? onPaymentComplete;
  final Function(String error)? onPaymentError;

  const InvoicePaymentWidget({
    Key? key,
    required this.invoice,
    required this.paymentHandler,
    this.onPaymentComplete,
    this.onPaymentError,
  }) : super(key: key);

  @override
  State<InvoicePaymentWidget> createState() => _InvoicePaymentWidgetState();
}

class _InvoicePaymentWidgetState extends State<InvoicePaymentWidget> {
  bool _isProcessing = false;
  bool _isCheckingBalance = false;
  String? _selectedToken;
  int? _selectedChainId;
  BigInt? _availableBalance;
  PaymentConfirmation? _confirmation;

  // Supported tokens per chain
  final Map<int, List<TokenOption>> _tokensByChain = {
    1: [
      // Ethereum
      TokenOption('USDC', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', 6),
      TokenOption('USDT', '0xdAC17F958D2ee523a2206206994597C13D831ec7', 6),
      TokenOption('DAI', '0x6B175474E89094C44Da98b954EedeAC495271d0F', 18),
      TokenOption('ETH', 'NATIVE', 18),
    ],
    137: [
      // Polygon
      TokenOption('USDC', '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174', 6),
      TokenOption('USDT', '0xc2132D05D31c914a87C6611C10748AEb04B58e8F', 6),
      TokenOption('DAI', '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063', 18),
      TokenOption('MATIC', 'NATIVE', 18),
    ],
    56: [
      // BNB Chain
      TokenOption('USDC', '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', 18),
      TokenOption('USDT', '0x55d398326f99059fF775485246999027B3197955', 18),
      TokenOption('BNB', 'NATIVE', 18),
    ],
    42161: [
      // Arbitrum
      TokenOption('USDC', '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', 6),
      TokenOption('USDT', '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', 6),
      TokenOption('ETH', 'NATIVE', 18),
    ],
  };

  @override
  void initState() {
    super.initState();
    // Set defaults
    _selectedChainId = 137; // Polygon
    _selectedToken = _tokensByChain[_selectedChainId]!.first.address;
    _checkBalance();
  }

  Future<void> _checkBalance() async {
    if (_selectedToken == null || _selectedChainId == null) return;

    setState(() => _isCheckingBalance = true);

    try {
      final hasBalance = await widget.paymentHandler.hasSufficientBalance(
        amount: widget.invoice.remainingAmount,
        tokenAddress: _selectedToken!,
        chainId: _selectedChainId!,
      );

      // For demo purposes, we'll assume a balance
      // In production, fetch actual balance from wallet
      setState(() {
        _availableBalance = hasBalance
            ? widget.invoice.remainingAmount * BigInt.from(2)
            : BigInt.zero;
      });
    } catch (e) {
      debugPrint('Balance check failed: $e');
      setState(() => _availableBalance = BigInt.zero);
    } finally {
      setState(() => _isCheckingBalance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 24),
            _buildPaymentAmount(),
            const SizedBox(height: 16),
            _buildNetworkSelector(),
            const SizedBox(height: 16),
            _buildTokenSelector(),
            const SizedBox(height: 16),
            _buildBalanceInfo(),
            const SizedBox(height: 24),
            if (_confirmation == null)
              _buildPayButton()
            else
              _buildConfirmationStatus(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(Icons.payment, size: 32, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pay Invoice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Invoice #${widget.invoice.number}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT AMOUNT
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPaymentAmount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Amount Due',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          Text(
            _formatAmount(widget.invoice.remainingAmount),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NETWORK SELECTOR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildNetworkSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Network',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedChainId,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(
              value: 1,
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Ethereum'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 137,
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Polygon'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 56,
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('BNB Chain'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 42161,
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.cyan),
                  SizedBox(width: 8),
                  Text('Arbitrum'),
                ],
              ),
            ),
          ],
          onChanged: _isProcessing
              ? null
              : (value) {
                  setState(() {
                    _selectedChainId = value;
                    _selectedToken = _tokensByChain[value]!.first.address;
                  });
                  _checkBalance();
                },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOKEN SELECTOR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTokenSelector() {
    final tokens = _tokensByChain[_selectedChainId] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pay with',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tokens.map((token) {
            final isSelected = _selectedToken == token.address;
            return ChoiceChip(
              label: Text(token.symbol),
              selected: isSelected,
              onSelected: _isProcessing
                  ? null
                  : (selected) {
                      setState(() => _selectedToken = token.address);
                      _checkBalance();
                    },
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BALANCE INFO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBalanceInfo() {
    if (_isCheckingBalance) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Checking balance...'),
        ],
      );
    }

    if (_availableBalance == null) {
      return const SizedBox.shrink();
    }

    final hasSufficient = _availableBalance! >= widget.invoice.remainingAmount;
    final tokenSymbol = _getSelectedTokenSymbol();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasSufficient
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            hasSufficient ? Icons.check_circle : Icons.warning,
            color: hasSufficient ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasSufficient
                  ? 'Balance: ${_formatAmount(_availableBalance!)} $tokenSymbol'
                  : 'Insufficient balance',
              style: TextStyle(
                color: hasSufficient ? Colors.green[800] : Colors.red[800],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAY BUTTON
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPayButton() {
    final canPay = _availableBalance != null &&
        _availableBalance! >= widget.invoice.remainingAmount;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: (_isProcessing || !canPay) ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing Payment...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send),
                  const SizedBox(width: 8),
                  Text('Pay ${_formatAmount(widget.invoice.remainingAmount)}'),
                ],
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CONFIRMATION STATUS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildConfirmationStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _confirmation!.isConfirmed
            ? Colors.green.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _confirmation!.isConfirmed ? Colors.green : Colors.blue,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                _confirmation!.isConfirmed
                    ? Icons.check_circle
                    : Icons.pending,
                color: _confirmation!.isConfirmed ? Colors.green : Colors.blue,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _confirmation!.isConfirmed
                          ? 'Payment Confirmed!'
                          : 'Payment Processing',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _confirmation!.isConfirmed
                            ? Colors.green[800]
                            : Colors.blue[800],
                      ),
                    ),
                    Text(
                      '${_confirmation!.confirmations} confirmations',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _confirmation!.confirmations / 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(
              _confirmation!.isConfirmed ? Colors.green : Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Transaction',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                _shortenTxHash(_confirmation!.txHash),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT PROCESSING
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _processPayment() async {
    if (_selectedToken == null || _selectedChainId == null) return;

    setState(() => _isProcessing = true);

    try {
      // Execute payment
      final txHash = await widget.paymentHandler.payInvoice(
        invoice: widget.invoice,
        tokenAddress: _selectedToken!,
        chainId: _selectedChainId!,
      );

      // Wait for confirmation
      final confirmation = await widget.paymentHandler.waitForConfirmation(
        txHash: txHash,
        chainId: _selectedChainId!,
        requiredConfirmations: 12,
      );

      setState(() {
        _confirmation = confirmation;
        _isProcessing = false;
      });

      widget.onPaymentComplete?.call(txHash);

      if (mounted) {
        _showSuccess('Payment confirmed!');
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      widget.onPaymentError?.call(e.toString());

      if (mounted) {
        _showError('Payment failed: $e');
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _getSelectedTokenSymbol() {
    if (_selectedChainId == null || _selectedToken == null) return '';
    final tokens = _tokensByChain[_selectedChainId]!;
    return tokens.firstWhere((t) => t.address == _selectedToken).symbol;
  }

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(
      amount,
      symbol: widget.invoice.currency,
    );
  }

  String _shortenTxHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Token option for payment
class TokenOption {
  final String symbol;
  final String address;
  final int decimals;

  TokenOption(this.symbol, this.address, this.decimals);
}
