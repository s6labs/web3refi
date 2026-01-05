import 'dart:async';
import '../core/rpc_client.dart';
import '../wallet/wallet_manager.dart';
import '../models/chain.dart';
import '../models/transaction.dart';
import '../constants/chains.dart';
import '../constants/tokens.dart';
import '../exceptions/web3_exception.dart';
import 'erc20.dart';
import 'token_helper.dart';
import 'abi_codec.dart';

/// Advanced token operations for DeFi interactions.
///
/// Provides high-level operations like batch transfers, multi-send,
/// swap preparation, and cross-chain utilities.
///
/// ## Features
///
/// - **Batch Transfers**: Send tokens to multiple recipients
/// - **Multi-Token Transfers**: Send multiple tokens in one flow
/// - **Swap Preparation**: Approve and prepare tokens for DEX swaps
/// - **Wrap/Unwrap**: Handle native token wrapping (ETH ↔ WETH)
/// - **Allowance Management**: Audit and manage approvals
///
/// ## Usage
///
/// ```dart
/// final operations = TokenOperations(
///   rpcClient: Web3Refi.instance.rpcClient,
///   walletManager: Web3Refi.instance.walletManager,
/// );
///
/// // Batch transfer to multiple recipients
/// final txHashes = await operations.batchTransfer(
///   tokenAddress: Tokens.usdcPolygon,
///   recipients: [
///     TransferRecipient(address: '0x111...', amount: '100'),
///     TransferRecipient(address: '0x222...', amount: '50'),
///     TransferRecipient(address: '0x333...', amount: '75'),
///   ],
/// );
/// ```
class TokenOperations {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// RPC client for blockchain calls.
  final RpcClient rpcClient;

  /// Wallet manager for signing transactions.
  final WalletManager walletManager;

  /// Token helper for basic operations.
  late final TokenHelper tokenHelper;

