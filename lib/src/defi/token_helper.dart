import 'dart:async';
import '../core/rpc_client.dart';
import '../wallet/wallet_manager.dart';
import '../models/chain.dart';
import '../constants/tokens.dart';
import '../exceptions/web3_exception.dart';
import 'erc20.dart';

/// High-level helper for common token operations.
///
/// Provides convenient methods for working with multiple tokens,
/// portfolio management, and batch operations.
///
/// ## Basic Usage
///
/// ```dart
/// final tokens = Web3Refi.instance.tokens;
///
/// // Get portfolio summary
/// final portfolio = await tokens.getPortfolio(myAddress);
/// for (final holding in portfolio) {
///   print('${holding.symbol}: ${holding.formattedBalance}');
/// }
///
/// // Quick balance check
/// final usdcBalance = await tokens.balanceOf(
///   Tokens.usdcPolygon,
///   myAddress,
/// );
/// ```
class TokenHelper {
  // ══════════════════════════════════════════════════════════════════════════
  // PROPERTIES
  // ══════════════════════════════════════════════════════════════════════════

  /// RPC client for blockchain calls.
  final RpcClient rpcClient;

  /// Wallet manager for signing transactions.
  final WalletManager walletManager;

  /// Cache of ERC20 instances.
  final Map<String, ERC20> _tokenCache = {};

  /// Cache of token metadata.
  final Map<String, TokenMetadata> _metadataCache = {};

  // ══════════════════════════════════════════════════════════════════════════
  // CONSTRUCTOR
  // ══════════════════════════════════════════════════════════════════════════

  TokenHelper({
    required this.rpcClient,
    required this.walletManager,
  });

  // ══════════════════════════════════════════════════════════════════════════
  // TOKEN INSTANCE MANAGEMENT
  // ══════════════════════════════════════════════════════════════════════════

  /// Get or create an ERC20 instance for a token address.
  ///
  /// Instances are cached for efficiency.
  ERC20 token(String address) {
    final normalizedAddress = address.toLowerCase();

    return _tokenCache.putIfAbsent(
      normalizedAddress,
      () => ERC20(
        address: address,
        rpcClient: rpcClient,
        walletManager: walletManager,
      ),
    );
  }

  /// Get ERC20 instance by token symbol.
  ///
  /// Only works for known tokens in [Tokens] constants.
  ///
  /// ```dart
  /// final usdc = tokens.bySymbol('USDC', chainId: 137);
  /// ```
  ERC20? bySymbol(String symbol, {required int chainId}) {
    final address = Tokens.addressBySymbol(symbol, chainId: chainId);
    if (address == null) return null;
    return token(address);
  }

