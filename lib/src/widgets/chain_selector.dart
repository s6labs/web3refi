import 'package:flutter/material.dart';
import '../core/web3refi_base.dart';
import '../models/chain.dart';
import '../constants/chains.dart';

/// A dropdown selector for switching between blockchain networks.
///
/// Automatically integrates with Web3Refi to switch chains.
///
/// Example:
/// ```dart
/// ChainSelector(
///   chains: [Chains.ethereum, Chains.polygon, Chains.arbitrum],
///   onChanged: (chain) => print('Switched to ${chain.name}'),
/// )
/// ```
class ChainSelector extends StatefulWidget {
  /// List of chains to show in the selector.
  /// If null, uses all chains from Web3Refi config.
  final List<Chain>? chains;

  /// Called when a chain is selected.
  final void Function(Chain chain)? onChanged;

  /// Whether to automatically switch chains via Web3Refi.
  final bool autoSwitch;

  /// Custom builder for each chain item.
  final Widget Function(Chain chain, bool isSelected)? itemBuilder;

  /// Style variant.
  final ChainSelectorStyle style;

  /// Whether the selector is enabled.
  final bool enabled;

  /// Whether to show chain icons.
  final bool showIcons;

  /// Whether to show testnet chains.
  final bool showTestnets;

  const ChainSelector({
    super.key,
    this.chains,
    this.onChanged,
    this.autoSwitch = true,
    this.itemBuilder,
    this.style = ChainSelectorStyle.dropdown,
    this.enabled = true,
    this.showIcons = true,
    this.showTestnets = false,
  });

  @override
  State<ChainSelector> createState() => _ChainSelectorState();
}

class _ChainSelectorState extends State<ChainSelector> {
  bool _isSwitching = false;

  List<Chain> get _chains {
    var chains = widget.chains ?? Web3Refi.instance.config.chains;
    if (!widget.showTestnets) {
      chains = chains.where((c) => !c.isTestnet).toList();
    }
    return chains;
  }

  Chain get _currentChain => Web3Refi.instance.currentChain;

