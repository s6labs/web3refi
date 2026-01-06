# Web3ReFi SDK - API Reference

Complete API documentation for the web3refi Flutter/Dart SDK.

**Version**: 2.1.0
**Last Updated**: January 5, 2026

---

## Table of Contents

1. [Core API](#core-api)
2. [Wallet Management](#wallet-management)
3. [Token Operations](#token-operations)
4. [Multi-Chain Support](#multi-chain-support)
5. [Invoice System](#invoice-system)
6. [Universal Name Service](#universal-name-service)
7. [Messaging](#messaging)
8. [Smart Contract Interaction](#smart-contract-interaction)
9. [Error Handling](#error-handling)
10. [Utilities](#utilities)

---

## Core API

### Web3Refi

Main entry point for the SDK.

#### Initialization

```dart
static Future<void> initialize({
  required Web3RefiConfig config,
}) async
```

**Parameters**:
- `config`: Configuration object with:
  - `projectId`: WalletConnect project ID (required)
  - `chains`: List of supported chains
  - `defaultChain`: Default blockchain network
  - `rpcUrls`: Optional custom RPC endpoints

**Example**:
```dart
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'YOUR_PROJECT_ID',
    chains: [Chains.ethereum, Chains.polygon],
    defaultChain: Chains.polygon,
  ),
);
```

#### Instance Access

```dart
static Web3Refi get instance
```

Returns the singleton instance after initialization.

---

## Wallet Management

### Connect Wallet

```dart
Future<String> connect({
  WalletProvider? preferredProvider,
}) async
```

Opens wallet selection and connects to user's wallet.

**Returns**: Connected wallet address

**Throws**:
- `WalletException` if connection fails
- `UserRejectedException` if user cancels

**Example**:
```dart
try {
  final address = await Web3Refi.instance.connect();
  print('Connected: $address');
} on UserRejectedException {
  print('User cancelled connection');
} on WalletException catch (e) {
  print('Connection failed: ${e.message}');
}
```

### Disconnect Wallet

```dart
Future<void> disconnect() async
```

Disconnects from the currently connected wallet.

### Check Connection Status

```dart
bool get isConnected
String? get address
```

---

## Token Operations

### Get Token Instance

```dart
Token token(String contractAddress)
```

Creates a token instance for ERC20 interactions.

**Parameters**:
- `contractAddress`: Token contract address

**Returns**: Token instance

### Token Methods

#### Balance Query

```dart
Future<BigInt> balanceOf(String address) async
```

**Example**:
```dart
final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
final balance = await usdc.balanceOf(myAddress);
print('Balance: ${await usdc.formatAmount(balance)} USDC');
```

#### Transfer

```dart
Future<String> transfer({
  required String to,
  required BigInt amount,
  BigInt? gasLimit,
  BigInt? gasPrice,
}) async
```

**Returns**: Transaction hash

**Example**:
```dart
final txHash = await usdc.transfer(
  to: recipientAddress,
  amount: await usdc.parseAmount('100.00'),
);
```

#### Approve

```dart
Future<String> approve({
  required String spender,
  required BigInt amount,
}) async
```

Approves spender to transfer tokens on your behalf.

#### Allowance

```dart
Future<BigInt> allowance({
  required String owner,
  required String spender,
}) async
```

Checks approved amount for a spender.

### Token Utilities

```dart
Future<BigInt> parseAmount(String amount) async
Future<String> formatAmount(BigInt amount) async
Future<int> decimals() async
Future<String> name() async
Future<String> symbol() async
```

---

## Multi-Chain Support

### Switch Chain

```dart
Future<void> switchChain(Chain chain) async
```

**Example**:
```dart
await Web3Refi.instance.switchChain(Chains.ethereum);
```

### Current Chain

```dart
Chain get currentChain
```

Returns the currently selected blockchain network.

### Supported Chains

Pre-configured chain constants:

**Mainnet**:
- `Chains.ethereum` - Ethereum Mainnet
- `Chains.polygon` - Polygon
- `Chains.arbitrum` - Arbitrum
- `Chains.optimism` - Optimism
- `Chains.base` - Base
- `Chains.bsc` - BNB Chain
- `Chains.avalanche` - Avalanche

**Testnet**:
- `Chains.sepolia` - Ethereum Sepolia
- `Chains.polygonMumbai` - Polygon Mumbai
- `Chains.arbitrumSepolia` - Arbitrum Sepolia
- `Chains.optimismSepolia` - Optimism Sepolia
- `Chains.baseSepolia` - Base Sepolia
- `Chains.bscTestnet` - BSC Testnet
- `Chains.avalancheFuji` - Avalanche Fuji

### Custom Chain

```dart
final customChain = Chain(
  chainId: 56,
  name: 'BNB Smart Chain',
  rpcUrl: 'https://bsc-dataseed.binance.org',
  symbol: 'BNB',
  explorerUrl: 'https://bscscan.com',
);
```

---

## Invoice System

Complete API for the invoice financing platform.

### InvoiceManager

#### Create Invoice

```dart
Future<Invoice> createInvoice(Invoice invoice) async
```

**Example**:
```dart
final invoice = Invoice(
  id: 'INV-${DateTime.now().millisecondsSinceEpoch}',
  invoiceNumber: 'INV-2026-001',
  sellerAddress: myAddress,
  buyerAddress: clientAddress,
  items: [
    InvoiceItem(
      id: 'item-1',
      description: 'Web Development',
      quantity: 40,
      unitPrice: BigInt.from(50) * BigInt.from(10).pow(6), // 50 USDC
    ),
  ],
  dueDate: DateTime.now().add(Duration(days: 30)),
  paymentInfo: PaymentInfo(
    tokenAddress: Tokens.usdcPolygon,
    chainId: 137,
  ),
);

await invoiceManager.createInvoice(invoice);
```

#### Get Invoice

```dart
Future<Invoice?> getInvoice(String invoiceId) async
```

#### List Invoices

```dart
Future<List<Invoice>> listInvoices({
  String? sellerAddress,
  String? buyerAddress,
  InvoiceStatus? status,
  int? limit,
  int? offset,
}) async
```

#### Update Invoice

```dart
Future<void> updateInvoice(Invoice invoice) async
```

#### Delete Invoice

```dart
Future<void> deleteInvoice(String invoiceId) async
```

#### Send Invoice

```dart
Future<void> sendInvoice(String invoiceId) async
```

Sends invoice notification via XMTP/Mailchain.

### InvoicePaymentHandler

#### Pay Invoice

```dart
Future<String> payInvoice({
  required Invoice invoice,
  required String tokenAddress,
  required int chainId,
  BigInt? amount, // Optional for partial payment
}) async
```

**Returns**: Transaction hash

**Example**:
```dart
final paymentHandler = InvoicePaymentHandler(ciFiManager: ciFiManager);
final txHash = await paymentHandler.payInvoice(
  invoice: invoice,
  tokenAddress: Tokens.usdcPolygon,
  chainId: 137,
);
```

#### Wait for Confirmation

```dart
Future<PaymentConfirmation> waitForConfirmation({
  required String txHash,
  int requiredConfirmations = 12,
}) async
```

### RecurringInvoiceManager

#### Create Template

```dart
Future<Invoice> createRecurringTemplate({
  required Invoice baseInvoice,
  required RecurringConfig recurringConfig,
}) async
```

**RecurringConfig**:
```dart
RecurringConfig(
  frequency: RecurringFrequency.monthly,
  dayOfMonth: 1, // For monthly
  dayOfWeek: 1, // For weekly (1 = Monday)
  autoSend: true,
  endDate: DateTime.now().add(Duration(days: 365)),
)
```

#### Generate from Template

```dart
Future<Invoice> generateFromTemplate({
  required String templateId,
  bool autoSend = false,
}) async
```

### InvoiceFactoringManager

#### List Invoice for Factoring

```dart
Future<FactoringListing> listInvoiceForFactoring({
  required String invoiceId,
  required double discountRate, // 0.0 to 1.0
  BigInt? minPrice,
}) async
```

**Example**:
```dart
final listing = await factoringManager.listInvoiceForFactoring(
  invoiceId: invoice.id,
  discountRate: 0.03, // 3% discount
);
```

#### Buy Factored Invoice

```dart
Future<FactoringTransaction> buyFactoredInvoice({
  required String listingId,
  required String buyerAddress,
  required String txHash,
  required int chainId,
}) async
```

---

## Universal Name Service

ENS-compatible naming system.

### Register Name

```dart
Future<String> register({
  required String name,
  required String ownerAddress,
  required int duration, // in seconds
}) async
```

**Example**:
```dart
final registry = UniversalRegistry.at(registryAddress);
await registry.register(
  namehash('alice.web3refi'),
  'alice',
  userAddress,
  365 * 24 * 60 * 60, // 1 year
);
```

### Resolve Name

```dart
Future<String> addr(bytes32 node) async
```

**Example**:
```dart
final resolver = UniversalResolver.at(resolverAddress);
final address = await resolver.addr(namehash('alice.web3refi'));
print('alice.web3refi → $address');
```

### Set Text Records

```dart
Future<void> setText({
  required bytes32 node,
  required String key,
  required String value,
}) async
```

**Supported keys**:
- `email`
- `url`
- `avatar`
- `description`
- `twitter`
- `github`

### Namehash Utility

```dart
bytes32 namehash(String name)
```

Converts human-readable name to bytes32 node.

---

## Messaging

### XMTP (Real-time Messaging)

```dart
final xmtp = Web3Refi.instance.messaging.xmtp;
await xmtp.initialize();
```

#### Send Message

```dart
Future<void> sendMessage({
  required String recipient,
  required String content,
}) async
```

#### Stream Messages

```dart
Stream<XMTPMessage> streamMessages()
```

**Example**:
```dart
xmtp.streamMessages().listen((message) {
  print('${message.sender}: ${message.content}');
});
```

### Mailchain (Blockchain Email)

```dart
final mailchain = Web3Refi.instance.messaging.mailchain;
await mailchain.initialize();
```

#### Send Email

```dart
Future<void> sendMail({
  required String to,
  required String subject,
  required String body,
}) async
```

#### Get Inbox

```dart
Future<List<MailchainMessage>> getInbox() async
```

---

## Smart Contract Interaction

### Deploy Contract

```dart
Future<String> deployContract({
  required String bytecode,
  required List<dynamic> constructorParams,
  BigInt? gasLimit,
}) async
```

### Call Contract Method

```dart
Future<List<dynamic>> callContractMethod({
  required String contractAddress,
  required String methodName,
  required List<dynamic> params,
  String? abi,
}) async
```

### Send Transaction

```dart
Future<String> sendTransaction({
  required String to,
  String? data,
  BigInt? value,
  BigInt? gasLimit,
  BigInt? gasPrice,
}) async
```

---

## Error Handling

### Exception Types

#### WalletException

Thrown when wallet operations fail.

**Properties**:
- `code`: Error code (e.g., 'user_rejected', 'wallet_not_installed')
- `message`: Human-readable error message

**Methods**:
- `toUserMessage()`: Get user-friendly error message

#### RpcException

Thrown when RPC calls fail.

**Properties**:
- `code`: RPC error code
- `message`: Error message
- `data`: Additional error data

#### TransactionException

Thrown when transactions fail.

**Properties**:
- `code`: Error code (e.g., 'insufficient_balance', 'gas_too_low')
- `message`: Error message
- `txHash`: Transaction hash (if available)

### Error Handling Example

```dart
try {
  await Web3Refi.instance.connect();
} on WalletException catch (e) {
  switch (e.code) {
    case 'user_rejected':
      showMessage('Connection cancelled');
      break;
    case 'wallet_not_installed':
      showMessage('Please install a wallet app');
      break;
    default:
      showMessage(e.toUserMessage());
  }
} on RpcException catch (e) {
  showMessage('Network error: ${e.message}');
} on TransactionException catch (e) {
  if (e.code == 'insufficient_balance') {
    showMessage('Not enough funds');
  } else {
    showMessage('Transaction failed: ${e.message}');
  }
}
```

---

## Utilities

### Format Amount

```dart
String formatAmount(BigInt amount, int decimals)
```

Formats wei/raw amount to human-readable string.

**Example**:
```dart
final formatted = formatAmount(
  BigInt.from(1000000), // 1 USDC (6 decimals)
  6,
);
print(formatted); // "1.0"
```

### Parse Amount

```dart
BigInt parseAmount(String amount, int decimals)
```

Converts human-readable amount to wei/raw BigInt.

### Address Utilities

```dart
bool isValidAddress(String address)
String checksumAddress(String address)
String shortenAddress(String address, {int start = 6, int end = 4})
```

### Transaction Utilities

```dart
Future<TransactionReceipt> waitForTransaction(
  String txHash, {
  int confirmations = 1,
  Duration? timeout,
}) async

Future<BigInt> estimateGas({
  required String to,
  String? data,
  BigInt? value,
}) async

Future<BigInt> getGasPrice() async
```

### Block Utilities

```dart
Future<int> getBlockNumber() async
Future<Block> getBlock(int blockNumber) async
```

---

## Widget API

### WalletConnectButton

```dart
WalletConnectButton({
  VoidCallback? onConnected,
  VoidCallback? onDisconnected,
  Function(String)? onError,
  String? connectedText,
  String? disconnectedText,
  ButtonStyle? style,
})
```

### TokenBalance

```dart
TokenBalance({
  required String tokenAddress,
  String? walletAddress,
  TextStyle? style,
  String? prefix,
  String? suffix,
})
```

### LiveTokenBalance

```dart
LiveTokenBalance({
  required String tokenAddress,
  String? walletAddress,
  Duration updateInterval = const Duration(seconds: 10),
  TextStyle? style,
})
```

### ChainSelector

```dart
ChainSelector({
  required List<Chain> chains,
  required ValueChanged<Chain> onChanged,
  Chain? selectedChain,
  Decoration? decoration,
})
```

---

## Constants

### Common Token Addresses

```dart
class Tokens {
  // Ethereum
  static const usdcEthereum = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
  static const usdtEthereum = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  static const daiEthereum = '0x6B175474E89094C44Da98b954EedeAC495271d0F';

  // Polygon
  static const usdcPolygon = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
  static const usdtPolygon = '0xc2132D05D31c914a87C6611C10748AEb04B58e8F';

  // Arbitrum
  static const usdcArbitrum = '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8';
}
```

---

## Type Definitions

### Chain

```dart
class Chain {
  final int chainId;
  final String name;
  final String rpcUrl;
  final String symbol;
  final String explorerUrl;
  final bool isTestnet;
}
```

### Invoice

```dart
class Invoice {
  final String id;
  final String invoiceNumber;
  final String sellerAddress;
  final String buyerAddress;
  final List<InvoiceItem> items;
  final DateTime dueDate;
  final PaymentInfo paymentInfo;
  final InvoiceStatus status;
  final BigInt totalAmount;
  final BigInt paidAmount;
}
```

### InvoiceItem

```dart
class InvoiceItem {
  final String id;
  final String description;
  final int quantity;
  final BigInt unitPrice;
  final double? taxRate;
  final BigInt get total; // Calculated
}
```

---

## Migration Guide

### From web3dart to web3refi

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed migration instructions.

---

## Support

- **Documentation**: https://docs.web3refi.dev
- **API Reference**: https://pub.dev/documentation/web3refi
- **GitHub**: https://github.com/web3refi/web3refi
- **Discord**: https://discord.gg/web3refi
- **Issues**: https://github.com/web3refi/web3refi/issues

---

**Last Updated**: January 5, 2026
**SDK Version**: 2.1.0
