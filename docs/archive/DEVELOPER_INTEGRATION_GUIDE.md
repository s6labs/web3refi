# web3refi - Developer Integration Guide

**Version:** 2.0.0
**Target Audience:** Flutter/Dart Developers
**Difficulty:** Beginner to Advanced
**Last Updated:** January 5, 2026

---

## 🎯 QUICK START (5 Minutes)

### Step 1: Install Package

```yaml
# pubspec.yaml
dependencies:
  web3refi: ^2.0.0
```

```bash
flutter pub get
```

### Step 2: Initialize SDK

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:web3refi/web3refi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Web3Refi.initialize(
    config: Web3RefiConfig(
      projectId: 'YOUR_WALLETCONNECT_PROJECT_ID', // Get from https://cloud.walletconnect.com
      chains: [Chains.polygon, Chains.ethereum],
      defaultChain: Chains.polygon,
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Web3 App',
      home: HomeScreen(),
    );
  }
}
```

### Step 3: Connect Wallet

```dart
// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:web3refi/web3refi.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Web3 App'),
        actions: [
          WalletConnectButton(
            onConnected: (address) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Connected: $address')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Text('Welcome to Web3!'),
      ),
    );
  }
}
```

**🎉 Done! You now have a working Web3 app.**

---

## 📚 COMPREHENSIVE INTEGRATION GUIDE

### TABLE OF CONTENTS

1. [Installation & Setup](#installation--setup)
2. [Wallet Integration](#wallet-integration)
3. [Token Operations](#token-operations)
4. [Universal Name Service](#universal-name-service)
5. [CiFi Platform Integration](#cifi-platform-integration)
6. [Smart Contract Interaction](#smart-contract-interaction)
7. [Messaging Integration](#messaging-integration)
8. [Advanced Features](#advanced-features)
9. [Production Deployment](#production-deployment)
10. [Troubleshooting](#troubleshooting)

---

## 1. INSTALLATION & SETUP

### 1.1 System Requirements

- **Flutter:** 3.10.0 or higher
- **Dart:** 3.0.0 or higher
- **Platforms:** iOS 12+, Android 5.0+ (API 21+)

### 1.2 Installation

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  web3refi: ^2.0.0
```

```bash
flutter pub get
```

### 1.3 Platform Configuration

#### iOS Configuration

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>QR code scanning for wallet addresses</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Access photos for NFT uploads</string>
```

#### Android Configuration

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.CAMERA" />
```

### 1.4 Full Initialization

```dart
import 'package:web3refi/web3refi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Web3Refi.initialize(
    config: Web3RefiConfig(
      // Required
      projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
      chains: [
        Chains.ethereum,
        Chains.polygon,
        Chains.arbitrum,
        Chains.optimism,
        Chains.base,
      ],
      defaultChain: Chains.polygon,

      // Optional - Logging
      enableLogging: true, // Enable for development

      // Optional - RPC
      rpcTimeout: Duration(seconds: 30),

      // Optional - CiFi Platform
      cifiApiKey: 'YOUR_CIFI_API_KEY',
      enableCiFiNames: true,

      // Optional - Universal Name Service
      enableUnstoppableDomains: true,
      enableSpaceId: true,
      enableSolanaNameService: true,
      enableSuiNameService: true,
      namesCacheSize: 1000,
      namesCacheTtl: Duration(hours: 1),

      // Optional - App Metadata
      appMetadata: AppMetadata(
        name: 'My Web3 App',
        description: 'Description of your app',
        url: 'https://myapp.com',
        icons: ['https://myapp.com/icon.png'],
      ),
    ),
  );

  runApp(MyApp());
}
```

---

## 2. WALLET INTEGRATION

### 2.1 Basic Wallet Connection

```dart
import 'package:web3refi/web3refi.dart';

class WalletScreen extends StatefulWidget {
  @override
  _WalletScreenState createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? connectedAddress;
  bool isConnecting = false;

  Future<void> connectWallet() async {
    setState(() => isConnecting = true);

    try {
      await Web3Refi.instance.connect();
      setState(() {
        connectedAddress = Web3Refi.instance.address;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
    } finally {
      setState(() => isConnecting = false);
    }
  }

  Future<void> disconnectWallet() async {
    await Web3Refi.instance.disconnect();
    setState(() {
      connectedAddress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Wallet')),
      body: Center(
        child: connectedAddress == null
            ? ElevatedButton(
                onPressed: isConnecting ? null : connectWallet,
                child: Text(isConnecting ? 'Connecting...' : 'Connect Wallet'),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Connected: $connectedAddress'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: disconnectWallet,
                    child: Text('Disconnect'),
                  ),
                ],
              ),
      ),
    );
  }
}
```

