import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web3refi/src/core/web3refi_base.dart';

/// Displays a token balance with automatic formatting.
///
/// Fetches the balance once when the widget is built.
/// For live updates, use [LiveTokenBalanceWidget] instead.
///
/// Example:
/// ```dart
/// TokenBalanceWidget(
///   tokenAddress: Tokens.usdcPolygon,
///   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
/// )
/// ```
class TokenBalanceWidget extends StatefulWidget {
  /// The token contract address.
  final String tokenAddress;

  /// Address to check balance for. Defaults to connected wallet.
  final String? ownerAddress;

  /// Text style for the balance.
  final TextStyle? style;

  /// Whether to show the token symbol.
  final bool showSymbol;

  /// Whether to show loading indicator.
  final bool showLoading;

  /// Number of decimal places to display.
  final int? displayDecimals;

  /// Custom prefix (e.g., "$" for USD value).
  final String? prefix;

  /// Custom suffix.
  final String? suffix;

  /// Widget to show while loading.
  final Widget? loadingWidget;

  /// Widget to show on error.
  final Widget? errorWidget;

  /// Callback when balance is loaded.
  final void Function(BigInt balance, String formatted)? onBalanceLoaded;

  /// Custom number formatter.
  final String Function(String amount)? formatter;

  const TokenBalanceWidget({
    required this.tokenAddress, super.key,
    this.ownerAddress,
    this.style,
    this.showSymbol = true,
    this.showLoading = true,
    this.displayDecimals,
    this.prefix,
    this.suffix,
    this.loadingWidget,
    this.errorWidget,
    this.onBalanceLoaded,
    this.formatter,
  });

  @override
  State<TokenBalanceWidget> createState() => _TokenBalanceWidgetState();
}

