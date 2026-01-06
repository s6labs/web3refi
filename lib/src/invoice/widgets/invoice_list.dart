import 'package:flutter/material.dart';
import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';
import 'package:web3refi/src/invoice/manager/invoice_manager.dart';
import 'package:web3refi/src/invoice/manager/invoice_calculator.dart';
import 'package:web3refi/src/invoice/widgets/invoice_viewer.dart';

/// Filterable list of invoices with search and sorting
class InvoiceList extends StatefulWidget {
  final InvoiceManager invoiceManager;
  final String? userAddress;
  final InvoiceListMode mode;
  final Function(Invoice)? onInvoiceTap;
  final bool showCreateButton;

  const InvoiceList({
    required this.invoiceManager, super.key,
    this.userAddress,
    this.mode = InvoiceListMode.all,
    this.onInvoiceTap,
    this.showCreateButton = true,
  });

  @override
  State<InvoiceList> createState() => _InvoiceListState();
}

class _InvoiceListState extends State<InvoiceList> {
  final _searchController = TextEditingController();
  List<Invoice> _invoices = [];
  List<Invoice> _filteredInvoices = [];
  bool _isLoading = true;
  InvoiceStatus? _filterStatus;
  InvoiceSortBy _sortBy = InvoiceSortBy.dateDesc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      List<Invoice> invoices;

      switch (widget.mode) {
        case InvoiceListMode.all:
          invoices = await widget.invoiceManager.getAllInvoices();
          break;
        case InvoiceListMode.sent:
          if (widget.userAddress == null) {
            invoices = [];
          } else {
            invoices = await widget.invoiceManager.getInvoicesBySender(
              widget.userAddress!,
            );
          }
          break;
        case InvoiceListMode.received:
          if (widget.userAddress == null) {
            invoices = [];
          } else {
            invoices = await widget.invoiceManager.getInvoicesByRecipient(
              widget.userAddress!,
            );
          }
          break;
      }

      setState(() {
        _invoices = invoices;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Failed to load invoices: $e');
    }
  }

