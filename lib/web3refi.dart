/// web3refi - The Universal Web3 SDK for Flutter
///
/// A comprehensive Web3 library providing:
/// - Multi-chain DeFi operations (transfers, swaps, staking)
/// - Universal wallet connections (EVM, Bitcoin, Solana, Hedera, Sui)
/// - Web3 messaging (XMTP real-time chat + Mailchain email)
/// - Production-ready Flutter widgets
///
/// ## Quick Start
///
/// ```dart
/// import 'package:web3refi/web3refi.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   await Web3Refi.initialize(
///     config: Web3RefiConfig(
///       projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
///       chains: [Chains.ethereum, Chains.polygon],
///       defaultChain: Chains.polygon,
///     ),
///   );
///
///   runApp(MyApp());
/// }
/// ```
///
/// ## Features
///
/// ### Wallet Connection
/// ```dart
/// await Web3Refi.instance.connect();
/// print('Connected: ${Web3Refi.instance.address}');
/// ```
///
/// ### Token Operations
/// ```dart
/// final usdc = Web3Refi.instance.token(Tokens.usdcPolygon);
/// final balance = await usdc.balanceOf(address);
/// await usdc.transfer(to: recipient, amount: amount);
/// ```
///
/// ### Messaging
/// ```dart
/// await Web3Refi.instance.messaging.xmtp.sendMessage(
///   recipient: '0x123...',
///   content: 'Hello Web3!',
/// );
/// ```
library web3refi;

// ============================================================================
// Core
// ============================================================================
export 'src/core/web3refi_base.dart';
export 'src/core/web3refi_config.dart';
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
export 'src/signing/siwe.dart';

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

// ============================================================================
// Wallet
// ============================================================================
export 'src/wallet/wallet_manager.dart';
export 'src/wallet/wallet_abstraction.dart';
export 'src/wallet/authentication/auth_message.dart';
export 'src/wallet/authentication/signature_verifier.dart';

// ============================================================================
// DeFi / Token Operations
// ============================================================================
export 'src/defi/token_operations.dart';
export 'src/defi/token_helper.dart';

// ============================================================================
// Messaging
// ============================================================================
export 'src/messaging/message_client.dart';
export 'src/messaging/xmtp/xmtp_client.dart';
export 'src/messaging/mailchain/mailchain_client.dart';

// ============================================================================
// Widgets
// ============================================================================
export 'src/widgets/wallet_connect_button.dart';
export 'src/widgets/token_balance.dart';
export 'src/widgets/chain_selector.dart';
export 'src/widgets/messaging/chat_screen.dart';
export 'src/widgets/messaging/inbox_screen.dart';
