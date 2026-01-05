# web3refi

**The Modern Web3 SDK for Flutter — A Complete Replacement for web3dart**

[![Pub Version](https://img.shields.io/pub/v/web3refi.svg)](https://pub.dev/packages/web3refi)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.10.0-blue.svg)](https://flutter.dev)

---

## Why web3refi?

The `web3dart` package has been deprecated and unmaintained since 2023. Flutter developers building Web3 mobile apps were left without a reliable, production-ready solution.

**web3refi** solves this by providing:

| Problem with web3dart | web3refi Solution |
|----------------------|-------------------|
| Unmaintained since 2023 | Actively maintained & updated |
| Ethereum-only | Multi-chain (EVM, Bitcoin, Solana, Hedera, Sui) |
| No wallet integration | Built-in WalletConnect v2 |
| Manual transaction signing | Seamless wallet app integration |
| No mobile optimization | Mobile-first architecture |
| Complex setup | 5-minute quickstart |

---

## Features

- **Multi-Chain Support** — Ethereum, Polygon, Arbitrum, Base, Bitcoin, Solana, Hedera, Sui
- **Universal Wallet Connection** — MetaMask, Rainbow, Trust, Phantom, 300+ wallets via WalletConnect
- **DeFi Operations** — Token transfers, approvals, swaps, balance queries
- **Web3 Messaging** — XMTP (real-time chat) + Mailchain (blockchain email)
- **Pre-built Widgets** — Drop-in Flutter components
- **Type-Safe** — Full Dart type safety with comprehensive error handling
- **Production-Ready** — Battle-tested in real applications

---

## Installation

```yaml
dependencies:
  web3refi: ^1.0.0
```

```bash
flutter pub get
```

### Platform Setup

**iOS** — Add to `ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>metamask</string>
  <string>rainbow</string>
  <string>trust</string>
</array>
```

**Android** — Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="metamask" />
  </intent>
</queries>
```

---

## Quick Start

### 1. Initialize (once at app startup)

```dart
import 'package:web3refi/web3refi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Web3Refi.initialize(
    config: Web3RefiConfig(
      projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
      chains: [Chains.ethereum, Chains.polygon],
      defaultChain: Chains.polygon,
    ),
  );

  runApp(MyApp());
}
```

Get your free Project ID at [cloud.walletconnect.com](https://cloud.walletconnect.com)

### 2. Connect Wallet

```dart
// Option A: Pre-built button
WalletConnectButton(
  onConnected: () => print('Connected: ${Web3Refi.instance.address}'),
)

// Option B: Programmatic
await Web3Refi.instance.connect();
print('Address: ${Web3Refi.instance.address}');
```

### 3. Token Operations

```dart
// Get token instance
final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);

// Read balance
final balance = await usdc.balanceOf(Web3Refi.instance.address!);
print('Balance: ${await usdc.formatAmount(balance)} USDC');

// Transfer tokens
final txHash = await usdc.transfer(
  to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  amount: await usdc.parseAmount('100.00'),
);

// Wait for confirmation
final receipt = await Web3Refi.instance.waitForTransaction(txHash);
if (receipt.isSuccess) {
  print('Transfer confirmed in block ${receipt.blockNumber}');
}
```

### 4. Native Currency (ETH, MATIC, etc.)

```dart
// Get balance
final balance = await Web3Refi.instance.getNativeBalance();
final formatted = Web3Refi.instance.formatNativeAmount(balance);
print('$formatted ${Web3Refi.instance.currentChain.symbol}');

// Send native currency
final txHash = await Web3Refi.instance.sendTransaction(
  to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  value: '0x${Web3Refi.instance.parseNativeAmount('0.1').toRadixString(16)}',
);
```

### 5. Switch Chains

```dart
// Switch to Ethereum
await Web3Refi.instance.switchChain(Chains.ethereum);

// Current chain info
print('Now on: ${Web3Refi.instance.currentChain.name}');
```

---

## Migration from web3dart

### Before (web3dart)

```dart
// Complex setup with web3dart
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart';

final client = Web3Client('https://mainnet.infura.io/v3/xxx', Client());
final credentials = EthPrivateKey.fromHex('YOUR_PRIVATE_KEY'); // UNSAFE!

final contract = DeployedContract(
  ContractAbi.fromJson(erc20Abi, 'ERC20'),
  EthereumAddress.fromHex(tokenAddress),
);

final balanceFunction = contract.function('balanceOf');
final result = await client.call(
  contract: contract,
  function: balanceFunction,
  params: [EthereumAddress.fromHex(walletAddress)],
);
final balance = result.first as BigInt;

// Manual transaction building
final transaction = Transaction.callContract(
  contract: contract,
  function: contract.function('transfer'),
  parameters: [recipientAddress, amount],
);
await client.sendTransaction(credentials, transaction);
```

### After (web3refi)

```dart
// Simple, secure setup with web3refi
import 'package:web3refi/web3refi.dart';

await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'xxx',
    chains: [Chains.ethereum],
  ),
);

await Web3Refi.instance.connect(); // Opens wallet app, no private keys!

final token = Web3Refi.instance.token(tokenAddress);
final balance = await token.balanceOf(Web3Refi.instance.address!);

