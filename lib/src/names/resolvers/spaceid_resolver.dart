import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/names/name_resolver.dart';
import 'package:web3refi/src/names/resolution_result.dart';
import 'package:web3refi/src/names/utils/namehash.dart';

/// Space ID resolver.
///
/// Resolves Space ID names (.bnb, .arb) to addresses on BNB Chain and Arbitrum.
///
/// ## Supported TLDs
///
/// - .bnb - BNB Chain domains
/// - .arb - Arbitrum domains
///
/// ## Features
///
/// - Forward resolution (name → address)
/// - Reverse resolution (address → name)
/// - Text records
/// - Multi-chain support
///
/// ## Usage
///
/// ```dart
/// final spaceId = SpaceIdResolver(rpcClient, chainId: 56); // BNB Chain
///
/// // Resolve .bnb name
/// final result = await spaceId.resolve('alice.bnb');
/// print(result?.address);
///
/// // Reverse resolve
/// final name = await spaceId.reverseResolve('0x123...');
/// print(name); // 'alice.bnb'
///
/// // Get all records
/// final records = await spaceId.getRecords('alice.bnb');
/// ```
///
/// ## Contract Addresses
///
/// - BNB Chain Registry: 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e
/// - Arbitrum Registry: 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e
class SpaceIdResolver extends NameResolver {
  final RpcClient _rpc;
  final int _chainId;

  // Space ID Registry addresses (similar to ENS)
  static const bnbRegistryAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';
  static const arbRegistryAddress = '0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e';

  SpaceIdResolver(this._rpc, {int chainId = 56}) : _chainId = chainId;

  @override
  String get id => 'spaceid';

  @override
  List<String> get supportedTLDs => ['bnb', 'arb'];

  @override
  List<int> get supportedChainIds => [56, 42161]; // BNB Chain, Arbitrum

  @override
  bool get supportsReverse => true;

  String get _registryAddress {
    return _chainId == 56 ? bnbRegistryAddress : arbRegistryAddress;
  }

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    try {
      final node = namehash(name);

      // Get resolver for this name
      final resolverAddr = await _getResolver(node);
      if (resolverAddr == null) return null;

      // Get address from resolver
      final address = await _resolveAddress(resolverAddr, node, coinType ?? '60');
      if (address == null) return null;

      return ResolutionResult(
        address: address,
        resolverUsed: 'spaceid',
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
      final addr = address.toLowerCase().replaceFirst('0x', '');

      // Compute reverse node: addr.addr.reverse
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

      // Get primary address
      final address = await _resolveAddress(resolverAddr, node, '60');

      // Get common text records
      final avatar = await _getText(resolverAddr, node, 'avatar');
      final email = await _getText(resolverAddr, node, 'email');
      final url = await _getText(resolverAddr, node, 'url');
      final description = await _getText(resolverAddr, node, 'description');
      final twitter = await _getText(resolverAddr, node, 'com.twitter');

      final texts = <String, String>{};
      if (avatar != null) texts['avatar'] = avatar;
      if (email != null) texts['email'] = email;
      if (url != null) texts['url'] = url;
      if (description != null) texts['description'] = description;
      if (twitter != null) texts['com.twitter'] = twitter;

      final addresses = <String, String>{};
      if (address != null) addresses['60'] = address;

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
        to: _registryAddress,
        data: data,
      );

      final decoded = AbiCoder.decodeParameters(['address'], result);
      final address = decoded[0] as String;

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
        final decoded = AbiCoder.decodeParameters(['address'], result);
        final address = decoded[0] as String;

        if (address == '0x0000000000000000000000000000000000000000') {
          return null;
        }

        return address;
      } else {
        final decoded = AbiCoder.decodeParameters(['bytes'], result);
        final bytes = decoded[0] as Uint8List;

        if (bytes.isEmpty) return null;

        return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
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
}