### 2.2 Using WalletConnectButton Widget

```dart
import 'package:web3refi/web3refi.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My App'),
        actions: [
          // Simple integration
          WalletConnectButton(
            onConnected: (address) {
              print('Wallet connected: $address');
            },
            onDisconnected: () {
              print('Wallet disconnected');
            },
          ),
        ],
      ),
      body: YourContent(),
    );
  }
}
```

### 2.3 HD Wallet Creation

```dart
import 'package:web3refi/web3refi.dart';

// Generate new wallet
final mnemonic = HDWallet.generateMnemonic();
print('Mnemonic: $mnemonic');
// Save mnemonic securely!

// Create wallet from mnemonic
final wallet = HDWallet.fromMnemonic(mnemonic);

// Derive accounts
final account0 = wallet.deriveAccount(0); // m/44'/60'/0'/0/0
final account1 = wallet.deriveAccount(1); // m/44'/60'/0'/0/1

print('Address 0: ${account0.address}');
print('Private Key 0: ${account0.privateKeyHex}');

// Use for signing
final signer = PrivateKeySigner.fromHex(account0.privateKeyHex);
```

### 2.4 Session Management

```dart
import 'package:web3refi/web3refi.dart';

class SessionManager {
  // Check if user is connected
  static bool get isConnected => Web3Refi.isInitialized &&
                                  Web3Refi.instance.isConnected;

  // Get current address
  static String? get currentAddress =>
      isConnected ? Web3Refi.instance.address : null;

  // Auto-restore session on app start
  static Future<void> restoreSession() async {
    if (Web3Refi.isInitialized) {
      try {
        await Web3Refi.instance.walletManager.restoreSession();
      } catch (e) {
        print('Failed to restore session: $e');
      }
    }
  }

  // Listen to connection changes
  static void listenToConnectionChanges(Function(bool) onChanged) {
    if (Web3Refi.isInitialized) {
      Web3Refi.instance.addListener(() {
        onChanged(Web3Refi.instance.isConnected);
      });
    }
  }
}

// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Web3Refi.initialize(config: config);

  // Restore previous session
  await SessionManager.restoreSession();

  runApp(MyApp());
}
```

---

## 3. TOKEN OPERATIONS

### 3.1 Display Token Balance

```dart
import 'package:web3refi/web3refi.dart';

class BalanceScreen extends StatelessWidget {
  final String walletAddress;

  const BalanceScreen({required this.walletAddress});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Balances')),
      body: TokenBalanceList(
        tokens: [
          Tokens.usdcPolygon,
          Tokens.usdtPolygon,
          Tokens.daiPolygon,
        ],
        walletAddress: walletAddress,
        showTotalValue: true,
        showUsdValue: true,
      ),
    );
  }
}
```

### 3.2 Manual Token Balance Query

```dart
import 'package:web3refi/web3refi.dart';

Future<void> getTokenBalance() async {
  final usdc = ERC20(
    contractAddress: Tokens.usdcPolygon.address,
    rpcClient: Web3Refi.instance.rpcClient,
    signer: Web3Refi.instance.wallet,
  );

  // Get balance
  final balance = await usdc.balanceOf(userAddress);

  // Get decimals for formatting
  final decimals = await usdc.decimals();

  // Format balance
  final formattedBalance = balance / BigInt.from(10).pow(decimals);
  print('USDC Balance: $formattedBalance');

  // Get token metadata
  final name = await usdc.name();
  final symbol = await usdc.symbol();
  print('Token: $name ($symbol)');
}
```

### 3.3 Send Tokens

