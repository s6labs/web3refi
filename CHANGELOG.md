# Changelog

All notable changes to **web3refi** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- DEX swap integration (Uniswap, SushiSwap)
- Hardware wallet support (Ledger, Trezor)
- Cosmos chain adapters

---

## [2.0.0] - 2026-01-06

### 🚀 Major Release - Complete SDK Overhaul

A comprehensive update addressing all compilation issues, adding WalletConnect v2 integration, and introducing the premium tier system.

### Added

#### SDK Tiers System
- **Free Tier (Standalone)** — Core blockchain functionality without third-party dependencies
- **Premium Tier (with CIFI ID)** — Full feature set with CIFI API integration
- `SdkFeature` enum for feature gating
- `canUseFeature()` method for runtime feature checks

#### WalletConnect v2 Integration
- Full WalletConnect v2 support via `reown_appkit` package
- `WalletManager` with optional `projectId` for WalletConnect features
- `StaticWalletRegistry` with predefined wallet metadata (MetaMask, Coinbase, Trust, Rainbow, Phantom)
- Wallet events: `WalletConnectedEvent`, `WalletDisconnectedEvent`, `ChainChangedEvent`, `AccountChangedEvent`
- Session persistence and restoration
- Deep link support for native wallet apps

#### Invoice Module Enhancements
- `issueDate` getter on `Invoice` class (alias for `createdAt`)
- `notes` property on `InvoiceItem` for line-item comments
- `FactoringConfig` extended with: `listingId`, `listedAt`, `buyer`, `soldAt`, `factorPrice`
- `InvoiceStatistics` class for analytics
- `getInvoicesBySender()` and `getInvoicesByRecipient()` methods

#### Universal Name Service (UNS)
- Complete UNS implementation with multiple resolvers
- ENS resolver (free tier)
- CiFi resolver (premium)
- Unstoppable Domains, SpaceID, SNS, SuiNS resolvers
- Name caching system
- CCIP-Read support for offchain resolution
- Batch resolution for multiple names
- ENS normalization
- Expiration tracking
- Name analytics

#### Messaging System
- XMTP client for real-time encrypted chat
- Mailchain client for blockchain email
- `MessagingException` for proper error handling
- `InboxScreen` and `ChatScreen` widgets

#### New Widgets
- `CiFiLoginButton` — Premium authentication widget
- Name service widgets: `AddressInputField`, `NameDisplay`, `NameRegistrationFlow`, `NameManagementScreen`

### Changed

#### Breaking Changes
- `WalletManager` constructor now takes `projectId` as optional parameter (enables standalone mode)
- `WalletConnectionResult` in `WalletManager` uses `int chainId` (vs `String` in `WalletConnectionResult` from wallet_abstraction)
- `web_socket_channel` upgraded to ^3.0.1 (required for `reown_appkit`)

#### Dependency Updates
- Added `reown_appkit: ^1.3.0` for WalletConnect v2
- Upgraded `web_socket_channel: ^2.4.0` → `^3.0.1`
- All dependencies verified compatible

### Fixed

#### Compilation Fixes
- Fixed all 100+ compilation errors from v1.x
- Resolved type mismatches between wallet abstraction and manager layers
- Fixed missing imports in invoice viewer widget
- Resolved circular dependency issues
- Fixed `FactoringConfig.copyWith()` extension to include all properties

#### Invoice Module
- Fixed `Payment` and `InvoiceItem` import issues in widgets
- Added missing `notes` property to `InvoiceItem` class
- Fixed `FactoringConfig` JSON serialization

### Security
- No private key storage — all signing via wallet apps
- Secure session storage with `flutter_secure_storage`
- Feature gating for premium functionality

### Documentation
- Updated library documentation with tier system explanation
- Added examples for both free and premium initialization
- Comprehensive export organization in `web3refi.dart`

### Migration from 1.x

```dart
// Before (1.x) - projectId was required
await Web3Refi.initialize(
  config: Web3RefiConfig(
    projectId: 'YOUR_PROJECT_ID', // Required
    chains: [Chains.ethereum],
  ),
);

// After (2.0) - Standalone mode (no WalletConnect)
await Web3Refi.initialize(
  config: Web3RefiConfig.standalone(
    chains: [Chains.ethereum],
  ),
);

// After (2.0) - With WalletConnect (optional)
await Web3Refi.initialize(
  config: Web3RefiConfig.premium(
    chains: [Chains.ethereum],
    cifiApiKey: 'YOUR_KEY',
    cifiApiSecret: 'YOUR_SECRET',
    projectId: 'YOUR_PROJECT_ID', // Optional
  ),
);
```

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
| 2.0.0 | 2026-01-06 | 🚀 Major release - SDK overhaul |
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
