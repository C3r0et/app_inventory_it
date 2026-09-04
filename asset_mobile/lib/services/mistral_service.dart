import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MistralScanResult {
  final bool isSuccess;
  final String? assetId;
  final List<String> candidates;
  final String rawText;
  final String? errorMessage;

  MistralScanResult({
    required this.isSuccess,
    this.assetId,
    this.candidates = const [],
    this.rawText = '',
    this.errorMessage,
  });
}

class MistralService {
  static const String defaultApiKey = 'ZQ8sRvnXqprZ2OrradlOY7w7AdlVG5lF';
  static const String _prefsKey = 'mistral_api_key';
  static const String visionModel = 'pixtral-12b-2409';
  static const String ocrModel = 'mistral-ocr-latest';

  /// Mendapatkan API Key yang tersimpan atau menggunakan default
  static Future<String> getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_prefsKey);
    if (key != null && key.trim().isNotEmpty) {
      return key.trim();
    }
    return defaultApiKey;
  }

  /// Menyimpan API Key baru ke penyimpanan lokal
  static Future<void> saveApiKey(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, apiKey.trim());
  }

  /// Menguji validitas koneksi API Key ke Mistral
  static Future<bool> testConnection([String? apiKey]) async {
    try {
      final key = apiKey ?? await getApiKey();
      final response = await http.get(
        Uri.parse('https://api.mistral.ai/v1/models'),
        headers: {
          'Authorization': 'Bearer $key',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Memindai gambar stiker aset dengan Mistral AI Vision (Pixtral 12B)
  /// Didukung fallback otomatis ke Mistral OCR endpoint
  static Future<MistralScanResult> scanAssetSticker(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return MistralScanResult(
        isSuccess: false,
        errorMessage: 'File gambar stiker tidak ditemukan.',
      );
    }

    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      return MistralScanResult(
        isSuccess: false,
        errorMessage: 'Mistral API Key belum dikonfigurasi.',
      );
    }

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 1. Coba menggunakan Pixtral 12B Vision (dengan instruksi terarah JSON)
      try {
        final result = await _scanWithPixtralVision(base64Image, apiKey);
        if (result.isSuccess && (result.assetId != null || result.candidates.isNotEmpty)) {
          return result;
        }
      } catch (e) {
        print('Pixtral error, mencoba fallback ke Mistral OCR: $e');
      }

      // 2. Fallback ke Mistral OCR API (/v1/ocr) jika Pixtral tidak menemukan kode
      return await _scanWithMistralOcr(base64Image, apiKey);

    } on SocketException {
      return MistralScanResult(
        isSuccess: false,
        errorMessage: 'Gagal terhubung ke server Mistral. Periksa koneksi internet Anda.',
      );
    } catch (e) {
      return MistralScanResult(
        isSuccess: false,
        errorMessage: 'Gagal memproses gambar: $e',
      );
    }
  }

  /// Memanggil endpoint chat completion multimodal (Pixtral)
  static Future<MistralScanResult> _scanWithPixtralVision(String base64Image, String apiKey) async {
    final url = Uri.parse('https://api.mistral.ai/v1/chat/completions');

    final body = jsonEncode({
      "model": visionModel,
      "response_format": {"type": "json_object"},
      "messages": [
        {
          "role": "system",
          "content": "Kamu adalah asisten OCR inventaris IT yang bertugas membaca kode stiker aset. "
              "Stiker aset berisi template teks cetakan komputer (seperti nama instansi, kategori, nomor register) "
              "dan isian tulisan tangan menggunakan spidol/pena tebal. "
              "Tugas utamamu: Identifikasi TULISAN TANGAN SPIDOL yang menunjukkan kode aset/nomor stiker. "
              "Format kode aset umumnya:\n"
              "- [KODE]/[NOMOR]/[TAHUN], contoh: HD/0008/2025, MN/0012/2024, KB/0002/2023, MS/005/2025, LAP/001/2024, HS/002/2025\n"
              "- atau kode dengan tanda strip/spasi: PC-001, MN-005, HD-002, PC001.\n"
              "Kembalikan HANYA format JSON valid:\n"
              "{\n"
              "  \"asset_id\": \"KODE_ASET_TERDETEKSI atau null jika tidak yakin\",\n"
              "  \"candidates\": [\"kandidat1\", \"kandidat2\"],\n"
              "  \"all_detected_text\": \"semua teks yang terbaca pada gambar\"\n"
              "}"
        },
        {
          "role": "user",
          "content": [
            {
              "type": "image_url",
              "image_url": "data:image/jpeg;base64,$base64Image"
            },
            {
              "type": "text",
              "text": "Deteksi kode aset pada gambar stiker ini, prioritaskan tulisan tangan spidol."
            }
          ]
        }
      ],
      "temperature": 0.1,
      "max_tokens": 300,
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonRes = jsonDecode(response.body);
      final rawContent = jsonRes['choices']?[0]?['message']?['content']?.toString() ?? '';
      
      try {
        final parsed = jsonDecode(rawContent);
        final String? rawAssetId = parsed['asset_id'];
        final List<dynamic>? rawCandidates = parsed['candidates'];
        final String allDetectedText = parsed['all_detected_text']?.toString() ?? '';

        List<String> candidates = [];
        if (rawCandidates != null) {
          candidates = rawCandidates
              .map((c) => c.toString().trim())
              .where((c) => c.isNotEmpty && c.toLowerCase() != 'null')
              .toList();
        }

        String? cleanedAssetId;
        if (rawAssetId != null && rawAssetId.trim().isNotEmpty && rawAssetId.toLowerCase() != 'null') {
          cleanedAssetId = _cleanAssetId(rawAssetId);
          if (!candidates.contains(cleanedAssetId)) {
            candidates.insert(0, cleanedAssetId);
          }
        }

        return MistralScanResult(
          isSuccess: true,
          assetId: cleanedAssetId,
          candidates: candidates,
          rawText: allDetectedText,
        );
      } catch (_) {
        // Jika response text bukan json, coba ekstrak dengan regex
        final extracted = _extractFromText(rawContent);
        return MistralScanResult(
          isSuccess: extracted != null,
          assetId: extracted,
          rawText: rawContent,
        );
      }
    } else {
      throw Exception('Mistral Vision error code ${response.statusCode}: ${response.body}');
    }
  }

  /// Memanggil endpoint Mistral OCR (/v1/ocr)
  static Future<MistralScanResult> _scanWithMistralOcr(String base64Image, String apiKey) async {
    final url = Uri.parse('https://api.mistral.ai/v1/ocr');

    final body = jsonEncode({
      "model": ocrModel,
      "document": {
        "type": "document_url",
        "document_url": "data:image/jpeg;base64,$base64Image"
      }
    });

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: body,
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final jsonRes = jsonDecode(response.body);
      final pages = jsonRes['pages'] as List<dynamic>?;
      if (pages != null && pages.isNotEmpty) {
        final markdown = pages[0]['markdown']?.toString() ?? '';
        final extracted = _extractFromText(markdown);
        final candidates = _extractAllCandidates(markdown);

        return MistralScanResult(
          isSuccess: true,
          assetId: extracted,
          candidates: candidates,
          rawText: markdown,
        );
      }
      return MistralScanResult(
        isSuccess: true,
        assetId: null,
        rawText: 'Tidak ada teks terdeteksi di dokumen.',
      );
    } else {
      return MistralScanResult(
        isSuccess: false,
        errorMessage: 'Mistral OCR API error (${response.statusCode})',
      );
    }
  }

  /// Regex scanner untuk mencari pola kode aset (HD/0008/2025, PC-001, dll)
  static String? _extractFromText(String text) {
    final clean = text.replaceAll('#', '').replaceAll('*', '').trim();

    final RegExp regex = RegExp(
      r'\b(MN|PC|KB|MS|HD|HS|LAP|MONITOR|KEYBOARD|MOUSE|HEADSET)[\s\/\-\_\:\.\|]+([A-Z0-9]{1,6})([\s\/\-\_\:\.\|]+([A-Z0-9]{2,4}))?\b',
      caseSensitive: false,
    );

    final match = regex.firstMatch(clean);
    if (match != null) {
      String prefix = match.group(1)!.toUpperCase();
      if (prefix == 'MONITOR') prefix = 'MN';
      if (prefix == 'KEYBOARD') prefix = 'KB';
      if (prefix == 'MOUSE') prefix = 'MS';
      if (prefix == 'HEADSET' || prefix == 'HS') prefix = 'HD';
      if (prefix == 'LAPTOP') prefix = 'LAP';

      String part1 = match.group(2)!.toUpperCase();
      String? part2 = match.group(4)?.toUpperCase();

      if (part2 != null && part2.isNotEmpty) {
        return '$prefix/$part1/$part2';
      } else {
        return '$prefix-$part1';
      }
    }
    return null;
  }

  static List<String> _extractAllCandidates(String text) {
    final List<String> list = [];
    final lines = text.split('\n');
    for (final line in lines) {
      final trimmed = line.replaceAll(RegExp(r'[#*`_\[\]]'), '').trim();
      if (trimmed.isEmpty) continue;
      final extracted = _extractFromText(trimmed);
      if (extracted != null && !list.contains(extracted)) {
        list.add(extracted);
      } else if (trimmed.length <= 25 && !list.contains(trimmed)) {
        list.add(trimmed);
      }
    }
    return list;
  }

  static String _cleanAssetId(String raw) {
    return raw.replaceAll(RegExp(r'[#*`_\[\]]'), '').trim().toUpperCase();
  }
}
