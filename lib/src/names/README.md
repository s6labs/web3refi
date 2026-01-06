# Universal Name Service (UNS)

**One API for all blockchain name services.**

## Overview

The Universal Name Service provides a unified interface for resolving names across multiple blockchain name services (ENS, Unstoppable Domains, Solana Name Service, etc.) with CiFi as a universal fallback.

## Features

- ✅ **Unified API** - One method to resolve all name formats
- ✅ **Multi-chain** - Resolve names on any blockchain
- ✅ **ENS Support** - Full Ethereum Name Service integration
- ✅ **CiFi Integration** - Free, instant resolution via @usernames
- ✅ **Reverse Resolution** - Address → name lookup
- ✅ **Batch Resolution** - Resolve multiple names efficiently
- ✅ **Caching** - Automatic caching for performance
- ✅ **Extensible** - Easy to add new name services

## Supported Name Services

| Service | TLD | Status | Example |
|---------|-----|--------|---------|
| **ENS** | .eth | ✅ Supported | vitalik.eth |
| **CiFi** | @username, .cifi | ✅ Supported | @alice |
| **Unstoppable** | .crypto, .nft, etc. | 🚧 Coming soon | brad.crypto |
| **Space ID** | .bnb, .arb | 🚧 Coming soon | alice.bnb |
| **SNS** | .sol | 🚧 Coming soon | toly.sol |
| **SuiNS** | .sui | 🚧 Coming soon | bob.sui |

## Quick Start

```dart
import 'package:web3refi/web3refi.dart';

// Initialize
final uns = UniversalNameService(
  rpcClient: rpcClient,
  cifiClient: cifiClient,
);

// Resolve any name
final address = await uns.resolve('vitalik.eth');
final address2 = await uns.resolve('@alice');
```

## Usage Examples

### Basic Resolution

```dart
// Resolve ENS name
final eth = await uns.resolve('vitalik.eth');

// Resolve CiFi username
final cifi = await uns.resolve('@alice');

// Resolve with chain ID
final polygon = await uns.resolve('@alice', chainId: 137);
```

### Reverse Resolution

```dart
// Find name for address
final name = await uns.reverseResolve('0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045');
// → 'vitalik.eth'
```

### Get All Records

```dart
final records = await uns.getRecords('vitalik.eth');

print(records?.ethereumAddress);         // Main address
print(records?.getText('email'));        // Email
print(records?.getText('url'));          // Website
print(records?.getText('com.twitter'));  // Twitter handle
print(records?.avatar);                  // Avatar URL
```

### Batch Resolution

```dart
final addresses = await uns.resolveMany([
  'vitalik.eth',
  '@alice',
  'bob.eth',
]);

// addresses = {
//   'vitalik.eth': '0xd8dA...',
//   '@alice': '0x742d...',
//   'bob.eth': '0x1234...',
// }
```

### Get Avatar

```dart
final avatarUrl = await uns.getAvatar('vitalik.eth');
// Use in Image widget:
// Image.network(avatarUrl)
```

### Name Validation

```dart
final error = NameValidator.validate(userInput);
if (error != null) {
  showError(error);
} else {
  final address = await uns.resolve(userInput);
}
```

### Resolve with Metadata

```dart
final result = await uns.resolveWithMetadata('vitalik.eth');

print(result?.address);              // Address
print(result?.resolverUsed);         // 'ens'
print(result?.expiresAt);            // Expiration date
print(result?.daysUntilExpiration);  // Days left
print(result?.isExpiringSoon);       // Warn user?
```

## Architecture

### Resolution Flow

```
User Input: "vitalik.eth"
    ↓
Normalize & Validate
    ↓
Determine Resolver (based on TLD)
    ↓
Try: ENS Resolver
    ✓ Found → Return address
    ✗ Not found ↓
Try: CiFi Resolver (fallback)
    ✓ Found → Return address
    ✗ Not found ↓
Try: Custom Resolvers
    ✓ Found → Return address
    ✗ Not found ↓
Return null
```

### Module Structure

```
lib/src/names/
├── universal_name_service.dart    # Main UNS class
├── name_resolver.dart             # Resolver interface
├── resolution_result.dart         # Result models
│
├── resolvers/
│   ├── ens_resolver.dart          # ENS implementation
│   ├── cifi_resolver.dart         # CiFi implementation
│   └── ...                        # More coming
│
└── utils/
    └── namehash.dart               # ENS namehash algorithm
```

## Custom Resolvers

You can add support for new name services by implementing `NameResolver`:

