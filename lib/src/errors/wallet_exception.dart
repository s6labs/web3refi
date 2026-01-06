import 'package:web3refi/src/errors/web3_exception.dart';

/// Exception for wallet connection, signing, and session errors.
///
/// Thrown when:
/// - Wallet connection fails or is rejected
/// - Wallet app is not installed
/// - Signing operations fail
/// - Session expires or becomes invalid
/// - Chain switching fails
///
/// ## Common Error Codes
///
/// | Code | Description |
/// |------|-------------|
/// | `user_rejected` | User cancelled the request |
/// | `wallet_not_installed` | Wallet app not found |
/// | `not_connected` | No wallet connected |
/// | `session_expired` | Session needs refresh |
/// | `connection_timeout` | Connection timed out |
/// | `chain_not_supported` | Chain not supported by wallet |
/// | `signing_failed` | Message/transaction signing failed |
///
/// ## Usage Example
///
/// ```dart
/// try {
///   await Web3Refi.instance.connect();
/// } on WalletException catch (e) {
///   switch (e.code) {
///     case 'user_rejected':
///       showSnackBar('You cancelled the connection');
///       break;
///     case 'wallet_not_installed':
///       showInstallWalletDialog(e.walletName);
///       break;
///     case 'connection_timeout':
///       showRetryDialog();
///       break;
///     default:
///       showErrorDialog(e.toUserMessage());
///   }
/// }
/// ```
class WalletException extends Web3Exception {
  /// The wallet name/ID associated with this error, if applicable.
  String? get walletName => data?['walletName'] as String?;

  /// The wallet type (e.g., 'metamask', 'walletconnect').
  String? get walletType => data?['walletType'] as String?;