  void _applyFilters() {
    var filtered = List<Invoice>.from(_invoices);

    // Apply status filter
    if (_filterStatus != null) {
      filtered = filtered.where((inv) => inv.status == _filterStatus).toList();
    }

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((inv) {
        return inv.number.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            inv.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (inv.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      }).toList();
    }

    // Apply sorting
    switch (_sortBy) {
      case InvoiceSortBy.dateDesc:
        filtered.sort((a, b) => b.issueDate.compareTo(a.issueDate));
        break;
      case InvoiceSortBy.dateAsc:
        filtered.sort((a, b) => a.issueDate.compareTo(b.issueDate));
        break;
      case InvoiceSortBy.amountDesc:
        filtered.sort((a, b) => b.total.compareTo(a.total));
        break;
      case InvoiceSortBy.amountAsc:
        filtered.sort((a, b) => a.total.compareTo(b.total));
        break;
      case InvoiceSortBy.dueDate:
        filtered.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case InvoiceSortBy.status:
        filtered.sort((a, b) => a.status.index.compareTo(b.status.index));
        break;
    }

    setState(() => _filteredInvoices = filtered);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? _buildEmptyState()
                    : _buildInvoiceList(),
          ),
        ],
      ),
      floatingActionButton: widget.showCreateButton
          ? FloatingActionButton(
              onPressed: _createInvoice,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search invoices...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _applyFilters();
                    });
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FILTER CHIPS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFilterChips() {
    if (_filterStatus == null && _sortBy == InvoiceSortBy.dateDesc) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (_filterStatus != null)
            Chip(
              label: Text('Status: ${_filterStatus!.name}'),
              onDeleted: () {
                setState(() {
                  _filterStatus = null;
                  _applyFilters();
                });
              },
            ),
          if (_sortBy != InvoiceSortBy.dateDesc) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('Sort: ${_getSortLabel(_sortBy)}'),
              onDeleted: () {
                setState(() {
                  _sortBy = InvoiceSortBy.dateDesc;
                  _applyFilters();
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INVOICE LIST
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildInvoiceList() {
    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredInvoices.length,
        itemBuilder: (context, index) {
          final invoice = _filteredInvoices[index];
          return _buildInvoiceCard(invoice);
        },
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _openInvoice(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  _buildStatusBadge(invoice),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoRow(
                      Icons.person,
                      _getPartyLabel(invoice),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoRow(
                      Icons.calendar_today,
                      _formatDate(invoice.dueDate),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (invoice.isRecurring)
                    const Chip(
                      avatar: Icon(Icons.repeat, size: 16),
                      label: Text('Recurring', style: TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (invoice.isFactored)
                    const Chip(
                      avatar: Icon(Icons.sell, size: 16),
                      label: Text('Factored', style: TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    ),
                  const Spacer(),
                  Text(
                    _formatAmount(invoice.remainingAmount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: invoice.isPaid
                          ? Colors.green
                          : invoice.isOverdue
                              ? Colors.red
                              : null,
                    ),
                  ),
                ],
              ),
              if (!invoice.isPaid && invoice.paidAmount > BigInt.zero) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: invoice.paymentProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation(Colors.blue),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(invoice.paymentProgress * 100).toStringAsFixed(1)}% paid',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Invoice invoice) {
    Color color;
    String label;
    IconData icon;

    if (invoice.isPaid) {
      color = Colors.green;
      label = 'PAID';
      icon = Icons.check_circle;
    } else if (invoice.isOverdue) {
      color = Colors.red;
      label = 'OVERDUE';
      icon = Icons.warning;
    } else if (invoice.status == InvoiceStatus.cancelled) {
      color = Colors.grey;
      label = 'CANCELLED';
      icon = Icons.cancel;
    } else if (invoice.status == InvoiceStatus.disputed) {
      color = Colors.orange;
      label = 'DISPUTED';
      icon = Icons.gavel;
    } else {
      color = Colors.blue;
      label = invoice.status.name.toUpperCase();
      icon = Icons.receipt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
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
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          if (widget.showCreateButton) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _createInvoice,
              icon: const Icon(Icons.add),
              label: const Text('Create Invoice'),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<InvoiceStatus?>(
              title: const Text('All'),
              value: null,
              groupValue: _filterStatus,
              onChanged: (value) {
                setState(() => _filterStatus = value);
                Navigator.pop(context);
                _applyFilters();
              },
            ),
            ...InvoiceStatus.values.map((status) {
              return RadioListTile<InvoiceStatus?>(
                title: Text(status.name.toUpperCase()),
                value: status,
                groupValue: _filterStatus,
                onChanged: (value) {
                  setState(() => _filterStatus = value);
                  Navigator.pop(context);
                  _applyFilters();
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort by'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: InvoiceSortBy.values.map((sortBy) {
            return RadioListTile<InvoiceSortBy>(
              title: Text(_getSortLabel(sortBy)),
              value: sortBy,
              groupValue: _sortBy,
              onChanged: (value) {
                setState(() => _sortBy = value!);
                Navigator.pop(context);
                _applyFilters();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

  void _openInvoice(Invoice invoice) {
    if (widget.onInvoiceTap != null) {
      widget.onInvoiceTap!(invoice);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InvoiceViewer(
            invoice: invoice,
            invoiceManager: widget.invoiceManager,
          ),
        ),
      );
    }
  }

  void _createInvoice() {
    // Navigate to invoice creator
    _showError('Invoice creator not implemented in this context');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _getTitle() {
    switch (widget.mode) {
      case InvoiceListMode.all:
        return 'All Invoices';
      case InvoiceListMode.sent:
        return 'Sent Invoices';
      case InvoiceListMode.received:
        return 'Received Invoices';
    }
  }

  String _getEmptyMessage() {
    if (_searchQuery.isNotEmpty) {
      return 'No invoices match your search';
    }
    switch (widget.mode) {
      case InvoiceListMode.all:
        return 'No invoices yet\nCreate your first invoice to get started';
      case InvoiceListMode.sent:
        return 'You haven\'t sent any invoices yet';
      case InvoiceListMode.received:
        return 'You haven\'t received any invoices yet';
    }
  }

  String _getPartyLabel(Invoice invoice) {
    switch (widget.mode) {
      case InvoiceListMode.sent:
        return 'To: ${invoice.toName ?? _shortenAddress(invoice.to)}';
      case InvoiceListMode.received:
        return 'From: ${invoice.fromName ?? _shortenAddress(invoice.from)}';
      case InvoiceListMode.all:
        if (widget.userAddress != null &&
            invoice.from.toLowerCase() == widget.userAddress!.toLowerCase()) {
          return 'To: ${invoice.toName ?? _shortenAddress(invoice.to)}';
        }
        return 'From: ${invoice.fromName ?? _shortenAddress(invoice.from)}';
    }
  }

  String _getSortLabel(InvoiceSortBy sortBy) {
    switch (sortBy) {
      case InvoiceSortBy.dateDesc:
        return 'Date (Newest)';
      case InvoiceSortBy.dateAsc:
        return 'Date (Oldest)';
      case InvoiceSortBy.amountDesc:
        return 'Amount (High to Low)';
      case InvoiceSortBy.amountAsc:
        return 'Amount (Low to High)';
      case InvoiceSortBy.dueDate:
        return 'Due Date';
      case InvoiceSortBy.status:
        return 'Status';
    }
  }

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(amount);
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Invoice list display mode
enum InvoiceListMode {
  all,
  sent,
  received,
}

/// Invoice sorting options
enum InvoiceSortBy {
  dateDesc,
  dateAsc,
  amountDesc,
  amountAsc,
  dueDate,
  status,
}