```dart
import 'package:web3refi/web3refi.dart';

class SendTokenScreen extends StatefulWidget {
  @override
  _SendTokenScreenState createState() => _SendTokenScreenState();
}

class _SendTokenScreenState extends State<SendTokenScreen> {
  String? recipientAddress;
  bool isSending = false;

  Future<void> sendUSDC(BigInt amount) async {
    setState(() => isSending = true);

    try {
      final usdc = ERC20(
        contractAddress: Tokens.usdcPolygon.address,
        rpcClient: Web3Refi.instance.rpcClient,
        signer: Web3Refi.instance.wallet,
      );

      // Send transaction
      final txHash = await usdc.transfer(
        to: recipientAddress!,
        amount: amount,
      );

      // Show transaction status
      showDialog(
        context: context,
        builder: (_) => TransactionStatusDialog(
          transactionHash: txHash,
          onConfirmed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Transaction confirmed!')),
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction failed: $e')),
      );
    } finally {
      setState(() => isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Send USDC')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Address input with name resolution
            AddressInputField(
              label: 'Recipient',
              hint: 'Enter address or name (vitalik.eth, @alice)',
              onAddressResolved: (address) {
                setState(() => recipientAddress = address);
              },
            ),
            SizedBox(height: 16),

            // Amount input
            TextField(
              decoration: InputDecoration(
                labelText: 'Amount',
                suffixText: 'USDC',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                // Store amount
              },
            ),
            SizedBox(height: 24),

            // Send button
            FilledButton(
              onPressed: isSending || recipientAddress == null
                  ? null
                  : () => sendUSDC(amount),
              child: Text(isSending ? 'Sending...' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3.4 Approve Token Spending

```dart
Future<void> approveToken() async {
  final usdc = ERC20(
    contractAddress: Tokens.usdcPolygon.address,
    rpcClient: Web3Refi.instance.rpcClient,
    signer: Web3Refi.instance.wallet,
  );

  // Approve unlimited spending (use with caution!)
  final maxUint256 = BigInt.parse(
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    radix: 16,
  );

  final txHash = await usdc.approve(
    spender: spenderContractAddress,
    amount: maxUint256,
  );

  // Wait for confirmation
  await waitForTransaction(txHash);

  // Check allowance
  final allowance = await usdc.allowance(
    owner: userAddress,
    spender: spenderContractAddress,
  );
  print('Allowance: $allowance');
}
```

---

## 4. UNIVERSAL NAME SERVICE

### 4.1 Resolve Names

```dart
import 'package:web3refi/web3refi.dart';

Future<void> resolveName() async {
  final uns = Web3Refi.instance.names;

  // Resolve ENS
  final address1 = await uns.resolve('vitalik.eth');
  print('vitalik.eth → $address1');

  // Resolve Unstoppable Domains
  final address2 = await uns.resolve('brad.crypto');
  print('brad.crypto → $address2');

  // Resolve CiFi usernames
  final address3 = await uns.resolve('@alice');
  print('@alice → $address3');

  // Resolve Solana Name Service
  final address4 = await uns.resolve('toly.sol');
  print('toly.sol → $address4');
}
```

### 4.2 Reverse Resolution

```dart
Future<void> reverseResolve() async {
  final uns = Web3Refi.instance.names;

  final name = await uns.reverseResolve(
    '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  );

  print('Address → Name: $name'); // 'vitalik.eth'
}
```

### 4.3 Batch Resolution

```dart
Future<void> batchResolve() async {
  final uns = Web3Refi.instance.names;

  final addresses = await uns.resolveMany([
    'vitalik.eth',
    'brad.crypto',
    '@alice',
    'toly.sol',
  ]);

  addresses.forEach((name, address) {
    print('$name → $address');
  });
}
```

### 4.4 Get Name Records

```dart
Future<void> getRecords() async {
  final uns = Web3Refi.instance.names;

  final records = await uns.getRecords('vitalik.eth');

  if (records != null) {
    print('Address: ${records.ethereumAddress}');
    print('Email: ${records.getText('email')}');
    print('Website: ${records.getText('url')}');
    print('Twitter: ${records.getText('com.twitter')}');
    print('Avatar: ${records.avatar}');
  }
}
```

### 4.5 Register Custom Name

```dart
class RegisterNameScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register Name')),
      body: NameRegistrationFlow(
        registryAddress: '0x...', // Your registry contract
        resolverAddress: '0x...', // Your resolver contract
        tld: 'xdc',
        suggestedName: 'alice',
        onComplete: (result) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('Success!'),
              content: Text(
                'Registered ${result.name}\n'
                'Expires: ${result.expiry}',
              ),
            ),
          );
        },
      ),
    );
  }
}
```

### 4.6 Manage Names

```dart
class MyNamesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Names')),
      body: NameManagementScreen(
        registryAddress: '0x...', // Your registry
        resolverAddress: '0x...', // Your resolver
      ),
    );
  }
}
```

---

## 5. CIFI PLATFORM INTEGRATION

### 5.1 CiFi Authentication

```dart
import 'package:web3refi/web3refi.dart';

class LoginScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CiFiLoginButton(
          cifiClient: CiFiClient(
            apiKey: 'YOUR_CIFI_API_KEY',
          ),
          signer: Web3Refi.instance.wallet,
          onSuccess: (session) {
            // Store session
            saveSession(session);

            // Navigate to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => DashboardScreen()),
            );
          },
          onError: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Login failed: $error')),
            );
          },
        ),
      ),
    );
  }
}
```

### 5.2 Manual SIWE Authentication

```dart
Future<void> loginWithSIWE() async {
  final cifi = CiFiClient(apiKey: 'YOUR_API_KEY');
  final auth = CiFiAuth(client: cifi);

  // 1. Request challenge
  final challenge = await auth.requestChallenge(userAddress);

  // 2. Sign message
  final signature = await Web3Refi.instance.wallet.sign(
    challenge.message,
  );

  // 3. Complete login
  final session = await auth.login(
    address: userAddress,
    signature: signature,
  );

  // 4. Store session
  saveSession(session);

  print('Logged in! Token: ${session.accessToken}');
}
```

### 5.3 Create User Profile

```dart
Future<void> createProfile() async {
  final cifi = CiFiClient(apiKey: 'YOUR_API_KEY');
  final identity = CiFiIdentity(client: cifi);

  final profile = await identity.createProfile(
    username: 'alice',
    email: 'alice@example.com',
    primaryAddress: userAddress,
  );

  print('Profile created: ${profile.userId}');
}
```

### 5.4 Link Multi-Chain Addresses

```dart
Future<void> linkAddresses() async {
  final cifi = CiFiClient(apiKey: 'YOUR_API_KEY');
  final identity = CiFiIdentity(client: cifi);

  // Link Ethereum
  await identity.linkAddress(
    userId: userId,
    chainId: 1,
    address: ethAddress,
  );

  // Link Polygon
  await identity.linkAddress(
    userId: userId,
    chainId: 137,
    address: polygonAddress,
  );

  // Get all linked addresses
  final addresses = await identity.getLinkedAddresses(userId);
  print('Linked addresses: ${addresses.length}');
}
```

### 5.5 Create Subscription

```dart
Future<void> createSubscription() async {
  final cifi = CiFiClient(apiKey: 'YOUR_API_KEY');
  final subscriptions = CiFiSubscription(client: cifi);

  final subscription = await subscriptions.createSubscription(
    userId: userId,
    amount: BigInt.from(10 * 1000000), // 10 USDC (6 decimals)
    currency: CiFiCurrency.usdc,
    interval: BillingInterval.month,
    network: CiFiNetwork.polygon,
  );

  print('Subscription created: ${subscription.id}');
  print('Next payment: ${subscription.nextPaymentDate}');
}
```

---

## 6. SMART CONTRACT INTERACTION

### 6.1 Call Any Contract

```dart
import 'package:web3refi/web3refi.dart';

Future<dynamic> callContract() async {
  // Encode function call
  final data = AbiCoder.encodeFunctionCall(
    'balanceOf(address)',
    [userAddress],
  );

  // Call contract
  final result = await Web3Refi.instance.rpcClient.ethCall(
    to: contractAddress,
    data: bytesToHex(data),
  );

  // Decode result
  final decoded = AbiCoder.decodeParameters(
    [AbiUint(256)],
    hexToBytes(result),
  );

  return decoded[0];
}
```

### 6.2 Send Transaction to Contract

```dart
Future<String> sendTransaction() async {
  // Encode function call
  final data = AbiCoder.encodeFunctionCall(
    'transfer(address,uint256)',
    [recipientAddress, amount],
  );

  // Build transaction
  final transaction = Transaction(
    to: contractAddress,
    data: data,
    value: BigInt.zero,
  );

  // Send transaction
  final txHash = await Web3Refi.instance.sendTransaction(transaction);

  return txHash;
}
```

### 6.3 Deploy Contract

```dart
Future<String> deployContract(String bytecode) async {
  // Build deployment transaction
  final transaction = Transaction(
    data: hexToBytes(bytecode),
    value: BigInt.zero,
  );

  // Deploy
  final txHash = await Web3Refi.instance.sendTransaction(transaction);

  // Wait for confirmation
  await waitForTransaction(txHash);

  // Get contract address
  final receipt = await Web3Refi.instance.rpcClient.getTransactionReceipt(txHash);
  final contractAddress = receipt['contractAddress'];

  return contractAddress;
}
```

### 6.4 Listen to Events

```dart
Future<void> listenToTransferEvents() async {
  final erc20 = ERC20(
    contractAddress: tokenAddress,
    rpcClient: Web3Refi.instance.rpcClient,
    signer: Web3Refi.instance.wallet,
  );

  // Listen to Transfer events
  erc20.onTransfer().listen((event) {
    print('Transfer:');
    print('  From: ${event.from}');
    print('  To: ${event.to}');
    print('  Amount: ${event.value}');
  });
}
```

---

## 7. MESSAGING INTEGRATION

### 7.1 XMTP Chat

```dart
class ChatScreen extends StatelessWidget {
  final String peerAddress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: NameDisplay(
          address: peerAddress,
          layout: NameDisplayLayout.row,
        ),
      ),
      body: ChatScreen(
        peerAddress: peerAddress,
        xmtpClient: Web3Refi.instance.messaging.xmtp,
      ),
    );
  }
}
```

### 7.2 Mailchain Inbox

```dart
class InboxScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Inbox')),
      body: InboxScreen(
        mailchainClient: Web3Refi.instance.messaging.mailchain,
      ),
    );
  }
}
```

---

## 8. ADVANCED FEATURES

### 8.1 Multi-Chain Operations

```dart
// Switch chain
await Web3Refi.instance.switchChain(Chains.arbitrum);

