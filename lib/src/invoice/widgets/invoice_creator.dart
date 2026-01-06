import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/invoice.dart';
import '../core/invoice_item.dart';
import '../core/payment_info.dart';
import '../core/invoice_status.dart';
import '../manager/invoice_manager.dart';
import '../manager/invoice_calculator.dart';

/// Multi-step invoice creation widget
class InvoiceCreator extends StatefulWidget {
  final InvoiceManager invoiceManager;
  final String fromAddress;
  final Function(Invoice)? onInvoiceCreated;
  final Function(String)? onError;

  const InvoiceCreator({
    Key? key,
    required this.invoiceManager,
    required this.fromAddress,
    this.onInvoiceCreated,
    this.onError,
  }) : super(key: key);

  @override
  State<InvoiceCreator> createState() => _InvoiceCreatorState();
}

class _InvoiceCreatorState extends State<InvoiceCreator> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isCreating = false;

  // Step 1: Basic Info
  final _titleController = TextEditingController();
  final _toController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCurrency = 'USDC';
  DateTime? _dueDate;

  // Step 2: Line Items
  final List<_InvoiceItemData> _items = [];

  // Step 3: Payment & Delivery
  InvoiceDeliveryMethod _deliveryMethod = InvoiceDeliveryMethod.both;
  InvoiceStorageBackend _storageBackend = InvoiceStorageBackend.ipfsWithLocal;
  final List<PaymentSplit> _paymentSplits = [];
  bool _enableSplitPayments = false;

  // Step 4: Advanced Options
  bool _enableRecurring = false;
  RecurringFrequency _recurringFrequency = RecurringFrequency.monthly;
  bool _enableAutoSend = false;
  double _taxRate = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _toController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () => setState(() => _currentStep--),
              child: const Text('Back'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          controlsBuilder: (context, details) {
            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  ElevatedButton(
                    onPressed: _isCreating ? null : details.onStepContinue,
                    child: _isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == 3 ? 'Create Invoice' : 'Continue'),
                  ),
                  const SizedBox(width: 8),
                  if (_currentStep > 0)
                    TextButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Back'),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Basic Information'),
              content: _buildBasicInfoStep(),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Line Items'),
              content: _buildLineItemsStep(),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Payment & Delivery'),
              content: _buildPaymentDeliveryStep(),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            ),
            Step(
              title: const Text('Advanced Options'),
              content: _buildAdvancedOptionsStep(),
              isActive: _currentStep >= 3,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 1: BASIC INFORMATION
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildBasicInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Invoice Title',
            hintText: 'e.g., Website Development Services',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _toController,
          decoration: const InputDecoration(
            labelText: 'Recipient',
            hintText: 'Address or name (e.g., alice.eth)',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a recipient';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            hintText: 'Additional details about this invoice',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCurrency,
          decoration: const InputDecoration(labelText: 'Currency'),
          items: ['USDC', 'USDT', 'DAI', 'ETH', 'MATIC']
              .map((currency) => DropdownMenuItem(
                    value: currency,
                    child: Text(currency),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedCurrency = value!),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due Date'),
          subtitle: Text(_dueDate?.toString().split(' ')[0] ?? 'Not set'),
          trailing: const Icon(Icons.calendar_today),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 30)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() => _dueDate = date);
            }
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 2: LINE ITEMS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildLineItemsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('No items added yet. Click the button below to add items.'),
          )
        else
          ..._items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(item.description),
                subtitle: Text('Qty: ${item.quantity} × ${_formatAmount(item.unitPrice)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatAmount(item.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => setState(() => _items.removeAt(index)),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _addLineItem,
          icon: const Icon(Icons.add),
          label: const Text('Add Item'),
        ),
        if (_items.isNotEmpty) ...[
          const Divider(height: 32),
          _buildTotalsSummary(),
        ],
      ],
    );
  }

  Widget _buildTotalsSummary() {
    final totals = InvoiceCalculator.calculateTotals(
      items: _items.map((data) => data.toInvoiceItem()).toList(),
      taxRate: _taxRate,
    );

    return Column(
      children: [
        _buildTotalRow('Subtotal:', totals.subtotal),
        if (totals.taxAmount > BigInt.zero)
          _buildTotalRow('Tax (${(_taxRate * 100).toStringAsFixed(1)}%):', totals.taxAmount),
        const Divider(),
        _buildTotalRow('Total:', totals.total, bold: true),
      ],
    );
  }

  Widget _buildTotalRow(String label, BigInt amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            _formatAmount(amount),
            style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }

  Future<void> _addLineItem() async {
    final descController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    final priceController = TextEditingController();

    final result = await showDialog<_InvoiceItemData>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Line Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: 'Unit Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (descController.text.isEmpty || priceController.text.isEmpty) {
                return;
              }
              final qty = int.tryParse(qtyController.text) ?? 1;
              final price = double.tryParse(priceController.text) ?? 0.0;
              final unitPrice = BigInt.from(price * 1e6); // Convert to smallest unit
              final total = unitPrice * BigInt.from(qty);

              Navigator.pop(
                context,
                _InvoiceItemData(
                  description: descController.text,
                  quantity: qty,
                  unitPrice: unitPrice,
                  total: total,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _items.add(result));
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 3: PAYMENT & DELIVERY
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPaymentDeliveryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Delivery Method', style: TextStyle(fontWeight: FontWeight.bold)),
        RadioListTile<InvoiceDeliveryMethod>(
          title: const Text('XMTP Only'),
          value: InvoiceDeliveryMethod.xmtp,
          groupValue: _deliveryMethod,
          onChanged: (value) => setState(() => _deliveryMethod = value!),
        ),
        RadioListTile<InvoiceDeliveryMethod>(
          title: const Text('Mailchain Only'),
          value: InvoiceDeliveryMethod.mailchain,
          groupValue: _deliveryMethod,
          onChanged: (value) => setState(() => _deliveryMethod = value!),
        ),
        RadioListTile<InvoiceDeliveryMethod>(
          title: const Text('Both (Recommended)'),
          value: InvoiceDeliveryMethod.both,
          groupValue: _deliveryMethod,
          onChanged: (value) => setState(() => _deliveryMethod = value!),
        ),
        const Divider(height: 32),
        const Text('Storage Backend', style: TextStyle(fontWeight: FontWeight.bold)),
        RadioListTile<InvoiceStorageBackend>(
          title: const Text('IPFS + Local'),
          subtitle: const Text('Decentralized with backup'),
          value: InvoiceStorageBackend.ipfsWithLocal,
          groupValue: _storageBackend,
          onChanged: (value) => setState(() => _storageBackend = value!),
        ),
        RadioListTile<InvoiceStorageBackend>(
          title: const Text('Arweave + Local'),
          subtitle: const Text('Permanent storage'),
          value: InvoiceStorageBackend.arweaveWithLocal,
          groupValue: _storageBackend,
          onChanged: (value) => setState(() => _storageBackend = value!),
        ),
        const Divider(height: 32),
        SwitchListTile(
          title: const Text('Enable Split Payments'),
          subtitle: const Text('Distribute payments to multiple recipients'),
          value: _enableSplitPayments,
          onChanged: (value) => setState(() => _enableSplitPayments = value),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 4: ADVANCED OPTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildAdvancedOptionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: const Text('Recurring Invoice'),
          subtitle: const Text('Create subscription billing'),
          value: _enableRecurring,
          onChanged: (value) => setState(() => _enableRecurring = value),
        ),
        if (_enableRecurring) ...[
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8),
            child: DropdownButtonFormField<RecurringFrequency>(
              value: _recurringFrequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: RecurringFrequency.values
                  .map((freq) => DropdownMenuItem(
                        value: freq,
                        child: Text(freq.name.toUpperCase()),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _recurringFrequency = value!),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SwitchListTile(
              title: const Text('Auto-send invoices'),
              value: _enableAutoSend,
              onChanged: (value) => setState(() => _enableAutoSend = value),
            ),
          ),
        ],
        const Divider(height: 32),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Tax Rate (%)',
            hintText: '0.0',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (value) {
            final rate = double.tryParse(value) ?? 0.0;
            setState(() => _taxRate = rate / 100);
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════

  void _onStepContinue() async {
    if (_currentStep == 0) {
      if (_formKey.currentState!.validate() && _dueDate != null) {
        setState(() => _currentStep++);
      } else if (_dueDate == null) {
        _showError('Please select a due date');
      }
    } else if (_currentStep == 1) {
      if (_items.isEmpty) {
        _showError('Please add at least one line item');
      } else {
        setState(() => _currentStep++);
      }
    } else if (_currentStep == 2) {
      setState(() => _currentStep++);
    } else if (_currentStep == 3) {
      await _createInvoice();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CREATE INVOICE
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _createInvoice() async {
    setState(() => _isCreating = true);

    try {
      final invoice = await widget.invoiceManager.createInvoice(
        to: _toController.text,
        title: _titleController.text,
        description: _descriptionController.text,
        items: _items.map((data) => data.toInvoiceItem()).toList(),
        currency: _selectedCurrency,
        dueDate: _dueDate!,
        deliveryMethod: _deliveryMethod,
        storageBackend: _storageBackend,
        taxRate: _taxRate > 0 ? _taxRate : null,
        paymentSplits: _enableSplitPayments ? _paymentSplits : null,
        recurringConfig: _enableRecurring
            ? RecurringConfig(
                frequency: _recurringFrequency,
                startDate: DateTime.now(),
                autoSend: _enableAutoSend,
              )
            : null,
      );

      widget.onInvoiceCreated?.call(invoice);

      if (mounted) {
        Navigator.pop(context, invoice);
      }
    } catch (e) {
      _showError(e.toString());
      widget.onError?.call(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _formatAmount(BigInt amount) {
    return InvoiceCalculator.formatAmount(
      amount,
      symbol: _selectedCurrency,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

/// Internal class for line item data
class _InvoiceItemData {
  final String description;
  final int quantity;
  final BigInt unitPrice;
  final BigInt total;

  _InvoiceItemData({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  InvoiceItem toInvoiceItem() {
    return InvoiceItem.create(
      description: description,
      quantity: quantity,
      unitPrice: unitPrice,
    );
  }
}
