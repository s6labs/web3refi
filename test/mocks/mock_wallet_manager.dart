import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:web3refi/web3refi.dart';
import '../test_utils.dart';

/// Mock wallet manager for testing without real wallet connections.
///
/// Simulates wallet connection, signing, and transaction sending.
///
/// Example:
/// ```dart
/// final mockWallet = MockWalletManager();
/// mockWallet.simulateConnected(address: '0x123...');
///
/// expect(mockWallet.isConnected, isTrue);
/// expect(mockWallet.address, equals('0x123...'));
///
/// // Simulate transaction
/// mockWallet.nextTransactionHash = '0xabc...';
/// final txHash = await mockWallet.sendTransaction(to: '0x456...');
/// expect(txHash, equals('0xabc...'));
/// ```
class MockWalletManager extends ChangeNotifier implements WalletManager {
  // ══════════════════════════════════════════════════════════════════════════
  // STATE
  // ══════════════════════════════════════════════════════════════════════════

  WalletConnectionState _state = WalletConnectionState.disconnected;
  String? _address;
  int? _chainId;
  String? _userId;
  String? _errorMessage;

  /// Tracks all method calls for verification.
  final List<MockWalletCall> _calls = [];

  /// Next transaction hash to return.
  String? nextTransactionHash;

  /// Next signature to return.
  String? nextSignature;

  /// Whether to simulate user rejection.
  bool simulateUserRejection = false;

  /// Whether to simulate timeout.
  bool simulateTimeout = false;

  /// Whether to simulate wallet not installed.
  bool simulateWalletNotInstalled = false;

  /// Delay before operations complete.
  Duration? operationDelay;

  /// Chains supported by this mock.
  final List<Chain> _chains;

  /// Default chain.
  final Chain _defaultChain;

  MockWalletManager({
    List<Chain>? chains,
    Chain? defaultChain,
  })  : _chains = chains ?? [TestChains.mockEthereum, TestChains.mockPolygon],
        _defaultChain = defaultChain ?? TestChains.mockEthereum;

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET MANAGER INTERFACE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  String get projectId => 'mock_project_id';

  @override
  AppMetadata? get appMetadata => null;

  @override
  List<Chain> get chains => _chains;

  @override
  Chain get defaultChain => _defaultChain;

  @override
  bool get enableLogging => false;

  @override
  WalletConnectionState get state => _state;

  @override
  bool get isConnected => _state == WalletConnectionState.connected && _address != null;

  @override
  String? get address => _address;

  @override
  int? get chainId => _chainId;

  @override
  String? get userId => _userId;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Chain? get currentChain {
    if (_chainId == null) return null;
    try {
      return _chains.firstWhere((c) => c.chainId == _chainId);
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MOCK CONTROL
  // ══════════════════════════════════════════════════════════════════════════

  /// Simulate a connected wallet.
  void simulateConnected({
    String address = TestAddresses.wallet1,
    int? chainId,
    String? userId,
  }) {
    _address = address;
    _chainId = chainId ?? _defaultChain.chainId;
    _userId = userId;
    _state = WalletConnectionState.connected;
    notifyListeners();
  }

  /// Simulate a disconnected state.
  void simulateDisconnected() {
    _address = null;
    _chainId = null;
    _userId = null;
    _state = WalletConnectionState.disconnected;
    notifyListeners();
  }

  /// Simulate an error state.
  void simulateError(String message) {
    _errorMessage = message;
    _state = WalletConnectionState.error;
    notifyListeners();
  }

  /// Reset all state and configuration.
  void reset() {
    _state = WalletConnectionState.disconnected;
    _address = null;
    _chainId = null;
    _userId = null;
    _errorMessage = null;
    _calls.clear();
    nextTransactionHash = null;
    nextSignature = null;
    simulateUserRejection = false;
    simulateTimeout = false;
    simulateWalletNotInstalled = false;
    operationDelay = null;
    notifyListeners();
  }

  /// Get all recorded calls.
  List<MockWalletCall> get calls => List.unmodifiable(_calls);

  /// Get calls for a specific method.
  List<MockWalletCall> callsFor(String method) {
    return _calls.where((c) => c.method == method).toList();
  }

  /// Check if method was called.
  bool wasCalled(String method) => callsFor(method).isNotEmpty;

  /// Get call count for method.
  int callCount(String method) => callsFor(method).length;

  // ══════════════════════════════════════════════════════════════════════════
  // WALLET MANAGER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Future<void> initialize() async {
    _recordCall('initialize', {});
    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }
  }