  /// Current chain configuration.
  Chain get currentChain => walletManager.currentChain ?? Chains.ethereum;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  TokenOperations({
    required this.rpcClient,
    required this.walletManager,
  }) {
    tokenHelper = TokenHelper(
      rpcClient: rpcClient,
      walletManager: walletManager,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BATCH TRANSFERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Send tokens to multiple recipients in sequence.
  ///
  /// Each transfer is a separate transaction. Returns list of tx hashes.
  ///
  /// ```dart
  /// final results = await operations.batchTransfer(
  ///   tokenAddress: Tokens.usdcPolygon,
  ///   recipients: [
  ///     TransferRecipient(address: '0x111...', amount: '100'),
  ///     TransferRecipient(address: '0x222...', amount: '50'),
  ///   ],
  /// );
  ///
  /// for (final result in results) {
  ///   print('${result.recipient}: ${result.txHash ?? result.error}');
  /// }
  /// ```
  Future<List<BatchTransferResult>> batchTransfer({
    required String tokenAddress,
    required List<TransferRecipient> recipients,
    bool stopOnError = false,
    Duration delayBetween = const Duration(milliseconds: 500),
  }) async {
    _requireConnected();

    final token = tokenHelper.token(tokenAddress);
    final results = <BatchTransferResult>[];

    // Validate total amount
    final totalAmount = await _calculateTotalAmount(token, recipients);
    final balance = await token.balanceOf(walletManager.address!);

    if (balance < totalAmount) {
      throw TransactionException.insufficientBalance(
        required: await token.formatAmount(totalAmount),
        available: await token.formatAmount(balance),
        symbol: await token.symbol(),
      );
    }

    // Process each transfer
    for (final recipient in recipients) {
      try {
        final amount = await token.parseAmount(recipient.amount);
        final txHash = await token.transfer(to: recipient.address, amount: amount);

        results.add(BatchTransferResult(
          recipient: recipient.address,
          amount: recipient.amount,
          txHash: txHash,
          success: true,
        ));

        // Delay between transfers to avoid nonce issues
        if (delayBetween.inMilliseconds > 0) {
          await Future.delayed(delayBetween);
        }
      } catch (e) {
        results.add(BatchTransferResult(
          recipient: recipient.address,
          amount: recipient.amount,
          success: false,
          error: e.toString(),
        ));

        if (stopOnError) break;
      }
    }

    return results;
  }

  /// Calculate total amount for batch transfer.
  Future<BigInt> _calculateTotalAmount(
    ERC20 token,
    List<TransferRecipient> recipients,
  ) async {
    BigInt total = BigInt.zero;
    for (final recipient in recipients) {
      total += await token.parseAmount(recipient.amount);
    }
    return total;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-TOKEN TRANSFERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Send multiple different tokens to the same recipient.
  ///
  /// ```dart
  /// await operations.multiTokenTransfer(
  ///   to: recipient,
  ///   transfers: [
  ///     TokenTransfer(tokenAddress: Tokens.usdcPolygon, amount: '100'),
  ///     TokenTransfer(tokenAddress: Tokens.wmaticPolygon, amount: '50'),
  ///   ],
  /// );
  /// ```
  Future<List<MultiTokenTransferResult>> multiTokenTransfer({
    required String to,
    required List<TokenTransfer> transfers,
    bool stopOnError = false,
  }) async {
    _requireConnected();

    final results = <MultiTokenTransferResult>[];

    for (final transfer in transfers) {
      try {
        final token = tokenHelper.token(transfer.tokenAddress);
        final amount = await token.parseAmount(transfer.amount);
        final txHash = await token.transfer(to: to, amount: amount);

        results.add(MultiTokenTransferResult(
          tokenAddress: transfer.tokenAddress,
          symbol: await token.symbol(),
          amount: transfer.amount,
          txHash: txHash,
          success: true,
        ));
      } catch (e) {
        results.add(MultiTokenTransferResult(
          tokenAddress: transfer.tokenAddress,
          symbol: null,
          amount: transfer.amount,
          success: false,
          error: e.toString(),
        ));

        if (stopOnError) break;
      }
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SWAP PREPARATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Prepare token for swap by ensuring approval.
  ///
  /// Checks balance, validates amount, and approves if needed.
  ///
  /// ```dart
  /// final prep = await operations.prepareForSwap(
  ///   tokenAddress: Tokens.usdcPolygon,
  ///   amount: '1000',
  ///   spender: uniswapRouter,
  /// );
  ///
  /// if (prep.needsApproval) {
  ///   await Web3Refi.instance.waitForTransaction(prep.approvalTxHash!);
  /// }
  ///
  /// // Now ready to swap
  /// ```
  Future<SwapPreparation> prepareForSwap({
    required String tokenAddress,
    required String amount,
    required String spender,
    bool useInfiniteApproval = false,
  }) async {
    _requireConnected();

    final token = tokenHelper.token(tokenAddress);
    final parsedAmount = await token.parseAmount(amount);

    // Check balance
    final balance = await token.balanceOf(walletManager.address!);
    if (balance < parsedAmount) {
      return SwapPreparation(
        isReady: false,
        insufficientBalance: true,
        requiredAmount: amount,
        availableBalance: await token.formatAmount(balance),
        symbol: await token.symbol(),
      );
    }

    // Check and handle approval
    final currentAllowance = await token.allowance(
      walletManager.address!,
      spender,
    );

    String? approvalTxHash;
    if (currentAllowance < parsedAmount) {
      approvalTxHash = await token.ensureApproval(
        spender: spender,
        amount: parsedAmount,
        useInfinite: useInfiniteApproval,
      );
    }

    return SwapPreparation(
      isReady: approvalTxHash == null,
      needsApproval: approvalTxHash != null,
      approvalTxHash: approvalTxHash,
      parsedAmount: parsedAmount,
      symbol: await token.symbol(),
    );
  }

  /// Prepare multiple tokens for swap.
  Future<Map<String, SwapPreparation>> prepareMultipleForSwap({
    required Map<String, String> tokenAmounts, // tokenAddress -> amount
    required String spender,
    bool useInfiniteApproval = false,
  }) async {
    final results = <String, SwapPreparation>{};

    for (final entry in tokenAmounts.entries) {
      results[entry.key] = await prepareForSwap(
        tokenAddress: entry.key,
        amount: entry.value,
        spender: spender,
        useInfiniteApproval: useInfiniteApproval,
      );
    }

    return results;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NATIVE TOKEN WRAPPING
  // ══════════════════════════════════════════════════════════════════════════

  /// Wrap native token to wrapped version (ETH → WETH).
  ///
  /// ```dart
  /// final txHash = await operations.wrapNative(
  ///   amount: '1.5', // 1.5 ETH
  /// );
  /// ```
  Future<String> wrapNative({required String amount}) async {
    _requireConnected();

    final wrappedAddress = _getWrappedNativeAddress();
    if (wrappedAddress == null) {
      throw UnsupportedError('Native token wrapping not supported on this chain');
    }

    final decimals = currentChain.decimals;
    final parsedAmount = _parseNativeAmount(amount, decimals);

    // Check native balance
    final nativeBalance = await rpcClient.getBalance(walletManager.address!);
    if (nativeBalance < parsedAmount) {
      throw TransactionException.insufficientBalance(
        required: amount,
        available: _formatNativeAmount(nativeBalance, decimals),
        symbol: currentChain.symbol,
      );
    }

    // WETH deposit() function
    final data = AbiCodec.encodeFunctionCall('deposit()', []);

    return walletManager.sendTransaction(
      to: wrappedAddress,
      data: data,
      value: '0x${parsedAmount.toRadixString(16)}',
    );
  }

  /// Unwrap wrapped token to native (WETH → ETH).
  ///
  /// ```dart
  /// final txHash = await operations.unwrapNative(
  ///   amount: '1.5', // 1.5 WETH → 1.5 ETH
  /// );
  /// ```
  Future<String> unwrapNative({required String amount}) async {
    _requireConnected();

    final wrappedAddress = _getWrappedNativeAddress();
    if (wrappedAddress == null) {
      throw UnsupportedError('Native token wrapping not supported on this chain');
    }

    final weth = tokenHelper.token(wrappedAddress);
    final parsedAmount = await weth.parseAmount(amount);

    // Check WETH balance
    final balance = await weth.balanceOf(walletManager.address!);
    if (balance < parsedAmount) {
      throw TransactionException.insufficientBalance(
        required: amount,
        available: await weth.formatAmount(balance),
        symbol: 'W${currentChain.symbol}',
      );
    }

    // WETH withdraw(uint256) function
    final data = AbiCodec.encodeFunctionCall(
      'withdraw(uint256)',
      [AbiCodec.encodeUint256(parsedAmount)],
    );

    return walletManager.sendTransaction(
      to: wrappedAddress,
      data: data,
      value: '0x0',
    );
  }

  /// Get wrapped native token address for current chain.
  String? _getWrappedNativeAddress() {
    switch (currentChain.chainId) {
      case 1: // Ethereum
        return Tokens.wethEthereum;
      case 137: // Polygon
        return Tokens.wmaticPolygon;
      case 42161: // Arbitrum
        return Tokens.wethArbitrum;
      case 10: // Optimism
        return Tokens.wethOptimism;
      case 8453: // Base
        return Tokens.wethBase;
      case 56: // BSC
        return Tokens.wbnbBsc;
      case 43114: // Avalanche
        return Tokens.wavaxAvalanche;
      default:
        return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ALLOWANCE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Get comprehensive approval audit for a token.
  ///
  /// Checks approvals against known DEXes and protocols.
  Future<AllowanceAudit> auditAllowances({
    required String tokenAddress,
  }) async {
    _requireConnected();

    final token = tokenHelper.token(tokenAddress);
    final metadata = await token.getMetadata();

    // Known spenders to check (DEXes, protocols)
    final knownSpenders = _getKnownSpenders();
    final approvals = <ApprovalInfo>[];

    for (final spender in knownSpenders.entries) {
      final allowance = await token.allowance(
        walletManager.address!,
        spender.key,
      );

      if (allowance > BigInt.zero) {
        approvals.add(ApprovalInfo(
          spenderAddress: spender.key,
          spenderName: spender.value,
          allowance: allowance,
          formattedAllowance: await token.formatAmount(allowance),
          isInfinite: allowance >= ERC20.maxUint256 ~/ BigInt.two,
        ));
      }
    }

    return AllowanceAudit(
      tokenAddress: tokenAddress,
      tokenSymbol: metadata.symbol,
      tokenName: metadata.name,
      approvals: approvals,
      totalApprovals: approvals.length,
      hasInfiniteApprovals: approvals.any((a) => a.isInfinite),
    );
  }

  /// Revoke all approvals for a token.
  Future<List<String>> revokeAllApprovals({
    required String tokenAddress,
  }) async {
    final audit = await auditAllowances(tokenAddress: tokenAddress);
    final txHashes = <String>[];

    for (final approval in audit.approvals) {
      final txHash = await tokenHelper
          .token(tokenAddress)
          .revokeApproval(approval.spenderAddress);
      txHashes.add(txHash);
    }

    return txHashes;
  }

  /// Get known DEX/protocol spenders for current chain.
  Map<String, String> _getKnownSpenders() {
    // Common DEX routers and protocols
    switch (currentChain.chainId) {
      case 1: // Ethereum
        return {
          '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D': 'Uniswap V2 Router',
          '0xE592427A0AEce92De3Edee1F18E0157C05861564': 'Uniswap V3 Router',
          '0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F': 'SushiSwap Router',
          '0x1111111254fb6c44bAC0beD2854e76F90643097d': '1inch Router',
        };
      case 137: // Polygon
        return {
          '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff': 'QuickSwap Router',
          '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506': 'SushiSwap Router',
          '0xE592427A0AEce92De3Edee1F18E0157C05861564': 'Uniswap V3 Router',
          '0x1111111254fb6c44bAC0beD2854e76F90643097d': '1inch Router',
        };
      case 42161: // Arbitrum
        return {
          '0xE592427A0AEce92De3Edee1F18E0157C05861564': 'Uniswap V3 Router',
          '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506': 'SushiSwap Router',
          '0x1111111254fb6c44bAC0beD2854e76F90643097d': '1inch Router',
        };
      default:
        return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOKEN COMPARISON & INFO
  // ══════════════════════════════════════════════════════════════════════════

  /// Compare two tokens (useful for swap interfaces).
  Future<TokenComparison> compareTokens({
    required String tokenAAddress,
    required String tokenBAddress,
    required String ownerAddress,
  }) async {
    final tokenA = tokenHelper.token(tokenAAddress);
    final tokenB = tokenHelper.token(tokenBAddress);

    final results = await Future.wait([
      tokenA.getMetadata(),
      tokenB.getMetadata(),
      tokenA.balanceOf(ownerAddress),
      tokenB.balanceOf(ownerAddress),
    ]);

    final metaA = results[0] as TokenMetadata;
    final metaB = results[1] as TokenMetadata;
    final balA = results[2] as BigInt;
    final balB = results[3] as BigInt;

    return TokenComparison(
      tokenA: TokenInfo(
        address: tokenAAddress,
        symbol: metaA.symbol,
        name: metaA.name,
        decimals: metaA.decimals,
        balance: balA,
        formattedBalance: await tokenA.formatAmount(balA),
      ),
      tokenB: TokenInfo(
        address: tokenBAddress,
        symbol: metaB.symbol,
        name: metaB.name,
        decimals: metaB.decimals,
        balance: balB,
        formattedBalance: await tokenB.formatAmount(balB),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAS ESTIMATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Estimate total gas for batch transfer.
  Future<GasEstimate> estimateBatchTransferGas({
    required String tokenAddress,
    required List<TransferRecipient> recipients,
  }) async {
    _requireConnected();

    final token = tokenHelper.token(tokenAddress);
    BigInt totalGas = BigInt.zero;

    // Estimate gas for first transfer (most accurate)
    if (recipients.isNotEmpty) {
      final firstAmount = await token.parseAmount(recipients.first.amount);
      final gasPerTransfer = await token.estimateTransferGas(
        to: recipients.first.address,
        amount: firstAmount,
      );

      // Multiply by number of transfers (gas varies slightly, add 10% buffer)
      totalGas = gasPerTransfer * BigInt.from(recipients.length);
      totalGas = totalGas * BigInt.from(110) ~/ BigInt.from(100);
    }

    final gasPrice = await rpcClient.getGasPrice();
    final totalCost = totalGas * gasPrice;

    return GasEstimate(
      gasLimit: totalGas,
      gasPrice: gasPrice,
      totalCost: totalCost,
      formattedCost: _formatNativeAmount(totalCost, currentChain.decimals),
      symbol: currentChain.symbol,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _requireConnected() {
    if (!walletManager.isConnected) {
      throw WalletException.notConnected();
    }
  }

  BigInt _parseNativeAmount(String amount, int decimals) {
    final parts = amount.split('.');
    final whole = BigInt.parse(parts[0]);

    if (parts.length == 1) {
      return whole * BigInt.from(10).pow(decimals);
    }

    var fraction = parts[1];
    if (fraction.length > decimals) {
      fraction = fraction.substring(0, decimals);
    }
    fraction = fraction.padRight(decimals, '0');

    return whole * BigInt.from(10).pow(decimals) + BigInt.parse(fraction);
  }

  String _formatNativeAmount(BigInt amount, int decimals) {
    final divisor = BigInt.from(10).pow(decimals);
    final whole = amount ~/ divisor;
    final fraction = (amount % divisor).toString().padLeft(decimals, '0');
    final trimmed = fraction.replaceAll(RegExp(r'0+$'), '');
    return '$whole.${trimmed.isEmpty ? '0' : trimmed}';
  }
}

// ════════════════════════════════════════════════════════════════════════════
// DATA CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Recipient for batch transfer.
class TransferRecipient {
  final String address;
  final String amount; // Human-readable amount

  const TransferRecipient({
    required this.address,
    required this.amount,
  });
}

/// Result of a single batch transfer.
class BatchTransferResult {
  final String recipient;
  final String amount;
  final String? txHash;
  final bool success;
  final String? error;

  const BatchTransferResult({
    required this.recipient,
    required this.amount,
    this.txHash,
    required this.success,
    this.error,
  });
}

/// Token transfer specification.
class TokenTransfer {
  final String tokenAddress;
  final String amount;

  const TokenTransfer({
    required this.tokenAddress,
    required this.amount,
  });
}

/// Result of multi-token transfer.
class MultiTokenTransferResult {
  final String tokenAddress;
  final String? symbol;
  final String amount;
  final String? txHash;
  final bool success;
  final String? error;

  const MultiTokenTransferResult({
    required this.tokenAddress,
    this.symbol,
    required this.amount,
    this.txHash,
    required this.success,
    this.error,
  });
}

/// Swap preparation result.
class SwapPreparation {
  final bool isReady;
  final bool needsApproval;
  final bool insufficientBalance;
  final String? approvalTxHash;
  final BigInt? parsedAmount;
  final String? requiredAmount;
  final String? availableBalance;
  final String? symbol;

  const SwapPreparation({
    required this.isReady,
    this.needsApproval = false,
    this.insufficientBalance = false,
    this.approvalTxHash,
    this.parsedAmount,
    this.requiredAmount,
    this.availableBalance,
    this.symbol,
  });
}

/// Allowance audit result.
class AllowanceAudit {
  final String tokenAddress;
  final String tokenSymbol;
  final String tokenName;
  final List<ApprovalInfo> approvals;
  final int totalApprovals;
  final bool hasInfiniteApprovals;

  const AllowanceAudit({
    required this.tokenAddress,
    required this.tokenSymbol,
    required this.tokenName,
    required this.approvals,
    required this.totalApprovals,
    required this.hasInfiniteApprovals,
  });
}

/// Individual approval info.
class ApprovalInfo {
  final String spenderAddress;
  final String spenderName;
  final BigInt allowance;
  final String formattedAllowance;
  final bool isInfinite;

  const ApprovalInfo({
    required this.spenderAddress,
    required this.spenderName,
    required this.allowance,
    required this.formattedAllowance,
    required this.isInfinite,
  });
}

/// Token comparison result.
class TokenComparison {
  final TokenInfo tokenA;
  final TokenInfo tokenB;

  const TokenComparison({
    required this.tokenA,
    required this.tokenB,
  });
}

/// Token info with balance.
class TokenInfo {
  final String address;
  final String symbol;
  final String name;
  final int decimals;
  final BigInt balance;
  final String formattedBalance;

  const TokenInfo({
    required this.address,
    required this.symbol,
    required this.name,
    required this.decimals,
    required this.balance,
    required this.formattedBalance,
  });
}

/// Gas estimation result.
class GasEstimate {
  final BigInt gasLimit;
  final BigInt gasPrice;
  final BigInt totalCost;
  final String formattedCost;
  final String symbol;

  const GasEstimate({
    required this.gasLimit,
    required this.gasPrice,
    required this.totalCost,
    required this.formattedCost,
    required this.symbol,
  });

  /// Gas price in Gwei.
  double get gasPriceGwei => gasPrice.toDouble() / 1e9;

  /// Display string (e.g., "0.0015 ETH").
  String get displayCost => '$formattedCost $symbol';
}
