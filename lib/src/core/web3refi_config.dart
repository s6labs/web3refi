import 'package:equatable/equatable.dart';
import 'package:web3refi/src/core/chain.dart';
import 'package:web3refi/src/core/feature_access.dart';

/// Configuration for initializing the Web3Refi SDK.
///
/// The SDK supports two tiers:
///
/// ## Free Tier (Standalone)
/// Core blockchain functionality without third-party dependencies:
/// - RPC operations, transactions, token operations
/// - Basic ENS resolution
/// - HD wallet generation
/// - Cryptographic operations
///
/// ## Premium Tier (with CIFI ID)
/// Full feature set including:
/// - XMTP & Mailchain messaging
/// - Universal Name Service (all resolvers)
/// - Invoice management
/// - CiFi identity & authentication
///
/// Example (Free Tier):
/// ```dart
/// final config = Web3RefiConfig(
///   chains: [Chains.ethereum, Chains.polygon],
/// );
/// ```
///
/// Example (Premium Tier):
/// ```dart
/// final config = Web3RefiConfig(
///   chains: [Chains.ethereum, Chains.polygon],
///   cifiApiKey: 'YOUR_CIFI_API_KEY',
///   cifiApiSecret: 'YOUR_CIFI_API_SECRET',
///   projectId: 'YOUR_WALLETCONNECT_PROJECT_ID', // Optional for WalletConnect
/// );
/// ```
class Web3RefiConfig extends Equatable {
  /// WalletConnect/Reown Cloud Project ID.
  ///
  /// Optional - only required if using WalletConnect for wallet connections.
  /// Get yours at https://cloud.walletconnect.com
  ///
  /// If not provided, the SDK will use direct wallet integration
  /// (private key signing, injected providers, etc.)
  final String? projectId;

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

  // ═══════════════════════════════════════════════════════════════════════════
  // CIFI ID CONFIGURATION (Premium Features)
  // ═══════════════════════════════════════════════════════════════════════════

  /// CiFi API key for premium features.
  ///
  /// Required for: Messaging, UNS, Invoice, CiFi Identity.
  /// Get yours at https://cifi.network
  final String? cifiApiKey;

  /// CiFi API secret for premium features.
  ///
  /// Required along with [cifiApiKey] for premium feature access.
  final String? cifiApiSecret;

  // ═══════════════════════════════════════════════════════════════════════════
  // UNIVERSAL NAME SERVICE CONFIGURATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enable CiFi names as fallback (@username, .cifi).
  /// Requires premium access (CIFI API key + secret).
  final bool? enableCiFiNames;

  /// Enable Unstoppable Domains (.crypto, .nft, etc.).
  final bool? enableUnstoppableDomains;

  /// Enable Space ID (.bnb, .arb).
  final bool? enableSpaceId;

  /// Enable Solana Name Service (.sol).
  final bool? enableSolanaNameService;

  /// Enable Sui Name Service (.sui).
  final bool? enableSuiNameService;

  /// Name resolution cache size.
  final int? namesCacheSize;

  /// Name resolution cache TTL.
  final Duration? namesCacheTtl;

  Web3RefiConfig({
    required this.chains,
    this.projectId,
    Chain? defaultChain,
    this.appMetadata,
    this.enableLogging = false,
    this.rpcTimeout = const Duration(seconds: 30),
    this.defaultConfirmations = 1,
    this.autoRestoreSession = true,
    this.xmtpEnvironment = 'production',
    this.enableMailchain = true,
    // CIFI ID configuration
    this.cifiApiKey,
    this.cifiApiSecret,
    // UNS configuration
    this.enableCiFiNames,
    this.enableUnstoppableDomains,
    this.enableSpaceId,
    this.enableSolanaNameService,
    this.enableSuiNameService,
    this.namesCacheSize,
    this.namesCacheTtl,
  })  : defaultChain = defaultChain ?? (chains.isNotEmpty ? chains.first : Chains.ethereum),
        assert(chains.isNotEmpty, 'At least one chain must be provided');

  /// Whether premium features are available (CIFI ID configured).
  bool get hasPremiumAccess =>
      cifiApiKey != null &&
      cifiApiKey!.isNotEmpty &&
      cifiApiSecret != null &&
      cifiApiSecret!.isNotEmpty;

  /// Whether WalletConnect is configured.
  bool get hasWalletConnect => projectId != null && projectId!.isNotEmpty;

  /// Get the feature access manager for this configuration.
  FeatureAccessManager get featureAccess => FeatureAccessManager(
        cifiApiKey: cifiApiKey,
        cifiApiSecret: cifiApiSecret,
      );