  /// Creates a new WalletException.
  const WalletException({
    required super.message,
    required super.code,
    super.cause,
    super.stackTrace,
    super.data,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // CONNECTION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// User rejected the connection or signing request.
  ///
  /// This is a normal user action, not an error condition.
  /// The app should handle this gracefully.
  factory WalletException.userRejected([String? details]) {
    return WalletException(
      message: details ?? 'User rejected the request',
      code: 'user_rejected',
    );
  }

  /// User rejected the connection request specifically.
  factory WalletException.connectionRejected() {
    return const WalletException(
      message: 'User rejected the wallet connection request',
      code: 'user_rejected',
      data: {'action': 'connect'},
    );
  }

  /// User rejected a signing request.
  factory WalletException.signingRejected() {
    return const WalletException(
      message: 'User rejected the signing request',
      code: 'user_rejected',
      data: {'action': 'sign'},
    );
  }

  /// User rejected a transaction request.
  factory WalletException.transactionRejected() {
    return const WalletException(
      message: 'User rejected the transaction',
      code: 'user_rejected',
      data: {'action': 'transaction'},
    );
  }

  /// Wallet app is not installed on the device.
  factory WalletException.walletNotInstalled(String walletName) {
    return WalletException(
      message: '$walletName is not installed. Please install it to continue.',
      code: 'wallet_not_installed',
      data: {
        'walletName': walletName,
        'action': 'install_wallet',
      },
    );
  }

  /// No wallet is currently connected.
  ///
  /// Thrown when attempting operations that require a connected wallet.
  factory WalletException.notConnected() {
    return const WalletException(
      message: 'No wallet connected. Please connect a wallet first.',
      code: 'not_connected',
    );
  }

  /// Wallet is already connected.
  factory WalletException.alreadyConnected() {
    return const WalletException(
      message: 'A wallet is already connected. Disconnect first to connect a different wallet.',
      code: 'already_connected',
    );
  }

  /// Connection attempt timed out.
  factory WalletException.connectionTimeout({Duration? timeout}) {
    return WalletException(
      message: 'Connection timed out. Please try again.',
      code: 'connection_timeout',
      data: {
        if (timeout != null) 'timeoutSeconds': timeout.inSeconds,
      },
    );
  }

  /// Failed to establish connection with wallet.
  factory WalletException.connectionFailed([String? reason, Object? cause]) {
    return WalletException(
      message: reason ?? 'Failed to connect to wallet',
      code: 'connection_failed',
      cause: cause,
    );
  }

  /// WalletConnect pairing failed.
  factory WalletException.pairingFailed([String? reason]) {
    return WalletException(
      message: reason ?? 'Failed to pair with wallet',
      code: 'pairing_failed',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESSION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Session has expired and needs to be re-established.
  factory WalletException.sessionExpired() {
    return const WalletException(
      message: 'Session expired. Please reconnect your wallet.',
      code: 'session_expired',
    );
  }

  /// Session is invalid or corrupted.
  factory WalletException.sessionInvalid([String? reason]) {
    return WalletException(
      message: reason ?? 'Invalid wallet session. Please reconnect.',
      code: 'session_invalid',
    );
  }

  /// Failed to restore previous session.
  factory WalletException.sessionRestoreFailed([Object? cause]) {
    return WalletException(
      message: 'Failed to restore wallet session. Please reconnect.',
      code: 'session_restore_failed',
      cause: cause,
    );
  }

  /// No session found to restore.
  factory WalletException.noSession() {
    return const WalletException(
      message: 'No wallet session found',
      code: 'no_session',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHAIN ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// The requested chain is not supported by the connected wallet.
  factory WalletException.chainNotSupported(String chainName, {int? chainId}) {
    return WalletException(
      message: '$chainName is not supported by the connected wallet.',
      code: 'chain_not_supported',
      data: {
        'chainName': chainName,
        if (chainId != null) 'chainId': chainId,
      },
    );
  }

  /// Failed to switch to the requested chain.
  factory WalletException.chainSwitchFailed(String chainName, {int? chainId, Object? cause}) {
    return WalletException(
      message: 'Failed to switch to $chainName',
      code: 'chain_switch_failed',
      cause: cause,
      data: {
        'chainName': chainName,
        if (chainId != null) 'chainId': chainId,
      },
    );
  }

  /// User rejected the chain switch request.
  factory WalletException.chainSwitchRejected(String chainName) {
    return WalletException(
      message: 'User rejected switching to $chainName',
      code: 'user_rejected',
      data: {
        'action': 'chain_switch',
        'chainName': chainName,
      },
    );
  }

  /// Chain needs to be added to wallet first.
  factory WalletException.chainNotAdded(String chainName, {int? chainId}) {
    return WalletException(
      message: '$chainName needs to be added to your wallet',
      code: 'chain_not_added',
      data: {
        'chainName': chainName,
        if (chainId != null) 'chainId': chainId,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGNING ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Message signing failed.
  factory WalletException.signingFailed([String? reason, Object? cause]) {
    return WalletException(
      message: reason ?? 'Failed to sign message',
      code: 'signing_failed',
      cause: cause,
    );
  }

  /// Invalid signature received.
  factory WalletException.invalidSignature([String? details]) {
    return WalletException(
      message: details ?? 'Invalid signature received from wallet',
      code: 'invalid_signature',
    );
  }

  /// Signature verification failed.
  factory WalletException.signatureVerificationFailed([String? reason]) {
    return WalletException(
      message: reason ?? 'Signature verification failed',
      code: 'signature_verification_failed',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACCOUNT ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// No accounts available in the wallet.
  factory WalletException.noAccounts() {
    return const WalletException(
      message: 'No accounts available in the connected wallet',
      code: 'no_accounts',
    );
  }

  /// Account changed unexpectedly.
  factory WalletException.accountChanged(String? newAddress) {
    return WalletException(
      message: 'Wallet account changed',
      code: 'account_changed',
      data: {
        if (newAddress != null) 'newAddress': newAddress,
      },
    );
  }

  /// Account is locked/inaccessible.
  factory WalletException.accountLocked() {
    return const WalletException(
      message: 'Wallet account is locked. Please unlock your wallet.',
      code: 'account_locked',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET-SPECIFIC ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// WalletConnect specific error.
  factory WalletException.walletConnect(String message, {int? code, Object? cause}) {
    return WalletException(
      message: message,
      code: 'walletconnect_error',
      cause: cause,
      data: {
        if (code != null) 'wcCode': code,
      },
    );
  }

  /// Deep link failed to open wallet.
  factory WalletException.deepLinkFailed(String walletName, [Object? cause]) {
    return WalletException(
      message: 'Failed to open $walletName',
      code: 'deep_link_failed',
      cause: cause,
      data: {'walletName': walletName},
    );
  }

  /// QR code scanning failed or was cancelled.
  factory WalletException.qrScanFailed([String? reason]) {
    return WalletException(
      message: reason ?? 'QR code scan failed or was cancelled',
      code: 'qr_scan_failed',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GENERIC
  // ══════════════════════════════════════════════════════════════════════════

  /// Generic wallet error.
  factory WalletException.generic(String message, [Object? cause]) {
    return WalletException(
      message: message,
      code: 'wallet_error',
      cause: cause,
    );
  }

  /// Creates from a WalletConnect error code.
  factory WalletException.fromWalletConnectError(int code, String message) {
    // WalletConnect error codes: https://docs.walletconnect.com/2.0/specs/sign/error-codes
    switch (code) {
      case 4001:
        return WalletException.userRejected(message);
      case 4100:
        return WalletException.accountLocked();
      case 4200:
        return WalletException.chainNotSupported(message);
      case 4900:
        return WalletException.connectionFailed(message);
      case 4901:
        return WalletException.chainNotAdded(message);
      default:
        return WalletException.walletConnect(message, code: code);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER MESSAGES
  // ══════════════════════════════════════════════════════════════════════════

  @override
  String toUserMessage() {
    switch (code) {
      case 'user_rejected':
        final action = data?['action'] as String?;
        switch (action) {
          case 'connect':
            return 'You cancelled the wallet connection.';
          case 'sign':
            return 'You cancelled the signing request.';
          case 'transaction':
            return 'You cancelled the transaction.';
          case 'chain_switch':
            return 'You cancelled switching networks.';
          default:
            return 'You cancelled the request. Try again when ready.';
        }

      case 'wallet_not_installed':
        final name = walletName ?? 'The wallet';
        return '$name is not installed. Please install it and try again.';

      case 'not_connected':
        return 'Please connect your wallet first.';

      case 'already_connected':
        return 'A wallet is already connected.';

      case 'connection_timeout':
        return 'Connection timed out. Please check your wallet app and try again.';

      case 'connection_failed':
        return 'Could not connect to wallet. Please try again.';

      case 'pairing_failed':
        return 'Failed to pair with wallet. Please try scanning again.';

      case 'session_expired':
        return 'Your session expired. Please reconnect your wallet.';

      case 'session_invalid':
      case 'session_restore_failed':
        return 'Session issue. Please reconnect your wallet.';

      case 'chain_not_supported':
        final chain = data?['chainName'] ?? 'This network';
        return '$chain is not supported by your wallet.';

      case 'chain_switch_failed':
        return 'Could not switch networks. Please try manually in your wallet.';

      case 'chain_not_added':
        final chain = data?['chainName'] ?? 'This network';
        return 'Please add $chain to your wallet first.';

      case 'signing_failed':
        return 'Could not sign the request. Please try again.';

      case 'invalid_signature':
      case 'signature_verification_failed':
        return 'Signature verification failed. Please try again.';

      case 'no_accounts':
        return 'No accounts found in your wallet.';

      case 'account_changed':
        return 'Your wallet account changed. Please verify and continue.';

      case 'account_locked':
        return 'Your wallet is locked. Please unlock it and try again.';

      case 'deep_link_failed':
        final name = walletName ?? 'wallet';
        return 'Could not open $name. Is it installed?';

      case 'qr_scan_failed':
        return 'QR scan failed. Please try again.';

      default:
        return 'Wallet error. Please try again.';
    }
  }

  @override
  String toString() => 'WalletException($code): $message';
}

/// Extension for checking common wallet exception types.
extension WalletExceptionType on WalletException {
  /// Whether the user explicitly rejected/cancelled the action.
  bool get isUserRejected => code == 'user_rejected';

  /// Whether this is a connection-related error.
  bool get isConnectionError => const [
        'connection_timeout',
        'connection_failed',
        'pairing_failed',
        'not_connected',
      ].contains(code);

  /// Whether this is a session-related error.
  bool get isSessionError => const [
        'session_expired',
        'session_invalid',
        'session_restore_failed',
        'no_session',
      ].contains(code);

  /// Whether this is a chain/network-related error.
  bool get isChainError => const [
        'chain_not_supported',
        'chain_switch_failed',
        'chain_not_added',
      ].contains(code);

  /// Whether reconnecting might resolve this error.
  bool get shouldReconnect => const [
        'session_expired',
        'session_invalid',
        'connection_failed',
        'not_connected',
      ].contains(code);

  /// Whether this error can be retried.
  bool get isRetryable => const [
        'connection_timeout',
        'connection_failed',
        'signing_failed',
        'deep_link_failed',
      ].contains(code);
}
