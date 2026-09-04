import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/asset.dart';

class ApiService {
  static String _currentBaseUrl = 'https://asset.sahabatsakinah.id/api';

  /// Normalizes IP or Domain input into a valid backend API URL.
  /// Supports:
  /// - Pure IP: 199.166.25.5 -> http://199.166.25.5:8080/api
  /// - IP with port: 199.166.25.5:9000 -> http://199.166.25.5:9000/api
  /// - Domain: asset.sahabatsakinah.id -> https://asset.sahabatsakinah.id/api
  /// - Domain with http/port: http://api.domain.com:8080 -> http://api.domain.com:8080/api
  /// - Full URL: https://asset.sahabatsakinah.id/api -> https://asset.sahabatsakinah.id/api
  static String formatBaseUrl(String input) {
    String clean = input.trim();
    if (clean.isEmpty) return 'https://asset.sahabatsakinah.id/api';

    while (clean.endsWith('/')) {
      clean = clean.substring(0, clean.length - 1);
    }

    String scheme;
    String hostPortAndPath;

    if (clean.startsWith('http://')) {
      scheme = 'http://';
      hostPortAndPath = clean.substring(7);
    } else if (clean.startsWith('https://')) {
      scheme = 'https://';
      hostPortAndPath = clean.substring(8);
    } else {
      final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(clean) || clean.startsWith('localhost');
      if (isIp || clean.contains(':8080')) {
        scheme = 'http://';
      } else {
        scheme = 'https://';
      }
      hostPortAndPath = clean;
    }

    final firstSlash = hostPortAndPath.indexOf('/');
    String hostAndPort = firstSlash != -1 ? hostPortAndPath.substring(0, firstSlash) : hostPortAndPath;
    String path = firstSlash != -1 ? hostPortAndPath.substring(firstSlash) : '';

    final isPureIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(hostAndPort) || hostAndPort == 'localhost';
    if (scheme == 'http://' && isPureIp && !hostAndPort.contains(':')) {
      hostAndPort = '$hostAndPort:8080';
    }

    if (path.isEmpty) {
      path = '/api';
    } else if (!path.endsWith('/api')) {
      if (path.endsWith('/api/')) {
        path = path.substring(0, path.length - 1);
      } else {
        path = '$path/api';
      }
    }

    return '$scheme$hostAndPort$path';
  }

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAddress = prefs.getString('server_address') ?? prefs.getString('server_ip');
    if (savedAddress != null && savedAddress.isNotEmpty) {
      _currentBaseUrl = formatBaseUrl(savedAddress);
    }
  }

  static Future<void> updateServerAddress(String address) async {
    final formatted = formatBaseUrl(address);
    _currentBaseUrl = formatted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_address', address.trim());
    await prefs.setString('server_ip', address.trim());
  }

  static Future<void> updateServerIp(String ip) => updateServerAddress(ip);

  static String get baseUrl => _currentBaseUrl;

  static String get serverHostDisplay {
    try {
      final uri = Uri.parse(_currentBaseUrl);
      final schemePrefix = uri.scheme == 'https' ? 'https://' : '';
      if (uri.hasPort && uri.port != 80 && uri.port != 443) {
        return '$schemePrefix${uri.host}:${uri.port}';
      }
      return '$schemePrefix${uri.host}';
    } catch (_) {
      return _currentBaseUrl;
    }
  }

  static String get serverIp => serverHostDisplay;

  // Get all assets
  static Future<List<Asset>> getAssets() async {
    final response = await http.get(Uri.parse('$baseUrl/assets'))
        .timeout(const Duration(seconds: 30));
    
    if (response.statusCode == 200) {
      List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((json) => Asset.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load assets');
    }
  }

  // Smart search by Serial Number, Legacy Code, or Asset ID
  static Future<Map<String, dynamic>?> searchAsset(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/assets/search?q=${Uri.encodeComponent(query)}'),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is List) {
        if (decoded.isNotEmpty) {
          return decoded.first as Map<String, dynamic>;
        }
        return null;
      } else if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } else if (response.statusCode == 404) {
      return null; // Asset not found
    } else {
      throw Exception('Failed to search asset');
    }
  }

  // Get asset by ID (legacy method, kept for compatibility)
  static Future<Asset?> getAssetById(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/assets/${Uri.encodeComponent(id)}'))
        .timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      return Asset.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load asset');
    }
  }

  // Create asset
  Future<Asset> createAsset(Asset asset) async {
    String? finalImagePath = asset.imagePath;

    // Check if images require upload (local files)
    if (finalImagePath != null && finalImagePath.isNotEmpty) {
       List<String> paths = finalImagePath.split(',');
       List<String> uploadedPaths = [];
       for (var path in paths) {
         if (!path.startsWith('http') && !path.startsWith('/uploads/')) {
           final file = File(path);
           if (await file.exists()) {
             final uploadedPath = await uploadImage(file);
             if (uploadedPath != null) {
               uploadedPaths.add(uploadedPath);
             } else {
               throw Exception('Failed to upload image $path to server');
             }
           }
         } else {
           uploadedPaths.add(path); // Already uploaded
         }
       }
       finalImagePath = uploadedPaths.isEmpty ? null : uploadedPaths.join(',');
    }

    final assetJson = asset.toJson();
    assetJson['image_path'] = finalImagePath; // Always overwrite it, even if null

    final response = await http.post(
      Uri.parse('$baseUrl/assets'),
      headers: {
        'Content-Type': 'application/json',
        'X-Source': 'mobile',
      },
      body: json.encode(assetJson),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 201) {
      return Asset.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to create asset');
  }

  // Update asset
  Future<Asset> updateAsset(Asset asset) async {
    String? finalImagePath = asset.imagePath;

    // Check if images require upload
    if (finalImagePath != null && finalImagePath.isNotEmpty) {
       List<String> paths = finalImagePath.split(',');
       List<String> uploadedPaths = [];
       for (var path in paths) {
         if (!path.startsWith('http') && !path.startsWith('/uploads/')) {
           final file = File(path);
           if (await file.exists()) {
             final uploadedPath = await uploadImage(file);
             if (uploadedPath != null) {
               uploadedPaths.add(uploadedPath);
             } else {
               throw Exception('Failed to upload image $path to server');
             }
           }
         } else {
           uploadedPaths.add(path); // Already uploaded
         }
       }
       finalImagePath = uploadedPaths.isEmpty ? null : uploadedPaths.join(',');
    }

    final assetJson = asset.toJson();
    assetJson['image_path'] = finalImagePath; // Always overwrite it, even if null

    final response = await http.put(
      Uri.parse('$baseUrl/assets/${Uri.encodeComponent(asset.id)}'),
      headers: {
        'Content-Type': 'application/json',
        'X-Source': 'mobile',
      },
      body: json.encode(assetJson),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode == 200) {
      return Asset.fromJson(json.decode(response.body));
    }
    print('DEBUG: updateAsset failed with status ${response.statusCode}: ${response.body}');
    throw Exception('Failed to update asset: ${response.body}');
  }

  // Delete asset
  Future<void> deleteAsset(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/assets/${Uri.encodeComponent(id)}'),
      headers: {
        'X-Source': 'mobile',
      },
    );
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Failed to delete asset');
    }
  }

  // Baseline audit
  Future<void> baselineAudit({
    required int deskNumber,
    required String area,
    required List<String> assetTypes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/baseline-audit'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'desk_number': deskNumber,
        'area': area,
        'asset_types': assetTypes,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to perform baseline audit');
    }
  }

  // Health check & Connection test
  Future<bool> checkConnection([String? testAddress]) => testConnection(testAddress);

  static Future<Map<String, dynamic>> testConnectionDetailed([String? testAddress]) async {
    final url = (testAddress != null && testAddress.trim().isNotEmpty)
        ? formatBaseUrl(testAddress)
        : baseUrl;
    try {
      // 1. First try /stats (very lightweight, ~124 bytes instead of 2.1MB asset list)
      try {
        final res = await http.get(Uri.parse('$url/stats')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          return {'success': true, 'message': 'Terhubung ke server! (HTTP 200 OK)'};
        }
      } catch (_) {}

      // 2. Try /health
      try {
        final res = await http.get(Uri.parse('$url/health')).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          return {'success': true, 'message': 'Terhubung ke server! (HTTP 200 OK)'};
        }
      } catch (_) {}

      // 3. Fallback to /assets
      final response = await http.get(Uri.parse('$url/assets'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Terhubung ke server! (HTTP 200 OK)'};
      }
      return {'success': false, 'message': 'Server merespons status code: ${response.statusCode}'};
    } catch (e) {
      String msg = e.toString();
      if (msg.contains('TimeoutException')) {
        msg = 'Waktu koneksi habis (timeout). Sinyal seluler mungkin lambat.';
      } else if (msg.contains('HandshakeException')) {
        msg = 'Gagal verifikasi sertifikat SSL.';
      } else if (msg.contains('SocketException')) {
        msg = 'Gagal menghubungi server. Periksa koneksi internet Anda.';
      }
      return {'success': false, 'message': msg};
    }
  }

  static Future<bool> testConnection([String? testAddress]) async {
    final res = await testConnectionDetailed(testAddress);
    return res['success'] == true;
  }

  // Log Activity (Manual)
  static Future<void> logActivity({
    required String user,
    required String action,
    required String entityType,
    required String entityId,
    required String details,
  }) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/history/log'),
        headers: {
          'Content-Type': 'application/json',
          'X-Source': 'mobile',
        },
        body: json.encode({
          'user': user,
          'action': action,
          'entity_type': entityType,
          'entity_id': entityId,
          'details': details,
          'source': 'mobile',
        }),
      );
    } catch (e) {
      print('Failed to log activity: $e');
    }
  }
  // Bulk Update Status
  static Future<void> bulkUpdateStatus(List<String> assetIds, String status) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assets/bulk-status'),
      headers: {
        'Content-Type': 'application/json',
        'X-Source': 'mobile',
      },
      body: json.encode({
        'asset_ids': assetIds,
        'status': status,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update status for selected assets');
    }
  }

  // Bulk Update Location
  static Future<void> bulkUpdateLocation(List<String> assetIds, String location) async {
    final response = await http.post(
      Uri.parse('$baseUrl/assets/bulk-location'),
      headers: {
        'Content-Type': 'application/json',
        'X-Source': 'mobile',
      },
      body: json.encode({
        'asset_ids': assetIds,
        'location': location,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update location for selected assets');
    }
  }

  // Upload Image
  static Future<String?> uploadImage(File imageFile) async {
    print('DEBUG: Starting uploadImage for ${imageFile.path}');
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/upload'));
    request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    
    try {
      final response = await request.send();
      print('DEBUG: Upload response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        print('DEBUG: Upload success payload: $respStr');
        final jsonResponse = json.decode(respStr);
        return jsonResponse['path'];
      } else {
        final respError = await response.stream.bytesToString();
        print('DEBUG: Image upload failed with status: ${response.statusCode}, Body: $respError');
        return null;
      }
    } catch (e) {
      print('DEBUG: Image upload error exception: $e');
      return null;
    }
  }

  // Helper to resolve full image URL
  static String getImageUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = baseUrl.replaceAll('/api', ''); // http://ip:port
    if (path.startsWith('/')) return '$base$path';
    return '$base/$path';
  }

  // Fetch asset audit logs / history
  static Future<List<Map<String, dynamic>>> getAssetLogs(String assetId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/history?asset_id=${Uri.encodeComponent(assetId)}&limit=30'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is List) {
          return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      // Error handled gracefully
    }
    return [];
  }

  // Fetch full asset maintenance/parts history
  static Future<Map<String, dynamic>?> getAssetFullHistory(String assetId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/assets/${Uri.encodeComponent(assetId)}/history'),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body) as Map);
      }
    } catch (_) {}
    return null;
  }
}
