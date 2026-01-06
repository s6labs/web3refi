import 'dart:typed_data';
import '../../transport/rpc_client.dart';
import '../../abi/abi_coder.dart';
import '../../signers/hd_wallet.dart';
import '../../transactions/eip1559_tx.dart';
import '../utils/namehash.dart';

/// Controller for name registration operations
///
/// Handles registration, renewal, and management of names in a Universal Registry.
///
/// ## Features
///
/// - Register new names
/// - Renew existing names
/// - Check name availability
/// - Get registration price
/// - Set resolver records
///
/// ## Usage
///
/// ```dart
/// final controller = RegistrationController(
///   registryAddress: '0x123...',
///   resolverAddress: '0x456...',
///   rpcClient: rpcClient,
///   signer: wallet,
/// );
///
/// // Register a name
/// await controller.register(
///   name: 'myname.xdc',
///   owner: myAddress,
///   duration: Duration(days: 365),
/// );
/// ```
class RegistrationController {
  final String _registryAddress;
  final String _resolverAddress;
  final RpcClient _rpc;
  final HdWallet _signer;

  RegistrationController({
    required String registryAddress,
    required String resolverAddress,
    required RpcClient rpcClient,
    required HdWallet signer,
  })  : _registryAddress = registryAddress,
        _resolverAddress = resolverAddress,
        _rpc = rpcClient,
        _signer = signer;

  // ══════════════════════════════════════════════════════════════════════
  // REGISTRATION FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════

  /// Register a new name
  ///
  /// [name] - Full domain name (e.g., 'myname.xdc')
  /// [owner] - Owner address
  /// [duration] - Registration duration
  /// [resolverAddress] - Optional custom resolver (uses default if not specified)
  /// [setRecords] - Optional records to set immediately
  Future<RegistrationResult> register({
    required String name,
    required String owner,
    required Duration duration,
    String? resolverAddress,
    Map<String, String>? setRecords,
  }) async {
    // Validate inputs
    final validation = NameValidator.validate(name);
    if (validation != null) {
      throw ArgumentError(validation);
    }

    // Check availability
    final available = await isAvailable(name);
    if (!available) {
      throw Exception('Name $name is not available');
    }

    // Compute namehash
    final node = namehash(name);

    // Register name
    final registerTxHash = await _registerName(
      node: node,
      name: name,
      owner: owner,
      duration: duration,
    );

    // Set resolver if provided
    String? setResolverTxHash;
    if (resolverAddress != null) {
      setResolverTxHash = await _setResolver(
        node: node,
        resolver: resolverAddress,
      );
    }

    // Set records if provided
    String? setRecordsTxHash;
    if (setRecords != null && setRecords.isNotEmpty) {
      setRecordsTxHash = await _setTextRecords(
        node: node,
        records: setRecords,
      );
    }

    // Calculate expiry
    final expiry = DateTime.now().add(duration);

    return RegistrationResult(
      name: name,
      owner: owner,
      expiry: expiry,
      registerTxHash: registerTxHash,
      setResolverTxHash: setResolverTxHash,
      setRecordsTxHash: setRecordsTxHash,
    );
  }

