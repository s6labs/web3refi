import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/wallet/wallet_manager.dart';
import 'package:web3refi/src/abi/abi_coder.dart';

/// ERC-1155 Multi-Token Standard interface.
///
/// Supports multiple token types (fungible and non-fungible) in a single contract.
///
/// ## Features
///
/// - Multiple token IDs in one contract
/// - Batch transfers
/// - Batch balance queries
/// - Both fungible and NFT support
///
/// ## Usage
///
/// ```dart
/// final multiToken = ERC1155(
///   address: '0x...',
///   rpcClient: Web3Refi.instance.rpcClient,
///   walletManager: Web3Refi.instance.walletManager,
/// );
///
/// // Get balance of specific token
/// final balance = await multiToken.balanceOf(
///   account: myAddress,
///   id: BigInt.from(1),
/// );
///
/// // Batch transfer
/// await multiToken.safeBatchTransferFrom(
///   from: sender,
///   to: recipient,
///   ids: [BigInt.one, BigInt.two],
///   amounts: [BigInt.from(10), BigInt.from(5)],
/// );
/// ```
class ERC1155 {
  final String address;
  final RpcClient rpcClient;
  final WalletManager? walletManager;

  ERC1155({
    required this.address,
    required this.rpcClient,
    this.walletManager,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCE QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Get balance of single token type.
  Future<BigInt> balanceOf({
    required String account,
    required BigInt id,
  }) async {
    final data = AbiCoder.encodeFunctionCall(
      'balanceOf(address,uint256)',
      [account, id],
    );

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    return decoded[0] as BigInt;
  }

  /// Get balances of multiple token types for multiple accounts.
  Future<List<BigInt>> balanceOfBatch({
    required List<String> accounts,
    required List<BigInt> ids,
  }) async {
    if (accounts.length != ids.length) {
      throw ArgumentError('accounts and ids arrays must have same length');
    }

    final data = AbiCoder.encodeFunctionCall(
      'balanceOfBatch(address[],uint256[])',
      [accounts, ids],
    );

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256[]'], result);
    return (decoded[0] as List).cast<BigInt>();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPROVALS
  // ══════════════════════════════════════════════════════════════════════════

  /// Set approval for operator to manage all tokens.
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

  /// Check if operator is approved.
  Future<bool> isApprovedForAll({
    required String account,
    required String operator,
  }) async {
    final data = AbiCoder.encodeFunctionCall(
      'isApprovedForAll(address,address)',
      [account, operator],
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

  /// Transfer single token type.
  Future<String> safeTransferFrom({
    required String from,
    required String to,
    required BigInt id,
    required BigInt amount,
    Uint8List? data,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for safeTransferFrom()');
    }

    final callData = AbiCoder.encodeFunctionCall(
      'safeTransferFrom(address,address,uint256,uint256,bytes)',
      [from, to, id, amount, data ?? Uint8List(0)],
    );

    return await walletManager!.sendTransaction(
      to: address,
      data: callData,
    );
  }

  /// Batch transfer multiple token types.
  Future<String> safeBatchTransferFrom({
    required String from,
    required String to,
    required List<BigInt> ids,
    required List<BigInt> amounts,
    Uint8List? data,
  }) async {
    if (walletManager == null) {
      throw StateError('WalletManager required for safeBatchTransferFrom()');
    }

    if (ids.length != amounts.length) {
      throw ArgumentError('ids and amounts arrays must have same length');
    }

    final callData = AbiCoder.encodeFunctionCall(
      'safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)',
      [from, to, ids, amounts, data ?? Uint8List(0)],
    );

    return await walletManager!.sendTransaction(
      to: address,
      data: callData,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA
  // ══════════════════════════════════════════════════════════════════════════

  /// Get URI for token metadata.
  ///
  /// Returns the metadata URI for a token ID. The URI may contain {id}
  /// placeholder that clients should replace with the actual token ID.
  Future<String> uri(BigInt id) async {
    final data = AbiCoder.encodeFunctionCall(
      'uri(uint256)',
      [id],
    );

    final result = await rpcClient.ethCall(
      to: address,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['string'], result);
    return decoded[0] as String;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get TransferSingle events.
  ///
  /// Query TransferSingle(address operator, address from, address to, uint256 id, uint256 value)
  /// events with optional filtering.
  Future<List<Map<String, dynamic>>> getTransferSingleEvents({
    String? operator,
    String? from,
    String? to,
    dynamic fromBlock = 'latest',
    dynamic toBlock = 'latest',
  }) async {
    // Event signature: TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value)
    final eventSig = AbiCoder.eventSignature(
      'TransferSingle(address,address,address,uint256,uint256)',
    );

    // Build topics (indexed parameters)
    final topics = <String?>[
      eventSig,
      operator != null
          ? AbiCoder.encodeIndexedParameter(operator, 'address')
          : null,
      from != null ? AbiCoder.encodeIndexedParameter(from, 'address') : null,
      to != null ? AbiCoder.encodeIndexedParameter(to, 'address') : null,
    ];

    final logs = await rpcClient.getLogs(
      address: address,
      topics: topics,
      fromBlock: fromBlock,
      toBlock: toBlock,
    );

    return logs.map((log) {
      // Indexed parameters are in topics
      final operatorAddr = log['topics'][1] as String;
      final fromAddr = log['topics'][2] as String;
      final toAddr = log['topics'][3] as String;

      // Non-indexed parameters (id, value) are in data
      final dataHex = log['data'] as String;
      final decoded = AbiCoder.decodeParameters(
        ['uint256', 'uint256'],
        dataHex,
      );

      return {
        'operator': AbiCoder.decodeAddress(operatorAddr),
        'from': AbiCoder.decodeAddress(fromAddr),
        'to': AbiCoder.decodeAddress(toAddr),
        'id': decoded[0] as BigInt,
        'value': decoded[1] as BigInt,
        'blockNumber': log['blockNumber'],
        'transactionHash': log['transactionHash'],
        'logIndex': log['logIndex'],
      };
    }).toList();
  }

  /// Get TransferBatch events.
  ///
  /// Query TransferBatch(address operator, address from, address to, uint256[] ids, uint256[] values)
  /// events with optional filtering.
  Future<List<Map<String, dynamic>>> getTransferBatchEvents({
    String? operator,
    String? from,
    String? to,
    dynamic fromBlock = 'latest',
    dynamic toBlock = 'latest',
  }) async {
    // Event signature: TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values)
    final eventSig = AbiCoder.eventSignature(
      'TransferBatch(address,address,address,uint256[],uint256[])',
    );

    // Build topics (indexed parameters)
    final topics = <String?>[
      eventSig,
      operator != null
          ? AbiCoder.encodeIndexedParameter(operator, 'address')
          : null,
      from != null ? AbiCoder.encodeIndexedParameter(from, 'address') : null,
      to != null ? AbiCoder.encodeIndexedParameter(to, 'address') : null,
    ];

    final logs = await rpcClient.getLogs(
      address: address,
      topics: topics,
      fromBlock: fromBlock,
      toBlock: toBlock,
    );

    return logs.map((log) {
      // Indexed parameters are in topics
      final operatorAddr = log['topics'][1] as String;
      final fromAddr = log['topics'][2] as String;
      final toAddr = log['topics'][3] as String;

      // Non-indexed parameters (ids[], values[]) are in data
      final dataHex = log['data'] as String;
      final decoded = AbiCoder.decodeParameters(
        ['uint256[]', 'uint256[]'],
        dataHex,
      );

      return {
        'operator': AbiCoder.decodeAddress(operatorAddr),
        'from': AbiCoder.decodeAddress(fromAddr),
        'to': AbiCoder.decodeAddress(toAddr),
        'ids': (decoded[0] as List).cast<BigInt>(),
        'values': (decoded[1] as List).cast<BigInt>(),
        'blockNumber': log['blockNumber'],
        'transactionHash': log['transactionHash'],
        'logIndex': log['logIndex'],
      };
    }).toList();
  }
}
