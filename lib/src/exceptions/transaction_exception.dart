import 'web3_exception.dart';

/// Exception for transaction-related errors.
///
/// Covers all stages of transaction lifecycle:
/// - Building/preparing transactions
/// - Signing transactions
/// - Broadcasting transactions
/// - Confirmation/mining
/// - Receipt processing
///
/// Example:
/// ```dart
/// try {
///   await token.transfer(to: recipient, amount: amount);
/// } on TransactionException catch (e) {
///   switch (e.code) {
///     case 'insufficient_balance':
///       showError('Not enough tokens');
///       break;
///     case 'insufficient_gas':
///       showError('Need more ${chain.symbol} for fees');
///       break;
///     case 'user_rejected':
///       // User cancelled, do nothing
///       break;
///     default:
///       showError(e.toUserMessage());
///   }
/// }
/// ```
class TransactionException extends Web3Exception {
  /// Transaction hash, if available.
  final String? txHash;

  /// Block number where transaction was included.
  final int? blockNumber;

  /// Gas used by the transaction.
  final BigInt? gasUsed;

  /// Gas limit that was set.
  final BigInt? gasLimit;

  /// Nonce of the transaction.
  final int? nonce;

  /// Recipient address.
  final String? to;

  /// Value being transferred.
  final BigInt? value;

  /// The stage where the error occurred.
  final TransactionStage? stage;

