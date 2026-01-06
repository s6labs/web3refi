import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3refi/src/core/web3refi_base.dart';
import 'package:web3refi/src/transactions/transaction.dart';
import 'package:web3refi/src/core/chain.dart';

/// Displays real-time transaction status with progress indicator.
///
/// Automatically polls for transaction confirmation and updates UI.
///
/// Example:
/// ```dart
/// TransactionStatus(
///   txHash: '0x123...',
///   onConfirmed: (receipt) => print('Confirmed in block ${receipt.blockNumber}'),
///   onFailed: (receipt) => print('Failed: ${receipt.errorMessage}'),
/// )
/// ```
class TransactionStatus extends StatefulWidget {
  /// Transaction hash to track.
  final String txHash;

  /// Called when transaction is confirmed.
  final void Function(TransactionReceipt receipt)? onConfirmed;

  /// Called when transaction fails.
  final void Function(TransactionReceipt receipt)? onFailed;

  /// Number of confirmations to wait for.
  final int confirmations;

  /// Whether to show the transaction hash.
  final bool showHash;

  /// Whether to show a link to block explorer.
  final bool showExplorerLink;

  /// Custom chain (defaults to current chain).
  final Chain? chain;

  /// Style variant.
  final TransactionStatusStyle style;

  /// Whether to auto-dismiss after confirmation.
  final bool autoDismiss;

  /// Duration before auto-dismiss.
  final Duration autoDismissDelay;

  /// Called when widget is dismissed.
  final VoidCallback? onDismiss;

  const TransactionStatus({
    required this.txHash, super.key,
    this.onConfirmed,
    this.onFailed,
    this.confirmations = 1,
    this.showHash = true,
    this.showExplorerLink = true,
    this.chain,
    this.style = TransactionStatusStyle.card,
    this.autoDismiss = false,
    this.autoDismissDelay = const Duration(seconds: 3),
    this.onDismiss,
  });

  @override
  State<TransactionStatus> createState() => _TransactionStatusState();
}

