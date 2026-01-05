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
export 'src/core/rpc_client.dart';
export 'src/core/chain_config.dart';

// ============================================================================
// Models
// ============================================================================
export 'src/models/chain.dart';
export 'src/models/transaction.dart';
export 'src/models/wallet_connection.dart';
export 'src/models/token_info.dart';

// ============================================================================
// Exceptions
// ============================================================================
export 'src/exceptions/web3_exception.dart';
export 'src/exceptions/wallet_exception.dart';
export 'src/exceptions/rpc_exception.dart';
export 'src/exceptions/transaction_exception.dart';

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
export 'src/defi/erc20.dart';
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

// ============================================================================
// Constants
// ============================================================================
export 'src/constants/chains.dart';
export 'src/constants/tokens.dart';
