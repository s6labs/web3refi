import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/invoice.dart';
import '../core/invoice_status.dart';

/// Local storage for invoices
class InvoiceStorage {
  static const String _invoicesKey = 'web3refi_invoices';
  static const String _invoiceCounterKey = 'web3refi_invoice_counter';
  static const String _invoiceNumberCounterKey = 'web3refi_invoice_number_counter';

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  InvoiceStorage({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  // ═══════════════════════════════════════════════════════════════════════
  // CRUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Save invoice
  Future<void> saveInvoice(Invoice invoice) async {
    final invoices = await getAllInvoices();

    // Remove existing invoice with same ID
    invoices.removeWhere((i) => i.id == invoice.id);

    // Add updated invoice
    invoices.add(invoice);

    // Save to storage
    await _saveAllInvoices(invoices);
  }

  /// Get invoice by ID
  Future<Invoice?> getInvoice(String id) async {
    final invoices = await getAllInvoices();
    try {
      return invoices.firstWhere((i) => i.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get invoice by number
  Future<Invoice?> getInvoiceByNumber(String number) async {
    final invoices = await getAllInvoices();
    try {
      return invoices.firstWhere((i) => i.number == number);
    } catch (e) {
      return null;
    }
  }

  /// Get all invoices
  Future<List<Invoice>> getAllInvoices() async {
    final jsonString = _prefs.getString(_invoicesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => Invoice.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[InvoiceStorage] Error loading invoices: $e');
      return [];
    }
  }

  /// Delete invoice
  Future<void> deleteInvoice(String id) async {
    final invoices = await getAllInvoices();
    invoices.removeWhere((i) => i.id == id);
    await _saveAllInvoices(invoices);
  }

  /// Save all invoices
  Future<void> _saveAllInvoices(List<Invoice> invoices) async {
    final jsonList = invoices.map((i) => i.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_invoicesKey, jsonString);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // QUERY OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get invoices by status
  Future<List<Invoice>> getInvoicesByStatus(InvoiceStatus status) async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.status == status).toList();
  }

  /// Get invoices by sender
  Future<List<Invoice>> getInvoicesBySender(String address) async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.from.toLowerCase() == address.toLowerCase()).toList();
  }

  /// Get invoices by recipient
  Future<List<Invoice>> getInvoicesByRecipient(String address) async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.to.toLowerCase() == address.toLowerCase()).toList();
  }

  /// Get overdue invoices
  Future<List<Invoice>> getOverdueInvoices() async {
    final invoices = await getAllInvoices();
    final now = DateTime.now();
    return invoices.where((i) => i.dueDate.isBefore(now) && !i.isPaid).toList();
  }

  /// Get paid invoices
  Future<List<Invoice>> getPaidInvoices() async {
    return getInvoicesByStatus(InvoiceStatus.paid);
  }

