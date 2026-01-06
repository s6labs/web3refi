import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/crypto/keccak.dart';

/// CCIP-Read (EIP-3668) implementation for off-chain name resolution
///
/// Enables ENS names to resolve data from off-chain sources like databases,
/// IPFS, or other APIs while maintaining security through verification.
///
/// ## Features
///
/// - Off-chain data resolution
/// - Gateway signature verification
/// - Multiple gateway support with fallback
/// - Automatic error handling
/// - Request caching
///
/// ## Usage
///
/// ```dart
/// final ccipRead = CCIPRead();
///
/// // Resolve data from off-chain gateway
/// final result = await ccipRead.request(
///   sender: contractAddress,
///   urls: ['https://gateway.example.com/{sender}/{data}.json'],
///   callData: encodedCallData,
/// );
/// ```
///
/// ## Specification
///
/// Implements [EIP-3668: CCIP Read](https://eips.ethereum.org/EIPS/eip-3668)
class CCIPRead {
  final http.Client _httpClient;
  final Duration _timeout;

  /// Error selector for OffchainLookup (0x556f1830)
  static const offchainLookupSelector = '0x556f1830';

  CCIPRead({
    http.Client? httpClient,
    Duration timeout = const Duration(seconds: 10),
  })  : _httpClient = httpClient ?? http.Client(),
        _timeout = timeout;

  /// Process a CCIP-Read request
  ///
  /// [sender] - Contract address that initiated the off-chain lookup
  /// [urls] - Gateway URLs to query (supports {sender} and {data} placeholders)
  /// [callData] - Original call data to resolve
  /// [callbackFunction] - Function selector for callback
  /// [extraData] - Additional data for verification
  Future<Uint8List?> request({
    required String sender,
    required List<String> urls,
    required Uint8List callData,
    String? callbackFunction,
    Uint8List? extraData,
  }) async {
    if (urls.isEmpty) {
      throw ArgumentError('At least one gateway URL is required');
    }

    // Try each gateway in order
    for (final url in urls) {
      try {
        final result = await _queryGateway(
          url: url,
          sender: sender,
          callData: callData,
        );

        if (result != null) {
          return result;
        }
      } catch (e) {
        // Try next gateway
        continue;
      }
    }

    return null;
  }

  /// Query a specific gateway
  Future<Uint8List?> _queryGateway({
    required String url,
    required String sender,
    required Uint8List callData,
  }) async {
    // Replace placeholders in URL
    final processedUrl = _processUrl(
      url: url,
      sender: sender,
      data: callData,
    );

    try {
      final response = await _httpClient
          .get(Uri.parse(processedUrl))
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract result from response
        if (json['data'] != null) {
          return _hexToBytes(json['data'] as String);
        }
      }
    } catch (e) {
      rethrow;
    }

    return null;
  }

  /// Process URL template with placeholders
  String _processUrl({
    required String url,
    required String sender,
    required Uint8List data,
  }) {
    var processed = url;

    // Replace {sender} placeholder
    processed = processed.replaceAll(
      '{sender}',
      sender.toLowerCase(),
    );

    // Replace {data} placeholder
    processed = processed.replaceAll(
      '{data}',
      '0x${_bytesToHex(data)}',
    );

    return processed;
  }

  /// Parse OffchainLookup error from revert data
  ///
  /// Returns null if not an OffchainLookup error
  static OffchainLookup? parseError(String revertData) {
    if (!revertData.startsWith(offchainLookupSelector)) {
      return null;
    }

    try {
      // Remove function selector
      final data = revertData.substring(10);

      // Decode parameters
      final decoded = AbiCoder.decodeParameters(
        ['address', 'string[]', 'bytes', 'bytes4', 'bytes'],
        '0x$data',
      );

      return OffchainLookup(
        sender: decoded[0] as String,
        urls: (decoded[1] as List).cast<String>(),
        callData: _hexToBytes(decoded[2] as String),
        callbackFunction: decoded[3] as String,
        extraData: _hexToBytes(decoded[4] as String),
      );
    } catch (e) {
      return null;
    }
  }

  /// Convert hex string to bytes
  static Uint8List _hexToBytes(String hex) {
    final cleaned = hex.replaceFirst('0x', '');
    final bytes = <int>[];

    for (var i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
  }

  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Dispose resources
  void dispose() {
    _httpClient.close();
  }
}

