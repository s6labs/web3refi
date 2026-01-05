import 'dart:async';
import 'package:flutter/foundation.dart';
import '../wallet/wallet_manager.dart';
import '../exceptions/web3_exception.dart';
import 'xmtp/xmtp_client.dart';
import 'mailchain/mailchain_client.dart';

/// Unified messaging client for web3refi.
///
/// Provides access to both XMTP (real-time chat) and Mailchain (blockchain email)
/// through a single, consistent interface.
///
/// ## Quick Start
///
/// ```dart
/// final messaging = Web3Refi.instance.messaging;
///
/// // Initialize messaging (requires connected wallet)
/// await messaging.initialize();
///
/// // Send real-time message via XMTP
/// await messaging.xmtp.sendMessage(
///   recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
///   content: 'Hello from web3refi!',
/// );
///
/// // Send blockchain email via Mailchain
/// await messaging.mailchain.sendMail(
///   to: '0x742d35Cc...@ethereum.mailchain.com',
///   subject: 'Payment Confirmation',
///   body: 'Your payment has been processed.',
/// );
/// ```
///
/// ## When to Use Each Protocol
///
/// | Use Case | Protocol | Why |
/// |----------|----------|-----|
/// | Quick notifications | XMTP | Real-time delivery |
/// | Transaction alerts | XMTP | Instant feedback |
/// | Formal communication | Mailchain | Email-like experience |
/// | Invoices/receipts | Mailchain | Document-style content |
/// | Customer support chat | XMTP | Back-and-forth conversation |
/// | Newsletter to holders | Mailchain | Batch sending |
class MessagingClient extends ChangeNotifier {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Wallet manager for authentication.
  final WalletManager _walletManager;

  /// XMTP environment ('production' or 'dev').
  final String xmtpEnvironment;

  /// Whether Mailchain is enabled.
  final bool enableMailchain;

  /// XMTP client for real-time messaging.
  late final XMTPClient _xmtpClient;

  /// Mailchain client for blockchain email.
  late final MailchainClient _mailchainClient;

  /// Whether messaging has been initialized.
  bool _isInitialized = false;

