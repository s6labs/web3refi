import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/invoice.dart';
import '../core/invoice_status.dart';
import '../manager/invoice_manager.dart';
import '../messaging/invoice_messenger.dart';

/// Manages recurring invoices (subscriptions)
class RecurringInvoiceManager extends ChangeNotifier {
  final InvoiceManager invoiceManager;
  final InvoiceMessenger? messenger;

  /// Timer for checking recurring invoices
  Timer? _recurringTimer;

  /// Active recurring templates
  final Map<String, Invoice> _recurringTemplates = {};

  RecurringInvoiceManager({
    required this.invoiceManager,
    this.messenger,
  }) {
    _startRecurringTimer();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RECURRING INVOICE CREATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Create recurring invoice template
  Future<Invoice> createRecurringTemplate({
    required Invoice baseInvoice,
    required RecurringConfig recurringConfig,
  }) async {
    // Validate recurring config
    if (!recurringConfig.isActive) {
      throw RecurringException('Recurring config is not active');
    }

    // Calculate next occurrence
    final nextOccurrence = recurringConfig.calculateNextOccurrence();

    // Create template
    final template = baseInvoice.copyWith(
      status: InvoiceStatus.template,
      isRecurring: true,
      recurringConfig: recurringConfig,
      nextOccurrence: nextOccurrence,
    );

    // Save template
    await invoiceManager.updateInvoice(template);

    // Cache template
    _recurringTemplates[template.id] = template;

    _log('Recurring template created: ${template.number}');

    notifyListeners();

    return template;
  }

  /// Generate invoice from recurring template
  Future<Invoice> generateFromTemplate({
    required String templateId,
    DateTime? dueDate,
    bool autoSend = false,
  }) async {
    final template = await _getTemplate(templateId);

    if (template.recurringConfig == null) {
      throw RecurringException('Template missing recurring config');
    }

    // Calculate due date
    final finalDueDate = dueDate ??
        DateTime.now().add(
          Duration(days: template.recurringConfig!.daysBeforeDue),
        );

    // Create invoice from template
    final invoice = await invoiceManager.createFromTemplate(
      template: template,
      to: template.to,
      dueDate: finalDueDate,
      overrides: {
        'recurringTemplateId': templateId,
      },
    );

    // Update template occurrence count
    final updatedConfig = template.recurringConfig!.copyWith(
      currentOccurrence: template.recurringConfig!.currentOccurrence + 1,
    );

    final updatedTemplate = template.copyWith(
      recurringConfig: updatedConfig,
      nextOccurrence: updatedConfig.calculateNextOccurrence(),
    );

    await invoiceManager.updateInvoice(updatedTemplate);
    _recurringTemplates[templateId] = updatedTemplate;

    // Auto-send if configured
    if (autoSend || template.recurringConfig!.autoSend) {
      await _sendInvoice(invoice);
    }

    _log('Invoice generated from template: ${invoice.number}');

    notifyListeners();

    return invoice;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // RECURRING TIMER
  // ═══════════════════════════════════════════════════════════════════════

  /// Start recurring invoice timer
  void _startRecurringTimer() {
    _recurringTimer?.cancel();

    // Check every hour
    _recurringTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) => _processRecurringInvoices(),
    );

    // Run immediately
    _processRecurringInvoices();
  }

