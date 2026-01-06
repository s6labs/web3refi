/// Feature access control for web3refi SDK.
///
/// Defines which features are available in free vs premium tiers.
/// Premium features require CIFI ID API key and secret.
library feature_access;

/// SDK feature tiers.
enum FeatureTier {
  /// Free tier - core blockchain functionality
  free,

  /// Premium tier - requires CIFI ID
  premium,
}

/// Available SDK features with their tier requirements.
enum SdkFeature {
  // ═══════════════════════════════════════════════════════════════════════════
  // FREE TIER FEATURES (No CIFI ID required)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Core RPC operations (read blockchain data)
  rpcOperations(FeatureTier.free, 'Core RPC operations'),

  /// Wallet connection and management
  walletConnection(FeatureTier.free, 'Wallet connection'),

  /// ERC20 token operations
  erc20Operations(FeatureTier.free, 'ERC20 token operations'),

  /// ERC721 NFT operations
  erc721Operations(FeatureTier.free, 'ERC721 NFT operations'),

  /// ERC1155 multi-token operations
  erc1155Operations(FeatureTier.free, 'ERC1155 operations'),

  /// Transaction signing and sending
  transactions(FeatureTier.free, 'Transaction management'),

  /// HD wallet generation
  hdWallet(FeatureTier.free, 'HD wallet generation'),

  /// Cryptographic operations (signing, hashing)
  cryptography(FeatureTier.free, 'Cryptographic operations'),

  /// ABI encoding/decoding
  abiCoding(FeatureTier.free, 'ABI encoding/decoding'),

  /// Chain management (switching, adding)
  chainManagement(FeatureTier.free, 'Chain management'),

  /// Gas estimation
  gasEstimation(FeatureTier.free, 'Gas estimation'),

  /// Basic ENS resolution (vitalik.eth only)
  basicEnsResolution(FeatureTier.free, 'Basic ENS resolution'),

  // ═══════════════════════════════════════════════════════════════════════════
  // PREMIUM TIER FEATURES (CIFI ID required)
  // ═══════════════════════════════════════════════════════════════════════════

  /// XMTP real-time messaging
  xmtpMessaging(FeatureTier.premium, 'XMTP messaging'),

  /// Mailchain blockchain email
  mailchainMessaging(FeatureTier.premium, 'Mailchain email'),

  /// Universal Name Service (all name services)
  universalNameService(FeatureTier.premium, 'Universal Name Service'),

  /// CiFi username resolution (@username, .cifi)
  cifiNameResolution(FeatureTier.premium, 'CiFi name resolution'),

  /// Unstoppable Domains resolution
  unstoppableDomainsResolution(FeatureTier.premium, 'Unstoppable Domains'),

  /// Space ID resolution
  spaceIdResolution(FeatureTier.premium, 'Space ID resolution'),

  /// Solana Name Service resolution
  solanaNameService(FeatureTier.premium, 'Solana Name Service'),

  /// Sui Name Service resolution
  suiNameService(FeatureTier.premium, 'Sui Name Service'),

  /// Invoice creation and management
  invoiceManagement(FeatureTier.premium, 'Invoice management'),

  /// Invoice storage (IPFS/Arweave)
  invoiceStorage(FeatureTier.premium, 'Decentralized invoice storage'),

  /// Invoice messaging (send via XMTP/Mailchain)
  invoiceMessaging(FeatureTier.premium, 'Invoice messaging'),

  /// CiFi identity management
  cifiIdentity(FeatureTier.premium, 'CiFi identity'),

  /// CiFi authentication
  cifiAuth(FeatureTier.premium, 'CiFi authentication'),

  /// CiFi subscriptions
  cifiSubscriptions(FeatureTier.premium, 'CiFi subscriptions'),

  /// CiFi webhooks
  cifiWebhooks(FeatureTier.premium, 'CiFi webhooks'),

  /// Batch name resolution
  batchNameResolution(FeatureTier.premium, 'Batch name resolution'),

  /// Name expiration tracking
  nameExpirationTracking(FeatureTier.premium, 'Name expiration tracking'),

  /// Name analytics
  nameAnalytics(FeatureTier.premium, 'Name analytics');

  /// The tier required for this feature.
  final FeatureTier tier;

