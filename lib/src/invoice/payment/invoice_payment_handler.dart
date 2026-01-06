import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3refi/src/invoice/core/invoice.dart';
import 'package:web3refi/src/invoice/core/payment_info.dart';
import 'package:web3refi/src/invoice/core/invoice_status.dart';
import 'package:web3refi/src/standards/erc20.dart';
import 'package:web3refi/src/transport/rpc_client.dart';
import 'package:web3refi/src/wallet/wallet_manager.dart';
import 'package:web3refi/src/core/chain.dart';

/// Handles multi-chain invoice payments
class InvoicePaymentHandler extends ChangeNotifier {
  final WalletManager walletManager;
  final Map<int, RpcClient> rpcClients;

  /// Payment monitoring subscriptions
  final Map<String, StreamSubscription> _paymentMonitors = {};

  /// Payment confirmations cache
  final Map<String, PaymentConfirmation> _confirmations = {};

  InvoicePaymentHandler({
    required this.walletManager,
    required this.rpcClients,
  });

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT EXECUTION
  // ═══════════════════════════════════════════════════════════════════════

  /// Pay invoice with specified token
  Future<String> payInvoice({
    required Invoice invoice,
    required String tokenAddress,
    required int chainId,
    BigInt? amount,
    BigInt? maxGas,
  }) async {
    // Validate
    if (!invoice.isPayable) {
      throw PaymentException('Invoice is not payable');
    }

    // Check if chain is accepted
    if (!invoice.acceptedChains.contains(chainId)) {
      throw PaymentException('Chain $chainId not accepted for this invoice');
    }

    // Get amount to pay (default to remaining amount)
    final payAmount = amount ?? invoice.remainingAmount;

    if (payAmount <= BigInt.zero) {
      throw PaymentException('Payment amount must be greater than zero');
    }

    if (payAmount > invoice.remainingAmount) {
      throw PaymentException('Payment amount exceeds remaining balance');
    }

    // Get RPC client for chain
    final rpcClient = rpcClients[chainId];
    if (rpcClient == null) {
      throw PaymentException('RPC client not configured for chain $chainId');
    }

    // Switch to correct chain if needed
    if (walletManager.chainId != chainId) {
      await walletManager.switchChain(chainId);
    }

    // Pay via token or native
    String txHash;
    if (tokenAddress.toLowerCase() == 'eth' || tokenAddress == '0x0000000000000000000000000000000000000000') {
      // Native token payment (ETH, MATIC, BNB, etc.)
      txHash = await _payWithNativeToken(
        invoice: invoice,
        amount: payAmount,
        chainId: chainId,
        maxGas: maxGas,
      );
    } else {
      // ERC20 token payment
      txHash = await _payWithERC20(
        invoice: invoice,
        tokenAddress: tokenAddress,
        amount: payAmount,
        rpcClient: rpcClient,
        maxGas: maxGas,
      );
    }

    _log('Payment sent: $txHash');

    // Start monitoring payment
    _monitorPayment(txHash, chainId);

    return txHash;
  }

  /// Pay with native token (ETH, MATIC, etc.)
  Future<String> _payWithNativeToken({
    required Invoice invoice,
    required BigInt amount,
    required int chainId,
    BigInt? maxGas,
  }) async {
    // Check if split payment
    if (invoice.hasSplitPayment && invoice.paymentSplits != null) {
      return await _payNativeWithSplit(
        invoice: invoice,
        amount: amount,
        chainId: chainId,
      );
    }

    // Simple direct payment
    final txHash = await walletManager.sendTransaction(
      to: invoice.to,
      value: amount,
      chainId: chainId,
    );

    return txHash;
  }

  /// Pay with ERC20 token
  Future<String> _payWithERC20({
    required Invoice invoice,
    required String tokenAddress,
    required BigInt amount,
    required RpcClient rpcClient,
    BigInt? maxGas,
  }) async {
    final token = ERC20(
      contractAddress: tokenAddress,
      rpcClient: rpcClient,
      signer: walletManager,
    );

    // Check allowance
    final allowance = await token.allowance(
      owner: walletManager.address!,
      spender: invoice.to,
    );

    // Approve if needed
    if (allowance < amount) {
      _log('Approving token spend...');
      await token.approve(
        spender: invoice.to,
        amount: amount,
      );
    }

    // Check if split payment
    if (invoice.hasSplitPayment && invoice.paymentSplits != null) {
      return await _payERC20WithSplit(
        invoice: invoice,
        token: token,
        amount: amount,
      );
    }

    // Simple transfer
    final txHash = await token.transfer(
      to: invoice.to,
      amount: amount,
    );

    return txHash;
  }

