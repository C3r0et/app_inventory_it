import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../models/asset.dart';
import 'asset_form_screen.dart';
import 'text_scanner_screen.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/quick_audit_modal.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _cameraController = MobileScannerController();
  final TextEditingController _manualController = TextEditingController();
  bool _isScanning = true;
  bool _isLoading = false;
  bool _isBoxShape = true; // true = Square (QR), false = Rect (Barcode)

  @override
  void dispose() {
    _cameraController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning || _isLoading) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final String code = barcode.rawValue!;
        _handleResult(code);
        break; 
      }
    }
  }

  String _cleanScannedQuery(String raw) {
    String q = raw.toUpperCase().replaceAll('O', '0').replaceAll('Q', '0').trim();
    // Match prefix + sequence + optional year (handles smudged slashes like KB-700202 -> KB-0700 or KB/0700/2025)
    RegExp smudgedRegex = RegExp(r'(MN|PC|KB|MS|HD|HS|LAP)[^\d]*(\d{1,4})(20\d{1,2}|20\d)?');
    Match? m = smudgedRegex.firstMatch(q);
    if (m != null) {
      String prefix = m.group(1)!;
      String num = m.group(2)!;
      return '$prefix-$num';
    }
    return q;
  }

  Future<void> _handleResult(String query) async {
    setState(() {
      _isScanning = false;
      _isLoading = true;
    });

    final dbService = context.read<DatabaseService>();

    try {
      String cleanQuery = _cleanScannedQuery(query);

      // 1. Check Local DB with clean query & raw query
      Asset? asset = await dbService.getAsset(cleanQuery);
      if (asset == null && cleanQuery != query) {
        asset = await dbService.getAsset(query);
      }

      // 2. If not found, check API (Smart Search)
      if (asset == null) {
        final apiResult = await ApiService.searchAsset(cleanQuery);
        if (apiResult != null) {
          asset = Asset.fromJson(apiResult);
          await dbService.insertAsset(asset);
        } else if (cleanQuery != query) {
          final apiResult2 = await ApiService.searchAsset(query);
          if (apiResult2 != null) {
            asset = Asset.fromJson(apiResult2);
            await dbService.insertAsset(asset);
          }
        }
      }

      if (!mounted) return;

      if (asset != null) {
        // Log Scan Activity
        ApiService.logActivity(
          user: 'admin',
          action: 'SCAN',
          entityType: 'asset',
          entityId: asset.id,
          details: 'Scanned asset ${asset.id}',
        );

        // Found - Show Quick Audit Modal for Field Audit
        AudioService.playSuccess();
        await _showQuickAuditModal(asset);
      } else {
        // Not Found - Ask to Create
        AudioService.playError();
        _showNotFoundDialog(cleanQuery.isNotEmpty ? cleanQuery : query);
      }
    } catch (e) {
      AudioService.playError();
      _showErrorDialog(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showQuickAuditModal(Asset asset) async {
    final baseUrl = ApiService.baseUrl;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAuditModal(
        assetData: {
          'id': asset.id,
          'type': asset.type,
          'status': asset.status,
          'location': asset.location,
          'specs': asset.specs,
          'legacy_inv_code': asset.legacyInvCode,
          'sticker_status': asset.stickerStatus,
        },
        serverUrl: baseUrl,
      ),
    );

    if (mounted) {
      setState(() {
        _isScanning = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToForm(Asset asset) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AssetFormScreen(asset: asset)),
    );
    if (mounted) {
      setState(() {
        _isScanning = true;
        _isLoading = false;
      });
    }
  }

  void _showNotFoundDialog(String id) {
    final guessedType = _guessTypeFromId(id);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text(
              'Aset Tidak Ditemukan',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nomor Inventaris / Stiker "$id" belum terdaftar di database.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Apakah Anda ingin menambahkan aset ini ke database sekarang?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
                _isLoading = false;
              });
            },
            child: const Text('Tidak', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToForm(Asset(
                id: id,
                type: guessedType,
                status: 'AVAILABLE',
                location: 'Ruang IT',
                legacyInvCode: id.contains('/') ? id : null,
                stickerStatus: 'STICKERED',
                isSynced: false,
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ya, Tambahkan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _guessTypeFromId(String id) {
    final upper = id.toUpperCase();
    if (upper.contains('PC')) return 'CPU';
    if (upper.contains('MN') || upper.contains('MON')) return 'Monitor';
    if (upper.contains('KB')) return 'Keyboard';
    if (upper.contains('MS')) return 'Mouse';
    if (upper.contains('HD') || upper.contains('HS')) return 'Headset';
    return 'CPU';
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
                _isLoading = false;
              });
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Camera View
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          
          // Scanner Overlay
          ScannerOverlay(
            overlayAspectRatio: _isBoxShape ? 1.0 : 2.0,
          ),
          
          // Overlay UI
          SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  color: Colors.black54,
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Kembali',
                        ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Scan Aset',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.flash_on, color: Colors.white, size: 22),
                        onPressed: () => _cameraController.toggleTorch(),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 22),
                        onPressed: () => _cameraController.switchCamera(),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          _isBoxShape ? Icons.crop_square : Icons.crop_16_9,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          setState(() {
                            _isBoxShape = !_isBoxShape;
                          });
                        },
                        tooltip: 'Toggle Scan Shape',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.text_fields, color: Colors.white, size: 22),
                        onPressed: () async {
                          setState(() => _isScanning = false);
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TextScannerScreen()),
                          );
                          if (result != null && result is String) {
                            _handleResult(result);
                          } else {
                            setState(() => _isScanning = true);
                          }
                        },
                        tooltip: 'Scan Text ID',
                      ),
                    ],
                  ),
                ),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('⌨️ Masukkan ID / No. Stiker Aset', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Contoh: KB-0700 atau KB/0700/2025',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.black26,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_manualController.text.isNotEmpty) {
                          final text = _manualController.text.trim();
                          _manualController.clear();
                          Navigator.pop(context);
                          _handleResult(text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cari Aset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
        child: const Icon(Icons.keyboard),
      ),
    );
  }
}