// Get current chain
final currentChain = Web3Refi.instance.currentChain;

// Check if connected to specific chain
if (Web3Refi.instance.currentChain == Chains.polygon) {
  // Do Polygon-specific operations
}
```

### 8.2 Custom RPC

```dart
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'xxx',
    chains: [
      Chain(
        chainId: 50,
        name: 'XDC Network',
        symbol: 'XDC',
        rpcUrl: 'https://rpc.xdc.network',
        explorerUrl: 'https://explorer.xdc.network',
      ),
    ],
  ),
);
```

### 8.3 Batch Calls with Multicall3

```dart
final multicall = Multicall3(
  rpcClient: Web3Refi.instance.rpcClient,
  signer: Web3Refi.instance.wallet,
);

final results = await multicall.aggregate3([
  Call3(
    target: token1Address,
    callData: balanceOfCallData,
    allowFailure: false,
  ),
  Call3(
    target: token2Address,
    callData: balanceOfCallData,
    allowFailure: false,
  ),
]);

// Process results
for (final result in results) {
  print('Success: ${result.success}');
  print('Data: ${result.returnData}');
}
```

---

## 9. PRODUCTION DEPLOYMENT

### 9.1 Environment Configuration

```dart
// lib/config/env.dart
class Env {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static String get walletConnectProjectId {
    return isProduction
        ? 'YOUR_PRODUCTION_PROJECT_ID'
        : 'YOUR_DEV_PROJECT_ID';
  }

  static String get cifiApiKey {
    return isProduction
        ? 'YOUR_PRODUCTION_CIFI_KEY'
        : 'YOUR_DEV_CIFI_KEY';
  }
}

// Usage
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: Env.walletConnectProjectId,
    enableLogging: !Env.isProduction,
  ),
);
```

### 9.2 Error Handling

```dart
try {
  await Web3Refi.instance.connect();
} on WalletException catch (e) {
  // Handle wallet errors
  print('Wallet error: ${e.message}');
} on RpcException catch (e) {
  // Handle RPC errors
  print('RPC error: ${e.message}');
  if (e.isRetryable) {
    // Retry
  }
} on TransactionException catch (e) {
  // Handle transaction errors
  print('Transaction error: ${e.message}');
} catch (e) {
  // Handle other errors
  print('Error: $e');
}
```

### 9.3 Analytics Integration

```dart
// Track wallet connections
WalletConnectButton(
  onConnected: (address) {
    analytics.logEvent(
      name: 'wallet_connected',
      parameters: {'address': address},
    );
  },
);

// Track transactions
final txHash = await sendTransaction();
analytics.logEvent(
  name: 'transaction_sent',
  parameters: {'hash': txHash},
);
```

---

## 10. TROUBLESHOOTING

### Common Issues

**Issue: WalletConnect not connecting**
```dart
// Solution: Check project ID and network
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'VALID_PROJECT_ID', // Get from cloud.walletconnect.com
    chains: [Chains.polygon], // Ensure supported
  ),
);
```

**Issue: Transaction failing**
```dart
// Solution: Check gas limits and approvals
try {
  final txHash = await erc20.transfer(to, amount);
} on TransactionException catch (e) {
  if (e.message.contains('insufficient funds')) {
    showError('Insufficient funds for gas');
  } else if (e.message.contains('allowance')) {
    showError('Approve token first');
  }
}
```

**Issue: Name resolution not working**
```dart
// Solution: Enable name services
await Web3Refi.initialize(
  config: Web3RefiConfig(
    enableUnstoppableDomains: true, // Enable UD
    enableSpaceId: true, // Enable SpaceID
    enableCiFiNames: true, // Enable CiFi
  ),
);
```

---

## 🎯 NEXT STEPS

1. **Explore Examples:** Check `examples/` folder
2. **Read API Docs:** See inline documentation
3. **Join Community:** https://github.com/circularityfinance/web3refi
4. **Get Support:** Open issues on GitHub

---

**Happy Building! 🚀**

For more information, visit: https://github.com/circularityfinance/web3refi