  const TransactionException({
    required super.message,
    required super.code,
    super.severity,
    super.cause,
    super.stackTrace,
    super.context,
    this.txHash,
    this.blockNumber,
    this.gasUsed,
    this.gasLimit,
    this.nonce,
    this.to,
    this.value,
    this.stage,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCE ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Insufficient token balance for transfer.
  factory TransactionException.insufficientBalance({
    required String required,
    required String available,
    String? symbol,
    String? tokenAddress,
  }) {
    final sym = symbol ?? 'tokens';
    return TransactionException(
      message: 'Insufficient balance. Need $required $sym but only have $available $sym.',
      code: 'insufficient_balance',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      context: {
        'required': required,
        'available': available,
        if (symbol != null) 'symbol': symbol,
        if (tokenAddress != null) 'tokenAddress': tokenAddress,
      },
    );
  }

  /// Insufficient native currency for gas fees.
  factory TransactionException.insufficientGas({
    required String required,
    required String available,
    String? symbol,
    BigInt? gasPrice,
    BigInt? gasLimit,
  }) {
    final sym = symbol ?? 'native currency';
    return TransactionException(
      message: 'Insufficient $sym for transaction fees. Need $required but only have $available.',
      code: 'insufficient_gas',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      gasLimit: gasLimit,
      context: {
        'required': required,
        'available': available,
        if (symbol != null) 'symbol': symbol,
        if (gasPrice != null) 'gasPrice': gasPrice.toString(),
      },
    );
  }

  /// Insufficient allowance for transferFrom.
  factory TransactionException.insufficientAllowance({
    required String spender,
    required String required,
    required String current,
    String? symbol,
  }) {
    return TransactionException(
      message: 'Insufficient allowance. $spender needs $required $symbol but only approved for $current.',
      code: 'insufficient_allowance',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      context: {
        'spender': spender,
        'required': required,
        'current': current,
        if (symbol != null) 'symbol': symbol,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // VALIDATION ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Invalid recipient address.
  factory TransactionException.invalidAddress(String address, {String? reason}) {
    return TransactionException(
      message: reason ?? 'Invalid address: $address',
      code: 'invalid_address',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      to: address,
      context: {
        'address': address,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Invalid transaction amount.
  factory TransactionException.invalidAmount(String amount, {String? reason}) {
    return TransactionException(
      message: reason ?? 'Invalid amount: $amount',
      code: 'invalid_amount',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      context: {
        'amount': amount,
        if (reason != null) 'reason': reason,
      },
    );
  }

  /// Amount exceeds maximum allowed.
  factory TransactionException.amountTooLarge({
    required String amount,
    required String maximum,
    String? symbol,
  }) {
    return TransactionException(
      message: 'Amount $amount exceeds maximum $maximum ${symbol ?? ''}',
      code: 'amount_too_large',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      context: {
        'amount': amount,
        'maximum': maximum,
        if (symbol != null) 'symbol': symbol,
      },
    );
  }

  /// Amount is below minimum required.
  factory TransactionException.amountTooSmall({
    required String amount,
    required String minimum,
    String? symbol,
  }) {
    return TransactionException(
      message: 'Amount $amount is below minimum $minimum ${symbol ?? ''}',
      code: 'amount_too_small',
      severity: ErrorSeverity.error,
      stage: TransactionStage.validation,
      context: {
        'amount': amount,
        'minimum': minimum,
        if (symbol != null) 'symbol': symbol,
      },
    );
  }

  /// Cannot send to same address.
  factory TransactionException.selfTransfer(String address) {
    return TransactionException(
      message: 'Cannot transfer to the same address',
      code: 'self_transfer',
      severity: ErrorSeverity.warning,
      stage: TransactionStage.validation,
      to: address,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // GAS ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Gas estimation failed.
  factory TransactionException.gasEstimationFailed({
    String? reason,
    Object? cause,
  }) {
    return TransactionException(
      message: reason ?? 'Failed to estimate gas for transaction',
      code: 'gas_estimation_failed',
      severity: ErrorSeverity.error,
      stage: TransactionStage.preparation,
      cause: cause,
    );
  }

  /// Gas price too low for network conditions.
  factory TransactionException.gasPriceTooLow({
    String? suggestedPrice,
    String? currentPrice,
  }) {
    return TransactionException(
      message: 'Gas price too low. Transaction may not be processed.',
      code: 'gas_price_too_low',
      severity: ErrorSeverity.warning,
      stage: TransactionStage.preparation,
      context: {
        if (suggestedPrice != null) 'suggested': suggestedPrice,
        if (currentPrice != null) 'current': currentPrice,
      },
    );
  }

  /// Gas limit too low for transaction.
  factory TransactionException.gasLimitTooLow({
    BigInt? provided,
    BigInt? required,
  }) {
    return TransactionException(
      message: 'Gas limit too low. Transaction will fail.',
      code: 'gas_limit_too_low',
      severity: ErrorSeverity.error,
      stage: TransactionStage.preparation,
      gasLimit: provided,
      context: {
        if (provided != null) 'provided': provided.toString(),
        if (required != null) 'required': required.toString(),
      },
    );
  }

  /// Transaction would exceed block gas limit.
  factory TransactionException.exceedsBlockGasLimit({
    BigInt? txGas,
    BigInt? blockLimit,
  }) {
    return TransactionException(
      message: 'Transaction gas exceeds block gas limit',
      code: 'exceeds_block_gas_limit',
      severity: ErrorSeverity.error,
      stage: TransactionStage.preparation,
      gasLimit: txGas,
      context: {
        if (txGas != null) 'transactionGas': txGas.toString(),
        if (blockLimit != null) 'blockLimit': blockLimit.toString(),
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NONCE ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// Nonce too low (transaction already processed or pending with same nonce).
  factory TransactionException.nonceTooLow({
    int? provided,
    int? expected,
  }) {
    return TransactionException(
      message: 'Nonce too low. A transaction with this nonce was already processed.',
      code: 'nonce_too_low',
      severity: ErrorSeverity.error,
      stage: TransactionStage.broadcast,
      nonce: provided,
      context: {
        if (provided != null) 'provided': provided,
        if (expected != null) 'expected': expected,
      },
    );
  }

  /// Nonce too high (gap in nonce sequence).
  factory TransactionException.nonceTooHigh({
    int? provided,
    int? expected,
  }) {
    return TransactionException(
      message: 'Nonce too high. There is a gap in the transaction sequence.',
      code: 'nonce_too_high',
      severity: ErrorSeverity.error,
      stage: TransactionStage.broadcast,
      nonce: provided,
      context: {
        if (provided != null) 'provided': provided,
        if (expected != null) 'expected': expected,
      },
    );
  }

  /// Replacement transaction (same nonce) underpriced.
  factory TransactionException.replacementUnderpriced({
    String? existingGasPrice,
    String? newGasPrice,
    int? nonce,
  }) {
    return TransactionException(
      message: 'Replacement transaction underpriced. Increase gas price by at least 10%.',
      code: 'replacement_underpriced',
      severity: ErrorSeverity.error,
      stage: TransactionStage.broadcast,
      nonce: nonce,
      context: {
        if (existingGasPrice != null) 'existing': existingGasPrice,
        if (newGasPrice != null) 'new': newGasPrice,
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SIGNING ERRORS
  // ══════════════════════════════════════════════════════════════════════════

  /// User rejected the transaction in wallet.
  factory TransactionException.userRejected() {
    return const TransactionException(
      message: 'Transaction rejected by user',
      code: 'user_rejected',
      severity: ErrorSeverity.warning,
      stage: TransactionStage.signing,
    );
  }

  /// Transaction signing failed.
  factory TransactionException.signingFailed({String? reason, Object? cause}) {
    return TransactionException(
      message: reason ?? 'Faile