  /// Process all recurring invoices
  Future<void> _processRecurringInvoices() async {
    try {
      final templates = await getActiveRecurringTemplates();
      final now = DateTime.now();

      for (final template in templates) {
        if (template.nextOccurrence != null &&
            now.isAfter(template.nextOccurrence!)) {
          try {
            await generateFromTemplate(
              templateId: template.id,
              autoSend: template.recurringConfig?.autoSend ?? false,
            );
          } catch (e) {
            _log('Error generating invoice from template ${template.id}: $e');
          }
        }
      }
    } catch (e) {
      _log('Error processing recurring invoices: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TEMPLATE MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Get recurring template
  Future<Invoice> _getTemplate(String templateId) async {
    // Check cache
    if (_recurringTemplates.containsKey(templateId)) {
      return _recurringTemplates[templateId]!;
    }

    // Load from storage
    final template = await invoiceManager.getInvoice(templateId);
    if (template == null) {
      throw RecurringException('Template not found: $templateId');
    }

    if (!template.isRecurring) {
      throw RecurringException('Invoice is not a recurring template');
    }

    // Cache
    _recurringTemplates[templateId] = template;

    return template;
  }

  /// Get all active recurring templates
  Future<List<Invoice>> getActiveRecurringTemplates() async {
    final allInvoices = await invoiceManager.getAllInvoices();

    return allInvoices.where((invoice) {
      return invoice.isRecurring &&
          invoice.status == InvoiceStatus.template &&
          invoice.recurringConfig != null &&
          invoice.recurringConfig!.isActive;
    }).toList();
  }

  /// Get invoices generated from template
  Future<List<Invoice>> getInvoicesFromTemplate(String templateId) async {
    final allInvoices = await invoiceManager.getAllInvoices();

    return allInvoices.where((invoice) {
      return invoice.recurringTemplateId == templateId;
    }).toList();
  }

  /// Update recurring template
  Future<Invoice> updateTemplate({
    required String templateId,
    RecurringConfig? recurringConfig,
    Map<String, dynamic>? updates,
  }) async {
    final template = await _getTemplate(templateId);

    final updated = template.copyWith(
      recurringConfig: recurringConfig ?? template.recurringConfig,
      // Apply other updates
    );

    await invoiceManager.updateInvoice(updated);
    _recurringTemplates[templateId] = updated;

    notifyListeners();

    return updated;
  }

  /// Pause recurring template
  Future<Invoice> pauseTemplate(String templateId) async {
    final template = await _getTemplate(templateId);

    if (template.recurringConfig == null) {
      throw RecurringException('Template has no recurring config');
    }

    // Set end date to now (effectively pausing)
    final pausedConfig = template.recurringConfig!.copyWith(
      endDate: DateTime.now(),
    );

    final updated = template.copyWith(recurringConfig: pausedConfig);

    await invoiceManager.updateInvoice(updated);
    _recurringTemplates[templateId] = updated;

    _log('Template paused: ${template.number}');

    notifyListeners();

    return updated;
  }

  /// Resume recurring template
  Future<Invoice> resumeTemplate(String templateId) async {
    final template = await _getTemplate(templateId);

    if (template.recurringConfig == null) {
      throw RecurringException('Template has no recurring config');
    }

    // Clear end date
    final resumedConfig = template.recurringConfig!.copyWith(
      endDate: null,
    );

    final updated = template.copyWith(
      recurringConfig: resumedConfig,
      nextOccurrence: resumedConfig.calculateNextOccurrence(),
    );

    await invoiceManager.updateInvoice(updated);
    _recurringTemplates[templateId] = updated;

    _log('Template resumed: ${template.number}');

    notifyListeners();

    return updated;
  }

  /// Cancel recurring template
  Future<void> cancelTemplate(String templateId) async {
    final template = await _getTemplate(templateId);

    final cancelled = template.copyWith(
      status: InvoiceStatus.cancelled,
    );

    await invoiceManager.updateInvoice(cancelled);
    _recurringTemplates.remove(templateId);

    _log('Template cancelled: ${template.number}');

    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATISTICS
  // ═══════════════════════════════════════════════════════════════════════

  /// Get recurring statistics for template
  Future<RecurringStatistics> getTemplateStatistics(String templateId) async {
    final invoices = await getInvoicesFromTemplate(templateId);

    int totalGenerated = invoices.length;
    int paid = 0;
    int pending = 0;
    int overdue = 0;
    BigInt totalBilled = BigInt.zero;
    BigInt totalPaid = BigInt.zero;

    for (final invoice in invoices) {
      if (invoice.isPaid) {
        paid++;
        totalPaid += invoice.total;
      } else if (invoice.isOverdue) {
        overdue++;
      } else if (invoice.status.isPayable) {
        pending++;
      }

      totalBilled += invoice.total;
    }

    return RecurringStatistics(
      templateId: templateId,
      totalGenerated: totalGenerated,
      paidCount: paid,
      pendingCount: pending,
      overdueCount: overdue,
      totalBilled: totalBilled,
      totalPaid: totalPaid,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Send invoice
  Future<void> _sendInvoice(Invoice invoice) async {
    if (messenger == null) return;

    try {
      await messenger!.sendInvoice(
        invoice: invoice,
        deliveryMethod: InvoiceDeliveryMethod.both,
      );

      await invoiceManager.markAsSent(invoice.id);
    } catch (e) {
      _log('Failed to send invoice: $e');
    }
  }

  /// Clear template cache
  void clearCache() {
    _recurringTemplates.clear();
    notifyListeners();
  }

  void _log(String message) {
    debugPrint('[RecurringInvoiceManager] $message');
  }

  @override
  void dispose() {
    _recurringTimer?.cancel();
    super.dispose();
  }
}

/// Recurring invoice statistics
class RecurringStatistics {
  final String templateId;
  final int totalGenerated;
  final int paidCount;
  final int pendingCount;
  final int overdueCount;
  final BigInt totalBilled;
  final BigInt totalPaid;

  RecurringStatistics({
    required this.templateId,
    required this.totalGenerated,
    required this.paidCount,
    required this.pendingCount,
    required this.overdueCount,
    required this.totalBilled,
    required this.totalPaid,
  });

  double get paymentRate {
    if (totalGenerated == 0) return 0.0;
    return paidCount / totalGenerated;
  }

  BigInt get totalOutstanding => totalBilled - totalPaid;

  @override
  String toString() {
    return 'RecurringStatistics(generated: $totalGenerated, paid: $paidCount, pending: $pendingCount, overdue: $overdueCount)';
  }
}

/// Recurring exception
class RecurringException implements Exception {
  final String message;

  RecurringException(this.message);

  @override
  String toString() => 'RecurringException: $message';
}

/// Extension on RecurringConfig for copying
extension RecurringConfigCopyWith on RecurringConfig {
  RecurringConfig copyWith({
    RecurringFrequency? frequency,
    Duration? customInterval,
    DateTime? startDate,
    DateTime? endDate,
    int? maxOccurrences,
    int? currentOccurrence,
    bool? autoSend,
    bool? autoCharge,
    int? daysBeforeDue,
  }) {
    return RecurringConfig(
      frequency: frequency ?? this.frequency,
      customInterval: customInterval ?? this.customInterval,
      startDate: startDate ?? this.startDate,
      endDate: endDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      currentOccurrence: currentOccurrence ?? this.currentOccurrence,
      autoSend: autoSend ?? this.autoSend,
      autoCharge: autoCharge ?? this.autoCharge,
      daysBeforeDue: daysBeforeDue ?? this.daysBeforeDue,
    );
  }
}
