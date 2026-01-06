import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3refi/src/invoice/core/invoice.dart';

/// IPFS storage handler for invoices
class IPFSStorage {
  final String apiUrl;
  final String gateway;
  final http.Client _httpClient;
  final String? apiKey;
  final String? apiSecret;

  IPFSStorage({
    this.apiUrl = 'https://ipfs.infura.io:5001/api/v0',
    this.gateway = 'https://ipfs.io/ipfs/',
    http.Client? httpClient,
    this.apiKey,
    this.apiSecret,
  }) : _httpClient = httpClient ?? http.Client();

  // ═══════════════════════════════════════════════════════════════════════
  // UPLOAD
  // ═══════════════════════════════════════════════════════════════════════

  /// Upload invoice to IPFS
  Future<String> uploadInvoice(Invoice invoice) async {
    final jsonData = jsonEncode(invoice.toJson());
    return await uploadData(jsonData);
  }

  /// Upload raw data to IPFS
  Future<String> uploadData(String data) async {
    final bytes = utf8.encode(data);
    return await uploadBytes(Uint8List.fromList(bytes));
  }

  /// Upload bytes to IPFS
  Future<String> uploadBytes(Uint8List bytes) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/add'))
        ..files.add(http.MultipartFile.fromBytes('file', bytes));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final cid = json['Hash'] as String;
        return cid;
      } else {
        throw IPFSException(
          'Failed to upload to IPFS: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      throw IPFSException('IPFS upload error: $e');
    }
  }

  /// Upload file to IPFS
  Future<String> uploadFile(Uint8List fileBytes, String filename) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/add'))
        ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['Hash'] as String;
      } else {
        throw IPFSException(
          'Failed to upload file to IPFS: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw IPFSException('IPFS file upload error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // DOWNLOAD
  // ═══════════════════════════════════════════════════════════════════════

  /// Download invoice from IPFS
  Future<Invoice> downloadInvoice(String cid) async {
    final data = await downloadData(cid);
    final json = jsonDecode(data);
    return Invoice.fromJson(json as Map<String, dynamic>);
  }

  /// Download raw data from IPFS
  Future<String> downloadData(String cid) async {
    try {
      final url = '$gateway$cid';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw IPFSException(
          'Failed to download from IPFS: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw IPFSException('IPFS download error: $e');
    }
  }

  /// Download bytes from IPFS
  Future<Uint8List> downloadBytes(String cid) async {
    try {
      final url = '$gateway$cid';
      final response = await _httpClient.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw IPFSException(
          'Failed to download bytes from IPFS: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw IPFSException('IPFS bytes download error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PIN MANAGEMENT
  // ═══════════════════════════════════════════════════════════════════════

  /// Pin CID to ensure it's retained
  Future<void> pin(String cid) async {
    try {
      final url = '$apiUrl/pin/add?arg=$cid';
      final request = http.Request('POST', Uri.parse(url));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw IPFSException('Failed to pin CID: ${response.statusCode}');
      }
    } catch (e) {
      throw IPFSException('IPFS pin error: $e');
    }
  }

  /// Unpin CID
  Future<void> unpin(String cid) async {
    try {
      final url = '$apiUrl/pin/rm?arg=$cid';
      final request = http.Request('POST', Uri.parse(url));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw IPFSException('Failed to unpin CID: ${response.statusCode}');
      }
    } catch (e) {
      throw IPFSException('IPFS unpin error: $e');
    }
  }

  /// List pinned CIDs
  Future<List<String>> listPins() async {
    try {
      final url = '$apiUrl/pin/ls';
      final request = http.Request('POST', Uri.parse(url));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final keys = json['Keys'] as Map<String, dynamic>;
        return keys.keys.toList();
      } else {
        throw IPFSException('Failed to list pins: ${response.statusCode}');
      }
    } catch (e) {
      throw IPFSException('IPFS list pins error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════

  /// Get full IPFS URL for CID
  String getUrl(String cid) {
    return '$gateway$cid';
  }

  /// Check if CID is valid
  bool isValidCID(String cid) {
    // CIDv0: Qm...
    if (cid.startsWith('Qm') && cid.length == 46) {
      return true;
    }

    // CIDv1: bafy..., bafk...
    if ((cid.startsWith('bafy') || cid.startsWith('bafk')) && cid.length >= 50) {
      return true;
    }

    return false;
  }

  /// Get file stat from IPFS
  Future<Map<String, dynamic>> getStat(String cid) async {
    try {
      final url = '$apiUrl/files/stat?arg=/ipfs/$cid';
      final request = http.Request('POST', Uri.parse(url));

      // Add authentication if provided
      if (apiKey != null && apiSecret != null) {
        final auth = base64Encode(utf8.encode('$apiKey:$apiSecret'));
        request.headers['Authorization'] = 'Basic $auth';
      }

      final streamedResponse = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw IPFSException('Failed to get stat: ${response.statusCode}');
      }
    } catch (e) {
      throw IPFSException('IPFS stat error: $e');
    }
  }

  /// Dispose HTTP client
  void dispose() {
    _httpClient.close();
  }
}

/// IPFS exception
class IPFSException implements Exception {
  final String message;

  IPFSException(this.message);

  @override
  String toString() => 'IPFSException: $message';
}
