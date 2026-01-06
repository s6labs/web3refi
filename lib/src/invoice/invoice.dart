// ═══════════════════════════════════════════════════════════════════════════
// INVOICE SYSTEM EXPORTS
// ═══════════════════════════════════════════════════════════════════════════
//
// Complete invoice financing system for web3refi
// Features:
// - Create and send invoices via XMTP & Mailchain
// - Multi-chain payment processing
// - IPFS & Arweave storage
// - Recurring invoice subscriptions
// - Invoice factoring marketplace
// - Production-ready Flutter widgets
// - Smart contract escrow system
//
// ═══════════════════════════════════════════════════════════════════════════

// Core Data Models
export 'core/invoice.dart';
export 'core/invoice_item.dart';
export 'core/invoice_status.dart';
export 'core/payment_info.dart';
export 'core/invoice_config.dart';

// Manager & Utilities
export 'manager/invoice_manager.dart';
export 'manager/invoice_calculator.dart';
export 'manager/invoice_validator.dart';

// Storage Systems
export 'storage/invoice_storage.dart';
export 'storage/ipfs_storage.dart';
export 'storage/arweave_storage.dart';

// Messaging
export 'messaging/invoice_messenger.dart';
export 'messaging/invoice_formatter.dart';

// Payment Processing
export 'payment/invoice_payment_handler.dart';

// Advanced Features
export 'advanced/recurring_invoice_manager.dart';
export 'advanced/invoice_factoring_manager.dart';

// Widgets
export 'widgets/invoice_creator.dart';
export 'widgets/invoice_viewer.dart';
export 'widgets/invoice_list.dart';
export 'widgets/invoice_payment_widget.dart';
export 'widgets/invoice_status_card.dart';
export 'widgets/invoice_template_selector.dart';
