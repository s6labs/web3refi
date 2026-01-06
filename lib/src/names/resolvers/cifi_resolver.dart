import '../../cifi/client.dart';
import '../name_resolver.dart';
import '../resolution_result.dart';

/// CiFi-based universal name resolver.
///
/// Resolves @usernames using CiFi's global identity system.
/// Works on ANY blockchain that the user has linked to their CiFi profile.
///
/// ## Features
///
/// - Resolves @username or username.cifi to addresses
/// - Multi-chain support (one username, all chains)
/// - Reverse resolution (address → @username)
/// - Free (no gas fees, no registration cost)
/// - Instant (no blockchain queries needed)
///
/// ## Usage
///
/// ```dart
/// final cifi = CiFiResolver(cifiClient);
///
/// // Resolve for Ethereum
/// final ethAddr = await cifi.resolve('@alice', chainId: 1);
///
/// // Resolve for Polygon
/// final polyAddr = await cifi.resolve('@alice', chainId: 137);
///
/// // Resolve for Bitcoin
/// final btcAddr = await cifi.resolve('@alice', chainId: 0); // Bitcoin
///
/// // Reverse resolve
/// final username = await cifi.reverseResolve('0x742d...');
/// print(username); // '@alice'
/// ```
class CiFiResolver extends NameResolver {
  final CiFiClient _client;

  CiFiResolver(this._client);

  @override
  String get id => 'cifi';

  @override
  List<String> get supportedTLDs => ['cifi']; // Also handles @username format

  @override
  List<int> get supportedChainIds => [
        1, // Ethereum
        137, // Polygon
        42161, // Arbitrum
        8453, // Base
        10, // Optimism
        43114, // Avalanche
        50, // XDC
        295, // Hedera
        // Supports any chain with linked wallet
      ];

  @override
  bool get supportsReverse => true;

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      // Extract username from various formats:
      // @alice, alice.cifi, alice
      final username = _extractUsername(name);

      // Get CiFi profile
      final profile = await _client.identity.getProfile(username);

      // Get linked addresses
      final addresses = await _client.identity.getLinkedAddresses(profile.userId);

      if (addresses.isEmpty) return null;

      // Find address for requested chain
      String? address;
      if (chainId != null) {
        // Look for specific chain
        final wallet = addresses.firstWhere(
          (w) => w.chainId == chainId,
          orElse: () => addresses.first,
        );
        address = wallet.address;
      } else {
        // Return primary address
        address = profile.primaryAddress;
      }

      return ResolutionResult(
        address: address,
        resolverUsed: 'cifi',
        name: '@${profile.username ?? username}',
        chainId: chainId,
        metadata: {
          'cifiUserId': profile.userId,
          'username': profile.username,
          'email': profile.email,
        },
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    try {
      // Query CiFi to find which user owns this address
      final addresses = await _client.identity.getLinkedAddresses(address);

      if (addresses.isEmpty) return null;

      // Get the user profile for the first linked address
      // Note: Using address as userId - update when CiFi API provides direct userId mapping
      final userId = addresses.first.address;
      final profile = await _client.identity.getProfile(userId);

      return '@${profile.username ?? profile.userId}';
    } catch (e) {
      return null;
    }
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    try {
      final username = _extractUsername(name);

      final profile = await _client.identity.getProfile(username);
      final wallets = await _client.identity.getLinkedAddresses(profile.userId);

      // Build address map for all chains
      final addresses = <String, String>{};
      for (final wallet in wallets) {
        addresses[wallet.chainId.toString()] = wallet.address;
      }

      return NameRecords(
        addresses: addresses,
        texts: {
          'username': profile.username ?? '',
          'email': profile.email ?? '',
        },
        owner: profile.primaryAddress,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  bool canResolve(String name) {
    // Can resolve if:
    // 1. Starts with @ (@alice)
    // 2. Ends with .cifi (alice.cifi)
    // 3. Is a plain username (alice)
    return name.startsWith('@') ||
        name.endsWith('.cifi') ||
        !name.contains('.');
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  String _extractUsername(String name) {
    // @alice → alice
    // alice.cifi → alice
    // alice → alice
    return name
        .replaceFirst('@', '')
        .replaceFirst('.cifi', '')
        .toLowerCase();
  }
}
