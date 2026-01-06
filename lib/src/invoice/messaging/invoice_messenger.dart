import 'dart:convert';
import '../core/invoice.dart';
import '../core/invoice_status.dart';
import '../../messaging/xmtp/xmtp_client.dart';
import '../../messaging/mailchain/mailchain_client.dart';
import '../../names/universal_name_service.dart';
import 'invoice_formatter.dart';

/// Handles sending invoices via XMTP and Mailchain
class InvoiceMessenger {
  final XMTPClient? xmtpClient;
  final MailchainClient? mailchainClient;
  final UniversalNameService? nameService;
  final InvoiceFormatter formatter;

  InvoiceMessenger({
    this.xmtpClient,
    this.mailchainClient,
    this.nameService,
    InvoiceFormatter? formatter,
  }) : formatter = formatter ?? InvoiceFormatter();

  // ═══════════════════════════════════════════════════════════════════════
  // SEND INVOICE
  // ═══════════════════════════════════════════════════════════════════════

  /// Send invoice via specified delivery method
  Future<InvoiceDeliveryResult> sendInvoice({
    required Invoice invoice,
    required InvoiceDeliveryMethod deliveryMethod,
    String? customMessage,
    bool includePaymentLink = true,
  }) async {
    final results = <String, dynamic>{};

    switch (deliveryMethod) {
      case InvoiceDeliveryMethod.xmtp:
        final xmtpResult = await _sendViaXMTP(invoice, customMessage, includePaymentLink);
        results['xmtp'] = xmtpResult;
        break;

      case InvoiceDeliveryMethod.mailchain:
        final mailchainResult = await _sendViaMailchain(invoice, customMessage, includePaymentLink);
        results['mailchain'] = mailchainResult;
        break;

      case InvoiceDeliveryMethod.both:
        final xmtpResult = await _sendViaXMTP(invoice, customMessage, includePaymentLink);
        final mailchainResult = await _sendViaMailchain(invoice, customMessage, includePaymentLink);
        results['xmtp'] = xmtpResult;
        results['mailchain'] = mailchainResult;
        break;

      case InvoiceDeliveryMethod.local:
        // No delivery, just return success
        break;
    }

    return InvoiceDeliveryResult(
      success: true,
      deliveryMethod: deliveryMethod,
      xmtpMessageId: results['xmtp']?['messageId'],
      mailchainMessageId: results['mailchain']?['messageId'],
    );
  }

  /// Send invoice via XMTP
  Future<Map<String, dynamic>> _sendViaXMTP(
    Invoice invoice,
    String? customMessage,
    bool includePaymentLink,
  ) async {
    if (xmtpClient == null) {
      throw InvoiceMessengerException('XMTP client not configured');
    }

    if (!xmtpClient!.isInitialized) {
      await xmtpClient!.initialize();
    }

    // Check if recipient can receive XMTP
    final canMessage = await xmtpClient!.canMessage(invoice.to);
    if (!canMessage) {
      throw InvoiceMessengerException('Recipient cannot receive XMTP messages: ${invoice.to}');
    }

    // Format message
    final content = formatter.formatXMTPMessage(
      invoice: invoice,
      customMessage: customMessage,
      includePaymentLink: includePaymentLink,
    );

    // Send message
    final message = await xmtpClient!.sendMessage(
      recipient: invoice.to,
      content: content,
    );

    return {
      'success': true,
      'messageId': message.id,
      'timestamp': message.sentAt.toIso8601String(),
    };
  }