  /// Initialization error, if any.
  String? _initError;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  MessagingClient({
    required WalletManager walletManager,
    this.xmtpEnvironment = 'production',
    this.enableMailchain = true,
  }) : _walletManager = walletManager {
    _xmtpClient = XMTPClient(
      walletManager: _walletManager,
      environment: xmtpEnvironment,
    );

    _mailchainClient = MailchainClient(
      walletManager: _walletManager,
      enabled: enableMailchain,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GETTERS
  // ══════════════════════════════════════════════════════════════════════════

  /// XMTP client for real-time messaging.
  ///
  /// Use for instant, chat-like communication between wallet addresses.
  ///
  /// ```dart
  /// await messaging.xmtp.sendMessage(
  ///   recipient: '0x123...',
  ///   content: 'Hey!',
  /// );
  /// ```
  XMTPClient get xmtp => _xmtpClient;

  /// Mailchain client for blockchain email.
  ///
  /// Use for formal, email-like communication.
  ///
  /// ```dart
  /// await messaging.mailchain.sendMail(
  ///   to: '0x123...@ethereum.mailchain.com',
  ///   subject: 'Invoice',
  ///   body: 'Please find attached...',
  /// );
  /// ```
  MailchainClient get mailchain => _mailchainClient;

  /// Whether messaging is initialized and ready.
  bool get isInitialized => _isInitialized;

  /// Whether XMTP is ready.
  bool get isXmtpReady => _xmtpClient.isInitialized;

  /// Whether Mailchain is ready.
  bool get isMailchainReady => _mailchainClient.isAuthenticated;

  /// Initialization error message, if any.
  String? get initializationError => _initError;

  /// Connected wallet address.
  String? get address => _walletManager.address;

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Initialize all messaging protocols.
  ///
  /// Requires a connected wallet. Call after [Web3Refi.instance.connect()].
  ///
  /// ```dart
  /// await Web3Refi.instance.connect();
  /// await Web3Refi.instance.messaging.initialize();
  /// ```
  ///
  /// You can also initialize protocols individually:
  /// ```dart
  /// await messaging.initializeXmtp();
  /// await messaging.initializeMailchain();
  /// ```
  Future<void> initialize() async {
    if (!_walletManager.isConnected) {
      throw MessagingException.notInitialized();
    }

    _initError = null;
    final errors = <String>[];

    // Initialize XMTP
    try {
      await _xmtpClient.initialize();
    } catch (e) {
      errors.add('XMTP: $e');
      _log('Failed to initialize XMTP: $e');
    }

    // Initialize Mailchain (if enabled)
    if (enableMailchain) {
      try {
        await _mailchainClient.initialize();
      } catch (e) {
        errors.add('Mailchain: $e');
        _log('Failed to initialize Mailchain: $e');
      }
    }

    // At least one protocol should be initialized
    if (!_xmtpClient.isInitialized && !_mailchainClient.isAuthenticated) {
      _initError = errors.join('; ');
      throw MessagingException(
        message: 'Failed to initialize messaging: $_initError',
        code: 'init_failed',
      );
    }

    _isInitialized = true;
    notifyListeners();
    _log('Messaging initialized');
  }

  /// Initialize only XMTP.
  Future<void> initializeXmtp() async {
    if (!_walletManager.isConnected) {
      throw MessagingException.notInitialized();
    }
    await _xmtpClient.initialize();
    notifyListeners();
  }

  /// Initialize only Mailchain.
  Future<void> initializeMailchain() async {
    if (!_walletManager.isConnected) {
      throw MessagingException.notInitialized();
    }
    if (!enableMailchain) {
      throw MessagingException(
        message: 'Mailchain is not enabled in configuration',
        code: 'mailchain_disabled',
      );
    }
    await _mailchainClient.initialize();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UNIFIED MESSAGING API
  // ══════════════════════════════════════════════════════════════════════════

  /// Send a message using the best available protocol.
  ///
  /// By default, uses XMTP for real-time delivery.
  /// Set [preferEmail] to true to use Mailchain instead.
  ///
  /// ```dart
  /// // Quick message via XMTP
  /// await messaging.send(
  ///   to: '0x123...',
  ///   content: 'Payment sent!',
  /// );
  ///
  /// // Formal email via Mailchain
  /// await messaging.send(
  ///   to: '0x123...',
  ///   content: 'Please review the attached document.',
  ///   subject: 'Document Review',
  ///   preferEmail: true,
  /// );
  /// ```
  Future<void> send({
    required String to,
    required String content,
    String? subject,
    bool preferEmail = false,
  }) async {
    _requireInitialized();

    if (preferEmail && _mailchainClient.isAuthenticated) {
      await _mailchainClient.sendMail(
        to: _mailchainClient.formatAddress(to),
        subject: subject ?? 'Message from ${_formatAddress(address!)}',
        body: content,
      );
    } else if (_xmtpClient.isInitialized) {
      await _xmtpClient.sendMessage(
        recipient: to,
        content: content,
      );
    } else if (_mailchainClient.isAuthenticated) {
      // Fallback to Mailchain if XMTP not available
      await _mailchainClient.sendMail(
        to: _mailchainClient.formatAddress(to),
        subject: subject ?? 'Message',
        body: content,
      );
    } else {
      throw MessagingException.notInitialized();
    }
  }

  /// Check if a recipient can receive messages.
  ///
  /// Returns a [RecipientCapabilities] object describing what
  /// protocols the recipient supports.
  ///
  /// ```dart
  /// final caps = await messaging.checkRecipient('0x123...');
  /// if (caps.canReceiveXmtp) {
  ///   await messaging.xmtp.sendMessage(...);
  /// }
  /// ```
  Future<RecipientCapabilities> checkRecipient(String address) async {
    _requireInitialized();

    bool canXmtp = false;
    bool canMailchain = false;

    // Check XMTP
    if (_xmtpClient.isInitialized) {
      try {
        canXmtp = await _xmtpClient.canMessage(address);
      } catch (_) {
        canXmtp = false;
      }
    }

    // Check Mailchain (always possible if authenticated)
    canMailchain = _mailchainClient.isAuthenticated;

    return RecipientCapabilities(
      address: address,
      canReceiveXmtp: canXmtp,
      canReceiveMailchain: canMailchain,
    );
  }

  /// Stream all incoming messages from all protocols.
  ///
  /// Returns a unified stream of [UnifiedMessage] objects.
  ///
  /// ```dart
  /// messaging.streamAllMessages().listen((message) {
  ///   print('${message.protocol}: ${message.content}');
  /// });
  /// ```
  Stream<UnifiedMessage> streamAllMessages() async* {
    _requireInitialized();

    // Merge streams from both protocols
    if (_xmtpClient.isInitialized) {
      await for (final msg in _xmtpClient.streamAllMessages()) {
        yield UnifiedMessage(
          id: msg.id,
          sender: msg.senderAddress,
          content: msg.content,
          timestamp: msg.sentAt,
          protocol: MessageProtocol.xmtp,
          raw: msg,
        );
      }
    }

    // Note: Mailchain doesn't support real-time streaming
    // Poll for new emails periodically if needed
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  void _requireInitialized() {
    if (!_isInitialized) {
      throw MessagingException.notInitialized();
    }
  }

  String _formatAddress(String address) {
    if (address.length > 10) {
      return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
    }
    return address;
  }

  void _log(String message) {
    debugPrint('[web3refi:Messaging] $message');
  }

  /// Clean up resources.
  Future<void> dispose() async {
    await _xmtpClient.dispose();
    await _mailchainClient.dispose();
    _isInitialized = false;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Messaging protocol type.
enum MessageProtocol {
  /// XMTP real-time messaging.
  xmtp,

  /// Mailchain blockchain email.
  mailchain,

  /// Auto-select best protocol.
  auto,
}

/// Capabilities of a recipient address.
class RecipientCapabilities {
  /// The address that was checked.
  final String address;

  /// Whether the address can receive XMTP messages.
  final bool canReceiveXmtp;

  /// Whether the address can receive Mailchain emails.
  final bool canReceiveMailchain;

  const RecipientCapabilities({
    required this.address,
    required this.canReceiveXmtp,
    required this.canReceiveMailchain,
  });

  /// Whether the recipient can receive any messages.
  bool get canReceiveAny => canReceiveXmtp || canReceiveMailchain;

  /// Best protocol to use for this recipient.
  MessageProtocol get recommendedProtocol {
    if (canReceiveXmtp) return MessageProtocol.xmtp;
    if (canReceiveMailchain) return MessageProtocol.mailchain;
    return MessageProtocol.auto;
  }

  @override
  String toString() =>
      'RecipientCapabilities($address, xmtp: $canReceiveXmtp, mailchain: $canReceiveMailchain)';
}

/// A message from any protocol in unified format.
class UnifiedMessage {
  /// Unique message identifier.
  final String id;

  /// Sender address.
  final String sender;

  /// Message content.
  final String content;

  /// When the message was sent.
  final DateTime timestamp;

  /// Which protocol delivered this message.
  final MessageProtocol protocol;

  /// Subject line (Mailchain only).
  final String? subject;

  /// Raw protocol-specific message object.
  final dynamic raw;

  const UnifiedMessage({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.protocol,
    this.subject,
    this.raw,
  });

  /// Whether this is an XMTP message.
  bool get isXmtp => protocol == MessageProtocol.xmtp;

  /// Whether this is a Mailchain email.
  bool get isMailchain => protocol == MessageProtocol.mailchain;

  @override
  String toString() => 'UnifiedMessage($protocol, from: $sender)';
}