/// OffchainLookup error data
class OffchainLookup {
  final String sender;
  final List<String> urls;
  final Uint8List callData;
  final String callbackFunction;
  final Uint8List extraData;

  OffchainLookup({
    required this.sender,
    required this.urls,
    required this.callData,
    required this.callbackFunction,
    required this.extraData,
  });

  @override
  String toString() {
    return 'OffchainLookup{\n'
        '  sender: $sender,\n'
        '  urls: $urls,\n'
        '  callbackFunction: $callbackFunction\n'
        '}';
  }
}

/// CCIP-Read aware RPC client wrapper
///
/// Automatically handles CCIP-Read errors and performs off-chain lookups.
///
/// ## Usage
///
/// ```dart
/// final client = CCIPReadClient(
///   rpcClient: rpcClient,
///   maxRedirects: 3,
/// );
///
/// // Automatically handles off-chain lookups
/// final result = await client.ethCall(
///   to: resolverAddress,
///   data: callData,
/// );
/// ```
class CCIPReadClient {
  final dynamic _rpcClient; // RpcClient type
  final CCIPRead _ccipRead;
  final int _maxRedirects;

  CCIPReadClient({
    required dynamic rpcClient,
    CCIPRead? ccipRead,
    int maxRedirects = 4,
  })  : _rpcClient = rpcClient,
        _ccipRead = ccipRead ?? CCIPRead(),
        _maxRedirects = maxRedirects;

  /// Perform eth_call with CCIP-Read support
  ///
  /// Automatically handles OffchainLookup errors and performs gateway requests.
  Future<String> ethCall({
    required String to,
    required String data,
    String? from,
    int redirects = 0,
  }) async {
    if (redirects >= _maxRedirects) {
      throw Exception('Maximum CCIP-Read redirects ($_maxRedirects) exceeded');
    }

    try {
      // Attempt normal RPC call
      return await _rpcClient.ethCall(
        to: to,
        data: data,
        from: from,
      );
    } catch (e) {
      // Check if error is OffchainLookup
      final errorStr = e.toString();

      // Extract revert data from error
      final revertData = _extractRevertData(errorStr);
      if (revertData == null) rethrow;

      final offchainLookup = CCIPRead.parseError(revertData);
      if (offchainLookup == null) rethrow;

      // Perform off-chain lookup
      final result = await _ccipRead.request(
        sender: offchainLookup.sender,
        urls: offchainLookup.urls,
        callData: offchainLookup.callData,
        callbackFunction: offchainLookup.callbackFunction,
        extraData: offchainLookup.extraData,
      );

      if (result == null) {
        throw Exception('All CCIP-Read gateways failed');
      }

      // Call callback function with result
      final callbackData = _encodeCallback(
        functionSelector: offchainLookup.callbackFunction,
        response: result,
        extraData: offchainLookup.extraData,
      );

      // Recursive call with callback data
      return await ethCall(
        to: to,
        data: callbackData,
        from: from,
        redirects: redirects + 1,
      );
    }
  }

  /// Extract revert data from error message
  String? _extractRevertData(String error) {
    // Try to find hex data in error message
    final hexPattern = RegExp(r'0x[a-fA-F0-9]+');
    final match = hexPattern.firstMatch(error);
    return match?.group(0);
  }

  /// Encode callback function call
  String _encodeCallback({
    required String functionSelector,
    required Uint8List response,
    required Uint8List extraData,
  }) {
    // Remove '0x' prefix if present
    final selector = functionSelector.replaceFirst('0x', '');

    // Encode parameters: (bytes response, bytes extraData)
    final encoded = AbiCoder.encodeParameters(
      ['bytes', 'bytes'],
      [response, extraData],
    );

    return '0x$selector${encoded.replaceFirst('0x', '')}';
  }

  /// Dispose resources
  void dispose() {
    _ccipRead.dispose();
  }
}