  /// Send invoice via Mailchain
  Future<Map<String, dynamic>> _sendViaMailchain(
    Invoice invoice,
    String? customMessage,
    bool includePaymentLink,
  ) async {
    if (mailchainClient == null) {
      throw InvoiceMessengerException('Mailchain client not configured');
    }

    if (!mailchainClient!.isAuthenticated) {
      await mailchainClient!.initialize();
    }

    // Format email
    final subject = formatter.formatEmailSubject(invoice);
    final body = formatter.formatEmailBody(
      invoice: invoice,
      customMessage: customMessage,
      includePaymentLink: includePaymentLink,
    );

    // Format recipient address
    final recipientEmail = mailchainClient!.formatAddress(invoice.to);

    // Send email
    final result = await mailchainClient!.sendMail(
      to: recipientEmail,
      subject: subject,
      body: body,
      isHtml: true,
    );

    return {
      'success': result.success,
      'messageId': result.messageId,
      'timestamp': result.timestamp.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SEND NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Send payment confirmation to sender
  Future<void> sendPaymentConfirmation({
    required Invoice invoice,
    required String txHash,
    required BigInt amount,
  }) async {
    if (xmtpClient == null) return;

    try {
      final message = formatter.formatPaymentConfirmation(
        invoice: invoice,
        txHash: txHash,
        amount: amount,
      );

      await xmtpClient!.sendMessage(
        recipient: invoice.from,
        content: message,
      );
    } catch (e) {
      print('[InvoiceMessenger] Failed to send payment confirmation: $e');
    }
  }

  /// Send payment reminder
  Future<void> sendPaymentReminder({
    required Invoice invoice,
    int daysUntilDue = 0,
  }) async {
    final message = formatter.formatPaymentReminder(
      invoice: invoice,
      daysUntilDue: daysUntilDue,
    );

    // Try XMTP first
    if (xmtpClient != null && xmtpClient!.isInitialized) {
      try {
        await xmtpClient!.sendMessage(
          recipient: invoice.to,
          content: message,
        );
        return;
      } catch (e) {
        print('[InvoiceMessenger] XMTP reminder failed: $e');
      }
    }

    // Fallback to Mailchain
    if (mailchainClient != null && mailchainClient!.isAuthenticated) {
      try {
        await mailchainClient!.sendMail(
          to: mailchainClient!.formatAddress(invoice.to),
          subject: 'Payment Reminder: Invoice ${invoice.number}',
          body: message,
        );
      } catch (e) {
        print('[InvoiceMessenger] Mailchain reminder failed: $e');
      }
    }
  }

  /// Send overdue notice
  Future<void> sendOverdueNotice({
    required Invoice invoice,
    int daysOverdue = 0,
  }) async {
    final message = formatter.formatOverdueNotice(
      invoice: invoice,
      daysOverdue: daysOverdue,
    );

    // Send via both channels for overdue notices
    if (xmtpClient != null && xmtpClient!.isInitialized) {
      try {
        await xmtpClient!.sendMessage(
          recipient: invoice.to,
          content: message,
        );
      } catch (e) {
        print('[InvoiceMessenger] XMTP overdue notice failed: $e');
      }
    }

    if (mailchainClient != null && mailchainClient!.isAuthenticated) {
      try {
        await mailchainClient!.sendMail(
          to: mailchainClient!.formatAddress(invoice.to),
          subject: 'OVERDUE: Invoice ${invoice.number}',
          body: message,
          isHtml: true,
        );
      } catch (e) {
        print('[InvoiceMessenger] Mailchain overdue notice failed: $e');
      }
    }
  }

  /// Send invoice viewed notification to sender
  Future<void> sendViewedNotification({
    required Invoice invoice,
  }) async {
    if (xmtpClient == null || !xmtpClient!.isInitialized) return;

    try {
      final message = '📧 Your invoice ${invoice.number} has been viewed by ${invoice.toName ?? invoice.to}';

      await xmtpClient!.sendMessage(
        recipient: invoice.from,
        content: message,
      );
    } catch (e) {
      print('[InvoiceMessenger] Failed to send viewed notification: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BULK OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════

  /// Send multiple invoices
  Future<List<InvoiceDeliveryResult>> sendMultipleInvoices({
    required List<Invoice> invoices,
    required InvoiceDeliveryMethod deliveryMethod,
    String? customMessage,
  }) async {
    final results = <InvoiceDeliveryResult>[];

    for (final invoice in invoices) {
      try {
        final result = await sendInvoice(
          invoice: invoice,
          deliveryMethod: deliveryMethod,
          customMessage: customMessage,
        );
        results.add(result);
      } catch (e) {
        results.add(InvoiceDeliveryResult(
          success: false,
          deliveryMethod: deliveryMethod,
          error: e.toString(),
        ));
      }
    }

    return results;
  }

  /// Send reminders for overdue invoices
  Future<void> sendOverdueReminders(List<Invoice> overdueInvoices) async {
    for (final invoice in overdueInvoices) {
      if (invoice.isOverdue) {
        try {
          await sendOverdueNotice(
            invoice: invoice,
            daysOverdue: invoice.daysOverdue,
          );
        } catch (e) {
          print('[InvoiceMessenger] Failed to send overdue notice for ${invoice.number}: $e');
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Check if delivery method is available
  bool isDeliveryMethodAvailable(InvoiceDeliveryMethod method) {
    switch (method) {
      case InvoiceDeliveryMethod.xmtp:
        return xmtpClient != null && xmtpClient!.isInitialized;
      case InvoiceDeliveryMethod.mailchain:
        return mailchainClient != null && mailchainClient!.isAuthenticated;
      case InvoiceDeliveryMethod.both:
        return (xmtpClient != null && xmtpClient!.isInitialized) ||
            (mailchainClient != null && mailchainClient!.isAuthenticated);
      case InvoiceDeliveryMethod.local:
        return true;
    }
  }

  /// Get available delivery methods
  List<InvoiceDeliveryMethod> getAvailableDeliveryMethods() {
    final methods = <InvoiceDeliveryMethod>[];

    if (xmtpClient != null && xmtpClient!.isInitialized) {
      methods.add(InvoiceDeliveryMethod.xmtp);
    }

    if (mailchainClient != null && mailchainClient!.isAuthenticated) {
      methods.add(InvoiceDeliveryMethod.mailchain);
    }

    if (methods.length == 2) {
      methods.add(InvoiceDeliveryMethod.both);
    }

    methods.add(InvoiceDeliveryMethod.local);

    return methods;
  }
}

/// Invoice delivery result
class InvoiceDeliveryResult {
  final bool success;
  final InvoiceDeliveryMethod deliveryMethod;
  final String? xmtpMessageId;
  final String? mailchainMessageId;
  final String? error;

  InvoiceDeliveryResult({
    required this.success,
    required this.deliveryMethod,
    this.xmtpMessageId,
    this.mailchainMessageId,
    this.error,
  });

  @override
  String toString() {
    if (success) {
      return 'InvoiceDeliveryResult(success: true, method: ${deliveryMethod.name})';
    } else {
      return 'InvoiceDeliveryResult(success: false, error: $error)';
    }
  }
}

/// Invoice messenger exception
class InvoiceMessengerException implements Exception {
  final String message;

  InvoiceMessengerException(this.message);

  @override
  String toString() => 'InvoiceMessengerException: $message';
}
