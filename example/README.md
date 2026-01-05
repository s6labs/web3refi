# web3refi Example App

A complete Flutter application demonstrating all features of the **web3refi** SDK.

## Features Demonstrated

- ✅ Wallet Connection (WalletConnect v2)
- ✅ Multi-chain Support (Ethereum, Polygon, Arbitrum, Base)
- ✅ Token Balances & Portfolio View
- ✅ Token Transfers
- ✅ Transaction History & Status
- ✅ Chain Switching
- ✅ Session Persistence
- ✅ XMTP Messaging
- ✅ Mailchain Email
- ✅ Error Handling Patterns

## Screenshots

| Home | Wallet | Tokens | Transfer |
|------|--------|--------|----------|
| ![Home](screenshots/home.png) | ![Wallet](screenshots/wallet.png) | ![Tokens](screenshots/tokens.png) | ![Transfer](screenshots/transfer.png) |

## Getting Started

### Prerequisites

- Flutter SDK >= 3.10.0
- A WalletConnect Project ID ([Get one free](https://cloud.walletconnect.com))
- A mobile wallet app (MetaMask, Rainbow, Trust, etc.)

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/web3refi/web3refi.git
   cd web3refi/example
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure your Project ID**
   
   Create a `.env` file or update `lib/config/app_config.dart`:
   ```dart
   const walletConnectProjectId = 'YOUR_PROJECT_ID_HERE';
   ```

4. **Run the app**
   ```bash
   # iOS
   flutter run -d ios

   # Android
   flutter run -d android
   ```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── config/
│   └── app_config.dart       # Configuration constants
├── screens/
│   ├── home_screen.dart      # Main dashboard
│   ├── wallet_screen.dart    # Wallet connection & management
│   ├── tokens_screen.dart    # Token portfolio
│   ├── transfer_screen.dart  # Send tokens
│   └── messaging_screen.dart # XMTP & Mailchain
├── widgets/
│   └── custom_widgets.dart   # Reusable components
└── theme/
    └── app_theme.dart        # App theming
```

## Key Code Examples

### Initialize web3refi

```dart
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: walletConnectProjectId,
    chains: [Chains.ethereum, Chains.polygon, Chains.arbitrum],
    defaultChain: Chains.polygon,
    appMetadata: AppMetadata(
      name: 'web3refi Example',
      description: 'Example app for web3refi SDK',
      url: 'https://web3refi.dev',
      icons: ['https://web3refi.dev/icon.png'],
    ),
  ),
);
```

### Connect Wallet

```dart
try {
  await Web3Refi.instance.connect();
  print('Connected: ${Web3Refi.instance.address}');
} on WalletException catch (e) {
  print('Error: ${e.toUserMessage()}');
}
```

### Transfer Tokens

```dart
final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
final amount = await usdc.parseAmount('10.00');

final txHash = await usdc.transfer(
  to: recipientAddress,
  amount: amount,
);

final receipt = await Web3Refi.instance.waitForTransaction(txHash);
```

## Testing Different Scenarios

### Test Networks

The app supports testnets for safe testing:

| Network | Faucet |
|---------|--------|
| Polygon Mumbai | [faucet.polygon.technology](https://faucet.polygon.technology/) |
| Sepolia | [sepoliafaucet.com](https://sepoliafaucet.com/) |
| Arbitrum Sepolia | [faucet.quicknode.com](https://faucet.quicknode.com/arbitrum/sepolia) |

### Error States

Test these scenarios:
- Reject connection in wallet
- Insufficient balance transfer
- Network switch rejection
- Transaction timeout

## Customization

### Theming

Modify `lib/theme/app_theme.dart` to customize:
- Colors
- Typography
- Component styles

### Adding Chains

Add new chains in `lib/config/app_config.dart`:
```dart
final customChains = [
  Chains.ethereum,
  Chains.polygon,
  // Add your chain
  Chain(
    chainId: 56,
    name: 'BNB Chain',
    rpcUrl: 'https://bsc-dataseed.binance.org',
    symbol: 'BNB',
    explorerUrl: 'https://bscscan.com',
  ),
];
```

## Troubleshooting

### "Wallet not installed"

Ensure you have a compatible wallet app:
- MetaMask
- Rainbow
- Trust Wallet
- Coinbase Wallet

### Connection Issues

1. Check internet connectivity
2. Ensure wallet app is updated
3. Try disconnecting and reconnecting
4. Check WalletConnect Project ID is valid

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

## License

MIT License - See [LICENSE](../LICENSE) for details.

## Support

- [Documentation](https://docs.web3refi.dev)
- [Discord](https://discord.gg/web3refi)
- [GitHub Issues](https://github.com/web3refi/web3refi/issues)

---

**Built with web3refi by S6 Labs LLC**