class _TokenBalanceWidgetState extends State<TokenBalanceWidget> {
  late Future<_BalanceData> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void didUpdateWidget(TokenBalanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokenAddress != widget.tokenAddress ||
        oldWidget.ownerAddress != widget.ownerAddress) {
      _loadBalance();
    }
  }

  void _loadBalance() {
    _balanceFuture = _fetchBalance();
  }

  Future<_BalanceData> _fetchBalance() async {
    final token = Web3Refi.instance.token(widget.tokenAddress);
    final owner = widget.ownerAddress ?? Web3Refi.instance.address;
    
    if (owner == null) {
      throw StateError('No wallet connected and no owner address provided');
    }

    final balance = await token.balanceOf(owner);
    final formatted = await token.formatAmount(
      balance,
      displayDecimals: widget.displayDecimals,
    );
    final symbol = widget.showSymbol ? await token.symbol() : '';

    widget.onBalanceLoaded?.call(balance, formatted);

    return _BalanceData(
      raw: balance,
      formatted: formatted,
      symbol: symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BalanceData>(
      future: _balanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? _buildLoading();
        }

        if (snapshot.hasError) {
          return widget.errorWidget ?? _buildError(snapshot.error!);
        }

        final data = snapshot.data!;
        return _buildBalance(data);
      },
    );
  }

  Widget _buildLoading() {
    if (!widget.showLoading) {
      return Text('--', style: widget.style);
    }
    
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.style?.color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Tooltip(
      message: error.toString(),
      child: Text(
        'Error',
        style: widget.style?.copyWith(color: Colors.red) ??
            const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildBalance(_BalanceData data) {
    String displayAmount = data.formatted;
    
    // Apply custom formatter
    if (widget.formatter != null) {
      displayAmount = widget.formatter!(displayAmount);
    }

    // Build display string
    final buffer = StringBuffer();
    if (widget.prefix != null) buffer.write(widget.prefix);
    buffer.write(displayAmount);
    if (widget.showSymbol && data.symbol.isNotEmpty) {
      buffer.write(' ${data.symbol}');
    }
    if (widget.suffix != null) buffer.write(widget.suffix);

    return Text(
      buffer.toString(),
      style: widget.style,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LIVE TOKEN BALANCE
// ═══════════════════════════════════════════════════════════════════════════

/// Displays a token balance with automatic live updates.
///
/// Polls the balance at the specified interval.
///
/// Example:
/// ```dart
/// LiveTokenBalanceWidget(
///   tokenAddress: Tokens.usdcPolygon,
///   updateInterval: Duration(seconds: 10),
///   style: TextStyle(fontSize: 24),
/// )
/// ```
class LiveTokenBalanceWidget extends StatefulWidget {
  /// The token contract address.
  final String tokenAddress;

  /// Address to check balance for. Defaults to connected wallet.
  final String? ownerAddress;

  /// How often to refresh the balance.
  final Duration updateInterval;

  /// Text style for the balance.
  final TextStyle? style;

  /// Whether to show the token symbol.
  final bool showSymbol;

  /// Number of decimal places to display.
  final int? displayDecimals;

  /// Custom prefix.
  final String? prefix;

  /// Widget to show while loading initially.
  final Widget? loadingWidget;

  /// Whether to animate balance changes.
  final bool animateChanges;

  /// Callback when balance changes.
  final void Function(BigInt oldBalance, BigInt newBalance)? onBalanceChanged;

  const LiveTokenBalanceWidget({
    required this.tokenAddress, super.key,
    this.ownerAddress,
    this.updateInterval = const Duration(seconds: 15),
    this.style,
    this.showSymbol = true,
    this.displayDecimals,
    this.prefix,
    this.loadingWidget,
    this.animateChanges = true,
    this.onBalanceChanged,
  });

  @override
  State<LiveTokenBalanceWidget> createState() => _LiveTokenBalanceWidgetState();
}

class _LiveTokenBalanceWidgetState extends State<LiveTokenBalanceWidget>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  _BalanceData? _currentData;
  bool _isLoading = true;
  String? _error;
  
  late AnimationController _flashController;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(LiveTokenBalanceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tokenAddress != widget.tokenAddress ||
        oldWidget.ownerAddress != widget.ownerAddress ||
        oldWidget.updateInterval != widget.updateInterval) {
      _timer?.cancel();
      _startPolling();
    }
  }

  void _startPolling() {
    _fetchBalance();
    _timer = Timer.periodic(widget.updateInterval, (_) => _fetchBalance());
  }

  Future<void> _fetchBalance() async {
    try {
      final token = Web3Refi.instance.token(widget.tokenAddress);
      final owner = widget.ownerAddress ?? Web3Refi.instance.address;
      
      if (owner == null) {
        setState(() {
          _error = 'No wallet connected';
          _isLoading = false;
        });
        return;
      }

      final balance = await token.balanceOf(owner);
      final formatted = await token.formatAmount(
        balance,
        displayDecimals: widget.displayDecimals,
      );
      final symbol = widget.showSymbol ? await token.symbol() : '';

      if (mounted) {
        final newData = _BalanceData(
          raw: balance,
          formatted: formatted,
          symbol: symbol,
        );

        // Check if balance changed
        if (_currentData != null && _currentData!.raw != balance) {
          widget.onBalanceChanged?.call(_currentData!.raw, balance);
          
          if (widget.animateChanges) {
            _flashColor = balance > _currentData!.raw
                ? Colors.green
                : Colors.red;
            _flashController.forward().then((_) {
              _flashController.reverse();
              _flashColor = null;
            });
          }
        }

        setState(() {
          _currentData = newData;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _currentData == null) {
      return widget.loadingWidget ?? _buildLoading();
    }

    if (_error != null && _currentData == null) {
      return _buildError();
    }

    return AnimatedBuilder(
      animation: _flashController,
      builder: (context, child) {
        return Container(
          decoration: _flashColor != null
              ? BoxDecoration(
                  color: _flashColor!.withOpacity(0.2 * (1 - _flashController.value)),
                  borderRadius: BorderRadius.circular(4),
                )
              : null,
          padding: _flashColor != null
              ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
              : null,
          child: child,
        );
      },
      child: _buildBalance(),
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.style?.color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Tooltip(
      message: _error,
      child: Text(
        'Error',
        style: widget.style?.copyWith(color: Colors.red) ??
            const TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildBalance() {
    final data = _currentData!;
    final buffer = StringBuffer();
    
    if (widget.prefix != null) buffer.write(widget.prefix);
    buffer.write(data.formatted);
    if (widget.showSymbol && data.symbol.isNotEmpty) {
      buffer.write(' ${data.symbol}');
    }

    return Text(
      buffer.toString(),
      style: widget.style,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NATIVE BALANCE WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// Displays native currency balance (ETH, MATIC, etc.).
///
/// Example:
/// ```dart
/// NativeBalance(
///   style: TextStyle(fontSize: 20),
///   showSymbol: true,
/// )
/// ```
class NativeBalance extends StatefulWidget {
  /// Address to check balance for. Defaults to connected wallet.
  final String? ownerAddress;

  /// Text style for the balance.
  final TextStyle? style;

  /// Whether to show the currency symbol.
  final bool showSymbol;

  /// Widget to show while loading.
  final Widget? loadingWidget;

  /// Number of decimal places to display.
  final int displayDecimals;

  const NativeBalance({
    super.key,
    this.ownerAddress,
    this.style,
    this.showSymbol = true,
    this.loadingWidget,
    this.displayDecimals = 4,
  });

  @override
  State<NativeBalance> createState() => _NativeBalanceState();
}

class _NativeBalanceState extends State<NativeBalance> {
  late Future<_NativeBalanceData> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  void _loadBalance() {
    _balanceFuture = _fetchBalance();
  }

  Future<_NativeBalanceData> _fetchBalance() async {
    final owner = widget.ownerAddress ?? Web3Refi.instance.address;
    
    if (owner == null) {
      throw StateError('No wallet connected');
    }

    final balance = await Web3Refi.instance.getNativeBalance(owner);
    final formatted = Web3Refi.instance.formatNativeAmount(balance);
    final symbol = Web3Refi.instance.currentChain.symbol;

    return _NativeBalanceData(
      raw: balance,
      formatted: formatted,
      symbol: symbol,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_NativeBalanceData>(
      future: _balanceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return widget.loadingWidget ?? _buildLoading();
        }

        if (snapshot.hasError) {
          return _buildError();
        }

        final data = snapshot.data!;
        final buffer = StringBuffer();
        buffer.write(data.formatted);
        if (widget.showSymbol) {
          buffer.write(' ${data.symbol}');
        }

        return Text(buffer.toString(), style: widget.style);
      },
    );
  }

  Widget _buildLoading() {
    return SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(
          widget.style?.color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildError() {
    return Text(
      '--',
      style: widget.style,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BALANCE CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════

/// A complete balance card with token info, balance, and optional USD value.
///
/// Example:
/// ```dart
/// BalanceCard(
///   tokenAddress: Tokens.usdcPolygon,
///   tokenName: 'USD Coin',
///   tokenIcon: 'assets/usdc.png',
///   onTap: () => navigateToTokenDetails(),
/// )
/// ```
class BalanceCard extends StatelessWidget {
  final String tokenAddress;
  final String tokenName;
  final String? tokenIcon;
  final VoidCallback? onTap;
  final bool showUsdValue;
  final double? usdPrice;

  const BalanceCard({
    required this.tokenAddress, required this.tokenName, super.key,
    this.tokenIcon,
    this.onTap,
    this.showUsdValue = false,
    this.usdPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Token icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: tokenIcon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(tokenIcon!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.toll,
                        color: Colors.grey.shade400,
                      ),
              ),
              const SizedBox(width: 12),
              // Token info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tokenName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    TokenBalanceWidget(
                      tokenAddress: tokenAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      showSymbol: true,
                    ),
                  ],
                ),
              ),
              // Arrow
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey.shade400,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ═══════════════════════════════════════════════════════════════════════════

class _BalanceData {
  final BigInt raw;
  final String formatted;
  final String symbol;

  _BalanceData({
    required this.raw,
    required this.formatted,
    required this.symbol,
  });
}

class _NativeBalanceData {
  final BigInt raw;
  final String formatted;
  final String symbol;

  _NativeBalanceData({
    required this.raw,
    required this.formatted,
    required this.symbol,
  });
}
