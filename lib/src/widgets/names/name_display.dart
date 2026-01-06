import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web3refi/src/names/universal_name_service.dart';
import 'package:web3refi/src/core/web3refi_base.dart';

/// Display widget for showing names with avatars and metadata
///
/// Shows a name or address with optional avatar, records, and actions.
///
/// ## Features
///
/// - Auto-resolves address to name (reverse resolution)
/// - Displays avatar from name records
/// - Shows additional metadata (email, url, twitter, etc.)
/// - Copy address/name functionality
/// - Customizable layout (row, column, card)
/// - Loading and error states
///
/// ## Usage
///
/// ```dart
/// NameDisplay(
///   address: '0x123...',
///   showAvatar: true,
///   showMetadata: true,
/// )
/// ```
class NameDisplay extends StatefulWidget {
  /// Address to display/resolve
  final String address;

  /// Optional pre-resolved name
  final String? name;

  /// Show avatar image
  final bool showAvatar;

  /// Show metadata (email, url, etc.)
  final bool showMetadata;

  /// Enable copy functionality
  final bool enableCopy;

  /// Layout style
  final NameDisplayLayout layout;

  /// Avatar size
  final double avatarSize;

  /// Custom avatar fallback
  final Widget? avatarFallback;

  /// On tap callback
  final VoidCallback? onTap;

  /// Custom name style
  final TextStyle? nameStyle;

  /// Custom address style
  final TextStyle? addressStyle;

  const NameDisplay({
    super.key,
    required this.address,
    this.name,
    this.showAvatar = true,
    this.showMetadata = false,
    this.enableCopy = true,
    this.layout = NameDisplayLayout.row,
    this.avatarSize = 40,
    this.avatarFallback,
    this.onTap,
    this.nameStyle,
    this.addressStyle,
  });

  @override
  State<NameDisplay> createState() => _NameDisplayState();
}

class _NameDisplayState extends State<NameDisplay> {
  String? _resolvedName;
  String? _avatarUrl;
  Map<String, String>? _metadata;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveNameAndRecords();
  }

  @override
  void didUpdateWidget(NameDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address != widget.address) {
      _resolveNameAndRecords();
    }
  }

  Future<void> _resolveNameAndRecords() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final uns = Web3Refi.instance.names;

      // Reverse resolve if name not provided
      if (widget.name == null) {
        _resolvedName = await uns.reverseResolve(widget.address);
      } else {
        _resolvedName = widget.name;
      }

      // Get records if name was found
      if (_resolvedName != null) {
        final records = await uns.getRecords(_resolvedName!);

        if (!mounted) return;

        setState(() {
          _avatarUrl = records?.avatar;
          _metadata = widget.showMetadata ? records?.texts : null;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $text'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _shortenAddress(String address) {
    if (address.length <= 13) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    switch (widget.layout) {
      case NameDisplayLayout.row:
        return _buildRowLayout();
      case NameDisplayLayout.column:
        return _buildColumnLayout();
      case NameDisplayLayout.card:
        return _buildCardLayout();
    }
  }

  Widget _buildLoadingState() {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Resolving...'),
      ],
    );
  }

  Widget _buildErrorState() {
    return Row(
      children: [
        Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Failed to load name',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    );
  }

  Widget _buildRowLayout() {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            if (widget.showAvatar) ...[
              _buildAvatar(),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_resolvedName != null)
                    Text(
                      _resolvedName!,
                      style: widget.nameStyle ??
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                    ),
                  Text(
                    _shortenAddress(widget.address),
                    style: widget.addressStyle ??
                        Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                  ),
                ],
              ),
            ),
            if (widget.enableCopy)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                onPressed: () => _copyToClipboard(_resolvedName ?? widget.address),
                tooltip: 'Copy ${_resolvedName != null ? 'name' : 'address'}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnLayout() {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (widget.showAvatar) ...[
              _buildAvatar(),
              const SizedBox(height: 12),
            ],
            if (_resolvedName != null) ...[
              Text(
                _resolvedName!,
                style: widget.nameStyle ??
                    Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
            ],
            Text(
              _shortenAddress(widget.address),
              style: widget.addressStyle ??
                  Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      ),
              textAlign: TextAlign.center,
            ),
            if (widget.enableCopy) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: Text(_resolvedName != null ? 'Copy Name' : 'Copy Address'),
                onPressed: () => _copyToClipboard(_resolvedName ?? widget.address),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardLayout() {
    return Card(
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (widget.showAvatar) ...[
                    _buildAvatar(),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_resolvedName != null)
                          Text(
                            _resolvedName!,
                            style: widget.nameStyle ??
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        Text(
                          _shortenAddress(widget.address),
                          style: widget.addressStyle ??
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.enableCopy)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => _copyToClipboard(_resolvedName ?? widget.address),
                    ),
                ],
              ),
              if (_metadata != null && _metadata!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ..._buildMetadata(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: widget.avatarSize / 2,
        backgroundImage: NetworkImage(_avatarUrl!),
        onBackgroundImageError: (_, __) {
          // Fallback handled by child
        },
        child: widget.avatarFallback,
      );
    }

    return widget.avatarFallback ??
        CircleAvatar(
          radius: widget.avatarSize / 2,
          child: Text(
            (_resolvedName ?? widget.address).substring(0, 2).toUpperCase(),
            style: TextStyle(
              fontSize: widget.avatarSize / 3,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
  }

  List<Widget> _buildMetadata() {
    if (_metadata == null) return [];

    return _metadata!.entries.map((entry) {
      IconData icon;
      switch (entry.key) {
        case 'email':
          icon = Icons.email;
          break;
        case 'url':
          icon = Icons.link;
          break;
        case 'com.twitter':
          icon = Icons.tag;
          break;
        case 'com.github':
          icon = Icons.code;
          break;
        default:
          icon = Icons.info;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              _formatMetadataKey(entry.key),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.value,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatMetadataKey(String key) {
    if (key.startsWith('com.')) {
      return key.substring(4).toUpperCase();
    }
    return key[0].toUpperCase() + key.substring(1);
  }
}

enum NameDisplayLayout {
  row,
  column,
  card,
}