class _TransactionStatusState extends State<TransactionStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  TransactionReceipt? _receipt;
  bool _isPolling = true;
  Timer? _pollTimer;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    
    _startPolling();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    super.dispose();
  }

  Chain get _chain => widget.chain ?? Web3Refi.instance.currentChain;

  void _startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!_isPolling) return;

    try {
      final receipt = await Web3Refi.instance.waitForTransaction(
        widget.txHash,
        confirmations: widget.confirmations,
        timeout: const Duration(seconds: 5),
      );

      if (!mounted) return;

      if (receipt.status == TransactionStatus.confirmed) {
        _stopPolling();
        setState(() => _receipt = receipt);
        widget.onConfirmed?.call(receipt);
        _startAutoDismiss();
      } else if (receipt.status == TransactionStatus.failed) {
        _stopPolling();
        setState(() => _receipt = receipt);
        widget.onFailed?.call(receipt);
      }
    } catch (e) {
      // Continue polling on error
    }
  }

  void _stopPolling() {
    _isPolling = false;
    _pollTimer?.cancel();
    _pulseController.stop();
  }

  void _startAutoDismiss() {
    if (widget.autoDismiss) {
      _dismissTimer = Timer(widget.autoDismissDelay, () {
        widget.onDismiss?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case TransactionStatusStyle.card:
        return _buildCard();
      case TransactionStatusStyle.inline:
        return _buildInline();
      case TransactionStatusStyle.minimal:
        return _buildMinimal();
      case TransactionStatusStyle.banner:
        return _buildBanner();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CARD STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusIcon(),
            const SizedBox(height: 12),
            _buildStatusText(),
            if (widget.showHash) ...[
              const SizedBox(height: 8),
              _buildHashRow(),
            ],
            if (widget.showExplorerLink && _receipt?.isSuccess == true) ...[
              const SizedBox(height: 12),
              _buildExplorerButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INLINE STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIconSmall(),
        const SizedBox(width: 8),
        Flexible(child: _buildStatusText()),
        if (widget.showExplorerLink) ...[
          const SizedBox(width: 8),
          _buildExplorerIconButton(),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MINIMAL STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMinimal() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatusIconSmall(),
        const SizedBox(width: 6),
        Text(
          _statusLabel,
          style: TextStyle(
            color: _statusColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BANNER STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        border: Border(
          left: BorderSide(color: _statusColor, width: 4),
        ),
      ),
      child: Row(
        children: [
          _buildStatusIconSmall(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
                if (widget.showHash) ...[
                  const SizedBox(height: 2),
                  Text(
                    _truncateHash(widget.txHash),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.showExplorerLink)
            _buildExplorerIconButton(),
          if (widget.onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: widget.onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusIcon() {
    const size = 56.0;
    
    if (_isPolling) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1 + 0.1 * _pulseController.value),
              borderRadius: BorderRadius.circular(size / 2),
            ),
            child: Center(
              child: SizedBox(
                width: size * 0.5,
                height: size * 0.5,
                child: const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
            ),
          );
        },
      );
    }

    IconData icon;
    Color color;
    
    if (_receipt?.isSuccess == true) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_receipt?.isFailed == true) {
      icon = Icons.error;
      color = Colors.red;
    } else {
      icon = Icons.hourglass_empty;
      color = Colors.orange;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  Widget _buildStatusIconSmall() {
    if (_isPolling) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      );
    }

    IconData icon;
    Color color;
    
    if (_receipt?.isSuccess == true) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_receipt?.isFailed == true) {
      icon = Icons.error;
      color = Colors.red;
    } else {
      icon = Icons.hourglass_empty;
      color = Colors.orange;
    }

    return Icon(icon, color: color, size: 20);
  }

  Widget _buildStatusText() {
    return Column(
      children: [
        Text(
          _statusLabel,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _statusColor,
          ),
        ),
        if (_receipt?.blockNumber != null) ...[
          const SizedBox(height: 2),
          Text(
            'Block #${_receipt!.blockNumber}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHashRow() {
    return InkWell(
      onTap: () => _copyHash(),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _truncateHash(widget.txHash),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorerButton() {
    return TextButton.icon(
      onPressed: _openExplorer,
      icon: const Icon(Icons.open_in_new, size: 16),
      label: const Text('View on Explorer'),
    );
  }

  Widget _buildExplorerIconButton() {
    return IconButton(
      onPressed: _openExplorer,
      icon: const Icon(Icons.open_in_new, size: 18),
      tooltip: 'View on Explorer',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }

  String get _statusLabel {
    if (_isPolling) return 'Transaction Pending...';
    if (_receipt?.isSuccess == true) return 'Transaction Confirmed';
    if (_receipt?.isFailed == true) return 'Transaction Failed';
    return 'Unknown Status';
  }

  Color get _statusColor {
    if (_isPolling) return Colors.blue;
    if (_receipt?.isSuccess == true) return Colors.green;
    if (_receipt?.isFailed == true) return Colors.red;
    return Colors.orange;
  }

  String _truncateHash(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 10)}...${hash.substring(hash.length - 6)}';
  }

  void _copyHash() {
    Clipboard.setData(ClipboardData(text: widget.txHash));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction hash copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _openExplorer() {
    final url = _chain.getTransactionUrl(widget.txHash);
    // launchUrl(Uri.parse(url));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTION STATUS DIALOG
// ═══════════════════════════════════════════════════════════════════════════

/// Shows a transaction status dialog.
///
/// Example:
/// ```dart
/// final confirmed = await showTransactionDialog(
///   context: context,
///   txHash: '0x123...',
/// );
/// ```
Future<bool?> showTransactionDialog({
  required BuildContext context,
  required String txHash,
  int confirmations = 1,
  bool dismissible = false,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: dismissible,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: TransactionStatus(
        txHash: txHash,
        confirmations: confirmations,
        style: TransactionStatusStyle.card,
        onConfirmed: (_) {
          Future.delayed(const Duration(seconds: 1), () {
            if (context.mounted) Navigator.pop(context, true);
          });
        },
        onFailed: (_) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) Navigator.pop(context, false);
          });
        },
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// TRANSACTION LIST WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Displays a list of pending/recent transactions.
///
/// Example:
/// ```dart
/// TransactionList(
///   transactions: pendingTxs,
///   onTransactionTap: (tx) => showDetails(tx),
/// )
/// ```
class TransactionList extends StatelessWidget {
  final List<PendingTransaction> transactions;
  final void Function(PendingTransaction)? onTransactionTap;
  final Widget? emptyWidget;

  const TransactionList({
    required this.transactions, super.key,
    this.onTransactionTap,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return emptyWidget ?? const _EmptyTransactions();
    }

    return ListView.separated(
      shrinkWrap: true,
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _TransactionListItem(
          transaction: tx,
          onTap: onTransactionTap != null ? () => onTransactionTap!(tx) : null,
        );
      },
    );
  }
}

class _TransactionListItem extends StatelessWidget {
  final PendingTransaction transaction;
  final VoidCallback? onTap;

  const _TransactionListItem({
    required this.transaction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _buildStatusIcon(),
      title: Text(
        transaction.description ?? 'Transaction',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatHash(transaction.hash),
        style: TextStyle(
          fontSize: 12,
          fontFamily: 'monospace',
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Text(
        _formatAge(transaction.age),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color;

    switch (transaction.status) {
      case TransactionStatus.pending:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case TransactionStatus.confirmed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case TransactionStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      default:
        icon = Icons.hourglass_empty;
        color = Colors.orange;
    }

    return Icon(icon, color: color);
  }

  String _formatHash(String hash) {
    return '${hash.substring(0, 8)}...${hash.substring(hash.length - 6)}';
  }

  String _formatAge(Duration age) {
    if (age.inSeconds < 60) return '${age.inSeconds}s ago';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'No transactions',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STYLE ENUM
// ═══════════════════════════════════════════════════════════════════════════

/// Visual style for [TransactionStatus].
enum TransactionStatusStyle {
  /// Full card with all details.
  card,

  /// Horizontal inline display.
  inline,

  /// Minimal icon + text only.
  minimal,

  /// Full-width banner style.
  banner,
}
