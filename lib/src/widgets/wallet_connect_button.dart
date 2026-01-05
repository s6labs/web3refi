import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/web3refi_base.dart';
import '../wallet/wallet_manager.dart';
import '../errors/web3_exception.dart';

/// A pre-built button for connecting and managing wallet connections.
///
/// Handles all connection states automatically:
/// - Disconnected: Shows "Connect Wallet" button
/// - Connecting: Shows loading indicator
/// - Connected: Shows truncated address with menu
/// - Error: Shows retry option
///
/// Example:
/// ```dart
/// WalletConnectButton(
///   onConnected: () => Navigator.pushNamed(context, '/dashboard'),
///   onDisconnected: () => Navigator.pushNamed(context, '/login'),
/// )
/// ```
///
/// Customization:
/// ```dart
/// WalletConnectButton(
///   style: WalletButtonStyle(
///     backgroundColor: Colors.blue,
///     textColor: Colors.white,
///     borderRadius: BorderRadius.circular(12),
///   ),
///   connectText: 'Sign In with Wallet',
///   showAddress: true,
///   showChainBadge: true,
/// )
/// ```
class WalletConnectButton extends StatefulWidget {
  /// Called when wallet is successfully connected.
  final VoidCallback? onConnected;

  /// Called when wallet is disconnected.
  final VoidCallback? onDisconnected;

  /// Called when an error occurs.
  final void Function(WalletException error)? onError;

  /// Custom text for the connect button.
  final String connectText;

  /// Custom text shown while connecting.
  final String connectingText;

  /// Whether to show the full address or truncated.
  final bool showFullAddress;

  /// Whether to show the chain badge when connected.
  final bool showChainBadge;

  /// Whether to show the wallet icon.
  final bool showIcon;

  /// Custom style for the button.
  final WalletButtonStyle? style;

  /// Custom builder for completely custom UI.
  final Widget Function(BuildContext, WalletConnectionState, String?)?
      customBuilder;

  /// Size of the button.
  final WalletButtonSize size;

  /// Whether the button is enabled.
  final bool enabled;

  const WalletConnectButton({
    super.key,
    this.onConnected,
    this.onDisconnected,
    this.onError,
    this.connectText = 'Connect Wallet',
    this.connectingText = 'Connecting...',
    this.showFullAddress = false,
    this.showChainBadge = true,
    this.showIcon = true,
    this.style,
    this.customBuilder,
    this.size = WalletButtonSize.medium,
    this.enabled = true,
  });

  @override
  State<WalletConnectButton> createState() => _WalletConnectButtonState();
}