  /// Pay native token with split payments
  Future<String> _payNativeWithSplit({
    required Invoice invoice,
    required BigInt amount,
    required int chainId,
  }) async {
    // Calculate distribution
    final distribution = _calculateSplitDistribution(
      total: amount,
      splits: invoice.paymentSplits!,
    );

    // Send to each recipient
    // Note: In production, use a batching contract for efficiency
    String? lastTxHash;

    for (final entry in distribution.entries) {
      final recipient = entry.key;
      final recipientAmount = entry.value;

      lastTxHash = await walletManager.sendTransaction(
        to: recipient,
        value: recipientAmount,
        chainId: chainId,
      );

      _log('Split payment sent to $recipient: $recipientAmount');
    }

    return lastTxHash!;
  }

  /// Pay ERC20 with split payments
  Future<String> _payERC20WithSplit({
    required Invoice invoice,
    required ERC20 token,
    required BigInt amount,
  }) async {
    // Calculate distribution
    final distribution = _calculateSplitDistribution(
      total: amount,
      splits: invoice.paymentSplits!,
    );

    // Send to each recipient
    String? lastTxHash;

    for (final entry in distribution.entries) {
      final recipient = entry.key;
      final recipientAmount = entry.value;

      lastTxHash = await token.transfer(
        to: recipient,
        amount: recipientAmount,
      );

      _log('Split payment sent to $recipient: $recipientAmount');
    }

    return lastTxHash!;
  }

  /// Calculate split payment distribution
  Map<String, BigInt> _calculateSplitDistribution({
    required BigInt total,
    required List<PaymentSplit> splits,
  }) {
    final distribution = <String, BigInt>{};
    BigInt allocated = BigInt.zero;

    // Calculate amounts
    for (int i = 0; i < splits.length; i++) {
      final split = splits[i];
      BigInt amount;

      if (split.fixedAmount != null) {
        amount = split.fixedAmount!;
      } else {
        amount = (total * BigInt.from((split.percentage * 100).toInt())) ~/ BigInt.from(10000);
      }

      distribution[split.address] = amount;
      allocated += amount;
    }

    // Handle rounding errors
    if (allocated != total) {
      final diff = total - allocated;
      final primarySplit = splits.firstWhere(
        (s) => s.isPrimary,
        orElse: () => splits.first,
      );
      distribution[primarySplit.address] = distribution[primarySplit.address]! + diff;
    }

    return distribution;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT MONITORING
  // ═══════════════════════════════════════════════════════════════════════

  /// Monitor payment confirmation
  void _monitorPayment(String txHash, int chainId) {
    final rpcClient = rpcClients[chainId];
    if (rpcClient == null) return;

    // Cancel existing monitor for this tx
    _paymentMonitors[txHash]?.cancel();

    // Poll for transaction receipt
    _paymentMonitors[txHash] = Stream.periodic(
      const Duration(seconds: 5),
      (count) => count,
    ).asyncMap((_) async {
      return await _checkTransactionStatus(txHash, chainId, rpcClient);
    }).listen((confirmation) {
      if (confirmation != null) {
        _confirmations[txHash] = confirmation;

        // Stop monitoring if confirmed
        if (confirmation.confirmations >= 12) {
          _paymentMonitors[txHash]?.cancel();
          _paymentMonitors.remove(txHash);
          _log('Payment confirmed: $txHash');
        }

        notifyListeners();
      }
    });
  }

  /// Check transaction status
  Future<PaymentConfirmation?> _checkTransactionStatus(
    String txHash,
    int chainId,
    RpcClient rpcClient,
  ) async {
    try {
      // Get transaction receipt
      final receipt = await rpcClient.getTransactionReceipt(txHash);

      if (receipt == null) {
        // Transaction not mined yet
        return null;
      }

      // Get current block
      final currentBlock = await rpcClient.getBlockNumber();

      final confirmations = currentBlock - (receipt['blockNumber'] as int? ?? 0);

      return PaymentConfirmation(
        txHash: txHash,
        blockNumber: receipt['blockNumber'] as int,
        confirmations: confirmations,
        status: (receipt['status'] as int) == 1
            ? PaymentStatus.confirmed
            : PaymentStatus.failed,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      _log('Error checking transaction status: $e');
      return null;
    }
  }

  /// Get payment confirmation
  PaymentConfirmation? getPaymentConfirmation(String txHash) {
    return _confirmations[txHash];
  }

  /// Wait for payment confirmation
  Future<PaymentConfirmation> waitForConfirmation({
    required String txHash,
    int requiredConfirmations = 12,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final completer = Completer<PaymentConfirmation>();
    Timer? timeoutTimer;

    // Set timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          PaymentException('Payment confirmation timeout'),
        );
      }
    });

    // Listen for confirmations
    final subscription = Stream.periodic(
      const Duration(seconds: 3),
    ).listen((_) {
      final confirmation = _confirmations[txHash];
      if (confirmation != null &&
          confirmation.confirmations >= requiredConfirmations &&
          !completer.isCompleted) {
        timeoutTimer?.cancel();
        completer.complete(confirmation);
      }
    });

