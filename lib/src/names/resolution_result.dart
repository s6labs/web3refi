/// Resolution result with metadata for name lookups.
///
/// Contains the resolved address along with metadata about how it was resolved
/// and when it expires (if applicable).
class ResolutionResult {
  /// The resolved blockchain address
  final String address;

  /// Which resolver was used (e.g., 'ens', 'cifi', 'unstoppable')
  final String resolverUsed;

  /// The original name that was resolved
  final String? name;

  /// Chain ID for which this address is valid
  final int? chainId;

  /// When this name registration expires (if applicable)
  final DateTime? expiresAt;

  /// Additional metadata from the resolver
  final Map<String, dynamic>? metadata;

  const ResolutionResult({
    required this.address,
    required this.resolverUsed,
    this.name,
    this.chainId,
    this.expiresAt,
    this.metadata,
  });

  /// Whether this name has expired
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  /// Whether this name is expiring soon (within 30 days)
  bool get isExpiringSoon =>
      expiresAt != null &&
      expiresAt!.difference(DateTime.now()).inDays < 30 &&
      !isExpired;

  /// Days until expiration (null if no expiry or already expired)
  int? get daysUntilExpiration {
    if (expiresAt == null || isExpired) return null;
    return expiresAt!.difference(DateTime.now()).inDays;
  }

  Map<String, dynamic> toJson() => {
        'address': address,
        'resolverUsed': resolverUsed,
        if (name != null) 'name': name,
        if (chainId != null) 'chainId': chainId,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      };

  factory ResolutionResult.fromJson(Map<String, dynamic> json) {
    return ResolutionResult(
      address: json['address'] as String,
      resolverUsed: json['resolverUsed'] as String,
      name: json['name'] as String?,
      chainId: json['chainId'] as int?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ResolutionResult(address: $address, resolver: $resolverUsed)';
}

/// All records associated with a name.
///
/// Contains addresses for multiple chains, text records, content hashes, etc.
class NameRecords {
  /// Chain-specific addresses (coinType → address)
  final Map<String, String> addresses;

  /// Text records (key → value)
  /// Common keys: 'email', 'url', 'avatar', 'description', 'com.twitter', 'com.github'
  final Map<String, String> texts;

  /// Content hash (IPFS, Arweave, etc.)
  final String? contentHash;

  /// Avatar URL or reference
  final String? avatar;

  /// Owner address
  final String? owner;

  /// Resolver contract address
  final String? resolver;

  /// Expiration date
  final DateTime? expiresAt;

  const NameRecords({
    this.addresses = const {},
    this.texts = const {},
    this.contentHash,
    this.avatar,
    this.owner,
    this.resolver,
    this.expiresAt,
  });

  /// Get address for a specific coin type (e.g., '60' for Ethereum)
  String? getAddress(String coinType) => addresses[coinType];

  /// Get Ethereum address (coin type 60)
  String? get ethereumAddress => addresses['60'];

  /// Get a text record by key
  String? getText(String key) => texts[key];

  Map<String, dynamic> toJson() => {
        'addresses': addresses,
        'texts': texts,
        if (contentHash != null) 'contentHash': contentHash,
        if (avatar != null) 'avatar': avatar,
        if (owner != null) 'owner': owner,
        if (resolver != null) 'resolver': resolver,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      };

  factory NameRecords.fromJson(Map<String, dynamic> json) {
    return NameRecords(
      addresses: Map<String, String>.from(json['addresses'] as Map? ?? {}),
      texts: Map<String, String>.from(json['texts'] as Map? ?? {}),
      contentHash: json['contentHash'] as String?,
      avatar: json['avatar'] as String?,
      owner: json['owner'] as String?,
      resolver: json['resolver'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
    );
  }
}
