import 'package:flutter/material.dart';
import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';
import 'package:web3refi/src/invoice/manager/invoice_calculator.dart';

/// Compact status display card with progress indicator
class InvoiceStatusCard extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;
  final bool showProgress;
  final bool showActions;

  const InvoiceStatusCard({
    super.key,
    required this.invoice,
    this.onTap,
    this.showProgress = true,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _buildAmountInfo(),
              if (showProgress && !invoice.isPaid) ...[
                const SizedBox(height: 12),
                _buildProgressIndicator(),
              ],
              if (showActions) ...[
                const SizedBox(height: 12),
                _buildActions(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invoice.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Invoice #${invoice.number}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final statusInfo = _getStatusInfo();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusInfo.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusInfo.icon, size: 14, color: statusInfo.color),
          const SizedBox(width: 4),
          Text(
            statusInfo.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusInfo.color,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // AMOUNT INFO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAmountInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Amount',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                _formatAmount(invoice.total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (invoice.paidAmount > BigInt.zero && !invoice.isPaid) ...[
                const SizedBox(height: 4),
                Text(
                  'Paid: ${_formatAmount(invoice.paidAmount)}',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ],
          ),
        ),
        _buildDueDateInfo(),
      ],
    );
  }

  Widget _buildDueDateInfo() {
    final daysUntilDue = invoice.dueDate.difference(DateTime.now()).inDays;
    final isOverdue = invoice.isOverdue;

    Color color;
    IconData icon;
    String text;

    if (invoice.isPaid) {
      color = Colors.green;
      icon = Icons.check_circle;
      text = 'Paid';
    } else if (isOverdue) {
      color = Colors.red;
      icon = Icons.warning;
      text = '${invoice.daysOverdue}d overdue';
    } else if (daysUntilDue <= 3) {
      color = Colors.orange;
      icon = Icons.schedule;
      text = '${daysUntilDue}d left';
    } else {
      color = Colors.blue;
      icon = Icons.schedule;
      text = '${daysUntilDue}d left';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'Due Date',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _formatDate(invoice.dueDate),
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PROGRESS INDICATOR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildProgressIndicator() {
    final progress = invoice.paymentProgress;
    final statusInfo = _getStatusInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Payment Progress',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusInfo.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation(statusInfo.color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Remaining: ${_formatAmount(invoice.remainingAmount)}',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        if (!invoice.isPaid) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _handleAction(context, 'pay'),
              icon: const Icon(Icons.payment, size: 16),
              label: const Text('Pay'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleAction(context, 'view'),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('View'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.share, size: 20),
          onPressed: () => _handleAction(context, 'share'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  void _handleAction(BuildContext context, String action) {
    // Actions would be handled by parent widget
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$action action triggered')),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATUS INFO
  // ═══════════════════════════════════════════════════════════════════════

  _StatusInfo _getStatusInfo() {
    if (invoice.isPaid) {
      return _StatusInfo(
        label: 'PAID',
        color: Colors.green,
        icon: Icons.check_circle,
      );
    } else if (invoice.isOverdue) {
      return _StatusInfo(
        label: 'OVERDUE',
        color: Colors.red,
        icon: Icons.warning,
      );
    } else if (invoice.status == InvoiceStatus.cancelled) {
      return _StatusInfo(
        label: 'CANCELLED',
        color: Colors.grey,
        icon: Icons.cancel,
      );
    } else if (invoice.status == InvoiceStatus.disputed) {
      return _StatusInfo(
        label: 'DISPUTED',
        color: Colors.orange,
        icon: Icons.gavel,
      );
    } else if (invoice.status == InvoiceStatus.partiallyPaid) {
      return _StatusInfo(
        label: 'PARTIAL',
        color: Colors.amber,
        icon: Icons.pie_chart,
      );
    } else if (invoice.status == InvoiceStatus.sent) {
      return _StatusInfo(
        label: 'SENT',
        color: Colors.blue,
        icon: Icons.send,
      );
    } else if (invoice.status == InvoiceStatus.viewed) {
      return _StatusInfo(
        label: 'VIEWED',
        color: Colors.cyan,
        icon: Icons.visibility,
      );
    } else {
      return _StatusInfo(
        label: invoice.status.name.toUpperCase(),
        color: Colors.grey,
        icon: Icons.receipt,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(
      amount,
      symbol: invoice.currency,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Status information
class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  _StatusInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}