    try {
      final result = await completer.future;
      subscription.cancel();
      return result;
    } catch (e) {
      subscription.cancel();
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT VALIDATION
  // ═══════════════════════════════════════════════════════════════════════

  /// Validate payment amount
  Future<bool> validatePayment({
    required Invoice invoice,
    required String txHash,
    required int chainId,
  }) async {
    final rpcClient = rpcClients[chainId];
    if (rpcClient == null) return false;

    try {
      // Get transaction
      final tx = await rpcClient.getTransaction(txHash);
      if (tx == null) return false;

      // Verify recipient
      final to = tx['to'] as String?;
      if (to?.toLowerCase() != invoice.to.toLowerCase()) {
        return false;
      }

      // Verify amount
      final value = BigInt.parse(tx['value'] as String);
      if (value < invoice.remainingAmount) {
        return false;
      }

      return true;
    } catch (e) {
      _log('Payment validation error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BALANCE CHECKS
  // ═══════════════════════════════════════════════════════════════════════

  /// Check if user has sufficient balance to pay
  Future<bool> hasSufficientBalance({
    required Invoice invoice,
    required String tokenAddress,
    required int chainId,
    BigInt? amount,
  }) async {
    final payAmount = amount ?? invoice.remainingAmount;
    final rpcClient = rpcClients[chainId];
    if (rpcClient == null) return false;

    try {
      if (tokenAddress.toLowerCase() == 'eth' ||
          tokenAddress == '0x0000000000000000000000000000000000000000') {
        // Check native balance
        final balance = await rpcClient.getBalance(walletManager.address!);
        return balance >= payAmount;
      } else {
        // Check ERC20 balance
        final token = ERC20(
          contractAddress: tokenAddress,
          rpcClient: rpcClient,
          signer: walletManager,
        );

        final balance = await token.balanceOf(walletManager.address!);
        return balance >= payAmount;
      }
    } catch (e) {
      _log('Balance check error: $e');
      return false;
    }
  }

  /// Get user balance for token
  Future<BigInt> getBalance({
    required String tokenAddress,
    required int chainId,
  }) async {
    final rpcClient = rpcClients[chainId];
    if (rpcClient == null) return BigInt.zero;

    try {
      if (tokenAddress.toLowerCase() == 'eth' ||
          tokenAddress == '0x0000000000000000000000000000000000000000') {
        return await rpcClient.getBalance(walletManager.address!);
      } else {
        final token = ERC20(
          contractAddress: tokenAddress,
          rpcClient: rpcClient,
          signer: walletManager,
        );

        return await token.balanceOf(walletManager.address!);
      }
    } catch (e) {
      _log('Get balance error: $e');
      return BigInt.zero;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAYMENT LINKS
  // ═══════════════════════════════════════════════════════════════════════

  /// Generate payment link for invoice
  String generatePaymentLink({
    required Invoice invoice,
    String? tokenAddress,
    int? chainId,
  }) {
    final params = <String, String>{
      'invoice': invoice.id,
      'to': invoice.to,
      'amount': invoice.remainingAmount.toString(),
      if (tokenAddress != null) 'token': tokenAddress,
      if (chainId != null) 'chain': chainId.toString(),
    };

    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return 'web3refi://pay?$query';
  }

  /// Parse payment link
  Map<String, String>? parsePaymentLink(String link) {
    if (!link.startsWith('web3refi://pay?')) {
      return null;
    }

    final query = link.split('?').last;
    final params = <String, String>{};

    for (final param in query.split('&')) {
      final parts = param.split('=');
      if (parts.length == 2) {
        params[parts[0]] = parts[1];
      }
    }

    return params;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Stop monitoring all payments
  void stopAllMonitoring() {
    for (final subscription in _paymentMonitors.values) {
      subscription.cancel();
    }
    _paymentMonitors.clear();
  }

  void _log(String message) {
    debugPrint('[InvoicePaymentHandler] $message');
  }

  @override
  void dispose() {
    stopAllMonitoring();
    super.dispose();
  }
}

/// Payment confirmation details
class PaymentConfirmation {
  final String txHash;
  final int blockNumber;
  final int confirmations;
  final PaymentStatus status;
  final DateTime timestamp;

  PaymentConfirmation({
    required this.txHash,
    required this.blockNumber,
    required this.confirmations,
    required this.status,
    required this.timestamp,
  });

  bool get isConfirmed => confirmations >= 12 && status == PaymentStatus.confirmed;
  bool get isFailed => status == PaymentStatus.failed;

  @override
  String toString() {
    return 'PaymentConfirmation(tx: $txHash, confirmations: $confirmations, status: ${status.name})';
  }
}

/// Payment exception
class PaymentException implements Exception {
  final String message;

  PaymentException(this.message);

  @override
  String toString() => 'PaymentException: $message';
}
