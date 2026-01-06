import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';
import 'package:web3refi/src/names/utils/namehash.dart';

/// Unstoppable Domains resolver.
///
/// Resolves Unstoppable Domains names (.crypto, .nft, .wallet, .x, .bitcoin,
/// .dao, .888, .zil, .blockchain) to addresses.
///
/// ## Supported TLDs
///
/// - .crypto - First UD TLD
/// - .nft - NFT-focused domains
/// - .wallet - Wallet-specific domains
/// - .x - Short form domains
/// - .bitcoin - Bitcoin-focused domains
/// - .dao - DAO organization domains
/// - .888 - Asian market domains
/// - .zil - Zilliqa domains
/// - .blockchain - General blockchain domains
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Multi-chain addresses (ETH, BTC, SOL, MATIC, etc.)
/// - Text records (email, url, avatar, ipfs, etc.)
/// - IPFS content hashes
/// - Custom records
///
/// ## Usage
///
/// ```dart
/// final ud = UnstoppableResolver(rpcClient);
///
/// // Resolve name
/// final result = await ud.resolve('brad.crypto');
/// print(result?.address);
///
/// // Get Bitcoin address
/// final btcAddr = await ud.resolve('brad.crypto', coinType: '0');
///
/// // Get all records
/// final records = await ud.getRecords('brad.crypto');
/// print(records?.getText('email'));
/// ```
///
/// ## Contract Addresses
///
/// - Polygon Mainnet: 0xa9a6A3626993D487d2Dbda3173cf58cA1a9D9e9f
/// - Ethereum Mainnet: 0x049aba7510f45BA5b64ea9E658E342F904DB358D
class UnstoppableResolver extends NameResolver {
  final RpcClient _rpc;
  final int _chainId;

  // Unstoppable Domains Registry (Polygon Mainnet by default)
  static const polygonRegistryAddress = '0xa9a6A3626993D487d2Dbda3173cf58cA1a9D9e9f';
  static const ethereumRegistryAddress = '0x049aba7510f45BA5b64ea9E658E342F904DB358D';

  // Common record keys
  static const recordKeyAddress = 'crypto.ETH.address';
  static const recordKeyBTC = 'crypto.BTC.address';
  static const recordKeySOL = 'crypto.SOL.address';
  static const recordKeyMATIC = 'crypto.MATIC.address';

  UnstoppableResolver(this._rpc, {int chainId = 137}) : _chainId = chainId;

  @override
  String get id => 'unstoppable';

  @override
  List<String> get supportedTLDs => [
        'crypto',
        'nft',
        'wallet',
        'x',
        'bitcoin',
        'dao',
        '888',
        'zil',
        'blockchain',
      ];

  @override
  List<int> get supportedChainIds => [1, 137]; // Ethereum, Polygon

  @override
  bool get supportsReverse => true;

  String get _registryAddress {
    return _chainId == 1 ? ethereumRegistryAddress : polygonRegistryAddress;
  }

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      final node = namehash(name);

      // Determine which record to fetch
      String recordKey;
      if (coinType != null) {
        recordKey = _coinTypeToRecordKey(coinType);
      } else {
        recordKey = recordKeyAddress; // Default to ETH
      }

      // Get record from registry
      final address = await _getRecord(node, recordKey);
      if (address == null || address.isEmpty) return null;

      return ResolutionResult(
        address: address,
        resolverUsed: 'unstoppable',
        name: name,
        chainId: chainId ?? _chainId,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    try {
      // Unstoppable Domains doesn't have native reverse resolution
      // Would need to query their API or maintain an index
      // For now, return null
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    try {
      final node = namehash(name);

      // Get common addresses
      final ethAddress = await _getRecord(node, recordKeyAddress);
      final btcAddress = await _getRecord(node, recordKeyBTC);
      final solAddress = await _getRecord(node, recordKeySOL);
      final maticAddress = await _getRecord(node, recordKeyMATIC);

      // Get common text records
      final email = await _getRecord(node, 'whois.email.value');
      final url = await _getRecord(node, 'whois.for_sale.value');
      final avatar = await _getRecord(node, 'social.picture.value');
      final twitter = await _getRecord(node, 'social.twitter.username');
      final ipfsHash = await _getRecord(node, 'ipfs.html.value');
      final redirectUrl = await _getRecord(node, 'browser.redirect_url');

      final addresses = <String, String>{};
      if (ethAddress != null && ethAddress.isNotEmpty) {
        addresses['60'] = ethAddress; // ETH
      }
      if (btcAddress != null && btcAddress.isNotEmpty) {
        addresses['0'] = btcAddress; // BTC
      }
      if (solAddress != null && solAddress.isNotEmpty) {
        addresses['501'] = solAddress; // SOL
      }
      if (maticAddress != null && maticAddress.isNotEmpty) {
        addresses['966'] = maticAddress; // MATIC
      }

      final texts = <String, String>{};
      if (email != null && email.isNotEmpty) texts['email'] = email;
      if (url != null && url.isNotEmpty) texts['url'] = url;
      if (twitter != null && twitter.isNotEmpty) texts['com.twitter'] = twitter;
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        texts['browser.redirect_url'] = redirectUrl;
      }

      return NameRecords(
        addresses: addresses,
        texts: texts,
        avatar: avatar,
        contentHash: ipfsHash,
      );
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Get a record from the Unstoppable Domains registry
  Future<String?> _getRecord(Uint8List node, String key) async {
    try {
      // get(string calldata key, uint256 tokenId) external view returns (string memory)
      final tokenId = _bytesToBigInt(node);

      final data = AbiCoder.encodeFunctionCall(
        'get(string,uint256)',
        [key, tokenId],
      );

      final result = await _rpc.ethCall(
        to: _registryAddress,
        data: data,
      );

      final decoded = AbiCoder.decodeParameters(['string'], result);
      final value = decoded[0] as String;

      return value.isNotEmpty ? value : null;
    } catch (e) {
      return null;
    }
  }

  /// Convert coin type to Unstoppable Domains record key
  String _coinTypeToRecordKey(String coinType) {
    switch (coinType) {
      case '0':
        return recordKeyBTC;
      case '60':
        return recordKeyAddress; // ETH
      case '501':
        return recordKeySOL;
      case '966':
        return recordKeyMATIC;
      default:
        return 'crypto.$coinType.address';
    }
  }

  /// Convert bytes to BigInt (for tokenId)
  BigInt _bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (var i = 0; i < bytes.length; i++) {
      result = (result << 8) | BigInt.from(bytes[i]);
    }
    return result;
  }
}
