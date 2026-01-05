import 'package:equatable/equatable.dart';
import '../models/chain.dart';
import '../constants/chains.dart';

/// Configuration for initializing the Web3Refi SDK.
///
/// Example:
/// ```dart
/// final config = Web3RefiConfig(
///   projectId: 'YOUR_WALLETCONNECT_PROJECT_ID',
///   chains: [Chains.ethereum, Chains.polygon],
///   defaultChain: Chains.polygon,
/// );
/// ```
class Web3RefiConfig extends Equatable {
  /// WalletConnect Cloud Project ID.
  ///
  /// Get yours at https://cloud.walletconnect.com
  final String projectId;

  /// List of supported blockchain networks.
  ///
  /// At least one chain must be provided.
  final List<Chain> chains;

  /// The default chain to use when connecting.
  ///
  /// Must be included in [chains]. Defaults to first chain if not specified.
  final Chain defaultChain;

  /// Optional app metadata for WalletConnect.
  final AppMetadata? appMetadata;

  /// Enable debug logging.
  final bool enableLogging;

  /// RPC request timeout duration.
  final Duration rpcTimeout;

  /// Number of block confirmations to wait for transactions.
  final int defaultConfirmations;

  /// Enable automatic session restoration on app restart.
  final bool autoRestoreSession;

  /// XMTP environment ('production' or 'dev').
  final String xmtpEnvironment;

  /// Enable Mailchain integration.
  final bool enableMailchain;

  const Web3RefiConfig({
    required this.projectId,
    required this.chains,
    Chain? defaultChain,
    this.appMetadata,
    this.enableLogging = false,
    this.rpcTimeout = const Duration(seconds: 30),
    this.defaultConfirmations = 1,
    this.autoRestoreSession = true,
    this.xmtpEnvironment = 'production',
    this.enableMailchain = true,
  })  : defaultChain = defaultChain ?? (chains.isNotEmpty ? chains.first : Chains.ethereum),
        assert(chains.length > 0, 'At least one chain must be provided');

  /// Creates a config for development/testing with sensible defaults.
  factory Web3RefiConfig.development({
    required String projectId,
  }) {
    return Web3RefiConfig(
      projectId: projectId,
      chains: [Chains.polygonMumbai, Chains.goerli],
      defaultChain: Chains.polygonMumbai,
      enableLogging: true,
      xmtpEnvironment: 'dev',
    );
  }

  /// Creates a config for production with mainnet chains.
  factory Web3RefiConfig.production({
    required String projectId,
    List<Chain>? chains,
    Chain? defaultChain,
    AppMetadata? appMetadata,
  }) {
    final productionChains = chains ?? [Chains.ethereum, Chains.polygon];
    return Web3RefiConfig(
      projectId: projectId,
      chains: productionChains,
      defaultChain: defaultChain ?? productionChains.first,
      appMetadata: appMetadata,
      enableLogging: false,
    );
  }

  @override
  List<Object?> get props => [
        projectId,
        chains,
        defaultChain,
        appMetadata,
        enableLogging,
        rpcTimeout,
        defaultConfirmations,
        autoRestoreSession,
        xmtpEnvironment,
        enableMailchain,
      ];

  Web3RefiConfig copyWith({
    String? projectId,
    List<Chain>? chains,
    Chain? defaultChain,
    AppMetadata? appMetadata,
    bool? enableLogging,
    Duration? rpcTimeout,
    int? defaultConfirmations,
    bool? autoRestoreSession,
    String? xmtpEnvironment,
    bool? enableMailchain,
  }) {
    return Web3RefiConfig(
      projectId: projectId ?? this.projectId,
      chains: chains ?? this.chains,
      defaultChain: defaultChain ?? this.defaultChain,
      appMetadata: appMetadata ?? this.appMetadata,
      enableLogging: enableLogging ?? this.enableLogging,
      rpcTimeout: rpcTimeout ?? this.rpcTimeout,
      defaultConfirmations: defaultConfirmations ?? this.defaultConfirmations,
      autoRestoreSession: autoRestoreSession ?? this.autoRestoreSession,
      xmtpEnvironment: xmtpEnvironment ?? this.xmtpEnvironment,
      enableMailchain: enableMailchain ?? this.enableMailchain,
    );
  }
}

/// Metadata about the application using Web3Refi.
///
/// Used in WalletConnect for displaying app info in wallet apps.
class AppMetadata extends Equatable {
  /// Application name (e.g., "My DeFi App").
  final String name;

  /// Application description.
  final String description;

  /// Application URL (e.g., "https://mydefiapp.com").
  final String url;

  /// Application icon URLs (recommended: 96x96 PNG).
  final List<String> icons;

  /// Deep link redirect URL (e.g., "mydefiapp://").
  final String? redirect;

  const AppMetadata({
    required this.name,
    required this.description,
    required this.url,
    required this.icons,
    this.redirect,
  });

  @override
  List<Object?> get props => [name, description, url, icons, redirect];

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'url': url,
        'icons': icons,
        if (redirect != null) 'redirect': redirect,
      };
}
