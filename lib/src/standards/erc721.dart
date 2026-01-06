import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/wallet/wallet_manager.dart';
import 'package:web3refi/src/abi/abi_coder.dart';

/// ERC-721 Non-Fungible Token (NFT) interface.
///
/// Complete implementation of the ERC-721 standard for NFTs.
///
/// ## Usage
///
/// ```dart
/// final nft = ERC721(
///   address: '0x...',
///   rpcClient: Web3Refi.instance.rpcClient,
///   walletManager: Web3Refi.instance.walletManager,
/// );
///
/// // Get token owner
/// final owner = await nft.ownerOf(tokenId);
///
/// // Transfer NFT
/// final txHash = await nft.transferFrom(
///   from: currentOwner,
///   to: newOwner,
///   tokenId: BigInt.from(123),
/// );
/// ```
class ERC721 {
  final String address;
  final RpcClient rpcClient;
  final WalletManager? walletManager;

  ERC721({
    required this.address,
    required this.rpcClient,
    this.walletManager,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA
  // ══════════════════════════════════════════════════════════════════════════

  /// Get token name.
  Future<String> name() async {
    final data = AbiCoder.encodeFunctionCall('name()', []);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['string'], result);
    return decoded[0] as String;
  }

  /// Get token symbol.
  Future<String> symbol() async {
    final data = AbiCoder.encodeFunctionCall('symbol()', []);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['string'], result);
    return decoded[0] as String;
  }

  /// Get token URI for metadata.
  Future<String> tokenURI(BigInt tokenId) async {
    final data = AbiCoder.encodeFunctionCall('tokenURI(uint256)', [tokenId]);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['string'], result);
    return decoded[0] as String;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCE & OWNERSHIP
  // ══════════════════════════════════════════════════════════════════════════

  /// Get number of NFTs owned by address.
  Future<BigInt> balanceOf(String owner) async {
    final data = AbiCoder.encodeFunctionCall('balanceOf(address)', [owner]);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    return decoded[0] as BigInt;
  }

  /// Get owner of specific token.
  Future<String> ownerOf(BigInt tokenId) async {
    final data = AbiCoder.encodeFunctionCall('ownerOf(uint256)', [tokenId]);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['address'], result);
    return decoded[0] as String;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPROVALS
  // ══════════════════════════════════════════════════════════════════════════

  /// Approve address to transfer specific token.
  Future<String> approve({
    required String to,
    required BigInt tokenId,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for approve()');
    }

    final data = AbiCoder.encodeFunctionCall(
      'approve(address,uint256)',
      [to, tokenId],
    );

    return await walletManager!.sendTransaction(
      to: address,
      data: data,
    );
  }

  /// Get approved address for token.
  Future<String> getApproved(BigInt tokenId) async {
    final data = AbiCoder.encodeFunctionCall('getApproved(uint256)', [tokenId]);

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['address'], result);
    return decoded[0] as String;
  }

  /// Set approval for all tokens.
  Future<String> setApprovalForAll({
    required String operator,
    required bool approved,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for setApprovalForAll()');
    }

    final data = AbiCoder.encodeFunctionCall(
      'setApprovalForAll(address,bool)',
      [operator, approved],
    );

    return await walletManager!.sendTransaction(
      to: address,
      data: data,
    );
  }

  /// Check if operator is approved for all owner's tokens.
  Future<bool> isApprovedForAll({
    required String owner,
    required String operator,
  }) async {
    final data = AbiCoder.encodeFunctionCall(
      'isApprovedForAll(address,address)',
      [owner, operator],
    );

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['bool'], result);
    return decoded[0] as bool;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TRANSFERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Transfer token.
  Future<String> transferFrom({
    required String from,
    required String to,
    required BigInt tokenId,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for transferFrom()');
    }

    final data = AbiCoder.encodeFunctionCall(
      'transferFrom(address,address,uint256)',
      [from, to, tokenId],
    );

    return await walletManager!.sendTransaction(
      to: address,
      data: data,
    );
  }

  /// Safely transfer token (calls onERC721Received on recipient).
  Future<String> safeTransferFrom({
    required String from,
    required String to,
    required BigInt tokenId,
    Uint8List? data,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for safeTransferFrom()');
    }

    final callData = data != null
        ? AbiCoder.encodeFunctionCall(
            'safeTransferFrom(address,address,uint256,bytes)',
            [from, to, tokenId, data],
          )
        : AbiCoder.encodeFunctionCall(
            'safeTransferFrom(address,address,uint256)',
            [from, to, tokenId],
          );

    return await walletManager!.sendTransaction(
      to: address,
      data: callData,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get Transfer events.
  ///
  /// Event signature: Transfer(address indexed from, address indexed to, uint256 indexed tokenId)
  Future<List<Map<String, dynamic>>> getTransferEvents({
    String? from,
    String? to,
    BigInt? tokenId,
    dynamic fromBlock = 'latest',
    dynamic toBlock = 'latest',
  }) async {
    // Transfer event signature
    final eventSig = AbiCoder.eventSignature('Transfer(address,address,uint256)');

    // Build topics
    final topics = <String?>[
      eventSig,
      from != null ? AbiCoder.encodeIndexedParameter(from, 'address') : null,
      to != null ? AbiCoder.encodeIndexedParameter(to, 'address') : null,
      tokenId != null ? AbiCoder.encodeIndexedParameter(tokenId, 'uint256') : null,
    ];

    // Get logs
    final logs = await rpcClient.getLogs(
      address: address,
      topics: topics,
      fromBlock: fromBlock,
      toBlock: toBlock,
    );

    // Parse logs
    return logs.map((log) {
      // Indexed parameters are in topics
      final fromAddr = log['topics'][1] as String;
      final toAddr = log['topics'][2] as String;
      final tokenIdHex = log['topics'][3] as String;

      return {
        'from': AbiCoder.decodeAddress(fromAddr),
        'to': AbiCoder.decodeAddress(toAddr),
        'tokenId': AbiCoder.decodeUint256(tokenIdHex),
        'blockNumber': log['blockNumber'],
        'transactionHash': log['transactionHash'],
        'logIndex': log['logIndex'],
      };
    }).toList();
  }
}
