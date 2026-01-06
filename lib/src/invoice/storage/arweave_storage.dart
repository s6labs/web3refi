import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../core/invoice.dart';

/// Arweave storage handler for invoices (permanent storage)
class ArweaveStorage {
  final String apiUrl;
  final String gateway;
  final http.Client _httpClient;
  final Map<String, dynamic>? walletKey;

  ArweaveStorage({
    this.apiUrl = 'https://arweave.net',
    this.gateway = 'https://arweave.net/',
    http.Client? httpClient,
    this.walletKey,
  }) : _httpClient = httpClient ?? http.Client();

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD (Requires wallet key for signing)
  // ═══════════════════════════════════════════════════════════════════════

  /// Upload invoice to Arweave
  Future<String> uploadInvoice(Invoice invoice) async {
    final jsonData = jsonEncode(invoice.toJson());
    return await uploadData(
      jsonData,
      contentType: 'application/json',
      tags: {
        'App-Name': 'web3refi',
        'Content-Type': 'application/json',
        'Invoice-ID': invoice.id,
        'Invoice-Number': invoice.number,
        'Invoice-From': invoice.from,
        'Invoice-To': invoice.to,
        'Invoice-Total': invoice.total.toString(),
        'Invoice-Currency': invoice.currency,
      },
    );
  }

  /// Upload raw data to Arweave
  Future<String> uploadData(
    String data, {
    String contentType = 'text/plain',
    Map<String, String>? tags,
  }) async {
    final bytes = utf8.encode(data);
    return await uploadBytes(
      Uint8List.fromList(bytes),
      contentType: contentType,
      tags: tags,
    );
  }

