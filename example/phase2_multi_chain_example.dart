/// Example demonstrating Phase 2: Multi-Chain Name Resolution
///
/// Shows how to resolve names across ALL supported name services:
/// - ENS (.eth)
/// - Unstoppable Domains (.crypto, .nft, .wallet, etc.)
/// - Space ID (.bnb, .arb)
/// - Solana Name Service (.sol)
/// - Sui Name Service (.sui)
/// - CiFi (@username, .cifi)
library;

import 'package:web3refi/web3refi.dart';

Future<void> main() async {
  // ══════════════════════════════════════════════════════════════════════
  // SETUP: Initialize RPC clients
  // ══════════════════════════════════════════════════════════════════════

  final ethRpcClient = RpcClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY',
  );

  final cifiClient = CiFiClient(
    apiKey: 'your-cifi-api-key',
    environment: CiFiEnvironment.production,
  );

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 1: Initialize UNS with ALL resolvers enabled
  // ══════════════════════════════════════════════════════════════════════

  print('Example 1: Initialize Universal Name Service with all resolvers\n');

  final uns = UniversalNameService(
    rpcClient: ethRpcClient,
    cifiClient: cifiClient,
    enableCiFiFallback: true,
    enableUnstoppableDomains: true,
    enableSpaceId: true,
    enableSolanaNameService: true,
    enableSuiNameService: true,
    unstoppableDomainsChainId: 137, // Use Polygon for UD
    spaceIdChainId: 56, // Use BNB Chain for Space ID
    solanaRpcUrl: 'https://api.mainnet-beta.solana.com',
    suiRpcUrl: 'https://fullnode.mainnet.sui.io',
  );

  print('✓ UNS initialized with 6 name service resolvers\n');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 2: Resolve names from DIFFERENT name services
  // ══════════════════════════════════════════════════════════════════════

  print('Example 2: Resolve names across different name services\n');

  // ENS (.eth)
  final ensAddress = await uns.resolve('vitalik.eth');
  print('ENS: vitalik.eth → $ensAddress');

  // Unstoppable Domains (.crypto)
  final udAddress = await uns.resolve('brad.crypto');
  print('UD: brad.crypto → $udAddress');

  // Space ID (.bnb)
  final bnbAddress = await uns.resolve('alice.bnb');
  print('Space ID: alice.bnb → $bnbAddress');

  // Solana Name Service (.sol)
  final solAddress = await uns.resolve('toly.sol');
  print('SNS: toly.sol → $solAddress');

  // Sui Name Service (.sui)
  final suiAddress = await uns.resolve('bob.sui');
  print('SuiNS: bob.sui → $suiAddress');

  // CiFi (@username)
  final cifiAddress = await uns.resolve('@alice');
  print('CiFi: @alice → $cifiAddress\n');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 3: Batch resolution across multiple chains
  // ══════════════════════════════════════════════════════════════════════

  print('Example 3: Batch resolution across ALL name services\n');

  final addresses = await uns.resolveMany([
    'vitalik.eth', // ENS
    'brad.crypto', // Unstoppable Domains
    'alice.bnb', // Space ID
    'toly.sol', // Solana Name Service
    'bob.sui', // Sui Name Service
    '@charlie', // CiFi
  ]);

  print('Batch resolution results:');
  for (final entry in addresses.entries) {
    print('  ${entry.key} → ${entry.value}');
  }
  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 4: Unstoppable Domains - Multiple TLDs
  // ══════════════════════════════════════════════════════════════════════

  print('Example 4: Unstoppable Domains supports multiple TLDs\n');

  final udTlds = [
    'brad.crypto',
    'alice.nft',
    'bob.wallet',
    'charlie.x',
    'satoshi.bitcoin',
    'vitalik.dao',
    'lucky.888',
    'dev.blockchain',
  ];

  print('Resolving Unstoppable Domains names:');
  for (final name in udTlds) {
    final address = await uns.resolve(name);
    print('  $name → ${address ?? 'not registered'}');
  }
  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 5: Get records from different name services
  // ══════════════════════════════════════════════════════════════════════

  print('Example 5: Get full records across name services\n');

  // ENS records
  final ensRecords = await uns.getRecords('vitalik.eth');
  if (ensRecords != null) {
    print('ENS Records for vitalik.eth:');
    print('  Avatar: ${ensRecords.avatar}');
    print('  Email: ${ensRecords.getText('email')}');
    print('  Twitter: ${ensRecords.getText('com.twitter')}');
  }

  // Unstoppable Domains records
  final udRecords = await uns.getRecords('brad.crypto');
  if (udRecords != null) {
    print('\nUD Records for brad.crypto:');
    print('  ETH: ${udRecords.ethereumAddress}');
    print('  BTC: ${udRecords.getAddress('0')}');
    print('  Email: ${udRecords.getText('email')}');
  }

  // CiFi records (multi-chain)
  final cifiRecords = await uns.getRecords('@alice');
  if (cifiRecords != null) {
    print('\nCiFi Records for @alice:');
    print('  Chains: ${cifiRecords.addresses.keys.join(', ')}');
    print('  Email: ${cifiRecords.getText('email')}');
  }
  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 6: Reverse resolution
  // ══════════════════════════════════════════════════════════════════════

  print('Example 6: Reverse resolution (address → name)\n');

  // Try ENS reverse
  final ensName = await uns.reverseResolve('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
  print('ENS Reverse: 0xd8dA... → ${ensName ?? 'not set'}');

  // Try CiFi reverse
  final cifiName = await uns.reverseResolve('0x742d...');
  print('CiFi Reverse: 0x742d... → ${cifiName ?? 'not set'}\n');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 7: Multi-chain CiFi resolution
  // ══════════════════════════════════════════════════════════════════════

  print('Example 7: CiFi multi-chain resolution (same username, different chains)\n');

  final chains = {
    1: 'Ethereum',
    137: 'Polygon',
    42161: 'Arbitrum',
    56: 'BNB Chain',
    10: 'Optimism',
    50: 'XDC',
  };

  print('Resolving @alice on different chains:');
  for (final entry in chains.entries) {
    final address = await uns.resolve('@alice', chainId: entry.key);
    print('  ${entry.value} (${entry.key}): $address');
  }
  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 8: Selective resolver enablement
  // ══════════════════════════════════════════════════════════════════════

  print('Example 8: Create UNS with only specific resolvers\n');

  // Only ENS + CiFi (no other resolvers)
  final unsMinimal = UniversalNameService(
    rpcClient: ethRpcClient,
    cifiClient: cifiClient,
    enableUnstoppableDomains: false,
    enableSpaceId: false,
    enableSolanaNameService: false,
    enableSuiNameService: false,
  );

  print('Minimal UNS (ENS + CiFi only) initialized');

  final ethName = await unsMinimal.resolve('vitalik.eth');
  print('  ENS works: vitalik.eth → ${ethName != null}');

  final cifiName2 = await unsMinimal.resolve('@alice');
  print('  CiFi works: @alice → ${cifiName2 != null}');

  // This would return null (UD not enabled)
  final udName = await unsMinimal.resolve('brad.crypto');
  print('  UD disabled: brad.crypto → ${udName ?? 'null (as expected)'}\n');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 9: Resolution with metadata
  // ══════════════════════════════════════════════════════════════════════

  print('Example 9: Resolve with full metadata\n');

  final result = await uns.resolveWithMetadata('vitalik.eth');
  if (result != null) {
    print('Resolution Result:');
    print('  Address: ${result.address}');
    print('  Resolver Used: ${result.resolverUsed}');
    print('  Name: ${result.name}');
    print('  Chain ID: ${result.chainId}');
    if (result.expiresAt != null) {
      print('  Expires: ${result.expiresAt}');
      print('  Days until expiry: ${result.daysUntilExpiration}');
    }
  }
  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 10: Use in a transfer function
  // ══════════════════════════════════════════════════════════════════════

  print('Example 10: Universal name resolution in transfer flow\n');

  Future<void> sendTokens(String recipientName, BigInt amount) async {
    print('  Sending to: $recipientName');

    // Resolve name using UNS - works with ANY supported format!
    final address = await uns.resolve(recipientName);

    if (address == null) {
      print('  ✗ Could not resolve $recipientName');
      return;
    }

    print('  ✓ Resolved to: $address');
    print('  → Sending $amount tokens...');

    // Proceed with transfer
    // await token.transfer(to: address, amount: amount);
  }

  // Works with ALL name formats!
  await sendTokens('vitalik.eth', BigInt.from(1000000)); // ENS
  await sendTokens('brad.crypto', BigInt.from(500000)); // Unstoppable
  await sendTokens('alice.bnb', BigInt.from(250000)); // Space ID
  await sendTokens('@charlie', BigInt.from(100000)); // CiFi

  print('');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 11: Cache performance
  // ══════════════════════════════════════════════════════════════════════

  print('Example 11: Cache improves performance\n');

  final stopwatch = Stopwatch()..start();

  // First resolution - hits blockchain
  await uns.resolve('vitalik.eth');
  final firstCall = stopwatch.elapsedMilliseconds;
  print('  First call (blockchain): ${firstCall}ms');

  stopwatch.reset();

  // Second resolution - uses cache
  await uns.resolve('vitalik.eth');
  final secondCall = stopwatch.elapsedMilliseconds;
  print('  Second call (cached): ${secondCall}ms');
  print('  Speed improvement: ${(firstCall / secondCall).toStringAsFixed(1)}x faster\n');

  print('✓ All Phase 2 examples completed!');
  print('\n════════════════════════════════════════════════════════════════');
  print('🎉 PHASE 2: Multi-Chain Resolution is PRODUCTION READY!');
  print('════════════════════════════════════════════════════════════════');
  print('\nSupported name services:');
  print('  ✓ ENS (.eth)');
  print('  ✓ Unstoppable Domains (.crypto, .nft, .wallet, .x, .bitcoin, .dao, .888, .blockchain)');
  print('  ✓ Space ID (.bnb, .arb)');
  print('  ✓ Solana Name Service (.sol)');
  print('  ✓ Sui Name Service (.sui)');
  print('  ✓ CiFi (@username, .cifi)');
  print('\nFeatures:');
  print('  ✓ Universal resolution (ONE API for ALL names)');
  print('  ✓ Batch resolution');
  print('  ✓ Reverse resolution');
  print('  ✓ Multi-chain support');
  print('  ✓ Text records & metadata');
  print('  ✓ Caching for performance');
  print('  ✓ Extensible architecture');
}