  /// Human-readable description of the feature.
  final String description;

  const SdkFeature(this.tier, this.description);

  /// Whether this feature requires premium access.
  bool get isPremium => tier == FeatureTier.premium;

  /// Whether this feature is available in free tier.
  bool get isFree => tier == FeatureTier.free;
}

/// Exception thrown when accessing a premium feature without CIFI ID.
class PremiumFeatureException implements Exception {
  /// The feature that was attempted to access.
  final SdkFeature feature;

  /// Human-readable message.
  final String message;

  PremiumFeatureException(this.feature)
      : message = 'Premium feature "${feature.description}" requires CIFI ID. '
            'Please configure your CIFI API key and secret to access this feature. '
            'Get your credentials at https://cifi.network';

  @override
  String toString() => 'PremiumFeatureException: $message';
}

/// Manages feature access based on CIFI ID configuration.
class FeatureAccessManager {
  /// CIFI API key.
  final String? cifiApiKey;

  /// CIFI API secret.
  final String? cifiApiSecret;

  /// Whether premium features are enabled.
  bool get hasPremiumAccess =>
      cifiApiKey != null &&
      cifiApiKey!.isNotEmpty &&
      cifiApiSecret != null &&
      cifiApiSecret!.isNotEmpty;

  /// Whether only API key is provided (partial premium).
  bool get hasApiKeyOnly =>
      cifiApiKey != null && cifiApiKey!.isNotEmpty && (cifiApiSecret == null || cifiApiSecret!.isEmpty);

  FeatureAccessManager({
    this.cifiApiKey,
    this.cifiApiSecret,
  });

  /// Check if a feature is accessible.
  bool canAccess(SdkFeature feature) {
    if (feature.isFree) return true;
    return hasPremiumAccess;
  }

  /// Require access to a feature, throwing if not available.
  void requireAccess(SdkFeature feature) {
    if (!canAccess(feature)) {
      throw PremiumFeatureException(feature);
    }
  }

  /// Get all accessible features.
  List<SdkFeature> get accessibleFeatures {
    return SdkFeature.values.where((f) => canAccess(f)).toList();
  }

  /// Get all premium features that are locked.
  List<SdkFeature> get lockedFeatures {
    if (hasPremiumAccess) return [];
    return SdkFeature.values.where((f) => f.isPremium).toList();
  }

  /// Get the current tier based on configuration.
  FeatureTier get currentTier => hasPremiumAccess ? FeatureTier.premium : FeatureTier.free;

  /// Summary of feature access.
  FeatureAccessSummary get summary => FeatureAccessSummary(
        tier: currentTier,
        accessibleCount: accessibleFeatures.length,
        totalCount: SdkFeature.values.length,
        lockedFeatures: lockedFeatures,
      );
}

/// Summary of feature access status.
class FeatureAccessSummary {
  /// Current tier.
  final FeatureTier tier;

  /// Number of accessible features.
  final int accessibleCount;

  /// Total number of features.
  final int totalCount;

  /// List of locked features.
  final List<SdkFeature> lockedFeatures;

  const FeatureAccessSummary({
    required this.tier,
    required this.accessibleCount,
    required this.totalCount,
    required this.lockedFeatures,
  });

  /// Percentage of features accessible.
  double get accessPercentage => (accessibleCount / totalCount) * 100;

  @override
  String toString() => 'FeatureAccessSummary('
      'tier: ${tier.name}, '
      'access: $accessibleCount/$totalCount (${accessPercentage.toStringAsFixed(1)}%)'
      ')';
}

/// Mixin for classes that need feature access control.
mixin FeatureGuard {
  /// The feature access manager.
  FeatureAccessManager? get featureAccess;

  /// Check if a premium feature can be accessed.
  bool canAccessFeature(SdkFeature feature) {
    return featureAccess?.canAccess(feature) ?? feature.isFree;
  }

  /// Require premium feature access, throwing if not available.
  void requireFeature(SdkFeature feature) {
    if (featureAccess != null) {
      featureAccess!.requireAccess(feature);
    } else if (feature.isPremium) {
      throw PremiumFeatureException(feature);
    }
  }

  /// Whether premium features are available.
  bool get hasPremiumFeatures => featureAccess?.hasPremiumAccess ?? false;
}
