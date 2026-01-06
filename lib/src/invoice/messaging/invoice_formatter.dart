import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/manager/invoice_calculator.dart';

/// Formats invoices for different messaging channels
class InvoiceFormatter {
  /// Format invoice for XMTP (plain text, compact)
  String formatXMTPMessage({
    required Invoice invoice,
    String? customMessage,
    bool includePaymentLink = true,
  }) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('📧 INVOICE RECEIVED');
    buffer.writeln('━' * 40);
    buffer.writeln();

    // Custom message
    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln(customMessage);
      buffer.writeln();
    }

    // Invoice details
    buffer.writeln('Invoice #: ${invoice.number}');
    buffer.writeln('From: ${invoice.fromName ?? _shortenAddress(invoice.from)}');
    buffer.writeln('Date: ${_formatDate(invoice.createdAt)}');
    buffer.writeln('Due: ${_formatDate(invoice.dueDate)}');
    buffer.writeln();

    buffer.writeln('DESCRIPTION');
    buffer.writeln(invoice.title);
    if (invoice.description != null) {
      buffer.writeln(invoice.description);
    }
    buffer.writeln();

    // Items
    buffer.writeln('ITEMS');
    buffer.writeln('─' * 40);
    for (final item in invoice.items) {
      final unitPrice = InvoiceCalculator.formatAmount(
        item.unitPrice,
        decimals: 6,
        symbol: invoice.currency,
      );
      final total = InvoiceCalculator.formatAmount(
        item.total,
        decimals: 6,
        symbol: invoice.currency,
      );
      buffer.writeln(item.description);
      buffer.writeln('  ${item.quantity} × $unitPrice = $total');
    }
    buffer.writeln();

    // Totals
    buffer.writeln('TOTAL');
    buffer.writeln('─' * 40);

    final subtotal = InvoiceCalculator.formatAmount(
      invoice.subtotal,
      decimals: 6,
      symbol: invoice.currency,
    );
    buffer.writeln('Subtotal: $subtotal');

    if (invoice.discount != null && invoice.discount! > BigInt.zero) {
      final discount = InvoiceCalculator.formatAmount(
        invoice.discount!,
        decimals: 6,
        symbol: invoice.currency,
      );
      buffer.writeln('Discount: -$discount');
    }

    if (invoice.taxAmount > BigInt.zero) {
      final tax = InvoiceCalculator.formatAmount(
        invoice.taxAmount,
        decimals: 6,
        symbol: invoice.currency,
      );
      buffer.writeln('Tax: $tax');
    }

    if (invoice.shippingCost != null && invoice.shippingCost! > BigInt.zero) {
      final shipping = InvoiceCalculator.formatAmount(
        invoice.shippingCost!,
        decimals: 6,
        symbol: invoice.currency,
      );
      buffer.writeln('Shipping: $shipping');
    }

    buffer.writeln('─' * 40);
    final total = InvoiceCalculator.formatAmount(
      invoice.total,
      decimals: 6,
      symbol: invoice.currency,
    );
    buffer.writeln('TOTAL DUE: $total');
    buffer.writeln();

    // Payment options
    buffer.writeln('PAYMENT OPTIONS');
    buffer.writeln('Accepted tokens: ${invoice.acceptedTokens.join(', ')}');
    buffer.writeln('Accepted chains: ${invoice.acceptedChains.map((c) => _getChainName(c)).join(', ')}');
    buffer.writeln();

    // Payment link
    if (includePaymentLink) {
      buffer.writeln('💳 PAY NOW');
      buffer.writeln('Click to pay invoice: [Payment Link]');
      buffer.writeln();
    }

    // Footer
    if (invoice.footerText != null) {
      buffer.writeln('─' * 40);
      buffer.writeln(invoice.footerText);
      buffer.writeln();
    }

    buffer.writeln('Powered by web3refi');

    return buffer.toString();
  }

  /// Format invoice for Mailchain (HTML, formatted)
  String formatEmailBody({
    required Invoice invoice,
    String? customMessage,
    bool includePaymentLink = true,
  }) {
    final buffer = StringBuffer();

    // HTML header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<style>');
    buffer.writeln(_getEmailStyles(invoice.brandColor));
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');

    // Email content
    buffer.writeln('<div class="container">');

    // Header with logo
    buffer.writeln('<div class="header">');
    if (invoice.logoUrl != null) {
      buffer.writeln('<img src="${invoice.logoUrl}" alt="Logo" class="logo">');
    }
    buffer.writeln('<h1>INVOICE</h1>');
    buffer.writeln('</div>');

    // Custom message
    if (customMessage != null && customMessage.isNotEmpty) {
      buffer.writeln('<div class="message">');
      buffer.writeln('<p>$customMessage</p>');
      buffer.writeln('</div>');
    }

    // Invoice details
    buffer.writeln('<div class="invoice-details">');
    buffer.writeln('<table class="details-table">');
    buffer.writeln('<tr><td><strong>Invoice #:</strong></td><td>${invoice.number}</td></tr>');
    buffer.writeln('<tr><td><strong>From:</strong></td><td>${invoice.fromName ?? invoice.from}</td></tr>');
    if (invoice.fromCompany != null) {
      buffer.writeln('<tr><td><strong>Company:</strong></td><td>${invoice.fromCompany}</td></tr>');
    }
    buffer.writeln('<tr><td><strong>Date:</strong></td><td>${_formatDate(invoice.createdAt)}</td></tr>');
    buffer.writeln('<tr><td><strong>Due Date:</strong></td><td>${_formatDate(invoice.dueDate)}</td></tr>');
    if (invoice.paymentTerms != null) {
      buffer.writeln('<tr><td><strong>Terms:</strong></td><td>${invoice.paymentTerms}</td></tr>');
    }
    buffer.writeln('</table>');
    buffer.writeln('</div>');

    // Title and description
    buffer.writeln('<div class="invoice-title">');
    buffer.writeln('<h2>${invoice.title}</h2>');
    if (invoice.description != null) {
      buffer.writeln('<p>${invoice.description}</p>');
    }
    buffer.writeln('</div>');

    // Line items
    buffer.writeln('<table class="items-table">');
    buffer.writeln('<thead>');
    buffer.writeln('<tr>');
    buffer.writeln('<th>Description</th>');
    buffer.writeln('<th>Qty</th>');
    buffer.writeln('<th>Unit Price</th>');
    buffer.writeln('<th>Total</th>');
    buffer.writeln('</tr>');
    buffer.writeln('</thead>');
    buffer.writeln('<tbody>');

    for (final item in invoice.items) {
      final unitPrice = InvoiceCalculator.formatAmount(item.unitPrice, decimals: 6);
      final total = InvoiceCalculator.formatAmount(item.total, decimals: 6);

      buffer.writeln('<tr>');
      buffer.writeln('<td>${item.description}</td>');
      buffer.writeln('<td>${item.quantity}</td>');
      buffer.writeln('<td>$unitPrice ${invoice.currency}</td>');
      buffer.writeln('<td>$total ${invoice.currency}</td>');
      buffer.writeln('</tr>');
    }

    buffer.writeln('</tbody>');
    buffer.writeln('</table>');

    // Totals
    buffer.writeln('<div class="totals">');

    final subtotal = InvoiceCalculator.formatAmount(invoice.subtotal, decimals: 6);
    buffer.writeln('<div class="total-line">');
    buffer.writeln('<span>Subtotal:</span>');
    buffer.writeln('<span>$subtotal ${invoice.currency}</span>');
    buffer.writeln('</div>');

    if (invoice.discount != null && invoice.discount! > BigInt.zero) {
      final discount = InvoiceCalculator.formatAmount(invoice.discount!, decimals: 6);
      buffer.writeln('<div class="total-line">');
      buffer.writeln('<span>Discount:</span>');
      buffer.writeln('<span>-$discount ${invoice.currency}</span>');
      buffer.writeln('</div>');
    }

    if (invoice.taxAmount > BigInt.zero) {
      final tax = InvoiceCalculator.formatAmount(invoice.taxAmount, decimals: 6);
      final rate = invoice.taxRate != null ? ' (${invoice.taxRate}%)' : '';
      buffer.writeln('<div class="total-line">');
      buffer.writeln('<span>Tax$rate:</span>');
      buffer.writeln('<span>$tax ${invoice.currency}</span>');
      buffer.writeln('</div>');
    }

    if (invoice.shippingCost != null && invoice.shippingCost! > BigInt.zero) {
      final shipping = InvoiceCalculator.formatAmount(invoice.shippingCost!, decimals: 6);
      buffer.writeln('<div class="total-line">');
      buffer.writeln('<span>Shipping:</span>');
      buffer.writeln('<span>$shipping ${invoice.currency}</span>');
      buffer.writeln('</div>');
    }

    final total = InvoiceCalculator.formatAmount(invoice.total, decimals: 6);
    buffer.writeln('<div class="total-line total">');
    buffer.writeln('<span><strong>TOTAL DUE:</strong></span>');
    buffer.writeln('<span><strong>$total ${invoice.currency}</strong></span>');
    buffer.writeln('</div>');
    buffer.writeln('</div>');

    // Payment options
    buffer.writeln('<div class="payment-info">');
    buffer.writeln('<h3>Payment Options</h3>');
    buffer.writeln('<p><strong>Accepted Tokens:</strong> ${invoice.acceptedTokens.join(', ')}</p>');
    buffer.writeln('<p><strong>Accepted Chains:</strong> ${invoice.acceptedChains.map((c) => _getChainName(c)).join(', ')}</p>');
    buffer.writeln('</div>');

    // Payment button
    if (includePaymentLink) {
      buffer.writeln('<div class="payment-button">');
      buffer.writeln('<a href="#" class="btn-pay">Pay Invoice</a>');
      buffer.writeln('</div>');
    }

    // Notes
    if (invoice.notes != null) {
      buffer.writeln('<div class="notes">');
      buffer.writeln('<h3>Notes</h3>');
      buffer.writeln('<p>${invoice.notes}</p>');
      buffer.writeln('</div>');
    }

    // Footer
    buffer.writeln('<div class="footer">');
    if (invoice.footerText != null) {
      buffer.writeln('<p>${invoice.footerText}</p>');
    }
    buffer.writeln('<p class="powered-by">Powered by <a href="https://web3refi.com">web3refi</a></p>');
    buffer.writeln('</div>');

    buffer.writeln('</div>'); // container
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// Format email subject
  String formatEmailSubject(Invoice invoice) {
    return 'Invoice ${invoice.number} from ${invoice.fromName ?? invoice.from}';
  }

  /// Format payment confirmation
  String formatPaymentConfirmation({
    required Invoice invoice,
    required String txHash,
    required BigInt amount,
  }) {
    final formattedAmount = InvoiceCalculator.formatAmount(
      amount,
      decimals: 6,
      symbol: invoice.currency,
    );

    return '''
✅ PAYMENT RECEIVED

Invoice: ${invoice.number}
Amount: $formattedAmount
Transaction: ${_shortenTxHash(txHash)}

Thank you for your payment!

View transaction: [Explorer Link]
''';
  }

  /// Format payment reminder
  String formatPaymentReminder({
    required Invoice invoice,
    int daysUntilDue = 0,
  }) {
    final total = InvoiceCalculator.formatAmount(
      invoice.remainingAmount,
      decimals: 6,
      symbol: invoice.currency,
    );

    String dueText;
    if (daysUntilDue == 0) {
      dueText = 'due today';
    } else if (daysUntilDue == 1) {
      dueText = 'due tomorrow';
    } else {
      dueText = 'due in $daysUntilDue days';
    }

    return '''
⏰ PAYMENT REMINDER

Invoice: ${invoice.number}
Amount: $total
Due Date: ${_formatDate(invoice.dueDate)} ($dueText)

Please process payment at your earliest convenience.

[Pay Now]
''';
  }

  /// Format overdue notice
  String formatOverdueNotice({
    required Invoice invoice,
    int daysOverdue = 0,
  }) {
    final total = InvoiceCalculator.formatAmount(
      invoice.remainingAmount,
      decimals: 6,
      symbol: invoice.currency,
    );

    return '''
⚠️ OVERDUE INVOICE

Invoice: ${invoice.number}
Amount: $total
Due Date: ${_formatDate(invoice.dueDate)}
Days Overdue: $daysOverdue

This invoice is now overdue. Please process payment immediately to avoid late fees.

[Pay Now]
''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // EMAIL STYLES
  // ═══════════════════════════════════════════════════════════════════════

  String _getEmailStyles(String? brandColor) {
    final primary = brandColor ?? '#2563eb';

    return '''
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
  line-height: 1.6;
  color: #333;
  background-color: #f5f5f5;
  margin: 0;
  padding: 20px;
}

.container {
  max-width: 700px;
  margin: 0 auto;
  background: white;
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 2px 8px rgba(0,0,0,0.1);
}

.header {
  background: $primary;
  color: white;
  padding: 30px;
  text-align: center;
}

.header h1 {
  margin: 0;
  font-size: 32px;
  font-weight: 700;
}

.logo {
  max-width: 150px;
  margin-bottom: 20px;
}

.message {
  padding: 20px 30px;
  background: #f8f9fa;
  border-left: 4px solid $primary;
  margin: 20px 30px;
}

.invoice-details {
  padding: 20px 30px;
}

.details-table {
  width: 100%;
  border-collapse: collapse;
}

.details-table td {
  padding: 8px 0;
  border-bottom: 1px solid #eee;
}

.invoice-title {
  padding: 20px 30px;
  border-top: 2px solid #eee;
}

.invoice-title h2 {
  margin: 0 0 10px 0;
  color: $primary;
}

.items-table {
  width: calc(100% - 60px);
  margin: 20px 30px;
  border-collapse: collapse;
}

.items-table th {
  background: #f8f9fa;
  padding: 12px;
  text-align: left;
  border-bottom: 2px solid #ddd;
  font-weight: 600;
}

.items-table td {
  padding: 12px;
  border-bottom: 1px solid #eee;
}

.totals {
  padding: 20px 30px;
  background: #f8f9fa;
}

.total-line {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  font-size: 16px;
}

.total-line.total {
  font-size: 20px;
  border-top: 2px solid #ddd;
  padding-top: 15px;
  margin-top: 10px;
}

.payment-info {
  padding: 20px 30px;
  background: white;
}

.payment-info h3 {
  color: $primary;
  margin-top: 0;
}

.payment-button {
  text-align: center;
  padding: 30px;
}

.btn-pay {
  display: inline-block;
  background: $primary;
  color: white;
  padding: 15px 40px;
  border-radius: 6px;
  text-decoration: none;
  font-weight: 600;
  font-size: 18px;
}

.btn-pay:hover {
  background: #1d4ed8;
}

.notes {
  padding: 20px 30px;
  background: #fffbeb;
  border-left: 4px solid #fbbf24;
}

.footer {
  padding: 20px 30px;
  text-align: center;
  background: #f8f9fa;
  color: #666;
  font-size: 14px;
}

.powered-by {
  margin-top: 10px;
  font-size: 12px;
}

.powered-by a {
  color: $primary;
  text-decoration: none;
}
''';
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _shortenAddress(String address) {
    if (address.length <= 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _shortenTxHash(String txHash) {
    if (txHash.length <= 16) return txHash;
    return '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}';
  }

  String _getChainName(int chainId) {
    switch (chainId) {
      case 1:
        return 'Ethereum';
      case 137:
        return 'Polygon';
      case 56:
        return 'BNB Chain';
      case 42161:
        return 'Arbitrum';
      case 10:
        return 'Optimism';
      case 8453:
        return 'Base';
      case 43114:
        return 'Avalanche';
      default:
        return 'Chain $chainId';
    }
  }
}
