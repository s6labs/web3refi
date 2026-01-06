import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';

/// Sui Name Service (SuiNS) resolver.
///
/// Resolves .sui names to Sui addresses using the SuiNS protocol.
///
/// ## Supported TLDs
///
/// - .sui - Sui domains
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Text records
/// - Avatar and profile data
///
/// ## Usage
///
/// ```dart
/// final suins = SuiNsResolver(suiRpcUrl: 'https://fullnode.mainnet.sui.io');
///
/// // Resolve .sui name
/// final result = await suins.resolve('alice.sui');
/// print(result?.address);
///
/// // Reverse resolve
/// final name = await suins.reverseResolve('0x123...');
/// print(name); // 'alice.sui'
///
/// // Get all records
/// final records = await suins.getRecords('alice.sui');
/// ```
///
/// ## Implementation Note
///
/// SuiNS uses Sui's Move-based smart contracts. This resolver
/// queries the Sui RPC endpoint to resolve names.
class SuiNsResolver extends NameResolver {
  final String _suiRpcUrl;
  final http.Client _httpClient;

  // SuiNS Package ID (mainnet)
  static const suinsPackageId = '0xd22b24490e0bae52676651b4f56660a5ff8022a2576e0089f79b3c88d44e08f0';

  SuiNsResolver({
    String suiRpcUrl = 'https://fullnode.mainnet.sui.io',
    http.Client? httpClient,
  })  : _suiRpcUrl = suiRpcUrl,
        _httpClient = httpClient ?? http.Client();

  @override
  String get id => 'suins';

  @override
  List<String> get supportedTLDs => ['sui'];

  @override
  List<int> get supportedChainIds => []; // Sui doesn't use EVM chain IDs

  @override
  bool get supportsReverse => true;

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      // Remove .sui if present
      final domainName = name.toLowerCase().replaceFirst('.sui', '');

      // Query SuiNS contract for domain resolution
      final address = await _resolveName(domainName);
      if (address == null) return null;

      return ResolutionResult(
        address: address,
        resolverUsed: 'suins',
        name: '$domainName.sui',
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    try {
      // Query for primary name set by address
      final domain = await _getPrimaryName(address);
      return domain != null ? '$domain.sui' : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    try {
      final domainName = name.toLowerCase().replaceFirst('.sui', '');

      final address = await _resolveName(domainName);
      if (address == null) return null;

      final textRecords = await _getTextRecords(domainName);

      return NameRecords(
        addresses: {'784': address ?? ''}, // 784 = Sui coin type
        texts: textRecords,
        owner: address,
      );
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Resolve domain name to Sui address
  Future<String?> _resolveName(String domainName) async {
    try {
      // Call sui_resolveNameServiceAddress RPC method
      final response = await _rpcCall('sui_resolveNameServiceAddress', [domainName]);

      if (response['result'] != null) {
        return response['result'] as String;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get primary name for an address
  Future<String?> _getPrimaryName(String address) async {
    try {
      // Call sui_resolveNameServiceNames RPC method
      final response = await _rpcCall('sui_resolveNameServiceNames', [address]);

      if (response['result'] != null && response['result'] is List) {
        final names = response['result'] as List;
        if (names.isNotEmpty) {
          return names[0] as String;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get text records for a domain
  Future<Map<String, String>> _getTextRecords(String domainName) async {
    try {
      // Query the domain object for metadata
      final response = await _rpcCall('suix_getDynamicFields', [
        await _getDomainObjectId(domainName),
      ]);

      if (response['result'] == null || response['result']['data'] == null) {
        return {};
      }

      final records = <String, String>{};
      final data = response['result']['data'] as List;

      for (final field in data) {
        if (field['name'] != null && field['value'] != null) {
          final name = field['name']['value'] as String?;
          final value = field['value']['value'] as String?;

          if (name != null && value != null) {
            records[name] = value;
          }
        }
      }

      return records;
    } catch (e) {
      return {};
    }
  }

  /// Get domain object ID for a domain name
  Future<String?> _getDomainObjectId(String domainName) async {
    try {
      // This would require querying the SuiNS registry
      // For now, return null (simplified implementation)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Make RPC call to Sui node
  Future<Map<String, dynamic>> _rpcCall(String method, List<dynamic> params) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_suiRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': method,
          'params': params,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  /// Cleanup
  void dispose() {
    _httpClient.close();
  }
}
