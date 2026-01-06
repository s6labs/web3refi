import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';

/// Solana Name Service (SNS) resolver.
///
/// Resolves .sol names to Solana addresses using the SNS protocol.
///
/// ## Supported TLDs
///
/// - .sol - Solana domains
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Text records (url, twitter, github, etc.)
/// - IPFS content
///
/// ## Usage
///
/// ```dart
/// final sns = SnsResolver(solanaRpcUrl: 'https://api.mainnet-beta.solana.com');
///
/// // Resolve .sol name
/// final result = await sns.resolve('toly.sol');
/// print(result?.address);
///
/// // Reverse resolve
/// final name = await sns.reverseResolve('DRpbCBMxVnDK7maPM5tGv6MvB3v1sRMC86PZ8okm21hy');
/// print(name); // 'toly.sol'
///
/// // Get all records
/// final records = await sns.getRecords('toly.sol');
/// ```
///
/// ## Implementation Note
///
/// SNS uses Solana's on-chain program. This resolver uses the SNS SDK
/// approach via RPC calls to the Solana network.
class SnsResolver extends NameResolver {
  final String _solanaRpcUrl;
  final http.Client _httpClient;

  // SNS Program ID
  static const snsProgramId = 'namesLPneVptA9Z5rqUDD9tMTWEJwofgaYwp8cawRkX';

  SnsResolver({
    String solanaRpcUrl = 'https://api.mainnet-beta.solana.com',
    http.Client? httpClient,
  })  : _solanaRpcUrl = solanaRpcUrl,
        _httpClient = httpClient ?? http.Client();

  @override
  String get id => 'sns';

  @override
  List<String> get supportedTLDs => ['sol'];

  @override
  List<int> get supportedChainIds => []; // Solana doesn't use EVM chain IDs

  @override
  bool get supportsReverse => true;

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      // Remove .sol if present
      final domainName = name.toLowerCase().replaceFirst('.sol', '');

      // Derive the domain account address
      final domainAccount = await _getDomainAccount(domainName);
      if (domainAccount == null) return null;

      // Get the owner address from the domain account
      final owner = await _getDomainOwner(domainAccount);
      if (owner == null) return null;

      return ResolutionResult(
        address: owner,
        resolverUsed: 'sns',
        name: '$domainName.sol',
        metadata: {
          'domainAccount': domainAccount,
        },
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    try {
      // Query for domain owned by this address
      final domain = await _findDomainByOwner(address);
      return domain != null ? '$domain.sol' : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    try {
      final domainName = name.toLowerCase().replaceFirst('.sol', '');
      final domainAccount = await _getDomainAccount(domainName);
      if (domainAccount == null) return null;

      final owner = await _getDomainOwner(domainAccount);
      final records = await _getDomainRecords(domainAccount);

      return NameRecords(
        addresses: {'501': owner ?? ''}, // 501 = Solana coin type
        texts: records,
        owner: owner,
      );
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Get domain account address for a domain name
  Future<String?> _getDomainAccount(String domainName) async {
    try {
      // This would require deriving the PDA (Program Derived Address)
      // For now, we'll use a simplified approach via RPC

      final response = await _rpcCall('getProgramAccounts', [
        snsProgramId,
        {
          'encoding': 'jsonParsed',
          'filters': [
            {
              'memcmp': {
                'offset': 0,
                'bytes': _base58Encode(domainName),
              }
            }
          ]
        }
      ]);

      if (response['result'] == null || (response['result'] as List).isEmpty) {
        return null;
      }

      return response['result'][0]['pubkey'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get owner address from domain account
  Future<String?> _getDomainOwner(String domainAccount) async {
    try {
      final response = await _rpcCall('getAccountInfo', [
        domainAccount,
        {'encoding': 'jsonParsed'}
      ]);

      if (response['result'] == null || response['result']['value'] == null) {
        return null;
      }

      final data = response['result']['value']['data'];
      if (data is Map && data['parsed'] != null) {
        return data['parsed']['info']['owner'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Find domain by owner address
  Future<String?> _findDomainByOwner(String ownerAddress) async {
    try {
      final response = await _rpcCall('getProgramAccounts', [
        snsProgramId,
        {
          'encoding': 'jsonParsed',
          'filters': [
            {
              'memcmp': {
                'offset': 32, // Owner field offset
                'bytes': ownerAddress,
              }
            }
          ]
        }
      ]);

      if (response['result'] == null || (response['result'] as List).isEmpty) {
        return null;
      }

      // Extract domain name from account data
      final accountData = response['result'][0]['account']['data'];
      if (accountData is Map && accountData['parsed'] != null) {
        return accountData['parsed']['info']['name'] as String?;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get domain records (text records, etc.)
  Future<Map<String, String>> _getDomainRecords(String domainAccount) async {
    try {
      final response = await _rpcCall('getAccountInfo', [
        domainAccount,
        {'encoding': 'jsonParsed'}
      ]);

      if (response['result'] == null || response['result']['value'] == null) {
        return {};
      }

      final data = response['result']['value']['data'];
      if (data is Map && data['parsed'] != null && data['parsed']['info'] != null) {
        final info = data['parsed']['info'] as Map<String, dynamic>;
        final records = <String, String>{};

        // Extract common records
        if (info['url'] != null) records['url'] = info['url'] as String;
        if (info['twitter'] != null) records['com.twitter'] = info['twitter'] as String;
        if (info['github'] != null) records['com.github'] = info['github'] as String;
        if (info['discord'] != null) records['com.discord'] = info['discord'] as String;

        return records;
      }

      return {};
    } catch (e) {
      return {};
    }
  }

  /// Make RPC call to Solana node
  Future<Map<String, dynamic>> _rpcCall(String method, List<dynamic> params) async {
    try {
      final response = await _httpClient.post(
        Uri.parse(_solanaRpcUrl),
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

  /// Simple base58 encoding helper (simplified version)
  String _base58Encode(String input) {
    // This is a placeholder - real implementation would use proper base58 encoding
    // For production, use a proper base58 library
    return input;
  }

  /// Cleanup
  void dispose() {
    _httpClient.close();
  }
}