  /// Get pending invoices
  Future<List<Invoice>> getPendingInvoices() async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.status.isPayable).toList();
  }

  /// Get draft invoices
  Future<List<Invoice>> getDraftInvoices() async {
    return getInvoicesByStatus(InvoiceStatus.draft);
  }

  /// Get recurring invoices
  Future<List<Invoice>> getRecurringInvoices() async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.isRecurring).toList();
  }

  /// Get factored invoices
  Future<List<Invoice>> getFactoredInvoices() async {
    final invoices = await getAllInvoices();
    return invoices.where((i) => i.isFactored).toList();
  }

  /// Search invoices
  Future<List<Invoice>> searchInvoices(String query) async {
    final invoices = await getAllInvoices();
    final lowerQuery = query.toLowerCase();

    return invoices.where((invoice) {
      return invoice.number.toLowerCase().contains(lowerQuery) ||
          invoice.title.toLowerCase().contains(lowerQuery) ||
          (invoice.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (invoice.toName?.toLowerCase().contains(lowerQuery) ?? false) ||
          (invoice.fromName?.toLowerCase().contains(lowerQuery) ?? false) ||
          invoice.to.toLowerCase().contains(lowerQuery) ||
          invoice.from.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get total invoice count
  Future<int> getTotalInvoiceCount() async {
    final invoices = await getAllInvoices();
    return invoices.length;
  }

  /// Get total amount billed
  Future<BigInt> getTotalAmountBilled() async {
    final invoices = await getAllInvoices();
    BigInt total = BigInt.zero;
    for (final invoice in invoices) {
      total += invoice.total;
    }
    return total;
  }

  /// Get total amount paid
  Future<BigInt> getTotalAmountPaid() async {
    final invoices = await getAllInvoices();
    BigInt total = BigInt.zero;
    for (final invoice in invoices) {
      total += invoice.paidAmount;
    }
    return total;
  }

  /// Get total amount outstanding
  Future<BigInt> getTotalAmountOutstanding() async {
    final invoices = await getAllInvoices();
    BigInt total = BigInt.zero;
    for (final invoice in invoices) {
      if (!invoice.isPaid) {
        total += invoice.remainingAmount;
      }
    }
    return total;
  }

  /// Get statistics
  Future<InvoiceStatistics> getStatistics() async {
    final invoices = await getAllInvoices();

    int draftCount = 0;
    int pendingCount = 0;
    int paidCount = 0;
    int overdueCount = 0;

    BigInt totalBilled = BigInt.zero;
    BigInt totalPaid = BigInt.zero;
    BigInt totalOutstanding = BigInt.zero;

    for (final invoice in invoices) {
      if (invoice.isDraft) draftCount++;
      if (invoice.status.isPayable) pendingCount++;
      if (invoice.isPaid) paidCount++;
      if (invoice.isOverdue) overdueCount++;

      totalBilled += invoice.total;
      totalPaid += invoice.paidAmount;
      if (!invoice.isPaid) {
        totalOutstanding += invoice.remainingAmount;
      }
    }

    return InvoiceStatistics(
      totalCount: invoices.length,
      draftCount: draftCount,
      pendingCount: pendingCount,
      paidCount: paidCount,
      overdueCount: overdueCount,
      totalBilled: totalBilled,
      totalPaid: totalPaid,
      totalOutstanding: totalOutstanding,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COUNTERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get next invoice counter
  Future<int> getNextInvoiceCounter() async {
    final counter = _prefs.getInt(_invoiceCounterKey) ?? 0;
    final nextCounter = counter + 1;
    await _prefs.setInt(_invoiceCounterKey, nextCounter);
    return nextCounter;
  }

  /// Get next invoice number counter
  Future<int> getNextInvoiceNumberCounter() async {
    final counter = _prefs.getInt(_invoiceNumberCounterKey) ?? 0;
    final nextCounter = counter + 1;
    await _prefs.setInt(_invoiceNumberCounterKey, nextCounter);
    return nextCounter;
  }

  /// Generate invoice number
  Future<String> generateInvoiceNumber({String prefix = 'INV', int? startingNumber}) async {
    final counter = await getNextInvoiceNumberCounter();
    final year = DateTime.now().year;
    final number = (startingNumber ?? 0) + counter;
    return '$prefix-$year-${number.toString().padLeft(4, '0')}';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SECURE STORAGE (for sensitive data)
  // ═══════════════════════════════════════════════════════════════════════

  /// Save sensitive invoice data securely
  Future<void> saveSensitiveData(String invoiceId, String key, String value) async {
    await _secureStorage.write(key: '${invoiceId}_$key', value: value);
  }

  /// Get sensitive invoice data
  Future<String?> getSensitiveData(String invoiceId, String key) async {
    return await _secureStorage.read(key: '${invoiceId}_$key');
  }

  /// Delete sensitive invoice data
  Future<void> deleteSensitiveData(String invoiceId, String key) async {
    await _secureStorage.delete(key: '${invoiceId}_$key');
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BULK OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Save multiple invoices
  Future<void> saveMultipleInvoices(List<Invoice> newInvoices) async {
    final existing = await getAllInvoices();

    // Create a map for quick lookup
    final Map<String, Invoice> invoiceMap = {
      for (var invoice in existing) invoice.id: invoice,
    };

    // Update or add new invoices
    for (final invoice in newInvoices) {
      invoiceMap[invoice.id] = invoice;
    }

    // Save all
    await _saveAllInvoices(invoiceMap.values.toList());
  }

  /// Delete multiple invoices
  Future<void> deleteMultipleInvoices(List<String> ids) async {
    final invoices = await getAllInvoices();
    invoices.removeWhere((i) => ids.contains(i.id));
    await _saveAllInvoices(invoices);
  }

  /// Clear all invoices
  Future<void> clearAll() async {
    await _prefs.remove(_invoicesKey);
    await _prefs.remove(_invoiceCounterKey);
    await _prefs.remove(_invoiceNumberCounterKey);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EXPORT/IMPORT
  // ═══════════════════════════════════════════════════════════════════════

  /// Export all invoices to JSON
  Future<String> exportToJson() async {
    final invoices = await getAllInvoices();
    final jsonList = invoices.map((i) => i.toJson()).toList();
    return jsonEncode(jsonList);
  }

  /// Import invoices from JSON
  Future<void> importFromJson(String jsonString) async {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    final invoices = jsonList.map((json) => Invoice.fromJson(json as Map<String, dynamic>)).toList();
    await saveMultipleInvoices(invoices);
  }
}

/// Invoice statistics
class InvoiceStatistics {
  final int totalCount;
  final int draftCount;
  final int pendingCount;
  final int paidCount;
  final int overdueCount;
  final BigInt totalBilled;
  final BigInt totalPaid;
  final BigInt totalOutstanding;

  const InvoiceStatistics({
    required this.totalCount,
    required this.draftCount,
    required this.pendingCount,
    required this.paidCount,
    required this.overdueCount,
    required this.totalBilled,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  @override
  String toString() {
    return 'InvoiceStatistics(total: $totalCount, draft: $draftCount, pending: $pendingCount, paid: $paidCount, overdue: $overdueCount)';
  }
}
