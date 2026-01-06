/// web3refi - The Universal Web3 SDK for Flutter
///
/// A comprehensive Web3 library providing:
/// - Multi-chain DeFi operations (transfers, swaps, staking)
/// - Universal wallet connections (EVM, Bitcoin, Solana, Hedera, Sui)
/// - Web3 messaging (XMTP real-time chat + Mailchain email) [PREMIUM]
/// - Universal Name Service (ENS, Unstoppable, etc.) [PREMIUM for non-ENS]
/// - Invoice management [PREMIUM]
/// - Production-ready Flutter widgets
///
/// ## SDK Tiers
///
/// ### Free Tier (Standalone)
/// Core blockchain functionality without third-party dependencies:
/// - RPC operations, transactions, token operations
/// - Basic ENS resolution (.eth names only)
/// - HD wallet generation
/// - Cryptographic operations
///
/// ### Premium Tier (with CIFI ID)
/// Full feature set with CIFI API key and secret:
/// - XMTP & Mailchain messaging
/// - Universal Name Service (all resolvers)
/// - Invoice management
/// - CiFi identity & authentication
///
/// ## Quick Start
///
/// ### Free Tier (Standalone)
/// ```dart
/// import 'package:web3refi/web3refi.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Web3Refi.initialize(
///     config: Web3RefiConfig.standalone(
///       chains: [Chains.ethereum, Chains.polygon],
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// ### Premium Tier (with CIFI ID)
/// ```dart
/// import 'package:web3refi/web3refi.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Web3Refi.initialize(
///     config: Web3RefiConfig.premium(
///       chains: [Chains.ethereum, Chains.polygon],
///       cifiApiKey: 'YOUR_CIFI_API_KEY',
///       cifiApiSecret: 'YOUR_CIFI_API_SECRET',
///       projectId: 'YOUR_WALLETCONNECT_PROJECT_ID', // Optional
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Features
///
/// ### Wallet Connection (FREE)
/// ```dart
/// await Web3Refi.instance.connect();
/// print('Connected: ${Web3Refi.instance.address}');
/// ```
///
/// ### Token Operations (FREE)
/// ```dart
/// final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
/// final balance = await usdc.balanceOf(address);
/// await usdc.transfer(to: recipient, amount: amount);
/// ```
///
/// ### Name Resolution
/// ```dart
/// // ENS is FREE
/// final addr = await Web3Refi.instance.names.resolve('vitalik.eth');
///
/// // Other name services require PREMIUM
/// final addr2 = await Web3Refi.instance.names.resolve('@alice'); // Requires CIFI ID
/// ```
///
/// ### Messaging (PREMIUM)
/// ```dart
/// await Web3Refi.instance.messaging.xmtp.sendMessage(
///   recipient: '0x123...',
///   content: 'Hello Web3!',
/// );
/// ```
///
/// ### Feature Access Check
/// ```dart
/// if (Web3Refi.instance.isPremium) {
///   // Use premium features
/// }
///
/// if (Web3Refi.instance.canUseFeature(SdkFeature.xmtpMessaging)) {
///   // Messaging is available
/// }
/// ```
library web3refi;

// ============================================================================
// Core
// ============================================================================
export 'src/core/web3refi_base.dart';
export 'src/core/web3refi_config.dart';
export 'src/core/feature_access.dart';
export 'src/core/chain.dart';
export 'src/core/chain_config.dart';
export 'src/core/types.dart';
export 'src/core/constants.dart';

// ============================================================================
// Transport
// ============================================================================
export 'src/transport/rpc_client.dart';

// ============================================================================
// Crypto Primitives
// ============================================================================
export 'src/crypto/keccak.dart';
export 'src/crypto/signature.dart';
export 'src/crypto/secp256k1.dart';
export 'src/crypto/rlp.dart';
export 'src/crypto/address.dart';

// ============================================================================
// ABI Encoding/Decoding
// ============================================================================
export 'src/abi/types/abi_types.dart';
export 'src/abi/function_selector.dart';
export 'src/abi/abi_coder.dart';

// ============================================================================
// Signers
// ============================================================================
export 'src/signers/hd_wallet.dart';

