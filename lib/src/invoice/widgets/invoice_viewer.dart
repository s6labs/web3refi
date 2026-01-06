import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/invoice.dart';
import '../core/invoice_status.dart';
import '../manager/invoice_calculator.dart';
import '../manager/invoice_manager.dart';
import '../payment/invoice_payment_handler.dart';

/// Display invoice with pay button
class InvoiceViewer extends StatefulWidget {
  final Invoice invoice;
  final InvoiceManager? invoiceManager;
  final InvoicePaymentHandler? paymentHandler;
  final String? currentUserAddress;
  final Function(String txHash)? onPaymentComplete;
  final bool showPayButton;

  const InvoiceViewer({
    Key? key,
    required this.invoice,
    this.invoiceManager,
    this.paymentHandler,
    this.currentUserAddress,
    this.onPaymentComplete,
    this.showPayButton = true,
  }) : super(key: key);

  @override
  State<InvoiceViewer> createState() => _InvoiceViewerState();
}

class _InvoiceViewerState extends State<InvoiceViewer> {
  bool _isPaying = false;
  String? _selectedTokenAddress;
  int? _selectedChainId;

  @override
  void initState() {
    super.initState();
    _markAsViewed();
  }

  Future<void> _markAsViewed() async {
    if (widget.invoiceManager != null &&
        widget.invoice.status == InvoiceStatus.sent) {
      try {
        await widget.invoiceManager!.markAsViewed(widget.invoice.id);
      } catch (e) {
        debugPrint('Failed to mark as viewed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice ${widget.invoice.number}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareInvoice,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const Divider(height: 32),
            _buildParties(),
            const Divider(height: 32),
            _buildLineItems(),
            const Divider(height: 32),
            _buildTotals(),
            const Divider(height: 32),
            _buildPaymentInfo(),
            if (_shouldShowPayButton()) ...[
              const Divider(height: 32),
              _buildPayButton(),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.invoice.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            _buildStatusChip(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Invoice #${widget.invoice.number}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        if (widget.invoice.description != null) ...[
          const SizedBox(height: 8),
          Text(widget.invoice.description!),
        ],
        const SizedBox(height: 16),
        _buildDateInfo(),
      ],
    );
  }

  Widget _buildStatusChip() {
    Color color;
    String label;

    if (widget.invoice.isPaid) {
      color = Colors.green;
      label = 'PAID';
    } else if (widget.invoice.isOverdue) {
      color = Colors.red;
      label = 'OVERDUE';
    } else if (widget.invoice.status == InvoiceStatus.cancelled) {
      color = Colors.grey;
      label = 'CANCELLED';
    } else if (widget.invoice.status == InvoiceStatus.disputed) {
      color = Colors.orange;
      label = 'DISPUTED';
    } else {
      color = Colors.blue;
      label = widget.invoice.status.name.toUpperCase();
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
    );
  }

  Widget _buildDateInfo() {
    return Row(
      children: [
        Expanded(
          child: _buildInfoTile(
            'Issue Date',
            _formatDate(widget.invoice.issueDate),
          ),
        ),
        Expanded(
          child: _buildInfoTile(
            'Due Date',
            _formatDate(widget.invoice.dueDate),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PARTIES
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildParties() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPartyCard(
            'From',
            widget.invoice.fromName ?? 'Unknown',
            widget.invoice.from,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPartyCard(
            'To',
            widget.invoice.toName ?? 'Unknown',
            widget.invoice.to,
          ),
        ),
      ],
    );
  }

  Widget _buildPartyCard(String label, String name, String address) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _copyToClipboard(address),
              child: Text(
                _shortenAddress(address),
                style: TextStyle(fontSize: 12, color: Colors.blue[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // LINE ITEMS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLineItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Items',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...widget.invoice.items.map((item) => _buildLineItem(item)),
      ],
    );
  }

  Widget _buildLineItem(InvoiceItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (item.notes != null)
                  Text(
                    item.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              _formatAmount(item.unitPrice),
              textAlign: TextAlign.right,
            ),
          ),
          Expanded(
            child: Text(
              _formatAmount(item.total),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOTALS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTotals() {
    return Column(
      children: [
        _buildTotalRow('Subtotal', widget.invoice.subtotal),
        if (widget.invoice.taxAmount != null && widget.invoice.taxAmount! > BigInt.zero)
          _buildTotalRow(
            'Tax (${((widget.invoice.taxRate ?? 0) * 100).toStringAsFixed(1)}%)',
            widget.invoice.taxAmount!,
          ),
        if (widget.invoice.discount != null && widget.invoice.discount! > BigInt.zero)
          _buildTotalRow('Discount', -widget.invoice.discount!, color: Colors.green),
        const Divider(),
        _buildTotalRow('Total', widget.invoice.total, bold: true, large: true),
        if (widget.invoice.paidAmount > BigInt.zero) ...[
          _buildTotalRow('Paid', widget.invoice.paidAmount, color: Colors.green),
          const Divider(),
          _buildTotalRow(
            'Remaining',
            widget.invoice.remainingAmount,
            bold: true,
            color: widget.invoice.isOverdue ? Colors.red : null,
          ),
        ],
      ],
    );
  }

  Widget _buildTotalRow(
    String label,
    BigInt amount, {
    bool bold = false,
    bool large = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: large ? 18 : 14,
              color: color,
            ),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: large ? 18 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT INFO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPaymentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Information',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (widget.invoice.payments.isNotEmpty) ...[
          ...widget.invoice.payments.map((payment) => _buildPaymentTile(payment)),
        ] else
          const Text('No payments recorded yet'),
        if (widget.invoice.isRecurring) ...[
          const SizedBox(height: 8),
          const Chip(
            avatar: Icon(Icons.repeat, size: 16),
            label: Text('Recurring Invoice'),
          ),
        ],
      ],
    );
  }

  Widget _buildPaymentTile(Payment payment) {
    return Card(
      child: ListTile(
        leading: Icon(
          payment.status == PaymentStatus.confirmed
              ? Icons.check_circle
              : Icons.pending,
          color: payment.status == PaymentStatus.confirmed
              ? Colors.green
              : Colors.orange,
        ),
        title: Text(_formatAmount(payment.amount)),
        subtitle: Text(
          '${payment.token} on Chain ${payment.chainId}\n${_shortenTxHash(payment.txHash)}',
        ),
        trailing: Text(
          '${payment.confirmations} conf',
          style: const TextStyle(fontSize: 12),
        ),
        onTap: () => _viewTransaction(payment.txHash, payment.chainId),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAY BUTTON
  // ═══════════════════════════════════════════════════════════════════════

  bool _shouldShowPayButton() {
    if (!widget.showPayButton || widget.paymentHandler == null) return false;
    if (widget.invoice.isPaid) return false;
    if (widget.currentUserAddress == null) return false;
    return widget.invoice.to.toLowerCase() == widget.currentUserAddress!.toLowerCase();
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isPaying ? null : _payInvoice,
        icon: _isPaying
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.payment),
        label: Text(
          _isPaying
              ? 'Processing Payment...'
              : 'Pay ${_formatAmount(widget.invoice.remainingAmount)}',
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _payInvoice() async {
    // Show payment options dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PaymentOptionsDialog(
        invoice: widget.invoice,
      ),
    );

    if (result == null) return;

    setState(() => _isPaying = true);

    try {
      final txHash = await widget.paymentHandler!.payInvoice(
        invoice: widget.invoice,
        tokenAddress: result['tokenAddress'] as String,
        chainId: result['chainId'] as int,
      );

      widget.onPaymentComplete?.call(txHash);

      if (mounted) {
        _showSuccess('Payment submitted! Transaction: ${_shortenTxHash(txHash)}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Payment failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isPaying = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  void _shareInvoice() {
    // Generate shareable link
    final link = widget.invoice.ipfsCid != null
        ? 'https://ipfs.io/ipfs/${widget.invoice.ipfsCid}'
        : 'Invoice ${widget.invoice.number}';

    Clipboard.setData(ClipboardData(text: link));
    _showSuccess('Invoice link copied to clipboard');
  }

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.invoice.ipfsCid != null)
            ListTile(
              leading: const Icon(Icons.cloud),
              title: const Text('View on IPFS'),
              onTap: () {
                Navigator.pop(context);
                _viewOnIPFS();
              },
            ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy Invoice ID'),
            onTap: () {
              Navigator.pop(context);
              _copyToClipboard(widget.invoice.id);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download PDF'),
            onTap: () {
              Navigator.pop(context);
              _downloadPDF();
            },
          ),
        ],
      ),
    );
  }

  void _viewOnIPFS() {
    _showSuccess('Opening IPFS...');
  }

  void _downloadPDF() {
    _showSuccess('PDF download not implemented yet');
  }

  void _viewTransaction(String txHash, int chainId) {
    _copyToClipboard(txHash);
    _showSuccess('Transaction hash copied');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(
      amount,
      symbol: widget.invoice.currency,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _shortenTxHash(String hash) {
    if (hash.length <= 10) return hash;
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    _showSuccess('Copied to clipboard');
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

/// Payment options dialog
class _PaymentOptionsDialog extends StatefulWidget {
  final Invoice invoice;

  const _PaymentOptionsDialog({required this.invoice});

  @override
  State<_PaymentOptionsDialog> createState() => _PaymentOptionsDialogState();
}

class _PaymentOptionsDialogState extends State<_PaymentOptionsDialog> {
  String _selectedToken = 'USDC';
  int _selectedChainId = 1; // Ethereum

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Payment Method'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedToken,
            decoration: const InputDecoration(labelText: 'Token'),
            items: ['USDC', 'USDT', 'DAI', 'ETH']
                .map((token) => DropdownMenuItem(
                      value: token,
                      child: Text(token),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _selectedToken = value!),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedChainId,
            decoration: const InputDecoration(labelText: 'Network'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Ethereum')),
              DropdownMenuItem(value: 137, child: Text('Polygon')),
              DropdownMenuItem(value: 56, child: Text('BNB Chain')),
              DropdownMenuItem(value: 42161, child: Text('Arbitrum')),
            ],
            onChanged: (value) => setState(() => _selectedChainId = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'tokenAddress': _selectedToken,
            'chainId': _selectedChainId,
          }),
          child: const Text('Pay'),
        ),
      ],
    );
  }
}
