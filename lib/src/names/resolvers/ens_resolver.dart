import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';
import 'package:web3refi/src/names/utils/namehash.dart';

/// Ethereum Name Service (ENS) resolver.
///
/// Resolves .eth names to Ethereum addresses using the ENS protocol.
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Multi-coin addresses (BTC, SOL, etc.)
/// - Text records (email, url, avatar, etc.)
/// - Content hashes (IPFS, Arweave)
///
/// ## Usage
///
/// ```dart
/// final ens = ENSResolver(rpcClient);
///
/// // Resolve name
/// final result = await ens.resolve('vitalik.eth');
/// print(result?.address);
///
/// // Reverse resolve
/// final name = await ens.reverseResolve('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
/// print(name); // 'vitalik.eth'
///
/// // Get all records
/// final records = await ens.getRecords('vitalik.eth');
/// print(records?.texts['url']); // Website URL
/// ```
class ENSResolver extends NameResolver {
  final RpcClient _rpc;

  // ENS Contract Addresses (Ethereum Mainnet)
  static const registryAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';
  static const publicResolverAddress =
      '0x231b0Ee14048e9dCcD1d247744d114a4EB5E8E63';

  ENSResolver(this._rpc);

  @override
  String get id => 'ens';

  @override
  List<String> get supportedTLDs => ['eth'];

  @override
  List<int> get supportedChainIds => [1]; // Ethereum mainnet

  @override
  bool get supportsReverse => true;

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      // Compute namehash
      final node = namehash(name);

      // Get resolver for this name
      final resolverAddr = await _getResolver(node);
      if (resolverAddr == null) return null;

      // Get address from resolver
      final address = await _resolveAddress(resolverAddr, node, coinType ?? '60');
      if (address == null) return null;

      return ResolutionResult(
        address: address,
        resolverUsed: 'ens',
        name: name,
        chainId: chainId ?? 1,
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    try {
      // Normalize address (remove 0x, lowercase)
      final addr = address.toLowerCase().replaceFirst('0x', '');

      // Compute reverse node: addr.reverse
      final reverseNode = namehash('$addr.addr.reverse');

      // Get resolver
      final resolverAddr = await _getResolver(reverseNode);
      if (resolverAddr == null) return null;

      // Get name from resolver
      return await _resolveName(resolverAddr, reverseNode);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    try {
      final node = namehash(name);
      final resolverAddr = await _getResolver(node);
      if (resolverAddr == null) return null;

      // Get primary address (coin type 60 = Ethereum)
      final ethAddress = await _resolveAddress(resolverAddr, node, '60');

      // Get common text records
      final avatar = await _getText(resolverAddr, node, 'avatar');
      final email = await _getText(resolverAddr, node, 'email');
      final url = await _getText(resolverAddr, node, 'url');
      final description = await _getText(resolverAddr, node, 'description');
      final twitter = await _getText(resolverAddr, node, 'com.twitter');
      final github = await _getText(resolverAddr, node, 'com.github');

      final texts = <String, String>{};
      if (avatar != null) texts['avatar'] = avatar;
      if (email != null) texts['email'] = email;
      if (url != null) texts['url'] = url;
      if (description != null) texts['description'] = description;
      if (twitter != null) texts['com.twitter'] = twitter;
      if (github != null) texts['com.github'] = github;

      final addresses = <String, String>{};
      if (ethAddress != null) addresses['60'] = ethAddress;

      return NameRecords(
        addresses: addresses,
        texts: texts,
        avatar: avatar,
        resolver: resolverAddr,
      );
    } catch (e) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL HELPERS
  // ══════════════════════════════════════════════════════════════════════

  /// Get resolver contract address for a node
  Future<String?> _getResolver(Uint8List node) async {
    try {
      final data = AbiCoder.encodeFunctionCall(
        'resolver(bytes32)',
        [node],
      );

      final result = await _rpc.ethCall(
        to: registryAddress,
        data: data,
      );

      // Decode address
      final decoded = AbiCoder.decodeParameters(['address'], result);
      final address = decoded[0] as String;

      // Check if zero address
      if (address == '0x0000000000000000000000000000000000000000') {
        return null;
      }

      return address;
    } catch (e) {
      return null;
    }
  }

  /// Resolve address from resolver contract
  Future<String?> _resolveAddress(
    String resolver,
    Uint8List node,
    String coinType,
  ) async {
    try {
      // For Ethereum (coinType 60), use addr(bytes32)
      // For other coins, use addr(bytes32, uint256)
      final data = coinType == '60'
          ? AbiCoder.encodeFunctionCall('addr(bytes32)', [node])
          : AbiCoder.encodeFunctionCall(
              'addr(bytes32,uint256)',
              [node, BigInt.parse(coinType)],
            );

      final result = await _rpc.ethCall(
        to: resolver,
        data: data,
      );

      if (coinType == '60') {
        // Decode as address
        final decoded = AbiCoder.decodeParameters(['address'], result);
        final address = decoded[0] as String;

        if (address == '0x0000000000000000000000000000000000000000') {
          return null;
        }

        return address;
      } else {
        // Decode as bytes (for non-EVM addresses)
        final decoded = AbiCoder.decodeParameters(['bytes'], result);
        final bytes = decoded[0] as Uint8List;

        if (bytes.isEmpty) return null;

        // Format based on coin type
        return _formatAddressForCoinType(bytes, coinType);
      }
    } catch (e) {
      return null;
    }
  }

  /// Resolve name from reverse registrar
  Future<String?> _resolveName(String resolver, Uint8List node) async {
    try {
      final data = AbiCoder.encodeFunctionCall('name(bytes32)', [node]);

      final result = await _rpc.ethCall(
        to: resolver,
        data: data,
      );

      final decoded = AbiCoder.decodeParameters(['string'], result);
      final name = decoded[0] as String;

      return name.isNotEmpty ? name : null;
    } catch (e) {
      return null;
    }
  }

  /// Get text record from resolver
  Future<String?> _getText(String resolver, Uint8List node, String key) async {
    try {
      final data = AbiCoder.encodeFunctionCall(
        'text(bytes32,string)',
        [node, key],
      );

      final result = await _rpc.ethCall(
        to: resolver,
        data: data,
      );

      final decoded = AbiCoder.decodeParameters(['string'], result);
      final value = decoded[0] as String;

      return value.isNotEmpty ? value : null;
    } catch (e) {
      return null;
    }
  }

  /// Format address bytes for specific coin type (SLIP-0044)
  String _formatAddressForCoinType(Uint8List bytes, String coinType) {
    // Returns hex representation for all coin types
    // Note: Specific formatting for BTC (Base58), SOL (Base58), etc. can be added
    // when multi-chain address support is needed. Current implementation works for EVM chains.
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}
