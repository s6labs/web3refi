import 'dart:typed_data';
import '../transport/rpc_client.dart';
import '../abi/abi_coder.dart';

/// Multicall3 contract interface.
///
/// Aggregate multiple contract calls into a single RPC request.
/// Significantly reduces latency for batch operations.
///
/// Multicall3 is deployed at the same address on all chains:
/// `0xcA11bde05977b3631167028862bE2a173976CA11`
///
/// ## Features
///
/// - Aggregate multiple calls
/// - Optional failure handling (aggregate3)
/// - Value calls support
/// - Block information
///
/// ## Usage
///
/// ```dart
/// final multicall = Multicall3(
///   rpcClient: Web3Refi.instance.rpcClient,
/// );
///
/// // Aggregate calls
/// final results = await multicall.aggregate([
///   Call(target: tokenA, callData: balanceOfData),
///   Call(target: tokenB, callData: balanceOfData),
///   Call(target: tokenC, callData: balanceOfData),
/// ]);
/// ```
class Multicall3 {
  /// Canonical Multicall3 address (same on all chains).
  static const String address =
      '0xcA11bde05977b3631167028862bE2a173976CA11';

  final RpcClient rpcClient;
  final String contractAddress;

  Multicall3({
    required this.rpcClient,
    String? contractAddress,
  }) : contractAddress = contractAddress ?? address;

  // ══════════════════════════════════════════════════════════════════════════
  // AGGREGATE FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Aggregate calls (all must succeed).
  ///
  /// Returns: (blockNumber, returnData[])
  Future<AggregateResult> aggregate(List<Call> calls) async {
    // TODO: Call aggregate((address,bytes)[]) function
    throw UnimplementedError('Multicall3 aggregate() pending');
  }

  /// Aggregate calls with optional failure handling.
  ///
  /// Each call can succeed or fail independently.
  Future<List<Result>> aggregate3(List<Call3> calls) async {
    // TODO: Call aggregate3((address,bool,bytes)[]) function
    throw UnimplementedError('Multicall3 aggregate3() pending');
  }

  /// Aggregate calls with value.
  ///
  /// Supports sending ETH with calls.
  Future<List<Result>> aggregate3Value(List<Call3Value> calls) async {
    // TODO: Call aggregate3Value((address,bool,uint256,bytes)[]) function
    throw UnimplementedError('Multicall3 aggregate3Value() pending');
  }

  /// Try aggregate (deprecated in favor of aggregate3).
  Future<TryAggregateResult> tryAggregate({
    required bool requireSuccess,
    required List<Call> calls,
  }) async {
    // TODO: Call tryAggregate(bool,(address,bytes)[]) function
    throw UnimplementedError('Multicall3 tryAggregate() pending');
  }

  /// Try block and aggregate.
  Future<TryBlockResult> tryBlockAndAggregate({
    required bool requireSuccess,
    required List<Call> calls,
  }) async {
    // TODO: Call tryBlockAndAggregate(bool,(address,bytes)[]) function
    throw UnimplementedError('Multicall3 tryBlockAndAggregate() pending');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get current block info.
  Future<BlockInfo> getBlockHash(BigInt blockNumber) async {
    // TODO: Call getBlockHash(uint256) function
    throw UnimplementedError('Multicall3 getBlockHash() pending');
  }

  /// Get block number.
  Future<BigInt> getBlockNumber() async {
    // TODO: Call getBlockNumber() function
    throw UnimplementedError('Multicall3 getBlockNumber() pending');
  }

  /// Get current block timestamp.
  Future<BigInt> getCurrentBlockTimestamp() async {
    // TODO: Call getCurrentBlockTimestamp() function
    throw UnimplementedError('Multicall3 getCurrentBlockTimestamp() pending');
  }

  /// Get ETH balance of address.
  Future<BigInt> getEthBalance(String address) async {
    // TODO: Call getEthBalance(address) function
    throw UnimplementedError('Multicall3 getEthBalance() pending');
  }
}

/// Call struct for multicall.
class Call {
  final String target;
  final Uint8List callData;

  const Call({
    required this.target,
    required this.callData,
  });

  List<dynamic> toRlp() => [target, callData];
}

/// Call3 struct (with allowFailure).
class Call3 {
  final String target;
  final bool allowFailure;
  final Uint8List callData;

  const Call3({
    required this.target,
    required this.allowFailure,
    required this.callData,
  });

  List<dynamic> toRlp() => [target, allowFailure, callData];
}

/// Call3Value struct (with value).
class Call3Value {
  final String target;
  final bool allowFailure;
  final BigInt value;
  final Uint8List callData;

  const Call3Value({
    required this.target,
    required this.allowFailure,
    required this.value,
    required this.callData,
  });

  List<dynamic> toRlp() => [target, allowFailure, value, callData];
}

/// Result of aggregate call.
class AggregateResult {
  final BigInt blockNumber;
  final List<Uint8List> returnData;

  const AggregateResult({
    required this.blockNumber,
    required this.returnData,
  });
}

/// Result of individual call in aggregate3.
class Result {
  final bool success;
  final Uint8List returnData;

  const Result({
    required this.success,
    required this.returnData,
  });
}

/// Result of tryAggregate.
class TryAggregateResult {
  final List<Result> results;

  const TryAggregateResult({required this.results});
}

/// Result of tryBlockAndAggregate.
class TryBlockResult {
  final BigInt blockNumber;
  final Uint8List blockHash;
  final List<Result> results;

  const TryBlockResult({
    required this.blockNumber,
    required this.blockHash,
    required this.results,
  });
}

/// Block information.
class BlockInfo {
  final BigInt number;
  final Uint8List hash;
  final BigInt timestamp;

  const BlockInfo({
    required this.number,
    required this.hash,
    required this.timestamp,
  });
}