class _WalletConnectButtonState extends State<WalletConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    Web3Refi.instance.walletManager.addListener(_onWalletStateChanged);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    Web3Refi.instance.walletManager.removeListener(_onWalletStateChanged);
    super.dispose();
  }

  void _onWalletStateChanged() {
    if (mounted) setState(() {});
  }

  WalletButtonStyle get _effectiveStyle =>
      widget.style ?? WalletButtonStyle.defaultStyle(context);

  @override
  Widget build(BuildContext context) {
    final state = Web3Refi.instance.connectionState;
    final address = Web3Refi.instance.address;

    // Custom builder takes priority
    if (widget.customBuilder != null) {
      return widget.customBuilder!(context, state, address);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _buildButton(state, address),
    );
  }

  Widget _buildButton(WalletConnectionState state, String? address) {
    switch (state) {
      case WalletConnectionState.disconnected:
        return _buildDisconnectedButton();
      case WalletConnectionState.connecting:
        return _buildConnectingButton();
      case WalletConnectionState.connected:
        return _buildConnectedButton(address!);
      case WalletConnectionState.error:
        return _buildErrorButton();
    }
  }

  Widget _buildDisconnectedButton() {
    return _BaseButton(
      key: const ValueKey('disconnected'),
      onPressed: widget.enabled ? _connect : null,
      style: _effectiveStyle,
      size: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showIcon) ...[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: _iconSize,
              color: _effectiveStyle.textColor,
            ),
            SizedBox(width: _spacing),
          ],
          Text(
            widget.connectText,
            style: TextStyle(
              color: _effectiveStyle.textColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingButton() {
    return _BaseButton(
      key: const ValueKey('connecting'),
      onPressed: null,
      style: _effectiveStyle.copyWith(
        backgroundColor: _effectiveStyle.backgroundColor?.withOpacity(0.7),
      ),
      size: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _iconSize,
            height: _iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                _effectiveStyle.textColor ?? Colors.white,
              ),
            ),
          ),
          SizedBox(width: _spacing),
          Text(
            widget.connectingText,
            style: TextStyle(
              color: _effectiveStyle.textColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedButton(String address) {
    final displayAddress = widget.showFullAddress
        ? address
        : _truncateAddress(address);

    return _BaseButton(
      key: const ValueKey('connected'),
      onPressed: widget.enabled ? () => _showAccountMenu(context) : null,
      style: _effectiveStyle.copyWith(
        backgroundColor: _effectiveStyle.connectedBackgroundColor,
      ),
      size: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chain badge
          if (widget.showChainBadge) ...[
            _ChainBadge(chain: Web3Refi.instance.currentChain),
            SizedBox(width: _spacing),
          ],
          // Address
          Text(
            displayAddress,
            style: TextStyle(
              color: _effectiveStyle.connectedTextColor ?? _effectiveStyle.textColor,
              fontSize: _fontSize,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          SizedBox(width: _spacing / 2),
          // Dropdown indicator
          Icon(
            Icons.keyboard_arrow_down,
            size: _iconSize,
            color: _effectiveStyle.connectedTextColor ?? _effectiveStyle.textColor,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorButton() {
    return _BaseButton(
      key: const ValueKey('error'),
      onPressed: widget.enabled ? _connect : null,
      style: _effectiveStyle.copyWith(
        backgroundColor: Colors.red.shade600,
      ),
      size: widget.size,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.refresh,
            size: _iconSize,
            color: Colors.white,
          ),
          SizedBox(width: _spacing),
          const Text(
            'Retry Connection',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      await Web3Refi.instance.connect();
      widget.onConnected?.call();
    } on WalletException catch (e) {
      widget.onError?.call(e);
      if (mounted) {
        _showErrorSnackBar(e.toUserMessage());
      }
    } catch (e) {
      final error = WalletException.generic(e.toString());
      widget.onError?.call(error);
      if (mounted) {
        _showErrorSnackBar('Connection failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAccountMenu(BuildContext context) {
    final address = Web3Refi.instance.address!;
    final chain = Web3Refi.instance.currentChain;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AccountMenuSheet(
        address: address,
        chain: chain,
        onDisconnect: () async {
          Navigator.pop(context);
          await Web3Refi.instance.disconnect();
          widget.onDisconnected?.call();
        },
        onCopyAddress: () {
          Clipboard.setData(ClipboardData(text: address));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Address copied to clipboard'),
              duration: Duration(seconds: 2),
            ),
          );
        },
        onViewExplorer: () {
          Navigator.pop(context);
          // Launch URL to explorer
          final url = chain.getAddressUrl(address);
          // launchUrl(Uri.parse(url));
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _connect,
        ),
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 12) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  double get _iconSize {
    switch (widget.size) {
      case WalletButtonSize.small:
        return 16;
      case WalletButtonSize.medium:
        return 20;
      case WalletButtonSize.large:
        return 24;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case WalletButtonSize.small:
        return 13;
      case WalletButtonSize.medium:
        return 15;
      case WalletButtonSize.large:
        return 17;
    }
  }

  double get _spacing {
    switch (widget.size) {
      case WalletButtonSize.small:
        return 6;
      case WalletButtonSize.medium:
        return 8;
      case WalletButtonSize.large:
        return 10;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _BaseButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final WalletButtonStyle style;
  final WalletButtonSize size;
  final Widget child;

  const _BaseButton({
    super.key,
    required this.onPressed,
    required this.style,
    required this.size,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: style.backgroundColor ?? Theme.of(context).primaryColor,
      borderRadius: style.borderRadius ?? BorderRadius.circular(12),
      elevation: style.elevation ?? 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: style.borderRadius ?? BorderRadius.circular(12),
        child: Container(
          padding: _padding,
          decoration: BoxDecoration(
            borderRadius: style.borderRadius ?? BorderRadius.circular(12),
            border: style.border,
          ),
          child: child,
        ),
      ),
    );
  }

  EdgeInsets get _padding {
    switch (size) {
      case WalletButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case WalletButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
      case WalletButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    }
  }
}

class _ChainBadge extends StatelessWidget {
  final dynamic chain;

  const _ChainBadge({required this.chain});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        chain?.shortName ?? 'ETH',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _AccountMenuSheet extends StatelessWidget {
  final String address;
  final dynamic chain;
  final VoidCallback onDisconnect;
  final VoidCallback onCopyAddress;
  final VoidCallback onViewExplorer;

  const _AccountMenuSheet({
    required this.address,
    required this.chain,
    required this.onDisconnect,
    required this.onCopyAddress,
    required this.onViewExplorer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Address display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _generateGradient(address),
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Address & chain
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${address.substring(0, 6)}...${address.substring(address.length - 4)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          chain?.name ?? 'Ethereum',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions
            _MenuAction(
              icon: Icons.copy_outlined,
              label: 'Copy Address',
              onTap: onCopyAddress,
            ),
            _MenuAction(
              icon: Icons.open_in_new,
              label: 'View on Explorer',
              onTap: onViewExplorer,
            ),
            const Divider(height: 1),
            _MenuAction(
              icon: Icons.logout,
              label: 'Disconnect',
              onTap: onDisconnect,
              isDestructive: true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Color> _generateGradient(String address) {
    final hash = address.hashCode;
    return [
      Color((hash & 0xFFFFFF) | 0xFF000000),
      Color(((hash >> 8) & 0xFFFFFF) | 0xFF000000),
    ];
  }
}

class _MenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red : Colors.black87;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STYLE & SIZE
// ═══════════════════════════════════════════════════════════════════════════

/// Button size options.
enum WalletButtonSize { small, medium, large }

/// Style configuration for [WalletConnectButton].
class WalletButtonStyle {
  final Color? backgroundColor;
  final Color? textColor;
  final Color? connectedBackgroundColor;
  final Color? connectedTextColor;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final double? elevation;

  const WalletButtonStyle({
    this.backgroundColor,
    this.textColor,
    this.connectedBackgroundColor,
    this.connectedTextColor,
    this.borderRadius,
    this.border,
    this.elevation,
  });

  /// Default style based on theme.
  factory WalletButtonStyle.defaultStyle(BuildContext context) {
    final theme = Theme.of(context);
    return WalletButtonStyle(
      backgroundColor: theme.primaryColor,
      textColor: Colors.white,
      connectedBackgroundColor: Colors.green.shade600,
      connectedTextColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
    );
  }

  /// Outlined style variant.
  factory WalletButtonStyle.outlined(BuildContext context) {
    final theme = Theme.of(context);
    return WalletButtonStyle(
      backgroundColor: Colors.transparent,
      textColor: theme.primaryColor,
      connectedBackgroundColor: Colors.green.shade50,
      connectedTextColor: Colors.green.shade700,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: theme.primaryColor, width: 2),
      elevation: 0,
    );
  }

  /// Dark style variant.
  factory WalletButtonStyle.dark() {
    return WalletButtonStyle(
      backgroundColor: const Color(0xFF1A1A2E),
      textColor: Colors.white,
      connectedBackgroundColor: const Color(0xFF16213E),
      connectedTextColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
    );
  }

  WalletButtonStyle copyWith({
    Color? backgroundColor,
    Color? textColor,
    Color? connectedBackgroundColor,
    Color? connectedTextColor,
    BorderRadius? borderRadius,
    BoxBorder? border,
    double? elevation,
  }) {
    return WalletButtonStyle(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textColor: textColor ?? this.textColor,
      connectedBackgroundColor: connectedBackgroundColor ?? this.connectedBackgroundColor,
      connectedTextColor: connectedTextColor ?? this.connectedTextColor,
      borderRadius: borderRadius ?? this.borderRadius,
      border: border ?? this.border,
      elevation: elevation ?? this.elevation,
    );
  }
}