  /// Renew an existing name
  ///
  /// [name] - Full domain name
  /// [duration] - Additional duration to add
  Future<String> renew({
    required String name,
    required Duration duration,
  }) async {
    final node = namehash(name);

    // renew(bytes32 node, uint256 duration)
    final data = AbiCoder.encodeFunctionCall(
      'renew(bytes32,uint256)',
      [node, BigInt.from(duration.inSeconds)],
    );

    return await _sendTransaction(
      to: _registryAddress,
      data: data,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // RESOLVER FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════

  /// Set address for a name
  ///
  /// [name] - Full domain name
  /// [address] - Address to set
  /// [coinType] - Coin type (60 for ETH, 0 for BTC, etc.)
  Future<String> setAddress({
    required String name,
    required String address,
    int coinType = 60,
  }) async {
    final node = namehash(name);

    if (coinType == 60) {
      // setAddr(bytes32,address)
      final data = AbiCoder.encodeFunctionCall(
        'setAddr(bytes32,address)',
        [node, address],
      );

      return await _sendTransaction(
        to: _resolverAddress,
        data: data,
      );
    } else {
      // setAddr(bytes32,uint256,bytes)
      final addressBytes = _hexToBytes(address);
      final data = AbiCoder.encodeFunctionCall(
        'setAddr(bytes32,uint256,bytes)',
        [node, BigInt.from(coinType), addressBytes],
      );

      return await _sendTransaction(
        to: _resolverAddress,
        data: data,
      );
    }
  }

  /// Set text record for a name
  ///
  /// [name] - Full domain name
  /// [key] - Record key (e.g., 'email', 'url', 'avatar')
  /// [value] - Record value
  Future<String> setTextRecord({
    required String name,
    required String key,
    required String value,
  }) async {
    final node = namehash(name);

    // setText(bytes32,string,string)
    final data = AbiCoder.encodeFunctionCall(
      'setText(bytes32,string,string)',
      [node, key, value],
    );

    return await _sendTransaction(
      to: _resolverAddress,
      data: data,
    );
  }

  /// Set multiple records at once (gas optimization)
  ///
  /// [name] - Full domain name
  /// [address] - Address to set
  /// [textRecords] - Map of text records (key → value)
  Future<String> setRecords({
    required String name,
    String? address,
    Map<String, String>? textRecords,
  }) async {
    final node = namehash(name);

    final addressBytes = address != null ? _hexToBytes(address) : Uint8List(0);
    final textKeys = textRecords?.keys.toList() ?? [];
    final textValues = textRecords?.values.toList() ?? [];

    // setRecords(bytes32,uint256,bytes,string[],string[])
    final data = AbiCoder.encodeFunctionCall(
      'setRecords(bytes32,uint256,bytes,string[],string[])',
      [node, BigInt.from(60), addressBytes, textKeys, textValues],
    );

    return await _sendTransaction(
      to: _resolverAddress,
      data: data,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // VIEW FUNCTIONS
  // ══════════════════════════════════════════════════════════════════════

  /// Check if a name is available for registration
  Future<bool> isAvailable(String name) async {
    final node = namehash(name);

    // available(bytes32)
    final data = AbiCoder.encodeFunctionCall('available(bytes32)', [node]);

    final result = await _rpc.ethCall(
      to: _registryAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['bool'], result);
    return decoded[0] as bool;
  }

  /// Get expiry time for a name
  Future<DateTime?> getExpiry(String name) async {
    final node = namehash(name);

    // nameExpires(bytes32)
    final data = AbiCoder.encodeFunctionCall('nameExpires(bytes32)', [node]);

    final result = await _rpc.ethCall(
      to: _registryAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['uint256'], result);
    final timestamp = decoded[0] as BigInt;

    if (timestamp == BigInt.zero) return null;

    return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
  }

  /// Get owner of a name
  Future<String?> getOwner(String name) async {
    final node = namehash(name);

    // owner(bytes32)
    final data = AbiCoder.encodeFunctionCall('owner(bytes32)', [node]);

    final result = await _rpc.ethCall(
      to: _registryAddress,
      data: data,
    );

    final decoded = AbiCoder.decodeParameters(['address'], result);
    final owner = decoded[0] as String;

    return owner == '0x0000000000000000000000000000000000000000' ? null : owner;
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL METHODS
  // ══════════════════════════════════════════════════════════════════════

  Future<String> _registerName({
    required Uint8List node,
    required String name,
    required String owner,
    required Duration duration,
  }) async {
    // register(bytes32 node, string calldata name, address owner, uint256 duration)
    final data = AbiCoder.encodeFunctionCall(
      'register(bytes32,string,address,uint256)',
      [node, name, owner, BigInt.from(duration.inSeconds)],
    );

    return await _sendTransaction(
      to: _registryAddress,
      data: data,
    );
  }

  Future<String> _setResolver({
    required Uint8List node,
    required String resolver,
  }) async {
    // setResolver(bytes32,address)
    final data = AbiCoder.encodeFunctionCall(
      'setResolver(bytes32,address)',
      [node, resolver],
    );

    return await _sendTransaction(
      to: _registryAddress,
      data: data,
    );
  }

  Future<String> _setTextRecords({
    required Uint8List node,
    required Map<String, String> records,
  }) async {
    // Set records one by one (could be optimized with batch setter)
    String? lastTxHash;

    for (final entry in records.entries) {
      final data = AbiCoder.encodeFunctionCall(
        'setText(bytes32,string,string)',
        [node, entry.key, entry.value],
      );

      lastTxHash = await _sendTransaction(
        to: _resolverAddress,
        data: data,
      );
    }

    return lastTxHash ?? '';
  }

  Future<String> _sendTransaction({
    required String to,
    required String data,
  }) async {
    final tx = Eip1559Transaction(
      to: to,
      value: BigInt.zero,
      data: data,
      chainId: await _getChainId(),
      nonce: await _getNonce(),
      maxFeePerGas: await _estimateMaxFeePerGas(),
      maxPriorityFeePerGas: await _estimatePriorityFee(),
      gasLimit: BigInt.from(200000),
    );

    final signedTx = await _signer.signTransaction(tx);
    return await _rpc.sendRawTransaction(signedTx);
  }

  Future<int> _getChainId() async {
    return await _rpc.chainId();
  }

  Future<int> _getNonce() async {
    final address = await _signer.getAddress();
    return await _rpc.getTransactionCount(address);
  }

  Future<BigInt> _estimateMaxFeePerGas() async {
    final gasPrice = await _rpc.getGasPrice();
    return gasPrice * BigInt.from(2);
  }

  Future<BigInt> _estimatePriorityFee() async {
    return BigInt.from(2000000000); // 2 gwei
  }

  Uint8List _hexToBytes(String hex) {
    final cleaned = hex.replaceFirst('0x', '');
    final bytes = <int>[];

    for (var i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
  }
}

/// Result of a name registration
class RegistrationResult {
  final String name;
  final String owner;
  final DateTime expiry;
  final String registerTxHash;
  final String? setResolverTxHash;
  final String? setRecordsTxHash;

  RegistrationResult({
    required this.name,
    required this.owner,
    required this.expiry,
    required this.registerTxHash,
    this.setResolverTxHash,
    this.setRecordsTxHash,
  });

  @override
  String toString() {
    return 'RegistrationResult{'
        'name: $name, '
        'owner: $owner, '
        'expiry: $expiry'
        '}';
  }
}
