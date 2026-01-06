import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';

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
    // Encode calls as tuple array
    final callsEncoded = calls.map((call) {
      return [call.target, call.callData];
    }).toList();

    final data = AbiCoder.encodeFunctionCall(
      'aggregate((address,bytes)[])',
      [callsEncoded],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    // Decode: (uint256 blockNumber, bytes[] returnData)
    final decoded = AbiCoder.decodeParameters(
      ['uint256', 'bytes[]'],
      result,
    );

    return AggregateResult(
      blockNumber: decoded[0] as BigInt,
      returnData: (decoded[1] as List).cast<Uint8List>(),
    );
  }

  /// Aggregate calls with optional failure handling.
  ///
  /// Each call can succeed or fail independently.
  Future<List<Result>> aggregate3(List<Call3> calls) async {
    // Encode Call3 structs: (address target, bool allowFailure, bytes callData)
    final callsEncoded = calls.map((call) {
      return [call.target, call.allowFailure, call.callData];
    }).toList();

    final data = AbiCoder.encodeFunctionCall(
      'aggregate3((address,bool,bytes)[])',
      [callsEncoded],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    // Decode: (bool success, bytes returnData)[]
    final decoded = AbiCoder.decodeParameters(
      ['(bool,bytes)[]'],
      result,
    );

    final resultsRaw = decoded[0] as List;
    return resultsRaw.map((item) {
      final tuple = item as List;
      return Result(
        success: tuple[0] as bool,
        returnData: tuple[1] as Uint8List,
      );
    }).toList();
  }

  /// Aggregate calls with value.
  ///
  /// Supports sending ETH with calls.
  Future<List<Result>> aggregate3Value(List<Call3Value> calls) async {
    // Encode Call3Value structs: (address target, bool allowFailure, uint256 value, bytes callData)
    final callsEncoded = calls.map((call) {
      return [call.target, call.allowFailure, call.value, call.callData];
    }).toList();

    // Calculate total value to send
    final totalValue = calls.fold<BigInt>(
      BigInt.zero,
      (sum, call) => sum + call.value,
    );

    final data = AbiCoder.encodeFunctionCall(
      'aggregate3Value((address,bool,uint256,bytes)[])',
      [callsEncoded],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
      value: totalValue,
    );

    // Decode: (bool success, bytes returnData)[]
    final decoded = AbiCoder.decodeParameters(
      ['(bool,bytes)[]'],
      result,
    );

    final resultsRaw = decoded[0] as List;
    return resultsRaw.map((item) {
      final tuple = item as List;
      return Result(
        success: tuple[0] as bool,
        returnData: tuple[1] as Uint8List,
      );
    }).toList();
  }

  /// Try aggregate (deprecated in favor of aggregate3).
  Future<TryAggregateResult> tryAggregate({
    required bool requireSuccess,
    required List<Call> calls,
  }) async {
    // Encode calls as tuple array
    final callsEncoded = calls.map((call) {
      return [call.target, call.callData];
    }).toList();

    final data = AbiCoder.encodeFunctionCall(
      'tryAggregate(bool,(address,bytes)[])',
      [requireSuccess, callsEncoded],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    // Decode: (bool success, bytes returnData)[]
    final decoded = AbiCoder.decodeParameters(
      ['(bool,bytes)[]'],
      result,
    );

    final resultsRaw = decoded[0] as List;
    final results = resultsRaw.map((item) {
      final tuple = item as List;
      return Result(
        success: tuple[0] as bool,
        returnData: tuple[1] as Uint8List,
      );
    }).toList();

    return TryAggregateResult(results: results);
  }

  /// Try block and aggregate.
  Future<TryBlockResult> tryBlockAndAggregate({
    required bool requireSuccess,
    required List<Call> calls,
  }) async {
    // Encode calls as tuple array
    final callsEncoded = calls.map((call) {
      return [call.target, call.callData];
    }).toList();

    final data = AbiCoder.encodeFunctionCall(
      'tryBlockAndAggregate(bool,(address,bytes)[])',
      [requireSuccess, callsEncoded],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    // Decode: (uint256 blockNumber, bytes32 blockHash, (bool,bytes)[] returnData)
    final decoded = AbiCoder.decodeParameters(
      ['uint256', 'bytes32', '(bool,bytes)[]'],
      result,
    );

    final blockNumber = decoded[0] as BigInt;
    final blockHash = decoded[1] as Uint8List;
    final resultsRaw = decoded[2] as List;

    final results = resultsRaw.map((item) {
      final tuple = item as List;
      return Result(
        success: tuple[0] as bool,
        returnData: tuple[1] as Uint8List,
      );
    }).toList();

    return TryBlockResult(
      blockNumber: blockNumber,
      blockHash: blockHash,
      results: results,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITY FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get current block info.
  Future<BlockInfo> getBlockHash(BigInt blockNumber) async {
    final data = AbiCoder.encodeFunctionCall(
      'getBlockHash(uint256)',
      [blockNumber],
    );

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['bytes32'], result);
    final hash = decoded[0] as Uint8List;

    return BlockInfo(
      number: blockNumber,
      hash: hash,
      timestamp: BigInt.zero, // Not provided by this function
    );
  }

  /// Get block number.
  Future<BigInt> getBlockNumber() async {
    final data = AbiCoder.encodeFunctionCall('getBlockNumber()', []);

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    return decoded[0] as BigInt;
  }

  /// Get current block timestamp.
  Future<BigInt> getCurrentBlockTimestamp() async {
    final data = AbiCoder.encodeFunctionCall('getCurrentBlockTimestamp()', []);

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    return decoded[0] as BigInt;
  }

  /// Get ETH balance of address.
  Future<BigInt> getEthBalance(String address) async {
    final data = AbiCoder.encodeFunctionCall('getEthBalance(address)', [
      address,
    ]);

    final result = await rpcClient.ethCall(
      to: contractAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    return decoded[0] as BigInt;
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
