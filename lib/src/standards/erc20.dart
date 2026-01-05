import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import '../transport/rpc_client.dart';
import '../wallet/wallet_manager.dart';
import '../core/chain.dart';
import '../transactions/transaction.dart';
import '../errors/web3_exception.dart';
import 'abi_codec.dart';

/// ERC-20 token contract interface.
///
/// Provides complete functionality to interact with any ERC-20 compliant token,
/// including standard operations (transfer, approve, allowance) and advanced
/// features (permit, batch operations, event parsing).
///
/// ## Basic Usage
///
/// ```dart
/// final usdc = ERC20(
///   address: Tokens.usdcPolygon,
///   rpcClient: Web3Refi.instance.rpcClient,
///   walletManager: Web3Refi.instance.walletManager,
/// );
///
/// // Read balance
/// final balance = await usdc.balanceOf(myAddress);
/// print('Balance: ${await usdc.formatAmount(balance)} USDC');
///
/// // Transfer tokens
/// final txHash = await usdc.transfer(
///   to: recipient,
///   amount: await usdc.parseAmount('100.00'),
/// );
/// ```
///
/// ## Advanced Usage
///
/// ```dart
/// // Smart approval (only approves if needed)
/// await usdc.ensureApproval(spender: dexContract, amount: amount);
///
/// // Watch balance changes
/// usdc.watchBalance(myAddress).listen((balance) {
///   print('New balance: $balance');
/// });
///
/// // Get transfer history
/// final transfers = await usdc.getTransferEvents(
///   fromBlock: 1000000,
///   toBlock: 'latest',
/// );
/// ```
class ERC20 {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Token contract address.
  final String address;

  /// RPC client for blockchain calls.
  final RpcClient rpcClient;

  /// Wallet manager for signing transactions.
  final WalletManager? walletManager;

  /// Optional chain override (uses RPC client's chain by default).
  final Chain? chain;

