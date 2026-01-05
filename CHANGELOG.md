# Changelog

All notable changes to **web3refi** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- DEX swap integration (Uniswap, SushiSwap)
- NFT support (ERC-721, ERC-1155)
- ENS name resolution
- Hardware wallet support (Ledger, Trezor)
- Cosmos chain adapters

---

## [1.0.0] - 2025-01-15

### 🎉 Initial Release

The first stable release of web3refi — a complete replacement for the deprecated web3dart library.

### Added

#### Core
- `Web3Refi` singleton class for SDK initialization and access
- `Web3RefiConfig` for flexible configuration options
- `RpcClient` with automatic failover to backup endpoints
- Response caching for improved performance
- Comprehensive logging system (opt-in)

#### Multi-Chain Support
- **EVM Mainnets:** Ethereum, Polygon, Arbitrum, Optimism, Base, BNB Chain, Avalanche
- **EVM Testnets:** Sepolia, Goerli, Mumbai, Arbitrum Sepolia, Base Sepolia
- **Non-EVM:** Bitcoin, Solana, Hedera, Sui, Constellation
- Custom chain configuration support
- Chain switching functionality

#### Wallet Integration
- WalletConnect v2 protocol support
- Universal wallet abstraction layer
- Session persistence across app restarts
- Multi-wallet profile system
- Supported wallets:
  - **EVM:** MetaMask, Rainbow, Trust Wallet, Coinbase Wallet, 300+ via WalletConnect
  - **Bitcoin:** BlueWallet, Electrum
  - **Solana:** Phantom, Solflare
  - **Hedera:** HashPack, Blade
  - **Sui:** Sui Wallet, Suiet

#### DeFi Operations
- `ERC20` class for token interactions
  - `balanceOf()` — Check token balance
  - `transfer()` — Send tokens
  - `approve()` — Approve spending
  - `allowance()` — Check allowance
  - `ensureApproval()` — Smart approval (only if needed)
  - `watchBalance()` — Real-time balance streaming
- Amount formatting and parsing with automatic decimal handling
- Native currency operations (ETH, MATIC, etc.)
- Gas estimation
- Transaction lifecycle management
- Transaction receipt polling with confirmations

#### Messaging
- **XMTP Integration**
  - Real-time encrypted messaging
  - Conversation management
  - Message streaming
- **Mailchain Integration**
  - Blockchain email sending
  - Inbox management
  - Read/unread status

#### Pre-built Widgets
- `WalletConnectButton` — Full wallet connection UI
- `TokenBalance` — Static balance display
- `LiveTokenBalance` — Auto-updating balance
- `ChainSelector` — Network switching dropdown
- `ChatScreen` — XMTP chat interface
- `InboxScreen` — Mailchain inbox interface

#### Error Handling
- `Web3Exception` — Base exception class
- `WalletException` — Wallet-specific errors
- `RpcException` — Network/RPC errors
- `TransactionException` — Transaction failures
- `ContractException` — Smart contract errors
- `MessagingException` — Messaging errors
- User-friendly error messages via `toUserMessage()`

#### Developer Experience
- Full Dart type safety
- Comprehensive documentation
- Example application
- Migration guide from web3dart

### Security
- No private key storage — all signing via wallet apps
- Secure session storage with `flutter_secure_storage`
- Replay attack protection for authentication
- Session expiration handling

### Documentation
- Complete README with quick start guide
- API reference documentation
- Migration guide from web3dart
- Code examples for all features
- Contributing guidelines

---

## [0.9.0] - 2025-01-08

### Beta Release

Pre-release for community testing and feedback.

### Added
- Core RPC client implementation
- Basic wallet connection flow
- ERC-20 token operations
- Initial widget set
- Example application skeleton

### Changed
- Refined public API based on internal testing
- Improved error messages

### Fixed
- RPC timeout handling
- Session restoration edge cases
- Chain switching on some wallets

---

## [0.5.0] - 2024-12-20

### Alpha Release

Internal alpha release for S6 Labs testing.

### Added
- Project structure and architecture
- Core abstractions
- Basic Ethereum support
- Proof of concept wallet connection

---

## Version History Summary

| Version | Date | Milestone |
|---------|------|-----------|
| 1.0.0 | 2025-01-15 | 🎉 Stable release |
| 0.9.0 | 2025-01-08 | Beta release |
| 0.5.0 | 2024-12-20 | Alpha release |

---

## Upgrade Guide

### From 0.9.x to 1.0.0

No breaking changes. Simply update your `pubspec.yaml`:

```yaml
dependencies:
  web3refi: ^1.0.0
```

### From web3dart

See our [Migration Guide](doc/migration-from-web3dart.md) for step-by-step instructions.

**Key differences:**
- No private key handling (uses wallet apps)
- Simplified API
- Multi-chain by default
- Built-in wallet connection

---

## Deprecation Policy

- Deprecated features will be marked with `@Deprecated` annotation
- Deprecated features remain functional for at least 2 minor versions
- Removal will be announced in changelog at least 1 version in advance

---

## Release Schedule

We follow a regular release cadence:

- **Patch releases (1.0.x):** As needed for bug fixes
- **Minor releases (1.x.0):** Monthly, with new features
- **Major releases (x.0.0):** When breaking changes are necessary

---

## Links

- [GitHub Releases](https://github.com/AguaClara/web3refi/releases)
- [pub.dev Package](https://pub.dev/packages/web3refi)
- [Documentation](https://docs.web3refi.dev)
- [Migration Guide](doc/migration-from-web3dart.md)

---

**Maintained with 💙 by [S6 Labs LLC](https://s6labs.com)**