// ============================================================================
// Transactions
// ============================================================================
export 'src/transactions/transaction.dart';
export 'src/transactions/eip2930_tx.dart';
export 'src/transactions/eip1559_tx.dart';

// ============================================================================
// Message Signing
// ============================================================================
export 'src/signing/personal_sign.dart';
export 'src/signing/typed_data.dart';
export 'src/signing/siwe.dart' hide VerificationResult;

// ============================================================================
// Token Standards
// ============================================================================
export 'src/standards/erc20.dart';
export 'src/standards/erc721.dart';
export 'src/standards/erc1155.dart';
export 'src/standards/multicall.dart';

// ============================================================================
// Errors
// ============================================================================
export 'src/errors/web3_exception.dart';
export 'src/errors/wallet_exception.dart';
export 'src/errors/rpc_exception.dart';
export 'src/errors/transaction_exception.dart';
export 'src/errors/messaging_exception.dart';

// ============================================================================
// Wallet
// ============================================================================
export 'src/wallet/wallet_manager.dart' hide LinkedWallet;
export 'src/wallet/wallet_abstraction.dart'
    hide WalletInfo, WalletSignature, WalletConnectionState;
export 'src/wallet/authentication/auth_message.dart';
export 'src/wallet/authentication/signature_verifier.dart';

// ============================================================================
// DeFi / Token Operations
// ============================================================================
export 'src/defi/token_operations.dart' hide TokenInfo;
export 'src/defi/token_helper.dart';

// ============================================================================
// Messaging
// ============================================================================
export 'src/messaging/message_client.dart';
export 'src/messaging/xmtp/xmtp_client.dart';
export 'src/messaging/mailchain/mailchain_client.dart';

// ============================================================================
// CiFi Payment & Identity Platform
// ============================================================================
export 'src/cifi/client.dart';
export 'src/cifi/identity.dart';
export 'src/cifi/subscription.dart';
export 'src/cifi/auth.dart';
export 'src/cifi/webhooks.dart';

// ============================================================================
// Universal Name Service (UNS)
// ============================================================================
export 'src/names/universal_name_service.dart';
export 'src/names/name_resolver.dart';
export 'src/names/resolution_result.dart';
export 'src/names/utils/namehash.dart';
export 'src/names/resolvers/ens_resolver.dart';
export 'src/names/resolvers/cifi_resolver.dart';
export 'src/names/resolvers/unstoppable_resolver.dart';
export 'src/names/resolvers/spaceid_resolver.dart';
export 'src/names/resolvers/sns_resolver.dart';
export 'src/names/resolvers/suins_resolver.dart';
export 'src/names/registry/registry_factory.dart';
export 'src/names/registry/registration_controller.dart';

// UNS Advanced Features (Phase 5)
export 'src/names/cache/name_cache.dart';
export 'src/names/ccip/ccip_read.dart';
export 'src/names/batch/batch_resolver.dart';
export 'src/names/normalization/ens_normalize.dart';
export 'src/names/expiration/expiration_tracker.dart';
export 'src/names/analytics/name_analytics.dart';

// ============================================================================
// Widgets
// ============================================================================
export 'src/widgets/wallet_connect_button.dart';
export 'src/widgets/token_balance.dart';
export 'src/widgets/chain_selector.dart';
export 'src/widgets/messaging/chat_screen.dart';
export 'src/widgets/messaging/inbox_screen.dart';
export 'src/widgets/cifi_login_button.dart';

// Name Service Widgets
export 'src/widgets/names/address_input_field.dart';
export 'src/widgets/names/name_display.dart';
export 'src/widgets/names/name_registration_flow.dart';
export 'src/widgets/names/name_management_screen.dart';

// ============================================================================
// Invoice System - Global Invoice Financing Platform
// ============================================================================
// Complete invoice financing system with:
// - Multi-chain payment processing
// - XMTP & Mailchain delivery
// - IPFS & Arweave storage
// - Recurring subscriptions
// - Invoice factoring marketplace
// - Smart contract escrow
export 'src/invoice/invoice.dart';