await token.transfer(to: recipientAddress, amount: amount);
```

### Key Differences

| web3dart | web3refi |
|----------|----------|
| Requires private key in app | Wallet app handles signing |
| Manual RPC setup | Automatic multi-RPC with failover |
| Ethereum only | 10+ blockchains |
| Manual ABI encoding | Automatic encoding |
| No wallet UI | Pre-built widgets |
| Complex error handling | Typed exceptions |

---

## Supported Chains

### EVM Chains

| Chain | Mainnet | Testnet |
|-------|---------|---------|
| Ethereum | `Chains.ethereum` | `Chains.sepolia` |
| Polygon | `Chains.polygon` | `Chains.polygonMumbai` |
| Arbitrum | `Chains.arbitrum` | `Chains.arbitrumSepolia` |
| Optimism | `Chains.optimism` | `Chains.optimismSepolia` |
| Base | `Chains.base` | `Chains.baseSepolia` |
| BNB Chain | `Chains.bsc` | `Chains.bscTestnet` |
| Avalanche | `Chains.avalanche` | `Chains.avalancheFuji` |

### Non-EVM Chains

| Chain | Constant |
|-------|----------|
| Bitcoin | `Chains.bitcoin` |
| Solana | `Chains.solana` |
| Hedera | `Chains.hedera` |
| Sui | `Chains.sui` |

### Custom Chains

```dart
final myChain = Chain(
  chainId: 56,
  name: 'BNB Smart Chain',
  rpcUrl: 'https://bsc-dataseed.binance.org',
  symbol: 'BNB',
  explorerUrl: 'https://bscscan.com',
);

await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'xxx',
    chains: [myChain],
  ),
);
```

---

## Pre-built Widgets

### WalletConnectButton

```dart
WalletConnectButton(
  onConnected: () => navigateToDashboard(),
  onDisconnected: () => navigateToLogin(),
  onError: (e) => showError(e.message),
)
```

### TokenBalance

```dart
// Static (fetches once)
TokenBalance(
  tokenAddress: Tokens.usdcPolygon,
  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
)

// Live updating
LiveTokenBalance(
  tokenAddress: Tokens.usdcPolygon,
  updateInterval: Duration(seconds: 10),
)
```

### ChainSelector

```dart
ChainSelector(
  chains: [Chains.ethereum, Chains.polygon, Chains.arbitrum],
  onChanged: (chain) => Web3Refi.instance.switchChain(chain),
)
```

---

## Web3 Messaging

### XMTP (Real-time Chat)

```dart
final xmtp = Web3Refi.instance.messaging.xmtp;
await xmtp.initialize();

// Send message
await xmtp.sendMessage(
  recipient: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  content: 'Hey! Payment sent.',
);

// Stream incoming messages
xmtp.streamMessages().listen((message) {
  print('${message.sender}: ${message.content}');
});
```

### Mailchain (Blockchain Email)

```dart
final mailchain = Web3Refi.instance.messaging.mailchain;
await mailchain.initialize();

await mailchain.sendMail(
  to: '0x742d35Cc...@ethereum.mailchain.com',
  subject: 'Invoice #12345',
  body: 'Please find your invoice attached.',
);

final inbox = await mailchain.getInbox();
```

---

## Error Handling

web3refi provides typed exceptions for precise error handling:

```dart
try {
  await Web3Refi.instance.connect();
} on WalletException catch (e) {
  switch (e.code) {
    case 'user_rejected':
      showSnackBar('You cancelled the connection');
      break;
    case 'wallet_not_installed':
      showSnackBar('Please install a wallet app');
      break;
    default:
      showSnackBar(e.toUserMessage());
  }
} on RpcException catch (e) {
  showSnackBar('Network error: ${e.toUserMessage()}');
} on TransactionException catch (e) {
  if (e.code == 'insufficient_balance') {
    showSnackBar('Not enough funds');
  }
}
```

---

## Common Token Addresses

```dart
// Ethereum Mainnet
Tokens.usdcEthereum   // 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
Tokens.usdtEthereum   // 0xdAC17F958D2ee523a2206206994597C13D831ec7
Tokens.daiEthereum    // 0x6B175474E89094C44Da98b954EedeAC495271d0F
Tokens.wethEthereum   // 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

// Polygon
Tokens.usdcPolygon    // 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174
Tokens.usdtPolygon    // 0xc2132D05D31c914a87C6611C10748AEb04B58e8F
Tokens.wmaticPolygon  // 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270

// Arbitrum
Tokens.usdcArbitrum   // 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8
Tokens.wethArbitrum   // 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1
```

---

## Requirements

- Flutter >= 3.10.0
- Dart >= 3.0.0
- iOS >= 13.0
- Android minSdkVersion >= 23

---

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md).

```bash
git clone https://github.com/web3refi/web3refi.git
cd web3refi
flutter pub get
flutter test
```

---

## Resources

- [Documentation](https://docs.web3refi.dev)
- [API Reference](https://pub.dev/documentation/web3refi)
- [Example App](https://github.com/web3refi/web3refi/tree/main/example)
- [Discord Community](https://discord.gg/web3refi)
- [GitHub Issues](https://github.com/web3refi/web3refi/issues)

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

**web3refi** — The web3dart replacement Flutter developers have been waiting for.
