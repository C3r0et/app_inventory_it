import 'package:flutter/material.dart';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/mistral_service.dart';

enum ScanEngine {
  mistralAi, // Mistral Pixtral 12B Vision (Sangat peka tulisan spidol & template)
  mlKitLocal, // Google ML Kit On-Device (Offline / Font cetak standar)
}

class TextScannerScreen extends StatefulWidget {
  const TextScannerScreen({super.key});

  @override
  State<TextScannerScreen> createState() => _TextScannerScreenState();
}

class _TextScannerScreenState extends State<TextScannerScreen> {
  CameraController? _cameraController;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isFound = false;
  String _detectedText = '';
  String _debugInfo = 'Siap memindai... Arahkan stiker lalu tekan tombol foto';
  List<String> _candidates = [];
  final TextEditingController _manualInputController = TextEditingController();

  // Engine aktif (default Mistral AI untuk tulisan tangan spidol)
  ScanEngine _currentEngine = ScanEngine.mistralAi;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Gunakan resolusi tinggi agar teks stiker dan goresan spidol tampak tajam
    _cameraController = CameraController(
      cameras[0],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        _debugInfo = _currentEngine == ScanEngine.mistralAi
            ? '🤖 Mode AI: Siap membaca tulisan tangan spidol & template cetak'
            : '⚡ Mode Offline: Arahkan stiker ke dalam kotak target';
      });
    } catch (e) {
      print('Camera initialization error: $e');
    }
  }

  // Normalization logic: Memperbaiki kesalahan baca OCR umum jika dibutuhkan
  String? _extractAndNormalizeAssetId(String raw) {
    String text = raw.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

    RegExp mainRegex = RegExp(
      r'(MN|PC|KB|MS|HD|HS|LAP|MONITOR|KEYBOARD|MOUSE|HEADSET)[\s\/\-\_\:\.\|]+([A-Z0-9]{1,6})([\s\/\-\_\:\.\|]+([A-Z0-9]{2,4}))?',
      caseSensitive: false,
    );

    Match? match = mainRegex.firstMatch(text);
    if (match != null) {
      String prefix = match.group(1)!.toUpperCase();
      if (prefix == 'MONITOR') prefix = 'MN';
      if (prefix == 'KEYBOARD') prefix = 'KB';
      if (prefix == 'MOUSE') prefix = 'MS';
      if (prefix == 'HEADSET' || prefix == 'HS') prefix = 'HD';
      if (prefix == 'LAPTOP') prefix = 'LAP';

      String part1 = _fixOcrDigits(match.group(2)!.toUpperCase());
      String? part2 = match.group(4) != null ? _normalizeYear(match.group(4)!.toUpperCase()) : null;

      if (part2 == null && part1.length >= 5) {
        RegExp smudgedYearRegex = RegExp(r'^(\d{1,4})(20\d{1,2}|20\d)$');
        Match? smudgedMatch = smudgedYearRegex.firstMatch(part1);
        if (smudgedMatch != null) {
          part1 = smudgedMatch.group(1)!;
          part2 = _normalizeYear(smudgedMatch.group(2)!);
        }
      }

      if (part2 != null && part2.isNotEmpty) {
        return '$prefix/$part1/$part2';
      } else {
        return '$prefix-$part1';
      }
    }
    return null;
  }

  String _normalizeYear(String yearRaw) {
    String cleaned = _fixOcrDigits(yearRaw);
    if (cleaned.length == 3 && cleaned.startsWith('20')) {
      return '202${cleaned[2]}';
    }
    if (cleaned.length == 2) {
      return '20$cleaned';
    }
    return cleaned;
  }

  String _fixOcrDigits(String input) {
    return input
        .replaceAll('O', '0')
        .replaceAll('Q', '0')
        .replaceAll('D', '0')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('Z', '2')
        .replaceAll('S', '5')
        .replaceAll('B', '8')
        .replaceAll('G', '6');
  }

  Future<void> _captureAndProcessImage() async {
    if (_isProcessing || _isFound || _cameraController == null) return;

    if (_currentEngine == ScanEngine.mistralAi) {
      await _processWithMistralAi();
    } else {
      await _processWithMlKit();
    }
  }

  /// Eksekusi pemindaian menggunakan Mistral AI Vision
  Future<void> _processWithMistralAi() async {
    setState(() {
      _isProcessing = true;
      _debugInfo = '🤖 Mengambil foto & menganalisis dengan Mistral AI Vision...';
      _candidates.clear();
    });

    XFile? picture;
    try {
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      picture = await _cameraController!.takePicture();

      setState(() {
        _debugInfo = '🤖 AI sedang mengidentifikasi tulisan spidol & kode aset...';
      });

      final result = await MistralService.scanAssetSticker(picture.path);

      if (!mounted) return;

      if (result.isSuccess) {
        if (result.assetId != null && result.assetId!.isNotEmpty) {
          _onMatchFound(result.assetId!);
        } else if (result.candidates.isNotEmpty) {
          setState(() {
            _candidates = result.candidates;
            _debugInfo = 'Pilih nomor stiker yang terdeteksi oleh AI:';
          });
          _showCandidateSelectionSheet(result.candidates);
        } else {
          setState(() {
            _debugInfo = 'Tulisan stiker tidak terbaca jelas. Dekatkan kamera atau nyalakan cahaya.';
          });
        }
      } else {
        setState(() {
          _debugInfo = result.errorMessage ?? 'Gagal memproses via Mistral AI.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Koneksi ke Mistral AI gagal.'),
            backgroundColor: Colors.redAccent,
            action: SnackBarAction(
              label: 'Beralih ke Offline',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _currentEngine = ScanEngine.mlKitLocal);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _debugInfo = 'Error: $e');
    } finally {
      if (picture != null) {
        final file = File(picture.path);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Eksekusi pemindaian menggunakan Google ML Kit (Offline)
  Future<void> _processWithMlKit() async {
    setState(() {
      _isProcessing = true;
      _debugInfo = '⚡ Menstabilkan fokus & menganalisis teks lokal...';
      _candidates.clear();
    });

    try {
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      final XFile picture1 = await _cameraController!.takePicture();
      await Future.delayed(const Duration(milliseconds: 150));
      XFile? picture2;
      try {
        picture2 = await _cameraController!.takePicture();
      } catch (_) {}

      List<String> foundCandidates = [];
      String? bestMatch;

      final pictures = [picture1, if (picture2 != null) picture2];

      for (var pic in pictures) {
        final inputImage = InputImage.fromFilePath(pic.path);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        for (TextBlock block in recognizedText.blocks) {
          for (TextLine line in block.lines) {
            final String originalLine = line.text.trim();
            if (originalLine.isEmpty) continue;

            if (!foundCandidates.contains(originalLine)) {
              foundCandidates.add(originalLine);
            }

            String? normalized = _extractAndNormalizeAssetId(originalLine);
            if (normalized != null) {
              if (bestMatch == null || _scoreCandidate(normalized) > _scoreCandidate(bestMatch)) {
                bestMatch = normalized;
              }
            }
          }
        }

        final file = File(pic.path);
        if (await file.exists()) {
          await file.delete();
        }
      }

      if (bestMatch != null) {
        _onMatchFound(bestMatch);
      } else if (foundCandidates.isNotEmpty) {
        setState(() {
          _candidates = foundCandidates;
          _debugInfo = 'Teks terdeteksi (${foundCandidates.length} baris). Pilih kandidat di bawah:';
        });
        _showCandidateSelectionSheet(foundCandidates);
      } else {
        setState(() {
          _debugInfo = 'Teks lokal buram. Anda bisa mencoba "Mode AI Mistral" di atas.';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _debugInfo = 'Error ML Kit: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  int _scoreCandidate(String candidate) {
    int score = 0;
    if (candidate.contains('/')) score += 10;
    if (candidate.contains('2025') || candidate.contains('2026')) score += 5;
    if (candidate.startsWith('HD') || candidate.startsWith('KB') || candidate.startsWith('PC') || candidate.startsWith('MN') || candidate.startsWith('MS')) score += 10;
    return score;
  }

  void _onMatchFound(String id) {
    if (_isFound) return;
    setState(() {
      _isFound = true;
      _detectedText = id.toUpperCase();
    });

    HapticFeedback.vibrate();
    AudioService.playSuccess();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        Navigator.pop(context, _detectedText);
      }
    });
  }

  void _showCandidateSelectionSheet(List<String> candidates) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _currentEngine == ScanEngine.mistralAi ? Icons.auto_awesome : Icons.text_snippet,
                    color: _currentEngine == ScanEngine.mistralAi ? Colors.purpleAccent : Colors.blueAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Pilih / Perbaiki Hasil Scan',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Ketuk teks yang paling sesuai dengan nomor stiker aset Anda:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: candidates.map((cand) {
                  String? norm = _extractAndNormalizeAssetId(cand);
                  String displayText = norm ?? cand;
                  return ActionChip(
                    backgroundColor: norm != null ? const Color(0xFF3B82F6) : const Color(0xFF334155),
                    label: Text(
                      displayText,
                      style: TextStyle(
                        color: norm != null ? Colors.white : Colors.white70,
                        fontWeight: norm != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _onMatchFound(displayText);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _manualInputController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Atau Masukkan / Perbaiki No. Stiker Manual',
                  labelStyle: const TextStyle(color: Colors.white60),
                  hintText: 'Contoh: HD/0008/2025',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.blueAccent),
                    onPressed: () {
                      final text = _manualInputController.text.trim();
                      if (text.isNotEmpty) {
                        Navigator.pop(context);
                        _onMatchFound(text);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Dialog pengaturan API Key Mistral
  Future<void> _showMistralSettingsDialog() async {
    final currentKey = await MistralService.getApiKey();
    final controller = TextEditingController(text: currentKey);
    bool isTesting = false;
    String? testResult;

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.smart_toy_rounded, color: Colors.purpleAccent),
                SizedBox(width: 8),
                Text('Pengaturan Mistral AI', style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'API Key Mistral digunakan untuk memproses foto tulisan tangan spidol dengan model Pixtral Vision.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Mistral API Key',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                if (testResult != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: testResult!.contains('Berhasil') ? Colors.green.shade900 : Colors.red.shade900,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      testResult!,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: isTesting
                      ? null
                      : () async {
                          setDialogState(() {
                            isTesting = true;
                            testResult = null;
                          });
                          final ok = await MistralService.testConnection(controller.text.trim());
                          setDialogState(() {
                            isTesting = false;
                            testResult = ok ? '✓ Berhasil terhubung ke Mistral AI' : '✗ Gagal terhubung / API Key tidak valid';
                          });
                        },
                  icon: isTesting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent))
                      : const Icon(Icons.bolt, color: Colors.purpleAccent, size: 18),
                  label: const Text('Uji Koneksi API', style: TextStyle(color: Colors.purpleAccent)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.white60)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                onPressed: () async {
                  final key = controller.text.trim();
                  if (key.isNotEmpty) {
                    await MistralService.saveApiKey(key);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('API Key Mistral berhasil disimpan!')),
                    );
                  }
                },
                child: const Text('Simpan', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _textRecognizer.close();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
      );
    }

    final isAi = _currentEngine == ScanEngine.mistralAi;
    final primaryAccentColor = isAi ? const Color(0xFFA855F7) : Colors.blueAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Stiker OCR'),
        backgroundColor: const Color(0xFF0F172A),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Mistral AI',
            icon: const Icon(Icons.tune_rounded, color: Colors.purpleAccent),
            onPressed: _showMistralSettingsDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraPreview(_cameraController!),

          // TOP ENGINE SWITCHER (Mistral AI vs ML Kit)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentEngine = ScanEngine.mistralAi;
                          _debugInfo = '🤖 Mode AI: Siap membaca tulisan tangan spidol & template cetak';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isAi
                              ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)])
                              : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.smart_toy_rounded, size: 16, color: isAi ? Colors.white : Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              'AI Mistral (Spidol)',
                              style: TextStyle(
                                color: isAi ? Colors.white : Colors.white60,
                                fontWeight: isAi ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentEngine = ScanEngine.mlKitLocal;
                          _debugInfo = '⚡ Mode Offline: Arahkan stiker ke dalam kotak target';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !isAi ? Colors.blueAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.flash_on_rounded, size: 16, color: !isAi ? Colors.white : Colors.white54),
                            const SizedBox(width: 6),
                            Text(
                              'ML Kit (Offline)',
                              style: TextStyle(
                                color: !isAi ? Colors.white : Colors.white60,
                                fontWeight: !isAi ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Target Box Guide
          Center(
            child: Container(
              width: 320,
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isFound ? Colors.greenAccent : primaryAccentColor,
                  width: _isFound ? 4 : 2.5,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _isFound ? Colors.greenAccent.withOpacity(0.2) : Colors.black12,
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isAi ? Icons.auto_awesome : Icons.crop_free,
                            color: isAi ? Colors.purpleAccent : Colors.amberAccent,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isAi ? 'Target Stiker (AI Spidol)' : 'Target Stiker (HD/0008/2025)',
                            style: TextStyle(
                              color: isAi ? Colors.purpleAccent : Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Loading Overlay saat processing AI
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: primaryAccentColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primaryAccentColor),
                      const SizedBox(height: 16),
                      Text(
                        isAi ? 'Menganalisis dengan Mistral AI...' : 'Membaca Teks...',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isAi
                            ? 'Mendeteksi goresan spidol & nomor aset'
                            : 'Memproses karakter font',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Instructions & Status Banner
          Positioned(
            bottom: 30,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFound
                        ? Colors.green.shade900.withOpacity(0.9)
                        : const Color(0xFF0F172A).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _isFound ? Colors.greenAccent : Colors.white24),
                  ),
                  child: Column(
                    children: [
                      if (_isFound)
                        Text(
                          '✓ Terdeteksi Presisi: $_detectedText',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        )
                      else
                        Text(
                          _debugInfo,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (!_isFound)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _captureAndProcessImage,
                      icon: _isProcessing
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Icon(isAi ? Icons.smart_toy_rounded : Icons.camera_alt, color: Colors.white),
                      label: Text(
                        _isProcessing
                            ? 'Sedang Menganalisis...'
                            : (isAi ? 'Pindai dengan AI Mistral' : 'Ambil Foto OCR (Offline)'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isAi ? const Color(0xFF9333EA) : Colors.blueAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