  /// Clear the token cache.
  void clearCache() {
    _tokenCache.clear();
    _metadataCache.clear();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUICK BALANCE OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get token balance for an address.
  ///
  /// Shorthand for `token(address).balanceOf(owner)`.
  Future<BigInt> balanceOf(String tokenAddress, String owner) async {
    return token(tokenAddress).balanceOf(owner);
  }

  /// Get formatted token balance.
  Future<String> formattedBalanceOf(String tokenAddress, String owner) async {
    final t = token(tokenAddress);
    final balance = await t.balanceOf(owner);
    return t.formatAmount(balance);
  }

  /// Get balance with symbol (e.g., "1,234.56 USDC").
  Future<String> balanceWithSymbol(String tokenAddress, String owner) async {
    final t = token(tokenAddress);
    final balance = await t.balanceOf(owner);
    return t.formatWithSymbol(balance);
  }

  /// Get connected wallet's token balance.
  Future<BigInt> myBalanceOf(String tokenAddress) async {
    _requireConnected();
    return balanceOf(tokenAddress, walletManager.address!);
  }

  /// Get connected wallet's formatted balance.
  Future<String> myFormattedBalanceOf(String tokenAddress) async {
    _requireConnected();
    return formattedBalanceOf(tokenAddress, walletManager.address!);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-TOKEN OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get balances for multiple tokens at once.
  ///
  /// Returns a map of token address to balance.
  ///
  /// ```dart
  /// final balances = await tokens.getBalances(
  ///   owner: myAddress,
  ///   tokenAddresses: [Tokens.usdcPolygon, Tokens.wmaticPolygon],
  /// );
  /// ```
  Future<Map<String, BigInt>> getBalances({
    required String owner,
    required List<String> tokenAddresses,
  }) async {
    final futures = tokenAddresses.map((addr) => balanceOf(addr, owner));
    final balances = await Future.wait(futures);

    return Map.fromIterables(tokenAddresses, balances);
  }

  /// Get formatted balances for multiple tokens.
  Future<Map<String, String>> getFormattedBalances({
    required String owner,
    required List<String> tokenAddresses,
  }) async {
    final futures = tokenAddresses.map((addr) => formattedBalanceOf(addr, owner));
    final balances = await Future.wait(futures);

    return Map.fromIterables(tokenAddresses, balances);
  }

  /// Get metadata for multiple tokens.
  Future<List<TokenMetadata>> getMetadataMultiple(
    List<String> tokenAddresses,
  ) async {
    final futures = tokenAddresses.map((addr) async {
      // Check cache first
      if (_metadataCache.containsKey(addr.toLowerCase())) {
        return _metadataCache[addr.toLowerCase()]!;
      }

      final metadata = await token(addr).getMetadata();
      _metadataCache[addr.toLowerCase()] = metadata;
      return metadata;
    });

    return Future.wait(futures);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PORTFOLIO
  // ══════════════════════════════════════════════════════════════════════════

  /// Get complete portfolio for an address.
  ///
  /// Returns holdings for all specified tokens with metadata.
  ///
  /// ```dart
  /// final portfolio = await tokens.getPortfolio(
  ///   owner: myAddress,
  ///   tokenAddresses: [
  ///     Tokens.usdcPolygon,
  ///     Tokens.usdtPolygon,
  ///     Tokens.wmaticPolygon,
  ///   ],
  /// );
  ///
  /// for (final holding in portfolio) {
  ///   print('${holding.symbol}: ${holding.formattedBalance}');
  /// }
  /// ```
  Future<List<TokenHolding>> getPortfolio({
    required String owner,
    required List<String> tokenAddresses,
    bool excludeZeroBalances = false,
  }) async {
    final holdings = <TokenHolding>[];

    // Fetch all data in parallel
    final balanceFutures = tokenAddresses.map((addr) => balanceOf(addr, owner));
    final metadataFutures = tokenAddresses.map((addr) => token(addr).getMetadata());

    final balances = await Future.wait(balanceFutures);
    final metadataList = await Future.wait(metadataFutures);

    for (var i = 0; i < tokenAddresses.length; i++) {
      final balance = balances[i];
      final metadata = metadataList[i];

      if (excludeZeroBalances && balance == BigInt.zero) {
        continue;
      }

      final formatted = await token(tokenAddresses[i]).formatAmount(balance);

      holdings.add(TokenHolding(
        tokenAddress: tokenAddresses[i],
        name: metadata.name,
        symbol: metadata.symbol,
        decimals: metadata.decimals,
        balance: balance,
        formattedBalance: formatted,
      ));
    }

    return holdings;
  }

  /// Get portfolio for connected wallet.
  Future<List<TokenHolding>> getMyPortfolio({
    required List<String> tokenAddresses,
    bool excludeZeroBalances = true,
  }) async {
    _requireConnected();
    return getPortfolio(
      owner: walletManager.address!,
      tokenAddresses: tokenAddresses,
      excludeZeroBalances: excludeZeroBalances,
    );
  }

  /// Get portfolio for common tokens on current chain.
  ///
  /// Automatically uses the appropriate token list for the chain.
  Future<List<TokenHolding>> getCommonTokenPortfolio({
    required String owner,
    required int chainId,
    bool excludeZeroBalances = true,
  }) async {
    final commonTokens = Tokens.commonForChain(chainId);
    return getPortfolio(
      owner: owner,
      tokenAddresses: commonTokens,
      excludeZeroBalances: excludeZeroBalances,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUICK TRANSFERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Transfer tokens with human-readable amount.
  ///
  /// ```dart
  /// await tokens.transfer(
  ///   tokenAddress: Tokens.usdcPolygon,
  ///   to: recipientAddress,
  ///   amount: '100.00',
  /// );
  /// ```
  Future<String> transfer({
    required String tokenAddress,
    required String to,
    required String amount,
  }) async {
    _requireConnected();
    return token(tokenAddress).transferFormatted(to: to, amount: amount);
  }

  /// Transfer exact raw amount.
  Future<String> transferExact({
    required String tokenAddress,
    required String to,
    required BigInt amount,
  }) async {
    _requireConnected();
    return token(tokenAddress).transfer(to: to, amount: amount);
  }

  /// Transfer all tokens (entire balance) to recipient.
  ///
  /// Useful for sweeping tokens to another wallet.
  Future<String> transferAll({
    required String tokenAddress,
    required String to,
  }) async {
    _requireConnected();
    final balance = await myBalanceOf(tokenAddress);

    if (balance == BigInt.zero) {
      throw TransactionException(
        message: 'No tokens to transfer',
        code: 'zero_balance',
      );
    }

    return token(tokenAddress).transfer(to: to, amount: balance);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APPROVAL HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if approval is needed for a token.
  Future<bool> needsApproval({
    required String tokenAddress,
    required String spender,
    required BigInt amount,
  }) async {
    _requireConnected();
    final t = token(tokenAddress);
    final allowance = await t.allowance(walletManager.address!, spender);
    return allowance < amount;
  }

  /// Ensure approval for multiple tokens.
  ///
  /// Returns list of approval transaction hashes (empty if all approved).
  ///
  /// ```dart
  /// final approvalTxs = await tokens.ensureApprovals(
  ///   spender: dexRouter,
  ///   tokens: {
  ///     Tokens.usdcPolygon: usdcAmount,
  ///     Tokens.wmaticPolygon: maticAmount,
  ///   },
  /// );
  ///
  /// // Wait for all approvals
  /// for (final tx in approvalTxs) {
  ///   await Web3Refi.instance.waitForTransaction(tx);
  /// }
  /// ```
  Future<List<String>> ensureApprovals({
    required String spender,
    required Map<String, BigInt> tokens,
    bool useInfinite = false,
  }) async {
    _requireConnected();
    final txHashes = <String>[];

    for (final entry in tokens.entries) {
      final txHash = await token(entry.key).ensureApproval(
        spender: spender,
        amount: entry.value,
        useInfinite: useInfinite,
      );

      if (txHash != null) {
        txHashes.add(txHash);
      }
    }

    return txHashes;
  }

  /// Get all active approvals for a token.
  ///
  /// Useful for reviewing and revoking approvals.
  Future<List<ActiveApproval>> getActiveApprovals({
    required String tokenAddress,
    required List<String> spenders,
  }) async {
    _requireConnected();
    final t = token(tokenAddress);
    final approvals = <ActiveApproval>[];

    for (final spender in spenders) {
      final allowance = await t.allowance(walletManager.address!, spender);
      if (allowance > BigInt.zero) {
        approvals.add(ActiveApproval(
          tokenAddress: tokenAddress,
          spender: spender,
          allowance: allowance,
          formattedAllowance: await t.formatAmount(allowance),
        ));
      }
    }

    return approvals;
  }

  /// Revoke all approvals for specified spenders.
  Future<List<String>> revokeApprovals({
    required String tokenAddress,
    required List<String> spenders,
  }) async {
    _requireConnected();
    final t = token(tokenAddress);
    final txHashes = <String>[];

    for (final spender in spenders) {
      final allowance = await t.allowance(walletManager.address!, spender);
      if (allowance > BigInt.zero) {
        final txHash = await t.revokeApproval(spender);
        txHashes.add(txHash);
      }
    }

    return txHashes;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TOKEN DISCOVERY
  // ══════════════════════════════════════════════════════════════════════════

  /// Check if an address is a valid ERC20 token.
  ///
  /// Attempts to call standard ERC20 methods.
  Future<bool> isValidToken(String address) async {
    try {
      final t = token(address);
      await Future.wait([
        t.symbol(),
        t.decimals(),
        t.totalSupply(),
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get token metadata if valid, null otherwise.
  Future<TokenMetadata?> getTokenMetadataSafe(String address) async {
    try {
      return await token(address).getMetadata();
    } catch (e) {
      return null;
    }
  }

  /// Discover tokens with non-zero balance.
  ///
  /// Checks a list of potential tokens and returns those with balance > 0.
  Future<List<String>> discoverTokensWithBalance({
    required String owner,
    required List<String> potentialTokens,
  }) async {
    final tokensWithBalance = <String>[];

    final balances = await getBalances(
      owner: owner,
      tokenAddresses: potentialTokens,
    );

    for (final entry in balances.entries) {
      if (entry.value > BigInt.zero) {
        tokensWithBalance.add(entry.key);
      }
    }

    return tokensWithBalance;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BALANCE WATCHING
  // ══════════════════════════════════════════════════════════════════════════

  /// Watch balances for multiple tokens.
  ///
  /// Emits a map of all token balances whenever any changes.
  Stream<Map<String, BigInt>> watchBalances({
    required String owner,
    required List<String> tokenAddresses,
    Duration interval = const Duration(seconds: 10),
  }) async* {
    Map<String, BigInt>? lastBalances;

    while (true) {
      try {
        final balances = await getBalances(
          owner: owner,
          tokenAddresses: tokenAddresses,
        );

        // Only emit if changed
        if (lastBalances == null || !_mapsEqual(lastBalances, balances)) {
          lastBalances = balances;
          yield balances;
        }
      } catch (e) {
        // Ignore errors, continue watching
      }

      await Future.delayed(interval);
    }
  }

  /// Watch portfolio for changes.
  Stream<List<TokenHolding>> watchPortfolio({
    required String owner,
    required List<String> tokenAddresses,
    Duration interval = const Duration(seconds: 10),
    bool excludeZeroBalances = true,
  }) async* {
    await for (final _ in watchBalances(
      owner: owner,
      tokenAddresses: tokenAddresses,
      interval: interval,
    )) {
      yield await getPortfolio(
        owner: owner,
        tokenAddresses: tokenAddresses,
        excludeZeroBalances: excludeZeroBalances,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════════════════

  /// Parse amount for any token.
  Future<BigInt> parseAmount(String tokenAddress, String amount) async {
    return token(tokenAddress).parseAmount(amount);
  }

  /// Format amount for any token.
  Future<String> formatAmount(String tokenAddress, BigInt amount) async {
    return token(tokenAddress).formatAmount(amount);
  }

  /// Get decimals for any token.
  Future<int> getDecimals(String tokenAddress) async {
    return token(tokenAddress).decimals();
  }

  /// Get symbol for any token.
  Future<String> getSymbol(String tokenAddress) async {
    return token(tokenAddress).symbol();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  void _requireConnected() {
    if (!walletManager.isConnected) {
      throw WalletException.notConnected();
    }
  }

  bool _mapsEqual(Map<String, BigInt> a, Map<String, BigInt> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// SUPPORTING CLASSES
// ════════════════════════════════════════════════════════════════════════════

/// Represents a token holding in a portfolio.
class TokenHolding {
  final String tokenAddress;
  final String name;
  final String symbol;
  final int decimals;
  final BigInt balance;
  final String formattedBalance;

  const TokenHolding({
    required this.tokenAddress,
    required this.name,
    required this.symbol,
    required this.decimals,
    required this.balance,
    required this.formattedBalance,
  });

  /// Whether this holding has zero balance.
  bool get isZero => balance == BigInt.zero;

  /// Display string (e.g., "1,234.56 USDC").
  String get displayString => '$formattedBalance $symbol';

  @override
  String toString() => 'TokenHolding($symbol: $formattedBalance)';

  Map<String, dynamic> toJson() => {
        'tokenAddress': tokenAddress,
        'name': name,
        'symbol': symbol,
        'decimals': decimals,
        'balance': balance.toString(),
        'formattedBalance': formattedBalance,
      };
}

/// Represents an active token approval.
class ActiveApproval {
  final String tokenAddress;
  final String spender;
  final BigInt allowance;
  final String formattedAllowance;

  const ActiveApproval({
    required this.tokenAddress,
    required this.spender,
    required this.allowance,
    required this.formattedAllowance,
  });

  /// Whether this is an infinite approval.
  bool get isInfinite => allowance >= ERC20.maxUint256 ~/ BigInt.two;

  @override
  String toString() => 'ActiveApproval($spender: $formattedAllowance)';
}
