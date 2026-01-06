/// Deployment script for Universal Registry
///
/// Usage:
/// ```bash
/// dart run scripts/deploy_registry.dart --tld xdc --chain-id 50 --rpc-url https://rpc.xdc.network
/// ```

import 'dart:io';
import 'package:web3refi/web3refi.dart';

Future<void> main(List<String> args) async {
  print('═══════════════════════════════════════════════════════════════');
  print('Universal Registry Deployment Script');
  print('═══════════════════════════════════════════════════════════════\n');

  // Parse arguments
  final config = _parseArgs(args);

  print('Configuration:');
  print('  TLD: ${config['tld']}');
  print('  Chain ID: ${config['chainId']}');
  print('  RPC URL: ${config['rpcUrl']}\n');

  // Get deployment wallet
  print('Enter deployment wallet mnemonic:');
  final mnemonic = stdin.readLineSync() ?? '';

  if (mnemonic.isEmpty) {
    print('Error: Mnemonic is required');
    exit(1);
  }

  // Initialize wallet and RPC client
  final wallet = HdWallet.fromMnemonic(mnemonic);
  final address = await wallet.getAddress();

  final rpcClient = RpcClient(rpcUrl: config['rpcUrl']!);

  print('Deployer address: $address');

  // Check balance
  final balance = await rpcClient.getBalance(address);
  print('Deployer balance: ${balance.toString()} wei\n');

  if (balance == BigInt.zero) {
    print('Error: Insufficient balance for deployment');
    exit(1);
  }

  // Confirm deployment
  print('Deploy Universal Registry for .${config['tld']} on chain ${config['chainId']}?');
  print('Press Enter to continue, or Ctrl+C to cancel...');
  stdin.readLineSync();

  print('\nStarting deployment...\n');

  // Create factory
  final factory = RegistryFactory(
    rpcClient: rpcClient,
    signer: wallet,
  );

  try {
    // Deploy
    print('Deploying registry and resolver contracts...');

    final deployment = await factory.deploy(
      tld: config['tld']!,
      chainId: int.parse(config['chainId']!),
    );

    print('\n✓ Deployment successful!\n');
    print('═══════════════════════════════════════════════════════════════');
    print('Deployment Results');
    print('═══════════════════════════════════════════════════════════════');
    print('TLD: .${deployment.tld}');
    print('Chain ID: ${deployment.chainId}');
    print('Registry: ${deployment.registryAddress}');
    print('Resolver: ${deployment.resolverAddress}');
    print('Deployed: ${deployment.deployedAt}');
    print('═══════════════════════════════════════════════════════════════\n');

    // Save deployment info
    _saveDeployment(deployment);

    print('✓ Deployment info saved to deployments/${deployment.tld}_${deployment.chainId}.json\n');

    // Next steps
    print('Next steps:');
    print('1. Verify contracts on block explorer');
    print('2. Add controllers for registration');
    print('3. Configure pricing (if needed)');
    print('4. Test name registration\n');
  } catch (e) {
    print('\n✗ Deployment failed: $e\n');
    exit(1);
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final config = <String, String>{};

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--tld':
        config['tld'] = args[++i];
        break;
      case '--chain-id':
        config['chainId'] = args[++i];
        break;
      case '--rpc-url':
        config['rpcUrl'] = args[++i];
        break;
    }
  }

  // Validate required args
  if (!config.containsKey('tld')) {
    print('Error: --tld is required');
    exit(1);
  }

  if (!config.containsKey('chainId')) {
    print('Error: --chain-id is required');
    exit(1);
  }

  if (!config.containsKey('rpcUrl')) {
    print('Error: --rpc-url is required');
    exit(1);
  }

  return config;
}

void _saveDeployment(RegistryDeployment deployment) {
  final dir = Directory('deployments');
  if (!dir.existsSync()) {
    dir.createSync();
  }

  final file = File('deployments/${deployment.tld}_${deployment.chainId}.json');

  final json = '''
{
  "tld": "${deployment.tld}",
  "chainId": ${deployment.chainId},
  "registryAddress": "${deployment.registryAddress}",
  "resolverAddress": "${deployment.resolverAddress}",
  "deployedAt": "${deployment.deployedAt.toIso8601String()}"
}
''';

  file.writeAsStringSync(json);
}
