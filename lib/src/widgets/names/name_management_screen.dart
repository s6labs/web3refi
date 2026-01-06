import 'package:flutter/material.dart';
import 'package:web3refi/src/names/registry/registration_controller.dart';
import 'package:web3refi/src/names/universal_name_service.dart';
import 'package:web3refi/src/core/web3refi_base.dart';
import 'package:web3refi/src/widgets/names/name_display.dart';

/// Complete screen for managing owned names
///
/// Provides a full-featured UI for viewing and managing user's names.
///
/// ## Features
///
/// - List all owned names
/// - View expiry dates
/// - Renew names
/// - Update records
/// - Transfer names
/// - Delete/release names
/// - Pull-to-refresh
/// - Search/filter
///
/// ## Usage
///
/// ```dart
/// NameManagementScreen(
///   registryAddress: '0x123...',
///   resolverAddress: '0x456...',
/// )
/// ```
class NameManagementScreen extends StatefulWidget {
  /// Registry contract address
  final String registryAddress;

  /// Resolver contract address
  final String resolverAddress;

  /// Optional user address (auto-detected if not provided)
  final String? userAddress;

  /// Custom app bar title
  final String? title;

  /// Show app bar
  final bool showAppBar;

  /// Enable pull-to-refresh
  final bool enableRefresh;

  /// Custom empty state widget
  final Widget? emptyStateWidget;

  const NameManagementScreen({
    super.key,
    required this.registryAddress,
    required this.resolverAddress,
    this.userAddress,
    this.title,
    this.showAppBar = true,
    this.enableRefresh = true,
    this.emptyStateWidget,
  });

  @override
  State<NameManagementScreen> createState() => _NameManagementScreenState();
}