  /// Upload bytes to Arweave
  Future<String> uploadBytes(
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    Map<String, String>? tags,
  }) async {
    if (walletKey == null) {
      throw ArweaveException('Wallet key required for uploading to Arweave');
    }

    try {
      // Get price for upload
      final price = await getPrice(bytes.length);
      print('[Arweave] Upload will cost: $price Winston (${_winstonToAR(price)} AR)');

      // Create transaction
      final transaction = await _createTransaction(
        data: bytes,
        contentType: contentType,
        tags: tags,
      );

      // Sign transaction
      final signedTx = await _signTransaction(transaction);

      // Submit transaction
      final txId = await _submitTransaction(signedTx);

      print('[Arweave] Transaction submitted: $txId');
      return txId;
    } catch (e) {
      throw ArweaveException('Arweave upload error: $e');
    }
  }

  /// Upload file to Arweave
  Future<String> uploadFile(
    Uint8List fileBytes,
    String filename, {
    String? contentType,
    Map<String, String>? tags,
  }) async {
    final fileTags = {
      'File-Name': filename,
      if (contentType != null) 'Content-Type': contentType,
      ...?tags,
    };

    return await uploadBytes(
      fileBytes,
      contentType: contentType ?? 'application/octet-stream',
      tags: fileTags,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DOWNLOAD
  // ═══════════════════════════════════════════════════════════════════════

  /// Download invoice from Arweave
  Future<Invoice> downloadInvoice(String txId) async {
    final data = await downloadData(txId);
    final json = jsonDecode(data);
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// Download raw data from Arweave
  Future<String> downloadData(String txId) async {
    try {
      final url = '$gateway$txId';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.body;
      } else if (response.statusCode == 202) {
        // Transaction is pending
        throw ArweaveException('Transaction is still pending: $txId');
      } else {
        throw ArweaveException(
          'Failed to download from Arweave: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ArweaveException('Arweave download error: $e');
    }
  }

  /// Download bytes from Arweave
  Future<Uint8List> downloadBytes(String txId) async {
    try {
      final url = '$gateway$txId';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw ArweaveException(
          'Failed to download bytes from Arweave: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ArweaveException('Arweave bytes download error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TRANSACTION INFO
  // ═══════════════════════════════════════════════════════════════════════

  /// Get transaction status
  Future<ArweaveTransactionStatus> getTransactionStatus(String txId) async {
    try {
      final url = '$apiUrl/tx/$txId/status';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ArweaveTransactionStatus.fromJson(json as Map<String, dynamic>);
      } else if (response.statusCode == 202) {
        return ArweaveTransactionStatus.pending();
      } else if (response.statusCode == 404) {
        return ArweaveTransactionStatus.notFound();
      } else {
        throw ArweaveException(
          'Failed to get transaction status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ArweaveException('Transaction status error: $e');
    }
  }

  /// Get transaction metadata
  Future<Map<String, dynamic>> getTransactionMetadata(String txId) async {
    try {
      final url = '$apiUrl/tx/$txId';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw ArweaveException(
          'Failed to get transaction metadata: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw ArweaveException('Transaction metadata error: $e');
    }
  }

  /// Get upload price in Winston (smallest unit of AR)
  Future<BigInt> getPrice(int bytes) async {
    try {
      final url = '$apiUrl/price/$bytes';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return BigInt.parse(response.body);
      } else {
        throw ArweaveException('Failed to get price: ${response.statusCode}');
      }
    } catch (e) {
      throw ArweaveException('Price query error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // INTERNAL TRANSACTION HELPERS
  // ═══════════════════════════════════════════════════════════════════════

  /// Create Arweave transaction
  Future<Map<String, dynamic>> _createTransaction({
    required Uint8List data,
    required String contentType,
    Map<String, String>? tags,
  }) async {
    // Get wallet address
    final walletAddress = await _getWalletAddress();

    // Get last transaction
    final lastTx = await _getLastTransaction(walletAddress);

    // Get reward
    final reward = await getPrice(data.length);

    // Build transaction
    final transaction = {
      'format': 2,
      'id': '',
      'last_tx': lastTx,
      'owner': walletKey!['n'],
      'tags': _encodeTags({
        'Content-Type': contentType,
        ...?tags,
      }),
      'target': '',
      'quantity': '0',
      'data': base64Url.encode(data),
      'data_size': data.length.toString(),
      'data_root': '',
      'reward': reward.toString(),
    };

    return transaction;
  }

  /// Sign transaction
  Future<Map<String, dynamic>> _signTransaction(Map<String, dynamic> transaction) async {
    // In production, this would use proper RSA signing
    // For now, this is a placeholder that shows the structure
    // You would need to implement proper Arweave transaction signing

    // This is a simplified version - production code needs proper crypto
    final signature = _generateDummySignature(transaction);

    transaction['signature'] = signature;
    transaction['id'] = _generateTransactionId(transaction);

    return transaction;
  }

  /// Submit signed transaction
  Future<String> _submitTransaction(Map<String, dynamic> signedTransaction) async {
    try {
      final url = '$apiUrl/tx';
      final response = await _httpClient.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(signedTransaction),
      );

      if (response.statusCode == 200 || response.statusCode == 202) {
        return signedTransaction['id'] as String;
      } else {
        throw ArweaveException(
          'Failed to submit transaction: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw ArweaveException('Transaction submission error: $e');
    }
  }

  /// Get wallet address from key
  Future<String> _getWalletAddress() async {
    // In production, derive address from public key
    // This is a placeholder
    return walletKey!['n'] as String? ?? '';
  }

  /// Get last transaction for wallet
  Future<String> _getLastTransaction(String address) async {
    try {
      final url = '$apiUrl/tx_anchor';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  /// Encode tags for transaction
  List<Map<String, String>> _encodeTags(Map<String, String> tags) {
    return tags.entries
        .map((e) => {
              'name': base64Url.encode(utf8.encode(e.key)),
              'value': base64Url.encode(utf8.encode(e.value)),
            })
        .toList();
  }

  /// Generate transaction signature (dummy - needs real implementation)
  String _generateDummySignature(Map<String, dynamic> transaction) {
    // This is a placeholder - real implementation needs proper RSA signing
    final data = jsonEncode(transaction);
    final hash = sha256.convert(utf8.encode(data));
    return base64Url.encode(hash.bytes);
  }

  /// Generate transaction ID
  String _generateTransactionId(Map<String, dynamic> transaction) {
    final signature = transaction['signature'] as String;
    final bytes = base64Url.decode(signature);
    final hash = sha256.convert(bytes);
    return base64Url.encode(hash.bytes);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get full Arweave URL for transaction
  String getUrl(String txId) {
    return '$gateway$txId';
  }

  /// Convert Winston to AR
  double _winstonToAR(BigInt winston) {
    return winston.toDouble() / 1e12;
  }

  /// Convert AR to Winston
  BigInt _arToWinston(double ar) {
    return BigInt.from(ar * 1e12);
  }

  /// Check if transaction ID is valid
  bool isValidTxId(String txId) {
    // Arweave transaction IDs are 43 characters, base64url
    return RegExp(r'^[a-zA-Z0-9_-]{43}$').hasMatch(txId);
  }

  /// Dispose HTTP client
  void dispose() {
    _httpClient.close();
  }
}

/// Arweave transaction status
class ArweaveTransactionStatus {
  final String status;
  final int? blockHeight;
  final int? confirmations;

  ArweaveTransactionStatus({
    required this.status,
    this.blockHeight,
    this.confirmations,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending';
  bool get isNotFound => status == 'not_found';

  factory ArweaveTransactionStatus.fromJson(Map<String, dynamic> json) {
    return ArweaveTransactionStatus(
      status: 'confirmed',
      blockHeight: json['block_height'] as int?,
      confirmations: json['number_of_confirmations'] as int?,
    );
  }

  factory ArweaveTransactionStatus.pending() {
    return ArweaveTransactionStatus(status: 'pending');
  }

  factory ArweaveTransactionStatus.notFound() {
    return ArweaveTransactionStatus(status: 'not_found');
  }
}

/// Arweave exception
class ArweaveException implements Exception {
  final String message;

  ArweaveException(this.message);

  @override
  String toString() => 'ArweaveException: $message';
}
