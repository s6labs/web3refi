import 'package:flutter/material.dart';
import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';
import 'package:web3refi/src/invoice/advanced/recurring_invoice_manager.dart';
import 'package:web3refi/src/invoice/manager/invoice_calculator.dart';

/// Pick recurring invoice templates
class InvoiceTemplateSelector extends StatefulWidget {
  final RecurringInvoiceManager recurringManager;
  final Function(Invoice)? onTemplateSelected;
  final Function(Invoice)? onGenerateFromTemplate;
  final bool showCreateButton;

  const InvoiceTemplateSelector({
    super.key,
    required this.recurringManager,
    this.onTemplateSelected,
    this.onGenerateFromTemplate,
    this.showCreateButton = true,
  });

  @override
  State<InvoiceTemplateSelector> createState() =>
      _InvoiceTemplateSelectorState();
}

class _InvoiceTemplateSelectorState extends State<InvoiceTemplateSelector> {
  List<Invoice> _templates = [];
  Map<String, RecurringStatistics> _statistics = {};
  bool _isLoading = true;
  bool _showOnlyActive = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);

    try {
      final templates = await widget.recurringManager.getActiveRecurringTemplates();

      // Load statistics for each template
      final stats = <String, RecurringStatistics>{};
      for (final template in templates) {
        try {
          final stat = await widget.recurringManager.getTemplateStatistics(template.id);
          stats[template.id] = stat;
        } catch (e) {
          debugPrint('Failed to load stats for ${template.id}: $e');
        }
      }

      setState(() {
        _templates = templates;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load templates: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Invoice Templates'),
        actions: [
          IconButton(
            icon: Icon(_showOnlyActive ? Icons.filter_alt : Icons.filter_alt_off),
            onPressed: () {
              setState(() => _showOnlyActive = !_showOnlyActive);
              _loadTemplates();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : _buildTemplateList(),
      floatingActionButton: widget.showCreateButton
          ? FloatingActionButton(
              onPressed: _createTemplate,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMPLATE LIST
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTemplateList() {
    return RefreshIndicator(
      onRefresh: _loadTemplates,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _templates.length,
        itemBuilder: (context, index) {
          final template = _templates[index];
          final stats = _statistics[template.id];
          return _buildTemplateCard(template, stats);
        },
      ),
    );
  }

  Widget _buildTemplateCard(Invoice template, RecurringStatistics? stats) {
    final config = template.recurringConfig!;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => widget.onTemplateSelected?.call(template),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTemplateHeader(template),
              const SizedBox(height: 12),
              _buildRecurringInfo(config),
              const SizedBox(height: 12),
              _buildNextOccurrence(template),
              if (stats != null) ...[
                const Divider(height: 24),
                _buildStatistics(stats),
              ],
              const SizedBox(height: 12),
              _buildActions(template),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMPLATE HEADER
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildTemplateHeader(Invoice template) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                template.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Template #${template.number}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatAmount(template.total),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(
              template.currency,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RECURRING INFO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildRecurringInfo(RecurringConfig config) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.repeat, color: Colors.purple, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getFrequencyLabel(config.frequency),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
                if (config.maxOccurrences != null)
                  Text(
                    '${config.currentOccurrence}/${config.maxOccurrences} occurrences',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          if (config.autoSend)
            const Chip(
              label: Text('Auto-send', style: TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEXT OCCURRENCE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildNextOccurrence(Invoice template) {
    if (template.nextOccurrence == null) {
      return const SizedBox.shrink();
    }

    final daysUntilNext = template.nextOccurrence!.difference(DateTime.now()).inDays;
    final isPastDue = daysUntilNext < 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPastDue
            ? Colors.red.withOpacity(0.1)
            : Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.schedule,
            color: isPastDue ? Colors.red : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Invoice',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  _formatDate(template.nextOccurrence!),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isPastDue ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          if (isPastDue)
            const Chip(
              label: Text('Due now', style: TextStyle(fontSize: 11)),
              backgroundColor: Colors.red,
              labelStyle: TextStyle(color: Colors.white),
              visualDensity: VisualDensity.compact,
            )
          else
            Text(
              'in ${daysUntilNext}d',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildStatistics(RecurringStatistics stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            'Generated',
            stats.totalGenerated.toString(),
            Icons.receipt_long,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Paid',
            stats.paidCount.toString(),
            Icons.check_circle,
            color: Colors.green,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Pending',
            stats.pendingCount.toString(),
            Icons.pending,
            color: Colors.orange,
          ),
        ),
        Expanded(
          child: _buildStatItem(
            'Rate',
            '${(stats.paymentRate * 100).toStringAsFixed(0)}%',
            Icons.trending_up,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildActions(Invoice template) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _generateNow(template),
            icon: const Icon(Icons.add_circle, size: 16),
            label: const Text('Generate Now'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.pause_circle),
          onPressed: () => _pauseTemplate(template),
          tooltip: 'Pause',
        ),
        IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => _editTemplate(template),
          tooltip: 'Edit',
        ),
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showTemplateMenu(template),
          tooltip: 'More',
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No recurring templates yet',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a template to set up subscription billing',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          if (widget.showCreateButton) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createTemplate,
              icon: const Icon(Icons.add),
              label: const Text('Create Template'),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _generateNow(Invoice template) async {
    try {
      final invoice = await widget.recurringManager.generateFromTemplate(
        templateId: template.id,
        autoSend: true,
      );

      widget.onGenerateFromTemplate?.call(invoice);
      _showSuccess('Invoice generated: ${invoice.number}');
      _loadTemplates();
    } catch (e) {
      _showError('Failed to generate invoice: $e');
    }
  }

  Future<void> _pauseTemplate(Invoice template) async {
    try {
      await widget.recurringManager.pauseTemplate(template.id);
      _showSuccess('Template paused');
      _loadTemplates();
    } catch (e) {
      _showError('Failed to pause template: $e');
    }
  }

  void _editTemplate(Invoice template) {
    _showError('Edit template not implemented yet');
  }

  void _showTemplateMenu(Invoice template) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.visibility),
            title: const Text('View Invoices'),
            onTap: () {
              Navigator.pop(context);
              _viewInvoicesFromTemplate(template);
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('View Statistics'),
            onTap: () {
              Navigator.pop(context);
              _viewStatistics(template);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Cancel Template'),
            onTap: () {
              Navigator.pop(context);
              _cancelTemplate(template);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _viewInvoicesFromTemplate(Invoice template) async {
    _showError('View invoices not implemented yet');
  }

  Future<void> _viewStatistics(Invoice template) async {
    final stats = _statistics[template.id];
    if (stats == null) {
      _showError('Statistics not available');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Statistics - ${template.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Generated', stats.totalGenerated.toString()),
            _buildStatRow('Paid', stats.paidCount.toString()),
            _buildStatRow('Pending', stats.pendingCount.toString()),
            _buildStatRow('Overdue', stats.overdueCount.toString()),
            const Divider(),
            _buildStatRow('Total Billed', _formatAmount(stats.totalBilled)),
            _buildStatRow('Total Paid', _formatAmount(stats.totalPaid)),
            _buildStatRow('Outstanding', _formatAmount(stats.totalOutstanding)),
            const Divider(),
            _buildStatRow(
              'Payment Rate',
              '${(stats.paymentRate * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _cancelTemplate(Invoice template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Template'),
        content: Text('Are you sure you want to cancel "${template.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.recurringManager.cancelTemplate(template.id);
        _showSuccess('Template cancelled');
        _loadTemplates();
      } catch (e) {
        _showError('Failed to cancel template: $e');
      }
    }
  }

  void _createTemplate() {
    _showError('Create template not implemented in this context');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _getFrequencyLabel(RecurringFrequency frequency) {
    switch (frequency) {
      case RecurringFrequency.daily:
        return 'Daily';
      case RecurringFrequency.weekly:
        return 'Weekly';
      case RecurringFrequency.biweekly:
        return 'Bi-weekly';
      case RecurringFrequency.monthly:
        return 'Monthly';
      case RecurringFrequency.quarterly:
        return 'Quarterly';
      case RecurringFrequency.semiannually:
        return 'Semi-annually';
      case RecurringFrequency.annually:
        return 'Annually';
      case RecurringFrequency.custom:
        return 'Custom';
    }
  }

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(amount);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
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
