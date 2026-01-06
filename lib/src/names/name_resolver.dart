import 'package:web3refi/src/names/resolution_result.dart';

/// Abstract interface for name resolvers.
///
/// Implement this interface to add support for a new name service
/// (e.g., ENS, Unstoppable Domains, Solana Name Service, etc.)
abstract class NameResolver {
  /// Unique identifier for this resolver (e.g., 'ens', 'cifi', 'unstoppable')
  String get id;

  /// Supported TLDs (e.g., ['eth'] for ENS, ['sol'] for Solana)
  List<String> get supportedTLDs;

  /// Supported chain IDs
  List<int> get supportedChainIds;

  /// Whether this resolver supports reverse resolution (address → name)
  bool get supportsReverse => false;

  /// Whether this resolver supports name registration
  bool get supportsRegistration => false;

  /// Resolve a name to an address.
  ///
  /// Returns null if the name is not found or resolution fails.
  ///
  /// [name] - The name to resolve (e.g., 'vitalik.eth', '@alice')
  /// [chainId] - Optional chain ID for multi-chain resolution
  /// [coinType] - Optional coin type for multi-coin addresses (SLIP-0044)
  Future<ResolutionResult?> resolve(
    String name, {
    int? chainId,
    String? coinType,
  });

  /// Reverse resolve an address to a name.
  ///
  /// Returns null if no name is associated with this address or if
  /// reverse resolution is not supported.
  Future<String?> reverseResolve(String address, {int? chainId}) async {
    return null;
  }

  /// Get all records for a name.
  ///
  /// Returns all available information including addresses for multiple chains,
  /// text records, content hashes, etc.
  Future<NameRecords?> getRecords(String name);

  /// Check if this resolver can handle a given name.
  ///
  /// Default implementation checks if the TLD matches supportedTLDs.
  bool canResolve(String name) {
    if (supportedTLDs.isEmpty) return true;

    final parts = name.split('.');
    if (parts.length < 2) return false;

    final tld = parts.last.toLowerCase();
    return supportedTLDs.contains(tld);
  }
}

/// Name resolver that supports registration.
abstract class RegisterableNameResolver extends NameResolver {
  @override
  bool get supportsRegistration => true;

  /// Check if a name is available for registration.
  Future<bool> isAvailable(String name);

  /// Get the price to register a name for a given duration.
  ///
  /// Returns the price in the smallest unit of the chain's native token
  /// (e.g., wei for Ethereum).
  Future<BigInt> getPrice(String name, Duration duration);

  /// Set records for an owned name.
  ///
  /// Updates the records associated with a name. The caller must own the name.
  Future<String> setRecords(
    String name,
    Map<String, String> records,
  );
}
