/// Example demonstrating Universal Name Service (UNS) usage.
///
/// Shows how to resolve names across multiple name services with one API.
library;

import 'package:web3refi/web3refi.dart';

Future<void> main() async {
  // Initialize RPC client
  final rpcClient = RpcClient(
    rpcUrl: 'https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY',
  );

  // Initialize CiFi client (optional, but enables CiFi fallback)
  final cifiClient = CiFiClient(
    apiKey: 'your-cifi-api-key',
    environment: CiFiEnvironment.production,
  );

  // Create Universal Name Service
  final uns = UniversalNameService(
    rpcClient: rpcClient,
    cifiClient: cifiClient,
    enableCiFiFallback: true,
  );

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 1: Resolve ENS name
  // ══════════════════════════════════════════════════════════════════════

  print('Example 1: Resolving ENS name');
  final vitalikAddress = await uns.resolve('vitalik.eth');
  print('vitalik.eth → $vitalikAddress');
  // Output: vitalik.eth → 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 2: Resolve CiFi username
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 2: Resolving CiFi username');
  final aliceAddress = await uns.resolve('@alice');
  print('@alice → $aliceAddress');

  // Same username, different chain
  final aliceOnPolygon = await uns.resolve('@alice', chainId: 137);
  print('@alice on Polygon → $aliceOnPolygon');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 3: Reverse resolution
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 3: Reverse resolution');
  final name = await uns.reverseResolve('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
  print('0xd8dA... → $name');
  // Output: 0xd8dA... → vitalik.eth

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 4: Get all records
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 4: Get all records for a name');
  final records = await uns.getRecords('vitalik.eth');
  if (records != null) {
    print('Owner: ${records.owner}');
    print('Avatar: ${records.avatar}');
    print('Email: ${records.getText('email')}');
    print('URL: ${records.getText('url')}');
    print('Twitter: ${records.getText('com.twitter')}');
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 5: Resolve with metadata
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 5: Resolve with full metadata');
  final result = await uns.resolveWithMetadata('vitalik.eth');
  if (result != null) {
    print('Address: ${result.address}');
    print('Resolved by: ${result.resolverUsed}');
    print('Expires: ${result.expiresAt}');
    print('Days until expiry: ${result.daysUntilExpiration}');
    print('Expiring soon: ${result.isExpiringSoon}');
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 6: Batch resolution
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 6: Resolve multiple names at once');
  final addresses = await uns.resolveMany([
    'vitalik.eth',
    '@alice',
    'bob.eth',
  ]);

  for (final entry in addresses.entries) {
    print('${entry.key} → ${entry.value}');
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 7: Get avatar
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 7: Get avatar URL');
  final avatarUrl = await uns.getAvatar('vitalik.eth');
  print('Avatar: $avatarUrl');

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 8: Name validation
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 8: Validate names');

  final validNames = ['vitalik.eth', '@alice', 'bob.crypto'];
  final invalidNames = ['ab', 'test..eth', '.invalid'];

  for (final name in [...validNames, ...invalidNames]) {
    final error = NameValidator.validate(name);
    if (error == null) {
      print('✓ $name is valid');
    } else {
      print('✗ $name is invalid: $error');
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 9: Use in transfer function
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 9: Use in transfer (pseudo-code)');

  Future<void> sendTokens(String recipientName, BigInt amount) async {
    // Resolve name to address
    final address = await uns.resolve(recipientName);

    if (address == null) {
      print('Error: Could not resolve $recipientName');
      return;
    }

    print('Sending $amount tokens to $address ($recipientName)');

    // Proceed with transfer
    // await token.transfer(to: address, amount: amount);
  }

  await sendTokens('vitalik.eth', BigInt.from(1000000));
  await sendTokens('@alice', BigInt.from(500000));

  // ══════════════════════════════════════════════════════════════════════
  // EXAMPLE 10: Register custom resolver
  // ══════════════════════════════════════════════════════════════════════

  print('\nExample 10: Register custom resolver (advanced)');

  // You can add support for other name services by implementing NameResolver
  // and registering it:
  //
  // final customResolver = MyCustomResolver();
  // uns.registerResolver('custom', customResolver);
  // uns.registerTLD('custom', 'custom');
  //
  // Now you can resolve names like: alice.custom

  print('\n✓ All examples completed!');
}