  // Cached token metadata
  String? _name;
  String? _symbol;
  int? _decimals;
  BigInt? _totalSupply;

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  /// Creates an ERC20 token instance.
  ///
  /// [address] is the token contract address.
  /// [rpcClient] is used for blockchain calls.
  /// [walletManager] is required for write operations (transfer, approve).
  /// [chain] optionally overrides the chain from rpcClient.
  ERC20({
    required this.address,
    required this.rpcClient,
    this.walletManager,
    this.chain,
  }) {
    if (!_isValidAddress(address)) {
      throw ArgumentError('Invalid token address: $address');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // METADATA (Cached)
  // ══════════════════════════════════════════════════════════════════════════

  /// Get the token name (e.g., "USD Coin").
  ///
  /// Result is cached after first call.
  Future<String> name() async {
    if (_name != null) return _name!;

    try {
      final data = AbiCodec.encodeFunctionCall('name()', []);
      final result = await _ethCall(data);
      _name = AbiCodec.decodeString(result);
      return _name!;
    } catch (e) {
      throw ContractException(
        message: 'Failed to get token name: $e',
        code: 'name_failed',
        contractAddress: address,
        functionName: 'name',
      );
    }
  }

  /// Get the token symbol (e.g., "USDC").
  ///
  /// Result is cached after first call.
  Future<String> symbol() async {
    if (_symbol != null) return _symbol!;

    try {
      final data = AbiCodec.encodeFunctionCall('symbol()', []);
      final result = await _ethCall(data);
      _symbol = AbiCodec.decodeString(result);
      return _symbol!;
    } catch (e) {
      throw ContractException(
        message: 'Failed to get token symbol: $e',
        code: 'symbol_failed',
        contractAddress: address,
        functionName: 'symbol',
      );
    }
  }

  /// Get the number of decimals (e.g., 6 for USDC, 18 for most tokens).
  ///
  /// Result is cached after first call.
  Future<int> decimals() async {
    if (_decimals != null) return _decimals!;

    try {
      final data = AbiCodec.encodeFunctionCall('decimals()', []);
      final result = await _ethCall(data);
      _decimals = AbiCodec.decodeUint256(result).toInt();
      return _decimals!;
    } catch (e) {
      // Default to 18 if decimals() call fails (some tokens don't implement it)
      _decimals = 18;
      return _decimals!;
    }
  }

  /// Get the total supply of the token.
  Future<BigInt> totalSupply() async {
    final data = AbiCodec.encodeFunctionCall('totalSupply()', []);
    final result = await _ethCall(data);
    return AbiCodec.decodeUint256(result);
  }

  /// Get all token metadata at once.
  ///
  /// More efficient than calling name(), symbol(), decimals() separately.
  Future<TokenMetadata> getMetadata() async {
    final results = await Future.wait([
      name(),
      symbol(),
      decimals(),
      totalSupply(),
    ]);

    return TokenMetadata(
      address: address,
      name: results[0] as String,
      symbol: results[1] as String,
      decimals: results[2] as int,
      totalSupply: results[3] as BigInt,
    );
  }

  /// Preload and cache all metadata.
  ///
  /// Call this early to avoid latency on first use.
  Future<void> preloadMetadata() async {
    await Future.wait([name(), symbol(), decimals()]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // READ OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get the token balance of an address.
  ///
  /// Returns the raw balance in smallest units (e.g., wei for 18-decimal tokens).
  /// Use [formatAmount] to convert to human-readable format.
  ///
  /// ```dart
  /// final balance = await token.balanceOf('0x123...');
  /// final formatted = await token.formatAmount(balance);
  /// print('$formatted ${await token.symbol()}');
  /// ```
  Future<BigInt> balanceOf(String owner) async {
    _validateAddress(owner, 'owner');

    final data = AbiCodec.encodeFunctionCall(
      'balanceOf(address)',
      [AbiCodec.encodeAddress(owner)],
    );

    final result = await _ethCall(data);
    return AbiCodec.decodeUint256(result);
  }

  /// Get the allowance granted by [owner] to [spender].
  ///
  /// Returns the amount [spender] is allowed to transfer from [owner].
  Future<BigInt> allowance(String owner, String spender) async {
    _validateAddress(owner, 'owner');
    _validateAddress(spender, 'spender');

    final data = AbiCodec.encodeFunctionCall(
      'allowance(address,address)',
      [
        AbiCodec.encodeAddress(owner),
        AbiCodec.encodeAddress(spender),
      ],
    );

    final result = await _ethCall(data);
    return AbiCodec.decodeUint256(result);
  }

  /// Check if [spender] has sufficient allowance to spend [amount] from [owner].
  Future<bool> hasAllowance(String owner, String spender, BigInt amount) async {
    final current = await allowance(owner, spender);
    return current >= amount;
  }

  /// Get balances for multiple addresses in parallel.
  ///
  /// More efficient than calling balanceOf() multiple times.
  Future<Map<String, BigInt>> balanceOfMultiple(List<String> addresses) async {
    final futures = addresses.map((addr) => balanceOf(addr));
    final balances = await Future.wait(futures);

    return Map.fromIterables(addresses, balances);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WRITE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Transfer tokens to another address.
  ///
  /// Returns the transaction hash.
  ///
  /// ```dart
  /// final txHash = await token.transfer(
  ///   to: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  ///   amount: await token.parseAmount('100.00'),
  /// );
  /// ```
  ///
  /// Throws [WalletException] if wallet not connected.
  /// Throws [TransactionException] if insufficient balance.
  Future<String> transfer({
    required String to,
    required BigInt amount,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    _requireWallet();
    _validateAddress(to, 'recipient');
    _validateAmount(amount);

    // Check balance before sending
    final balance = await balanceOf(walletManager!.address!);
    if (balance < amount) {
      final sym = await symbol();
      throw TransactionException.insufficientBalance(
        required: await formatAmount(amount),
        available: await formatAmount(balance),
        symbol: sym,
      );
    }

    final data = AbiCodec.encodeFunctionCall(
      'transfer(address,uint256)',
      [
        AbiCodec.encodeAddress(to),
        AbiCodec.encodeUint256(amount),
      ],
    );

    return _sendTransaction(
      data: data,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
    );
  }

  /// Approve a spender to spend tokens on your behalf.
  ///
  /// Returns the transaction hash.
  ///
  /// ```dart
  /// // Approve DEX to spend 1000 USDC
  /// final txHash = await usdc.approve(
  ///   spender: dexContractAddress,
  ///   amount: await usdc.parseAmount('1000'),
  /// );
  /// ```
  Future<String> approve({
    required String spender,
    required BigInt amount,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    _requireWallet();
    _validateAddress(spender, 'spender');

    final data = AbiCodec.encodeFunctionCall(
      'approve(address,uint256)',
      [
        AbiCodec.encodeAddress(spender),
        AbiCodec.encodeUint256(amount),
      ],
    );

    return _sendTransaction(
      data: data,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
    );
  }

  /// Transfer tokens from one address to another (requires prior approval).
  ///
  /// The caller must have been approved by [from] to spend at least [amount].
  Future<String> transferFrom({
    required String from,
    required String to,
    required BigInt amount,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    _requireWallet();
    _validateAddress(from, 'from');
    _validateAddress(to, 'to');
    _validateAmount(amount);

    // Check allowance
    final allowed = await allowance(from, walletManager!.address!);
    if (allowed < amount) {
      throw ContractException.insufficientAllowance(
        spender: walletManager!.address!,
        required: await formatAmount(amount),
        current: await formatAmount(allowed),
      );
    }

    final data = AbiCodec.encodeFunctionCall(
      'transferFrom(address,address,uint256)',
      [
        AbiCodec.encodeAddress(from),
        AbiCodec.encodeAddress(to),
        AbiCodec.encodeUint256(amount),
      ],
    );

    return _sendTransaction(
      data: data,
      gasLimit: gasLimit,
      gasPrice: gasPrice,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SMART OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Approve if needed, returns tx hash or null if already approved.
  ///
  /// This checks the current allowance and only sends an approval
  /// transaction if the current allowance is less than the required amount.
  ///
  /// ```dart
  /// // Only approves if necessary
  /// final txHash = await token.ensureApproval(
  ///   spender: dexAddress,
  ///   amount: swapAmount,
  /// );
  ///
  /// if (txHash != null) {
  ///   await Web3Refi.instance.waitForTransaction(txHash);
  /// }
  ///
  /// // Now safe to swap
  /// ```
  Future<String?> ensureApproval({
    required String spender,
    required BigInt amount,
    bool useInfinite = false,
  }) async {
    _requireWallet();

    final currentAllowance = await allowance(
      walletManager!.address!,
      spender,
    );

    if (currentAllowance >= amount) {
      return null; // Already approved
    }

    // Use infinite approval if requested, otherwise exact amount
    final approvalAmount = useInfinite ? maxUint256 : amount;
    return approve(spender: spender, amount: approvalAmount);
  }

  /// Approve infinite spending (common pattern for better UX).
  ///
  /// **Warning:** This allows the spender to transfer all your tokens.
  /// Only use with trusted contracts.
  Future<String> approveInfinite(String spender) async {
    return approve(spender: spender, amount: maxUint256);
  }

  /// Revoke approval for a spender (set allowance to 0).
  Future<String> revokeApproval(String spender) async {
    return approve(spender: spender, amount: BigInt.zero);
  }

  /// Transfer with balance check and formatted amount.
  ///
  /// Convenience method that handles parsing and validation.
  ///
  /// ```dart
  /// await token.transferFormatted(
  ///   to: recipient,
  ///   amount: '100.50', // Human-readable amount
  /// );
  /// ```
  Future<String> transferFormatted({
    required String to,
    required String amount,
  }) async {
    final parsedAmount = await parseAmount(amount);
    return transfer(to: to, amount: parsedAmount);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCE WATCHING
  // ══════════════════════════════════════════════════════════════════════════

  /// Stream balance updates for an address.
  ///
  /// Polls the balance at the specified interval and emits when changed.
  ///
  /// ```dart
  /// token.watchBalance(myAddress).listen((balance) {
  ///   setState(() => _balance = balance);
  /// });
  /// ```
  Stream<BigInt> watchBalance(
    String owner, {
    Duration interval = const Duration(seconds: 5),
  }) async* {
    BigInt? lastBalance;

    while (true) {
      try {
        final balance = await balanceOf(owner);
        if (balance != lastBalance) {
          lastBalance = balance;
          yield balance;
        }
      } catch (e) {
        // Ignore errors in watch, continue polling
      }
      await Future.delayed(interval);
    }
  }

  /// Stream formatted balance updates.
  Stream<String> watchBalanceFormatted(
    String owner, {
    Duration interval = const Duration(seconds: 5),
  }) async* {
    await for (final balance in watchBalance(owner, interval: interval)) {
      yield await formatAmount(balance);
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EVENT PARSING
  // ══════════════════════════════════════════════════════════════════════════

  /// Get Transfer events for this token.
  ///
  /// ```dart
  /// final transfers = await token.getTransferEvents(
  ///   from: myAddress, // Optional: filter by sender
  ///   to: null,        // Optional: filter by recipient
  ///   fromBlock: 1000000,
  ///   toBlock: 'latest',
  /// );
  /// ```
  Future<List<TransferEvent>> getTransferEvents({
    String? from,
    String? to,
    dynamic fromBlock = 'latest',
    dynamic toBlock = 'latest',
  }) async {
    // Transfer(address indexed from, address indexed to, uint256 value)
    final transferTopic = AbiCodec.eventSignature(
      'Transfer(address,address,uint256)',
    );

    final topics = <String?>[
      transferTopic,
      from != null ? AbiCodec.encodeAddress(from, padded: true) : null,
      to != null ? AbiCodec.encodeAddress(to, padded: true) : null,
    ];

    final logs = await rpcClient.getLogs(
      address: address,
      topics: topics.where((t) => t != null).cast<String>().toList(),
      fromBlock: fromBlock.toString(),
      toBlock: toBlock.toString(),
    );

    return logs.map((log) => TransferEvent.fromLog(log)).toList();
  }

  /// Get Approval events for this token.
  Future<List<ApprovalEvent>> getApprovalEvents({
    String? owner,
    String? spender,
    dynamic fromBlock = 'latest',
    dynamic toBlock = 'latest',
  }) async {
    final approvalTopic = AbiCodec.eventSignature(
      'Approval(address,address,uint256)',
    );

    final topics = <String?>[
      approvalTopic,
      owner != null ? AbiCodec.encodeAddress(owner, padded: true) : null,
      spender != null ? AbiCodec.encodeAddress(spender, padded: true) : null,
    ];

    final logs = await rpcClient.getLogs(
      address: address,
      topics: topics.where((t) => t != null).cast<String>().toList(),
      fromBlock: fromBlock.toString(),
      toBlock: toBlock.toString(),
    );

    return logs.map((log) => ApprovalEvent.fromLog(log)).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAS ESTIMATION
  // ══════════════════════════════════════════════════════════════════════════

  /// Estimate gas for a transfer.
  Future<BigInt> estimateTransferGas({
    required String to,
    required BigInt amount,
  }) async {
    _requireWallet();

    final data = AbiCodec.encodeFunctionCall(
      'transfer(address,uint256)',
      [
        AbiCodec.encodeAddress(to),
        AbiCodec.encodeUint256(amount),
      ],
    );

    return rpcClient.estimateGas({
      'from': walletManager!.address!,
      'to': address,
      'data': data,
    });
  }

  /// Estimate gas for an approval.
  Future<BigInt> estimateApproveGas({
    required String spender,
    required BigInt amount,
  }) async {
    _requireWallet();

    final data = AbiCodec.encodeFunctionCall(
      'approve(address,uint256)',
      [
        AbiCodec.encodeAddress(spender),
        AbiCodec.encodeUint256(amount),
      ],
    );

    return rpcClient.estimateGas({
      'from': walletManager!.address!,
      'to': address,
      'data': data,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FORMATTING
  // ══════════════════════════════════════════════════════════════════════════

  /// Format a raw token amount for display.
  ///
  /// Converts from smallest units to human-readable format.
  ///
  /// ```dart
  /// final balance = await token.balanceOf(address); // 1000000 (USDC)
  /// final formatted = await token.formatAmount(balance); // "1.0"
  /// ```
  Future<String> formatAmount(
    BigInt amount, {
    int? displayDecimals,
    bool trimZeros = true,
  }) async {
    final dec = await decimals();
    final divisor = BigInt.from(10).pow(dec);

    final isNegative = amount.isNegative;
    final absAmount = amount.abs();

    final whole = absAmount ~/ divisor;
    final fraction = (absAmount % divisor).toString().padLeft(dec, '0');

    // Determine display decimals
    final show = displayDecimals ?? (dec > 8 ? 8 : dec);
    var trimmedFraction = fraction.substring(0, show.clamp(0, fraction.length));

    // Trim trailing zeros if requested
    if (trimZeros) {
      trimmedFraction = trimmedFraction.replaceAll(RegExp(r'0+$'), '');
      if (trimmedFraction.isEmpty) trimmedFraction = '0';
    }

    final sign = isNegative ? '-' : '';
    return '$sign$whole.$trimmedFraction';
  }

  /// Parse a human-readable amount to raw token units.
  ///
  /// ```dart
  /// final amount = await token.parseAmount('100.50'); // BigInt
  /// ```
  Future<BigInt> parseAmount(String amount) async {
    final dec = await decimals();

    // Handle negative amounts
    final isNegative = amount.startsWith('-');
    final cleanAmount = amount.replaceFirst('-', '').trim();

    final parts = cleanAmount.split('.');
    if (parts.isEmpty || parts.length > 2) {
      throw ArgumentError('Invalid amount format: $amount');
    }

    final wholePart = parts[0].isEmpty ? '0' : parts[0];
    var fractionPart = parts.length > 1 ? parts[1] : '';

    // Validate parts are numeric
    if (!RegExp(r'^\d+$').hasMatch(wholePart)) {
      throw ArgumentError('Invalid amount format: $amount');
    }
    if (fractionPart.isNotEmpty && !RegExp(r'^\d+$').hasMatch(fractionPart)) {
      throw ArgumentError('Invalid amount format: $amount');
    }

    // Truncate or pad fraction to match decimals
    if (fractionPart.length > dec) {
      fractionPart = fractionPart.substring(0, dec);
    }
    fractionPart = fractionPart.padRight(dec, '0');

    final whole = BigInt.parse(wholePart);
    final fraction = BigInt.parse(fractionPart.isEmpty ? '0' : fractionPart);
    final result = whole * BigInt.from(10).pow(dec) + fraction;

    return isNegative ? -result : result;
  }

  /// Format amount with symbol.
  Future<String> formatWithSymbol(BigInt amount) async {
    final formatted = await formatAmount(amount);
    final sym = await symbol();
    return '$formatted $sym';
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _ethCall(String data) async {
    return rpcClient.ethCall({
      'to': address,
      'data': data,
    });
  }

  Future<String> _sendTransaction({
    required String data,
    BigInt? gasLimit,
    BigInt? gasPrice,
  }) async {
    return walletManager!.sendTransaction(
      to: address,
      data: data,
      value: '0x0',
      gas: gasLimit != null ? '0x${gasLimit.toRadixString(16)}' : null,
      gasPrice: gasPrice != null ? '0x${gasPrice.toRadixString(16)}' : null,
    );
  }

  void _requireWallet() {
    if (walletManager == null || !walletManager!.isConnected) {
      throw WalletException.notConnected();
    }
  }

  void _validateAddress(String addr, String paramName) {
    if (!_isValidAddress(addr)) {
      throw ArgumentError('Invalid $paramName address: $addr');
    }
  }

  void _validateAmount(BigInt amount) {
    if (amount <= BigInt.zero) {
      throw ArgumentError('Amount must be positive');
    }
  }

  bool _isValidAddress(String addr) {
    if (!addr.startsWith('0x')) return false;
    if (addr.length != 42) return false;
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(addr);
  }

  /// Maximum uint256 value (for infinite approvals).
  static final maxUint256 = BigInt.parse(
    'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
    radix: 16,
  );
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Token metadata container.
class TokenMetadata {
  final String address;
  final String name;
  final String symbol;
  final int decimals;
  final BigInt totalSupply;

  const TokenMetadata({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.totalSupply,
  });

  @override
  String toString() => 'TokenMetadata($symbol: $name)';
}

/// ERC-20 Transfer event.
class TransferEvent {
  final String from;
  final String to;
  final BigInt value;
  final String transactionHash;
  final int blockNumber;
  final int logIndex;

  const TransferEvent({
    required this.from,
    required this.to,
    required this.value,
    required this.transactionHash,
    required this.blockNumber,
    required this.logIndex,
  });

  factory TransferEvent.fromLog(Map<String, dynamic> log) {
    final topics = log['topics'] as List;
    return TransferEvent(
      from: AbiCodec.decodeAddress(topics[1] as String),
      to: AbiCodec.decodeAddress(topics[2] as String),
      value: AbiCodec.decodeUint256(log['data'] as String),
      transactionHash: log['transactionHash'] as String,
      blockNumber: _parseHex(log['blockNumber']),
      logIndex: _parseHex(log['logIndex']),
    );
  }

  static int _parseHex(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.parse(value.replaceFirst('0x', ''), radix: 16);
    }
    return 0;
  }
}

/// ERC-20 Approval event.
class ApprovalEvent {
  final String owner;
  final String spender;
  final BigInt value;
  final String transactionHash;
  final int blockNumber;
  final int logIndex;

  const ApprovalEvent({
    required this.owner,
    required this.spender,
    required this.value,
    required this.transactionHash,
    required this.blockNumber,
    required this.logIndex,
  });

  factory ApprovalEvent.fromLog(Map<String, dynamic> log) {
    final topics = log['topics'] as List;
    return ApprovalEvent(
      owner: AbiCodec.decodeAddress(topics[1] as String),
      spender: AbiCodec.decodeAddress(topics[2] as String),
      value: AbiCodec.decodeUint256(log['data'] as String),
      transactionHash: log['transactionHash'] as String,
      blockNumber: _parseHex(log['blockNumber']),
      logIndex: _parseHex(log['logIndex']),
    );
  }

  static int _parseHex(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.parse(value.replaceFirst('0x', ''), radix: 16);
    }
    return 0;
  }
}