  @override
  void initState() {
    super.initState();
    Web3Refi.instance.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    Web3Refi.instance.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _selectChain(Chain chain) async {
    if (chain.chainId == _currentChain.chainId) return;
    if (_isSwitching) return;

    setState(() => _isSwitching = true);

    try {
      if (widget.autoSwitch) {
        await Web3Refi.instance.switchChain(chain);
      }
      widget.onChanged?.call(chain);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch to ${chain.name}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSwitching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case ChainSelectorStyle.dropdown:
        return _buildDropdown();
      case ChainSelectorStyle.chips:
        return _buildChips();
      case ChainSelectorStyle.list:
        return _buildList();
      case ChainSelectorStyle.modal:
        return _buildModalTrigger();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DROPDOWN STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _currentChain.chainId,
          icon: _isSwitching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.keyboard_arrow_down),
          items: _chains.map((chain) {
            return DropdownMenuItem<int>(
              value: chain.chainId,
              child: widget.itemBuilder?.call(chain, chain.chainId == _currentChain.chainId) ??
                  _ChainItem(
                    chain: chain,
                    showIcon: widget.showIcons,
                    isSelected: chain.chainId == _currentChain.chainId,
                  ),
            );
          }).toList(),
          onChanged: widget.enabled && !_isSwitching
              ? (chainId) {
                  if (chainId != null) {
                    final chain = _chains.firstWhere((c) => c.chainId == chainId);
                    _selectChain(chain);
                  }
                }
              : null,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHIPS STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _chains.map((chain) {
          final isSelected = chain.chainId == _currentChain.chainId;
          
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: widget.itemBuilder?.call(chain, isSelected) ??
                _ChainChip(
                  chain: chain,
                  isSelected: isSelected,
                  isLoading: _isSwitching && isSelected,
                  showIcon: widget.showIcons,
                  onTap: widget.enabled ? () => _selectChain(chain) : null,
                ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIST STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildList() {
    return Column(
      children: _chains.map((chain) {
        final isSelected = chain.chainId == _currentChain.chainId;
        
        return widget.itemBuilder?.call(chain, isSelected) ??
            _ChainListTile(
              chain: chain,
              isSelected: isSelected,
              isLoading: _isSwitching && isSelected,
              showIcon: widget.showIcons,
              onTap: widget.enabled ? () => _selectChain(chain) : null,
            );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODAL STYLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildModalTrigger() {
    return InkWell(
      onTap: widget.enabled ? () => _showChainModal(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcons) ...[
              _ChainIcon(chain: _currentChain, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              _currentChain.shortName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 20),
          ],
        ),
      ),
    );
  }

  void _showChainModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChainModalSheet(
        chains: _chains,
        currentChainId: _currentChain.chainId,
        showIcons: widget.showIcons,
        onSelect: (chain) {
          Navigator.pop(context);
          _selectChain(chain);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUPPORTING WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _ChainItem extends StatelessWidget {
  final Chain chain;
  final bool showIcon;
  final bool isSelected;

  const _ChainItem({
    required this.chain,
    required this.showIcon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          _ChainIcon(chain: chain, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          chain.name,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (chain.isTestnet) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'TEST',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ChainChip extends StatelessWidget {
  final Chain chain;
  final bool isSelected;
  final bool isLoading;
  final bool showIcon;
  final VoidCallback? onTap;

  const _ChainChip({
    required this.chain,
    required this.isSelected,
    required this.isLoading,
    required this.showIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? Theme.of(context).primaryColor
          : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                )
              else if (showIcon)
                _ChainIcon(chain: chain, size: 16),
              if (showIcon || isLoading) const SizedBox(width: 6),
              Text(
                chain.shortName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChainListTile extends StatelessWidget {
  final Chain chain;
  final bool isSelected;
  final bool isLoading;
  final bool showIcon;
  final VoidCallback? onTap;

  const _ChainListTile({
    required this.chain,
    required this.isSelected,
    required this.isLoading,
    required this.showIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: showIcon ? _ChainIcon(chain: chain, size: 32) : null,
      title: Text(
        chain.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        'Chain ID: ${chain.chainId}',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: isSelected
          ? isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                )
          : null,
    );
  }
}

class _ChainIcon extends StatelessWidget {
  final Chain chain;
  final double size;

  const _ChainIcon({required this.chain, required this.size});

  @override
  Widget build(BuildContext context) {
    // If chain has icon URL, use it
    if (chain.iconUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          chain.iconUrl!,
          width: size,
          height: size,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _getChainColor(chain),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          chain.symbol.substring(0, 1),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getChainColor(Chain chain) {
    // Return appropriate color for each chain
    switch (chain.chainId) {
      case 1: // Ethereum
        return const Color(0xFF627EEA);
      case 137: // Polygon
        return const Color(0xFF8247E5);
      case 42161: // Arbitrum
        return const Color(0xFF28A0F0);
      case 10: // Optimism
        return const Color(0xFFFF0420);
      case 8453: // Base
        return const Color(0xFF0052FF);
      case 56: // BSC
        return const Color(0xFFF0B90B);
      case 43114: // Avalanche
        return const Color(0xFFE84142);
      default:
        return Colors.grey;
    }
  }
}

class _ChainModalSheet extends StatelessWidget {
  final List<Chain> chains;
  final int currentChainId;
  final bool showIcons;
  final void Function(Chain) onSelect;

  const _ChainModalSheet({
    required this.chains,
    required this.currentChainId,
    required this.showIcons,
    required this.onSelect,
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
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Network',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),
            // Chains list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: chains.length,
                itemBuilder: (context, index) {
                  final chain = chains[index];
                  final isSelected = chain.chainId == currentChainId;
                  
                  return ListTile(
                    onTap: () => onSelect(chain),
                    leading: showIcons ? _ChainIcon(chain: chain, size: 36) : null,
                    title: Row(
                      children: [
                        Text(
                          chain.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        if (chain.isTestnet) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'TESTNET',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      chain.symbol,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          )
                        : null,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STYLE ENUM
// ═══════════════════════════════════════════════════════════════════════════

/// Visual style for [ChainSelector].
enum ChainSelectorStyle {
  /// Standard dropdown menu.
  dropdown,

  /// Horizontal scrollable chips.
  chips,

  /// Vertical list.
  list,

  /// Compact trigger that opens a modal sheet.
  modal,
}