  @override
  Future<void> connect({Chain? preferredChain}) async {
    _recordCall('connect', {'preferredChain': preferredChain});

    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }

    if (simulateWalletNotInstalled) {
      throw WalletException.walletNotInstalled('MockWallet');
    }

    if (simulateUserRejection) {
      throw WalletException.userRejected();
    }

    if (simulateTimeout) {
      throw WalletException.connectionTimeout();
    }

    _state = WalletConnectionState.connecting;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 10));

    _address = TestAddresses.wallet1;
    _chainId = preferredChain?.chainId ?? _defaultChain.chainId;
    _state = WalletConnectionState.connected;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _recordCall('disconnect', {});

    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }

    _address = null;
    _chainId = null;
    _userId = null;
    _state = WalletConnectionState.disconnected;
    notifyListeners();
  }

  @override
  Future<void> switchChain(Chain chain) async {
    _recordCall('switchChain', {'chain': chain});

    if (!isConnected) {
      throw WalletException.notConnected();
    }

    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }

    if (simulateUserRejection) {
      throw WalletException.userRejected('User rejected chain switch');
    }

    if (!_chains.any((c) => c.chainId == chain.chainId)) {
      throw WalletException.chainNotSupported(chain.name);
    }

    _chainId = chain.chainId;
    notifyListeners();
  }

  @override
  Future<String> sendTransaction({
    required String to,
    String? value,
    String? data,
    String? gas,
    String? gasPrice,
  }) async {
    _recordCall('sendTransaction', {
      'to': to,
      'value': value,
      'data': data,
      'gas': gas,
      'gasPrice': gasPrice,
    });

    if (!isConnected) {
      throw WalletException.notConnected();
    }

    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }

    if (simulateUserRejection) {
      throw WalletException.userRejected('User rejected transaction');
    }

    // Return configured hash or generate one
    return nextTransactionHash ??
        '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(64, '0')}';
  }

  @override
  Future<String> signMessage(String message) async {
    _recordCall('signMessage', {'message': message});

    if (!isConnected) {
      throw WalletException.notConnected();
    }

    if (operationDelay != null) {
      await Future.delayed(operationDelay!);
    }

    if (simulateUserRejection) {
      throw WalletException.userRejected('User rejected signature');
    }

    // Return configured signature or generate one
    return nextSignature ??
        '0x${message.hashCode.abs().toRadixString(16).padLeft(130, '0')}';
  }

  @override
  Future<String> signTypedData(Map<String, dynamic> typedData) async {
    _recordCall('signTypedData', {'typedData': typedData});

    if (!isConnected) {
      throw WalletException.notConnected();
    }

    if (simulateUserRejection) {
      throw WalletException.userRejected('User rejected typed data signature');
    }

    return nextSignature ??
        '0x${typedData.hashCode.abs().toRadixString(16).padLeft(130, '0')}';
  }

  @override
  Future<void> saveSession() async {
    _recordCall('saveSession', {});
  }

  @override
  Future<bool> restoreSession() async {
    _recordCall('restoreSession', {});
    return false;
  }

  @override
  Future<void> clearSession() async {
    _recordCall('clearSession', {});
  }

  @override
  Future<void> addWallet({
    required String walletId,
    required BlockchainType chainType,
  }) async {
    _recordCall('addWallet', {'walletId': walletId, 'chainType': chainType});
  }

  @override
  Future<List<LinkedWallet>> getLinkedWallets() async {
    _recordCall('getLinkedWallets', {});
    return [];
  }

  @override
  Future<bool> launchWallet(String deepLink) async {
    _recordCall('launchWallet', {'deepLink': deepLink});
    return true;
  }

  @override
  Future<void> dispose() async {
    _recordCall('dispose', {});
  }

  void _recordCall(String method, Map<String, dynamic> params) {
    _calls.add(MockWalletCall(
      method: method,
      params: params,
      timestamp: DateTime.now(),
    ));
  }
}

/// Record of a wallet manager call.
class MockWalletCall {
  final String method;
  final Map<String, dynamic> params;
  final DateTime timestamp;

  MockWalletCall({
    required this.method,
    required this.params,
    required this.timestamp,
  });

  @override
  String toString() => 'MockWalletCall($method, $params)';
}