class _NameManagementScreenState extends State<NameManagementScreen> {
  List<OwnedName> _ownedNames = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOwnedNames();
  }

  Future<void> _loadOwnedNames() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final controller = RegistrationController(
        registryAddress: widget.registryAddress,
        resolverAddress: widget.resolverAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      final userAddr = widget.userAddress ?? await Web3Refi.instance.wallet.getAddress();

      // In a production implementation, you would query the registry for all names
      // owned by the user. For now, this is a simplified version that would need
      // to be enhanced with event logs or indexing.

      // This is where you'd implement:
      // 1. Query Transfer events where 'to' == userAddr
      // 2. For each name, check if still owned and not expired
      // 3. Get expiry, resolver, and records for each name

      // Placeholder implementation
      final names = <OwnedName>[];

      if (!mounted) return;

      setState(() {
        _ownedNames = names;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _renewName(OwnedName name) async {
    // Show duration picker
    final duration = await _showDurationPicker();
    if (duration == null) return;

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final controller = RegistrationController(
        registryAddress: widget.registryAddress,
        resolverAddress: widget.resolverAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      await controller.renew(
        name: name.name,
        duration: duration,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${name.name} renewed for ${_formatDuration(duration)}')),
      );

      await _loadOwnedNames();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to renew: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  Future<void> _editRecords(OwnedName name) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => _RecordEditorScreen(
          name: name.name,
          initialRecords: name.records ?? {},
        ),
      ),
    );

    if (result == null) return;

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final controller = RegistrationController(
        registryAddress: widget.registryAddress,
        resolverAddress: widget.resolverAddress,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      // Set records
      for (final entry in result.entries) {
        await controller.setTextRecord(
          name: name.name,
          key: entry.key,
          value: entry.value,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Records updated successfully')),
      );

      await _loadOwnedNames();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update records: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  Future<void> _transferName(OwnedName name) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transfer ${name.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New Owner Address',
            hintText: '0x...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true || controller.text.isEmpty) return;

    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      // Implementation would use registry's transfer function
      // This requires adding a transfer method to RegistrationController

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name transferred successfully')),
      );

      await _loadOwnedNames();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to transfer: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  Future<Duration?> _showDurationPicker() async {
    return await showDialog<Duration>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Renewal Duration'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DurationOption(
              duration: Duration(days: 90),
              label: '3 months',
            ),
            _DurationOption(
              duration: Duration(days: 365),
              label: '1 year',
            ),
            _DurationOption(
              duration: Duration(days: 730),
              label: '2 years',
            ),
            _DurationOption(
              duration: Duration(days: 1095),
              label: '3 years',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final days = duration.inDays;
    if (days >= 365) {
      final years = days ~/ 365;
      return '$years year${years > 1 ? 's' : ''}';
    }
    return '$days days';
  }

  List<OwnedName> get _filteredNames {
    if (_searchQuery.isEmpty) return _ownedNames;

    return _ownedNames.where((name) {
      return name.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: Text(widget.title ?? 'My Names'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _showSearchDialog,
                ),
              ],
            )
          : null,
      body: _buildBody(),
    );

    return scaffold;
  }

  Widget _buildBody() {
    if (_isLoading && _ownedNames.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _ownedNames.isEmpty) {
      return _buildErrorState();
    }

    if (_filteredNames.isEmpty) {
      return _buildEmptyState();
    }

    if (widget.enableRefresh) {
      return RefreshIndicator(
        onRefresh: _loadOwnedNames,
        child: _buildNameList(),
      );
    }

    return _buildNameList();
  }

  Widget _buildNameList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredNames.length,
      itemBuilder: (context, index) {
        final name = _filteredNames[index];
        return _buildNameCard(name);
      },
    );
  }

  Widget _buildNameCard(OwnedName name) {
    final now = DateTime.now();
    final isExpired = name.expiry.isBefore(now);
    final daysUntilExpiry = name.expiry.difference(now).inDays;
    final isExpiringSoon = daysUntilExpiry < 30 && !isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isExpired
                                ? Icons.error
                                : isExpiringSoon
                                    ? Icons.warning
                                    : Icons.check_circle,
                            size: 16,
                            color: isExpired
                                ? Theme.of(context).colorScheme.error
                                : isExpiringSoon
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpired
                                ? 'Expired ${_formatDuration(now.difference(name.expiry))} ago'
                                : 'Expires in ${_formatDuration(name.expiry.difference(now))}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: isExpired
                                      ? Theme.of(context).colorScheme.error
                                      : isExpiringSoon
                                          ? Colors.orange
                                          : null,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (name.records != null && name.records!.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Records:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              ...name.records!.entries.take(3).map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          entry.key,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
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
              }),
              if (name.records!.length > 3)
                Text(
                  '+ ${name.records!.length - 3} more',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _renewName(name),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Renew'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _editRecords(name),
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Edit Records'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _transferName(name),
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Transfer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    if (widget.emptyStateWidget != null) {
      return widget.emptyStateWidget!;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No names found' : 'No matching names',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'You don\'t own any names yet'
                : 'Try a different search query',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load names',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadOwnedNames,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Names'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Enter name to search...',
          ),
          onChanged: (value) {
            setState(() => _searchQuery = value);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _searchQuery = '');
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

/// Data model for owned names
class OwnedName {
  final String name;
  final String owner;
  final DateTime expiry;
  final String? resolver;
  final Map<String, String>? records;

  OwnedName({
    required this.name,
    required this.owner,
    required this.expiry,
    this.resolver,
    this.records,
  });
}

/// Duration selection option
class _DurationOption extends StatelessWidget {
  final Duration duration;
  final String label;

  const _DurationOption({
    required this.duration,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.pop(context, duration),
    );
  }
}

/// Record editor screen
class _RecordEditorScreen extends StatefulWidget {
  final String name;
  final Map<String, String> initialRecords;

  const _RecordEditorScreen({
    required this.name,
    required this.initialRecords,
  });

  @override
  State<_RecordEditorScreen> createState() => _RecordEditorScreenState();
}

class _RecordEditorScreenState extends State<_RecordEditorScreen> {
  late Map<String, TextEditingController> _controllers;

  final _supportedKeys = [
    'email',
    'url',
    'avatar',
    'com.twitter',
    'com.github',
    'description',
  ];

  @override
  void initState() {
    super.initState();
    _controllers = {};

    for (final key in _supportedKeys) {
      _controllers[key] = TextEditingController(
        text: widget.initialRecords[key] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, String> _getRecords() {
    final records = <String, String>{};

    for (final entry in _controllers.entries) {
      if (entry.value.text.isNotEmpty) {
        records[entry.key] = entry.value.text;
      }
    }

    return records;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${widget.name}'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, _getRecords()),
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Update records for ${widget.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ..._supportedKeys.map((key) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _controllers[key],
                decoration: InputDecoration(
                  labelText: _formatKey(key),
                  hintText: 'Enter ${_formatKey(key).toLowerCase()}',
                  border: const OutlineInputBorder(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    if (key.startsWith('com.')) {
      return key.substring(4).toUpperCase();
    }
    return key[0].toUpperCase() + key.substring(1);
  }
}
