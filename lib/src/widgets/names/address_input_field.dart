import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3refi/src/names/universal_name_service.dart';
import 'package:web3refi/src/core/web3refi_base.dart';

/// Auto-resolving address input field with name service support
///
/// Automatically resolves names to addresses as the user types.
/// Supports all name formats (ENS, Unstoppable, CiFi, etc.)
///
/// ## Features
///
/// - Real-time name resolution
/// - Address validation
/// - Debounced resolution (prevents excessive RPC calls)
/// - Loading state indicator
/// - Error state display
/// - Copy/paste support
/// - Custom styling
///
/// ## Usage
///
/// ```dart
/// AddressInputField(
///   onAddressResolved: (address) {
///     setState(() => recipient = address);
///   },
///   label: 'Recipient',
///   hint: 'Enter address or name',
/// )
/// ```
class AddressInputField extends StatefulWidget {
  /// Callback when an address is successfully resolved
  final ValueChanged<String>? onAddressResolved;

  /// Callback when the input text changes
  final ValueChanged<String>? onChanged;

  /// Initial value
  final String? initialValue;

  /// Label text
  final String? label;

  /// Hint text
  final String? hint;

  /// Whether the field is required
  final bool required;

  /// Whether to show the resolved address below input
  final bool showResolvedAddress;

  /// Whether to auto-validate on input
  final bool autoValidate;

  /// Custom resolution delay (default: 500ms)
  final Duration? resolutionDelay;

  /// Enable copy button for resolved address
  final bool enableCopy;

  /// Custom decoration
  final InputDecoration? decoration;

  /// Text style
  final TextStyle? style;

  /// Controller (optional, for external control)
  final TextEditingController? controller;

  const AddressInputField({
    super.key,
    this.onAddressResolved,
    this.onChanged,
    this.initialValue,
    this.label,
    this.hint,
    this.required = false,
    this.showResolvedAddress = true,
    this.autoValidate = true,
    this.resolutionDelay,
    this.enableCopy = true,
    this.decoration,
    this.style,
    this.controller,
  });

  @override
  State<AddressInputField> createState() => _AddressInputFieldState();
}

class _AddressInputFieldState extends State<AddressInputField> {
  late TextEditingController _controller;
  String? _resolvedAddress;
  String? _resolvedName;
  bool _isResolving = false;
  String? _errorMessage;
  DateTime? _lastInputTime;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text.trim();

    widget.onChanged?.call(text);

    if (text.isEmpty) {
      setState(() {
        _resolvedAddress = null;
        _resolvedName = null;
        _errorMessage = null;
        _isResolving = false;
      });
      return;
    }

    // Update last input time
    _lastInputTime = DateTime.now();

    // Debounce resolution
    final delay = widget.resolutionDelay ?? const Duration(milliseconds: 500);
    Future.delayed(delay, () {
      if (_lastInputTime != null &&
          DateTime.now().difference(_lastInputTime!) >= delay) {
        _resolveAddress(text);
      }
    });
  }

  Future<void> _resolveAddress(String input) async {
    if (!mounted) return;

    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      // Check if input is already an address
      if (_isValidAddress(input)) {
        setState(() {
          _resolvedAddress = input;
          _resolvedName = null;
          _isResolving = false;
        });
        widget.onAddressResolved?.call(input);
        return;
      }

      // Try to resolve as name
      final uns = Web3Refi.instance.names;
      final address = await uns.resolve(input);

      if (!mounted) return;

      if (address != null) {
        setState(() {
          _resolvedAddress = address;
          _resolvedName = input;
          _isResolving = false;
          _errorMessage = null;
        });
        widget.onAddressResolved?.call(address);
      } else {
        setState(() {
          _resolvedAddress = null;
          _resolvedName = null;
          _isResolving = false;
          _errorMessage = 'Could not resolve "$input"';
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _resolvedAddress = null;
        _resolvedName = null;
        _isResolving = false;
        _errorMessage = 'Resolution error: ${e.toString()}';
      });
    }
  }

  bool _isValidAddress(String address) {
    // Basic Ethereum address validation
    final ethAddressRegex = RegExp(r'^0x[a-fA-F0-9]{40}$');
    return ethAddressRegex.hasMatch(address);
  }

  void _copyAddress() {
    if (_resolvedAddress != null) {
      Clipboard.setData(ClipboardData(text: _resolvedAddress!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Address copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Input field
        TextField(
          controller: _controller,
          style: widget.style,
          decoration: widget.decoration ??
              InputDecoration(
                labelText: widget.label ?? 'Address or Name',
                hintText: widget.hint ?? 'Enter address or name (e.g., vitalik.eth, @alice)',
                border: const OutlineInputBorder(),
                suffixIcon: _buildSuffixIcon(),
                errorText: widget.autoValidate ? _errorMessage : null,
              ),
        ),

        // Resolved address display
        if (widget.showResolvedAddress && _resolvedAddress != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_resolvedName != null)
                          Text(
                            'Resolved: $_resolvedName',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          _resolvedAddress!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.enableCopy)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: _copyAddress,
                      tooltip: 'Copy address',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),

        // Error message (when not using autoValidate)
        if (!widget.autoValidate && _errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: theme.colorScheme.error,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (_isResolving) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_resolvedAddress != null) {
      return Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    if (_errorMessage != null) {
      return Icon(
        Icons.error,
        color: Theme.of(context).colorScheme.error,
      );
    }

    return null;
  }
}