```dart
class MyCustomResolver extends NameResolver {
  @override
  String get id => 'custom';

  @override
  List<String> get supportedTLDs => ['custom'];

  @override
  List<int> get supportedChainIds => [1, 137];

  @override
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  }) async {
    // Your resolution logic here
    final address = await _queryCustomAPI(name);

    if (address != null) {
      return ResolutionResult(
        address: address,
        resolverUsed: 'custom',
        name: name,
      );
    }

    return null;
  }

  @override
  Future<NameRecords?> getRecords(String name) async {
    // Return all records
  }
}

// Register it
uns.registerResolver('custom', MyCustomResolver());
uns.registerTLD('custom', 'custom');

// Now you can resolve: alice.custom
```

## CiFi Integration

CiFi usernames work as universal names across **all chains**:

```dart
// Same username, different chains
final eth = await uns.resolve('@alice', chainId: 1);      // Ethereum
final poly = await uns.resolve('@alice', chainId: 137);   // Polygon
final btc = await uns.resolve('@alice', chainId: 0);      // Bitcoin
final sol = await uns.resolve('@alice');                  // Solana

// All resolve to the same user's addresses on different chains!
```

**Benefits:**
- ✅ Free (no gas fees)
- ✅ Instant (no blockchain queries)
- ✅ Multi-chain by default
- ✅ No registration needed (just create CiFi profile)

## Performance

### Caching

Results are automatically cached for 1 hour:

```dart
// First call: hits RPC
await uns.resolve('vitalik.eth'); // ~200ms

// Second call: uses cache
await uns.resolve('vitalik.eth'); // ~1ms

// Disable cache for specific call
await uns.resolve('vitalik.eth', useCache: false);

// Clear entire cache
uns.clearCache();
```

### Batch Resolution

Use `resolveMany()` for better performance when resolving multiple names:

```dart
// ❌ Slow (3 RPC calls)
for (final name in names) {
  await uns.resolve(name);
}

// ✅ Fast (1 RPC call with Multicall)
final addresses = await uns.resolveMany(names);
```

## Error Handling

```dart
try {
  final address = await uns.resolve('invalid..eth');
} on ArgumentError catch (e) {
  // Invalid name format
  print('Invalid name: ${e.message}');
} catch (e) {
  // Resolution failed
  print('Could not resolve: $e');
}

// Or check for null
final address = await uns.resolve('unknown.eth');
if (address == null) {
  print('Name not found');
}
```

## Best Practices

### 1. Validate User Input

```dart
final normalized = NameValidator.normalize(userInput);
final error = NameValidator.validate(normalized);

if (error != null) {
  showError(error);
  return;
}

final address = await uns.resolve(normalized);
```

### 2. Show Resolved Address

```dart
TextField(
  onChanged: (value) async {
    final address = await uns.resolve(value);
    setState(() {
      resolvedAddress = address;
    });
  },
);

if (resolvedAddress != null) {
  Text('→ $resolvedAddress');  // Show user what they're sending to
}
```

### 3. Handle Expiration

```dart
final result = await uns.resolveWithMetadata('vitalik.eth');

if (result?.isExpiringSoon == true) {
  showWarning('This name expires in ${result?.daysUntilExpiration} days!');
}
```

### 4. Use Batch for Lists

```dart
// In a contacts list
final contacts = ['alice.eth', 'bob.eth', '@charlie'];
final addresses = await uns.resolveMany(contacts);

ListView.builder(
  itemCount: contacts.length,
  itemBuilder: (context, index) {
    final name = contacts[index];
    final address = addresses[name];

    return ListTile(
      title: Text(name),
      subtitle: Text(address ?? 'Not found'),
    );
  },
);
```

## Testing

```dart
// Mock for testing
class MockResolver extends NameResolver {
  final Map<String, String> mockData;

  MockResolver(this.mockData);

  @override
  Future<ResolutionResult?> resolve(String name, {...}) async {
    final address = mockData[name];
    if (address != null) {
      return ResolutionResult(
        address: address,
        resolverUsed: 'mock',
        name: name,
      );
    }
    return null;
  }

  // ... implement other methods
}

// In tests
final uns = UniversalNameService(rpcClient: mockRpc);
uns.registerResolver('mock', MockResolver({
  'test.eth': '0x1234...',
  '@alice': '0x5678...',
}));
```

## Roadmap

- [ ] Phase 1: Core UNS + ENS + CiFi ✅ **DONE**
- [ ] Phase 2: Unstoppable Domains
- [ ] Phase 3: Space ID (.bnb, .arb)
- [ ] Phase 4: Solana Name Service
- [ ] Phase 5: Sui Name Service
- [ ] Phase 6: Off-chain resolution (CCIP-Read)
- [ ] Phase 7: Deployable registries for new chains

## API Reference

See [API Documentation](../../../docs/api/names.md) for complete API reference.

## Support

- GitHub Issues: [web3refi/issues](https://github.com/yourorg/web3refi/issues)
- Discord: [Join our Discord](https://discord.gg/web3refi)
- Docs: [docs.web3refi.com](https://docs.web3refi.com)
