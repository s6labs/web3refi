import 'dart:typed_data';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/abi/abi_coder.dart';
import 'package:web3refi/src/signers/hd_wallet.dart';
import 'package:web3refi/src/transactions/eip1559_tx.dart';
import 'package:web3refi/src/names/utils/namehash.dart';

/// Factory for deploying Universal Registry contracts
///
/// Enables deployment of custom name service registries on any EVM chain.
///
/// ## Features
///
/// - Deploy registry contracts
/// - Deploy resolver contracts
/// - Configure registry settings
/// - Add controllers
/// - Get deployment addresses
///
/// ## Usage
///
/// ```dart
/// final factory = RegistryFactory(
///   rpcClient: rpcClient,
///   signer: wallet,
/// );
///
/// // Deploy registry for .xdc TLD
/// final deployment = await factory.deploy(
///   tld: 'xdc',
///   chainId: 50,
/// );
///
/// print('Registry: ${deployment.registryAddress}');
/// print('Resolver: ${deployment.resolverAddress}');
/// ```
class RegistryFactory {
  final RpcClient _rpc;
  final HdWallet _signer;

  RegistryFactory({
    required RpcClient rpcClient,
    required HdWallet signer,
  })  : _rpc = rpcClient,
        _signer = signer;

  /// Deploy a complete name service (registry + resolver)
  ///
  /// [tld] - Top-level domain (e.g., 'xdc', 'hedera')
  /// [chainId] - Chain ID for deployment
  /// [gasPrice] - Optional gas price (auto-detected if not provided)
  /// [maxFeePerGas] - Optional max fee for EIP-1559
  /// [maxPriorityFeePerGas] - Optional priority fee for EIP-1559
  Future<RegistryDeployment> deploy({
    required String tld,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    // Compute TLD namehash
    final tldNode = namehash(tld);

    // Deploy registry
    final registryAddress = await _deployRegistry(
      tld: tld,
      tldNode: tldNode,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );

    // Deploy resolver
    final resolverAddress = await _deployResolver(
      registryAddress: registryAddress,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );

    return RegistryDeployment(
      tld: tld,
      chainId: chainId,
      registryAddress: registryAddress,
      resolverAddress: resolverAddress,
      deployedAt: DateTime.now(),
    );
  }

  /// Deploy only the registry contract
  Future<String> deployRegistry({
    required String tld,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    final tldNode = namehash(tld);

    return _deployRegistry(
      tld: tld,
      tldNode: tldNode,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Deploy only the resolver contract
  Future<String> deployResolver({
    required String registryAddress,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    return _deployResolver(
      registryAddress: registryAddress,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  /// Add a controller to the registry
  ///
  /// Controllers can register names on behalf of users
  Future<String> addController({
    required String registryAddress,
    required String controllerAddress,
    required int chainId,
  }) async {
    // addController(address)
    final data = AbiCoder.encodeFunctionCall(
      'addController(address)',
      [controllerAddress],
    );

    return await _sendTransaction(
      to: registryAddress,
      data: data,
      chainId: chainId,
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  // INTERNAL DEPLOYMENT METHODS
  // ══════════════════════════════════════════════════════════════════════

  Future<String> _deployRegistry({
    required String tld,
    required Uint8List tldNode,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    // Constructor: constructor(string memory _tld, bytes32 _tldNode)
    final constructorParams = AbiCoder.encodeParameters(
      ['string', 'bytes32'],
      [tld, tldNode],
    );

    final bytecode = _getRegistryBytecode() + constructorParams.replaceFirst('0x', '');

    return await _deployContract(
      bytecode: bytecode,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  Future<String> _deployResolver({
    required String registryAddress,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    // Constructor: constructor(IUniversalRegistry _registry)
    final constructorParams = AbiCoder.encodeParameters(
      ['address'],
      [registryAddress],
    );

    final bytecode = _getResolverBytecode() + constructorParams.replaceFirst('0x', '');

    return await _deployContract(
      bytecode: bytecode,
      chainId: chainId,
      gasPrice: gasPrice,
      maxFeePerGas: maxFeePerGas,
      maxPriorityFeePerGas: maxPriorityFeePerGas,
    );
  }

  Future<String> _deployContract({
    required String bytecode,
    required int chainId,
    BigInt? gasPrice,
    BigInt? maxFeePerGas,
    BigInt? maxPriorityFeePerGas,
  }) async {
    // Create deployment transaction
    final tx = Eip1559Transaction(
      to: null, // Contract creation
      value: BigInt.zero,
      data: bytecode,
      chainId: chainId,
      nonce: await _getNonce(),
      maxFeePerGas: maxFeePerGas ?? await _estimateMaxFeePerGas(),
      maxPriorityFeePerGas: maxPriorityFeePerGas ?? await _estimatePriorityFee(),
      gasLimit: BigInt.from(3000000), // High limit for deployment
    );

    // Sign and send
    final signedTx = await _signer.signTransaction(tx);
    final txHash = await _rpc.sendRawTransaction(signedTx);

    // Wait for receipt
    final receipt = await _waitForReceipt(txHash);

    if (receipt['contractAddress'] == null) {
      throw Exception('Contract deployment failed');
    }

    return receipt['contractAddress'] as String;
  }

  Future<String> _sendTransaction({
    required String to,
    required String data,
    required int chainId,
  }) async {
    final tx = Eip1559Transaction(
      to: to,
      value: BigInt.zero,
      data: data,
      chainId: chainId,
      nonce: await _getNonce(),
      maxFeePerGas: await _estimateMaxFeePerGas(),
      maxPriorityFeePerGas: await _estimatePriorityFee(),
      gasLimit: BigInt.from(100000),
    );

    final signedTx = await _signer.signTransaction(tx);
    return await _rpc.sendRawTransaction(signedTx);
  }

  // ══════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════

  Future<int> _getNonce() async {
    final address = await _signer.getAddress();
    return await _rpc.getTransactionCount(address);
  }

  Future<BigInt> _estimateMaxFeePerGas() async {
    final gasPrice = await _rpc.getGasPrice();
    return gasPrice * BigInt.from(2); // 2x current price for fast inclusion
  }

  Future<BigInt> _estimatePriorityFee() async {
    return BigInt.from(2000000000); // 2 gwei default
  }

  Future<Map<String, dynamic>> _waitForReceipt(String txHash,
      {int maxAttempts = 60}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final receipt = await _rpc.getTransactionReceipt(txHash);
        if (receipt != null) {
          return receipt;
        }
      } catch (e) {
        // Receipt not found yet
      }

      await Future.delayed(const Duration(seconds: 2));
    }

    throw Exception('Transaction not mined after $maxAttempts attempts');
  }

  // ══════════════════════════════════════════════════════════════════════
  // CONTRACT BYTECODE
  // ══════════════════════════════════════════════════════════════════════
  // In production, these would be loaded from compiled contract artifacts

  String _getRegistryBytecode() {
    // This is a placeholder - in production, use actual compiled bytecode
    // The bytecode would be generated by compiling UniversalRegistry.sol
    return '0x608060405234801561001057600080fd5b50...'; // Truncated for brevity
  }

  String _getResolverBytecode() {
    // This is a placeholder - in production, use actual compiled bytecode
    // The bytecode would be generated by compiling UniversalResolver.sol
    return '0x608060405234801561001057600080fd5b50...'; // Truncated for brevity
  }
}

/// Result of a registry deployment
class RegistryDeployment {
  final String tld;
  final int chainId;
  final String registryAddress;
  final String resolverAddress;
  final DateTime deployedAt;

  RegistryDeployment({
    required this.tld,
    required this.chainId,
    required this.registryAddress,
    required this.resolverAddress,
    required this.deployedAt,
  });

  @override
  String toString() {
    return 'RegistryDeployment{'
        'tld: $tld, '
        'chainId: $chainId, '
        'registry: $registryAddress, '
        'resolver: $resolverAddress'
        '}';
  }
}