  /// Creates a config for development/testing with sensible defaults.
  ///
  /// This is a free tier config - no CIFI ID required.
  factory Web3RefiConfig.development({
    String? projectId,
    String? cifiApiKey,
    String? cifiApiSecret,
  }) {
    return Web3RefiConfig(
      chains: [Chains.polygonMumbai, Chains.sepolia],
      projectId: projectId,
      defaultChain: Chains.polygonMumbai,
      enableLogging: true,
      xmtpEnvironment: 'dev',
      cifiApiKey: cifiApiKey,
      cifiApiSecret: cifiApiSecret,
    );
  }

  /// Creates a config for production with mainnet chains.
  factory Web3RefiConfig.production({
    required List<Chain> chains,
    String? projectId,
    Chain? defaultChain,
    AppMetadata? appMetadata,
    String? cifiApiKey,
    String? cifiApiSecret,
  }) {
    return Web3RefiConfig(
      chains: chains,
      projectId: projectId,
      defaultChain: defaultChain ?? chains.first,
      appMetadata: appMetadata,
      enableLogging: false,
      cifiApiKey: cifiApiKey,
      cifiApiSecret: cifiApiSecret,
    );
  }

  /// Creates a standalone free tier config (no third-party dependencies).
  ///
  /// Use this when you only need core blockchain functionality:
  /// - RPC operations
  /// - Token operations (ERC20/721/1155)
  /// - Transaction signing
  /// - Basic ENS resolution
  factory Web3RefiConfig.standalone({
    required List<Chain> chains,
    Chain? defaultChain,
    bool enableLogging = false,
  }) {
    return Web3RefiConfig(
      chains: chains,
      defaultChain: defaultChain,
      enableLogging: enableLogging,
    );
  }

  /// Creates a premium config with CIFI ID for full feature access.
  ///
  /// Includes access to:
  /// - XMTP & Mailchain messaging
  /// - Universal Name Service (all resolvers)
  /// - Invoice management
  /// - CiFi identity & authentication
  factory Web3RefiConfig.premium({
    required List<Chain> chains,
    required String cifiApiKey,
    required String cifiApiSecret,
    String? projectId,
    Chain? defaultChain,
    AppMetadata? appMetadata,
    bool enableLogging = false,
  }) {
    return Web3RefiConfig(
      chains: chains,
      projectId: projectId,
      defaultChain: defaultChain,
      appMetadata: appMetadata,
      enableLogging: enableLogging,
      cifiApiKey: cifiApiKey,
      cifiApiSecret: cifiApiSecret,
      enableCiFiNames: true,
      enableUnstoppableDomains: true,
      enableSpaceId: true,
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
        cifiApiKey,
        cifiApiSecret,
        enableCiFiNames,
        enableUnstoppableDomains,
        enableSpaceId,
        enableSolanaNameService,
        enableSuiNameService,
        namesCacheSize,
        namesCacheTtl,
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
    String? cifiApiKey,
    String? cifiApiSecret,
    bool? enableCiFiNames,
    bool? enableUnstoppableDomains,
    bool? enableSpaceId,
    bool? enableSolanaNameService,
    bool? enableSuiNameService,
    int? namesCacheSize,
    Duration? namesCacheTtl,
  }) {
    return Web3RefiConfig(
      chains: chains ?? this.chains,
      projectId: projectId ?? this.projectId,
      defaultChain: defaultChain ?? this.defaultChain,
      appMetadata: appMetadata ?? this.appMetadata,
      enableLogging: enableLogging ?? this.enableLogging,
      rpcTimeout: rpcTimeout ?? this.rpcTimeout,
      defaultConfirmations: defaultConfirmations ?? this.defaultConfirmations,
      autoRestoreSession: autoRestoreSession ?? this.autoRestoreSession,
      xmtpEnvironment: xmtpEnvironment ?? this.xmtpEnvironment,
      enableMailchain: enableMailchain ?? this.enableMailchain,
      cifiApiKey: cifiApiKey ?? this.cifiApiKey,
      cifiApiSecret: cifiApiSecret ?? this.cifiApiSecret,
      enableCiFiNames: enableCiFiNames ?? this.enableCiFiNames,
      enableUnstoppableDomains: enableUnstoppableDomains ?? this.enableUnstoppableDomains,
      enableSpaceId: enableSpaceId ?? this.enableSpaceId,
      enableSolanaNameService: enableSolanaNameService ?? this.enableSolanaNameService,
      enableSuiNameService: enableSuiNameService ?? this.enableSuiNameService,
      namesCacheSize: namesCacheSize ?? this.namesCacheSize,
      namesCacheTtl: namesCacheTtl ?? this.namesCacheTtl,
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
