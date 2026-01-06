import 'package:flutter/material.dart';
import '../cifi/client.dart';
import '../cifi/auth.dart';
import '../signing/siwe.dart';
import '../signers/hd_wallet.dart';

/// CiFi Login Button widget for Flutter applications.
///
/// A ready-to-use button that handles the complete CiFi authentication flow:
/// - Wallet connection
/// - SIWE message signing
/// - Authentication with CiFi backend
/// - Session management
///
/// ## Features
///
/// - One-click wallet authentication
/// - Customizable appearance
/// - Built-in loading states
/// - Error handling
/// - Success/failure callbacks
///
/// ## Usage
///
/// ```dart
/// CiFiLoginButton(
///   client: cifiClient,
///   signer: walletSigner,
///   onSuccess: (session) {
///     print('Logged in: ${session.user.address}');
///     Navigator.pushNamed(context, '/dashboard');
///   },
///   onError: (error) {
///     showDialog(
///       context: context,
///       builder: (context) => AlertDialog(
///         title: Text('Login Failed'),
///         content: Text(error.toString()),
///       ),
///     );
///   },
/// )
/// ```
class CiFiLoginButton extends StatefulWidget {
  final CiFiClient client;
  final Signer signer;
  final VoidCallback? onSuccess;
  final void Function(AuthSession session)? onSessionCreated;
  final void Function(dynamic error)? onError;
  final String? buttonText;
  final TextStyle? textStyle;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? elevation;
  final int chainId;
  final String? domain;

  const CiFiLoginButton({
    Key? key,
    required this.client,
    required this.signer,
    this.onSuccess,
    this.onSessionCreated,
    this.onError,
    this.buttonText,
    this.textStyle,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.padding,
    this.elevation,
    this.chainId = 1,
    this.domain,
  }) : super(key: key);

  @override
  State<CiFiLoginButton> createState() => _CiFiLoginButtonState();
}

class _CiFiLoginButtonState extends State<CiFiLoginButton> {
  bool _isLoading = false;
  String? _error;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Request authentication challenge
      final challenge = await widget.client.auth.requestChallenge(
        address: widget.signer.address,
        chainId: widget.chainId,
        domain: widget.domain,
      );

      // 2. Create SIWE message
      final siweMessage = SiweMessage.fromMessage(challenge.message);

      // 3. Sign message
      final signature = widget.signer.sign(
        siweMessage.toMessage().codeUnits as List<int>,
      );

      // 4. Login with signature
      final session = await widget.client.auth.loginWithSiwe(
        siweMessage: siweMessage,
        signature: signature.toHex(),
      );

      // 5. Success callbacks
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onSessionCreated?.call(session);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });

        widget.onError?.call(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor ?? theme.primaryColor,
        foregroundColor: widget.textColor ?? Colors.white,
        padding: widget.padding ??
            const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: widget.elevation ?? 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius ?? 8),
        ),
      ),
      child: _isLoading
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.textColor ?? Colors.white,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 20,
                  color: widget.textColor ?? Colors.white,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.buttonText ?? 'Sign In with Wallet',
                  style: widget.textStyle ??
                      TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor ?? Colors.white,
                      ),
                ),
              ],
            ),
    );
  }
}

/// Compact CiFi login button (icon only).
class CiFiLoginButtonCompact extends StatefulWidget {
  final CiFiClient client;
  final Signer signer;
  final VoidCallback? onSuccess;
  final void Function(AuthSession session)? onSessionCreated;
  final void Function(dynamic error)? onError;
  final Color? iconColor;
  final Color? backgroundColor;
  final double? size;
  final int chainId;
  final String? domain;

  const CiFiLoginButtonCompact({
    Key? key,
    required this.client,
    required this.signer,
    this.onSuccess,
    this.onSessionCreated,
    this.onError,
    this.iconColor,
    this.backgroundColor,
    this.size,
    this.chainId = 1,
    this.domain,
  }) : super(key: key);

  @override
  State<CiFiLoginButtonCompact> createState() =>
      _CiFiLoginButtonCompactState();
}

class _CiFiLoginButtonCompactState extends State<CiFiLoginButtonCompact> {
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final challenge = await widget.client.auth.requestChallenge(
        address: widget.signer.address,
        chainId: widget.chainId,
        domain: widget.domain,
      );

      final siweMessage = SiweMessage.fromMessage(challenge.message);
      final signature = widget.signer.sign(
        siweMessage.toMessage().codeUnits as List<int>,
      );

      final session = await widget.client.auth.loginWithSiwe(
        siweMessage: siweMessage,
        signature: signature.toHex(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onSessionCreated?.call(session);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onError?.call(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.size ?? 48.0;

    return Material(
      color: widget.backgroundColor ?? theme.primaryColor,
      borderRadius: BorderRadius.circular(size / 2),
      child: InkWell(
        onTap: _isLoading ? null : _handleLogin,
        borderRadius: BorderRadius.circular(size / 2),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          child: _isLoading
              ? SizedBox(
                  width: size * 0.5,
                  height: size * 0.5,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.iconColor ?? Colors.white,
                    ),
                  ),
                )
              : Icon(
                  Icons.account_balance_wallet,
                  size: size * 0.5,
                  color: widget.iconColor ?? Colors.white,
                ),
        ),
      ),
    );
  }
}

/// CiFi branded login button with logo.
class CiFiLoginButtonBranded extends StatefulWidget {
  final CiFiClient client;
  final Signer signer;
  final VoidCallback? onSuccess;
  final void Function(AuthSession session)? onSessionCreated;
  final void Function(dynamic error)? onError;
  final int chainId;
  final String? domain;

  const CiFiLoginButtonBranded({
    Key? key,
    required this.client,
    required this.signer,
    this.onSuccess,
    this.onSessionCreated,
    this.onError,
    this.chainId = 1,
    this.domain,
  }) : super(key: key);

  @override
  State<CiFiLoginButtonBranded> createState() => _CiFiLoginButtonBrandedState();
}

class _CiFiLoginButtonBrandedState extends State<CiFiLoginButtonBranded> {
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final challenge = await widget.client.auth.requestChallenge(
        address: widget.signer.address,
        chainId: widget.chainId,
        domain: widget.domain,
      );

      final siweMessage = SiweMessage.fromMessage(challenge.message);
      final signature = widget.signer.sign(
        siweMessage.toMessage().codeUnits as List<int>,
      );

      final session = await widget.client.auth.loginWithSiwe(
        siweMessage: siweMessage,
        signature: signature.toHex(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onSessionCreated?.call(session);
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        widget.onError?.call(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _handleLogin,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1), // CiFi brand color
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text(
                      'C',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Continue with CiFi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }
}
