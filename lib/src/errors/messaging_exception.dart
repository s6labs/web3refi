import 'package:web3refi/src/errors/web3_exception.dart';

/// Exception for messaging-related errors.
///
/// Covers errors from XMTP and Mailchain messaging operations:
/// - Client initialization
/// - Message sending/receiving
/// - Conversation management
/// - Recipient validation
///
/// Example:
/// ```dart
/// try {
///   await xmtp.sendMessage(recipient: address, content: 'Hello!');
/// } on MessagingException catch (e) {
///   switch (e.code) {
///     case 'not_initialized':
///       showError('Please connect your wallet first');
///       break;
///     case 'recipient_not_found':
///       showError('This address cannot receive messages');
///       break;
///     default:
///       showError(e.toUserMessage());
///   }
/// }
/// ```
class MessagingException extends Web3Exception {
  /// The messaging protocol (xmtp, mailchain).
  final String? protocol;

  /// The recipient address, if applicable.
  final String? recipient;

  /// The conversation ID, if applicable.
  final String? conversationId;

  const MessagingException({
    required super.message,
    required super.code,
    super.severity,
    super.cause,
    super.stackTrace,
    super.context,
    this.protocol,
    this.recipient,
    this.conversationId,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Messaging client not initialized.
  factory MessagingException.notInitialized([String? protocol]) {
    return MessagingException(
      message: '${protocol ?? 'Messaging client'} not initialized. Call initialize() first.',
      code: 'not_initialized',
      severity: ErrorSeverity.error,
      protocol: protocol,
    );
  }

  /// Failed to initialize messaging client.
  factory MessagingException.initializationFailed({
    String? protocol,
    String? reason,
    Object? cause,
  }) {
    return MessagingException(
      message: reason ?? 'Failed to initialize ${protocol ?? 'messaging client'}',
      code: 'init_failed',
      severity: ErrorSeverity.error,
      protocol: protocol,
      cause: cause,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECTION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Connection to messaging service failed.
  factory MessagingException.connectionFailed({
    String? protocol,
    String? reason,
    Object? cause,
  }) {
    return MessagingException(
      message: reason ?? 'Failed to connect to ${protocol ?? 'messaging service'}',
      code: 'connection_failed',
      severity: ErrorSeverity.error,
      protocol: protocol,
      cause: cause,
    );
  }

  /// Wallet not connected for messaging.
  factory MessagingException.walletNotConnected() {
    return const MessagingException(
      message: 'Wallet must be connected before using messaging',
      code: 'wallet_not_connected',
      severity: ErrorSeverity.error,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RECIPIENT ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Recipient address not found or cannot receive messages.
  factory MessagingException.recipientNotFound(String recipient) {
    return MessagingException(
      message: 'Recipient $recipient cannot receive messages or is not registered',
      code: 'recipient_not_found',
      severity: ErrorSeverity.warning,
      recipient: recipient,
    );
  }

  /// Invalid recipient address format.
  factory MessagingException.invalidRecipient(String recipient, {String? reason}) {
    return MessagingException(
      message: reason ?? 'Invalid recipient address: $recipient',
      code: 'invalid_recipient',
      severity: ErrorSeverity.error,
      recipient: recipient,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SEND/RECEIVE ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Failed to send message.
  factory MessagingException.sendFailed(String reason, {Object? cause}) {
    return MessagingException(
      message: reason,
      code: 'send_failed',
      severity: ErrorSeverity.error,
      cause: cause,
    );
  }

  /// Failed to fetch messages.
  factory MessagingException.fetchFailed({String? reason, Object? cause}) {
    return MessagingException(
      message: reason ?? 'Failed to fetch messages',
      code: 'fetch_failed',
      severity: ErrorSeverity.error,
      cause: cause,
    );
  }

  /// Message content too large.
  factory MessagingException.messageTooLarge({
    int? size,
    int? maxSize,
  }) {
    return MessagingException(
      message: 'Message content exceeds maximum size${maxSize != null ? ' of $maxSize bytes' : ''}',
      code: 'message_too_large',
      severity: ErrorSeverity.error,
      context: {
        if (size != null) 'size': size,
        if (maxSize != null) 'maxSize': maxSize,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVERSATION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Conversation not found.
  factory MessagingException.conversationNotFound(String conversationId) {
    return MessagingException(
      message: 'Conversation not found: $conversationId',
      code: 'conversation_not_found',
      severity: ErrorSeverity.error,
      conversationId: conversationId,
    );
  }

  /// Failed to create conversation.
  factory MessagingException.createConversationFailed({
    String? recipient,
    String? reason,
    Object? cause,
  }) {
    return MessagingException(
      message: reason ?? 'Failed to create conversation${recipient != null ? ' with $recipient' : ''}',
      code: 'create_conversation_failed',
      severity: ErrorSeverity.error,
      recipient: recipient,
      cause: cause,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY METHODS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  String toUserMessage() {
    switch (code) {
      case 'not_initialized':
        return 'Messaging is not set up. Please connect your wallet first.';
      case 'wallet_not_connected':
        return 'Please connect your wallet to use messaging.';
      case 'recipient_not_found':
        return 'This address cannot receive messages yet.';
      case 'invalid_recipient':
        return 'Please enter a valid address.';
      case 'send_failed':
        return 'Message could not be sent. Please try again.';
      case 'connection_failed':
        return 'Could not connect to messaging service. Please check your connection.';
      case 'message_too_large':
        return 'Message is too long. Please shorten it and try again.';
      default:
        return message;
    }
  }
}
