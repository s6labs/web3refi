import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/standards/multicall.dart';
import 'package:web3refi/src/names/resolution_result.dart';
import 'package:web3refi/src/names/utils/namehash.dart';

/// Optimized batch name resolution using Multicall3
///
/// Resolves multiple names in a single RPC call, dramatically reducing
/// latency and improving performance.
///
/// ## Features
///
/// - Batch forward resolution (names → addresses)
/// - Batch reverse resolution (addresses → names)
/// - Batch record fetching
/// - Automatic chunking for large batches
/// - Error handling per-name
/// - Gas-optimized multicall
///
/// ## Usage
///
/// ```dart
/// final batchResolver = BatchResolver(
///   rpcClient: rpcClient,
///   resolverAddress: '0x...',
/// );
///
/// // Resolve multiple names at once
/// final results = await batchResolver.resolveMany([
///   'vitalik.eth',
///   'alice.eth',
///   'bob.eth',
/// ]);
/// ```
class BatchResolver {
  final RpcClient _rpc;
  final String _resolverAddress;
  final int _maxBatchSize;

  /// Multicall3 instance
  late final Multicall3 _multicall;

  BatchResolver({
    required RpcClient rpcClient,
    required String resolverAddress,
    String? multicallAddress,
    int maxBatchSize = 100,
  })  : _rpc = rpcClient,
        _resolverAddress = resolverAddress,
        _maxBatchSize = maxBatchSize {
    _multicall = Multicall3(
      rpcClient: rpcClient,
      contractAddress: multicallAddress,
    );
  }

  /// Batch resolve multiple names to addresses
  ///
  /// Returns a map of name → address (null if resolution failed)
  Future<Map<String, String?>> resolveMany(List<String> names) async {
    if (names.isEmpty) return {};

    final results = <String, String?>{};

    // Process in chunks
    for (var i = 0; i < names.length; i += _maxBatchSize) {
      final chunk = names.skip(i).take(_maxBatchSize).toList();
      final chunkResults = await _resolveBatch(chunk);
      results.addAll(chunkResults);
    }

    return results;
  }

  /// Resolve a batch of names
  Future<Map<String, String?>> _resolveBatch(List<String> names) async {
    // Build multicall calls
    final calls = names.map((name) {
      final node = namehash(name);

      // Call: addr(bytes32 node) returns (address)
      final data = AbiCoder.encodeFunctionCall(
        'addr(bytes32)',
        [node],
      );

      return Call3(
        target: _resolverAddress,
        allowFailure: true,
        callData: data,
      );
    }).toList();

    // Execute multicall
    final responses = await _multicall.aggregate3(calls);

    // Parse results
    final results = <String, String?>{};

    for (var i = 0; i < names.length; i++) {
      final name = names[i];
      final response = responses[i];

      if (response.success && response.returnData.isNotEmpty) {
        try {
          final decoded = AbiCoder.decodeParameters(
            ['address'],
            '0x${_bytesToHex(response.returnData)}',
          );
          final address = decoded[0] as String;

          // Check if zero address
          if (address != '0x0000000000000000000000000000000000000000') {
            results[name] = address;
          } else {
            results[name] = null;
          }
        } catch (e) {
          results[name] = null;
        }
      } else {
        results[name] = null;
      }
    }

    return results;
  }

  /// Batch reverse resolve addresses to names
  Future<Map<String, String?>> reverseResolveMany(
    List<String> addresses,
  ) async {
    if (addresses.isEmpty) return {};

    final results = <String, String?>{};

    // Process in chunks
    for (var i = 0; i < addresses.length; i += _maxBatchSize) {
      final chunk = addresses.skip(i).take(_maxBatchSize).toList();
      final chunkResults = await _reverseResolveBatch(chunk);
      results.addAll(chunkResults);
    }

    return results;
  }

  /// Reverse resolve a batch of addresses
  Future<Map<String, String?>> _reverseResolveBatch(
    List<String> addresses,
  ) async {
    // Build multicall calls
    final calls = addresses.map((address) {
      // Construct reverse node: addr.reverse namehash
      final reverseName = '${address.toLowerCase().replaceFirst('0x', '')}.addr.reverse';
      final node = namehash(reverseName);

      // Call: name(bytes32 node) returns (string)
      final data = AbiCoder.encodeFunctionCall(
        'name(bytes32)',
        [node],
      );

      return Call3(
        target: _resolverAddress,
        allowFailure: true,
        callData: data,
      );
    }).toList();

    // Execute multicall
    final responses = await _multicall.aggregate3(calls);

    // Parse results
    final results = <String, String?>{};

    for (var i = 0; i < addresses.length; i++) {
      final address = addresses[i];
      final response = responses[i];

      if (response.success && response.returnData.isNotEmpty) {
        try {
          final decoded = AbiCoder.decodeParameters(
            ['string'],
            '0x${_bytesToHex(response.returnData)}',
          );
          final name = decoded[0] as String;

          if (name.isNotEmpty) {
            results[address] = name;
          } else {
            results[address] = null;
          }
        } catch (e) {
          results[address] = null;
        }
      } else {
        results[address] = null;
      }
    }

    return results;
  }

  /// Batch fetch text records for multiple names
  Future<Map<String, Map<String, String>>> fetchRecordsMany({
    required List<String> names,
    required List<String> keys,
  }) async {
    if (names.isEmpty || keys.isEmpty) return {};

    final results = <String, Map<String, String>>{};

    // Process in chunks
    for (var i = 0; i < names.length; i += _maxBatchSize) {
      final chunk = names.skip(i).take(_maxBatchSize).toList();
      final chunkResults = await _fetchRecordsBatch(chunk, keys);
      results.addAll(chunkResults);
    }

    return results;
  }

  /// Fetch records for a batch of names
  Future<Map<String, Map<String, String>>> _fetchRecordsBatch(
    List<String> names,
    List<String> keys,
  ) async {
    // Build multicall calls (one call per name-key combination)
    final calls = <Call3>[];
    final callMetadata = <_RecordCallMetadata>[];

    for (final name in names) {
      final node = namehash(name);

      for (final key in keys) {
        // Call: text(bytes32 node, string key) returns (string)
        final data = AbiCoder.encodeFunctionCall(
          'text(bytes32,string)',
          [node, key],
        );

        calls.add(Call3(
          target: _resolverAddress,
          allowFailure: true,
          callData: data,
        ));

        callMetadata.add(_RecordCallMetadata(
          name: name,
          key: key,
        ));
      }
    }

    // Execute multicall
    final responses = await _multicall.aggregate3(calls);

    // Parse results
    final results = <String, Map<String, String>>{};

    for (var i = 0; i < responses.length; i++) {
      final response = responses[i];
      final metadata = callMetadata[i];

      // Initialize map for this name if needed
      results[metadata.name] ??= {};

      if (response.success && response.returnData.isNotEmpty) {
        try {
          final decoded = AbiCoder.decodeParameters(
            ['string'],
            '0x${_bytesToHex(response.returnData)}',
          );
          final value = decoded[0] as String;

          if (value.isNotEmpty) {
            results[metadata.name]![metadata.key] = value;
          }
        } catch (e) {
          // Skip failed records
        }
      }
    }

    return results;
  }

  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Metadata for record calls
class _RecordCallMetadata {
  final String name;
  final String key;

  _RecordCallMetadata({
    required this.name,
    required this.key,
  });
}
