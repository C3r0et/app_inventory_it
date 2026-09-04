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
import '../services/theme_provider.dart';

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
      Map<String, Asset> assetMap = {};

      // 1. Check exact ID in local DB
      Asset? exactLocal = await dbService.getAsset(cleanQuery);
      if (exactLocal == null && cleanQuery != query) {
        exactLocal = await dbService.getAsset(query);
      }
      if (exactLocal != null) {
        assetMap[exactLocal.id] = exactLocal;
      }

      // 2. Search local DB by partial pattern (e.g. '1126' matches both KB-1126 & MS-1126)
      final localList = await dbService.getAllAssets(query: cleanQuery);
      for (var a in localList) {
        assetMap[a.id] = a;
      }
      if (cleanQuery != query) {
        final localListRaw = await dbService.getAllAssets(query: query);
        for (var a in localListRaw) {
          assetMap[a.id] = a;
        }
      }

      // 3. Search API for remote matches
      try {
        final remoteList = await ApiService.searchAssets(cleanQuery);
        for (var a in remoteList) {
          assetMap[a.id] = a;
          try {
            await dbService.insertAsset(a);
          } catch (_) {}
        }
        if (cleanQuery != query) {
          final remoteListRaw = await ApiService.searchAssets(query);
          for (var a in remoteListRaw) {
            assetMap[a.id] = a;
            try {
              await dbService.insertAsset(a);
            } catch (_) {}
          }
        }
      } catch (e) {
        print('Remote search error in scanner: $e');
      }

      final matchedAssets = assetMap.values.toList();

      if (!mounted) return;

      if (matchedAssets.length == 1) {
        final asset = matchedAssets.first;
        // Log Scan Activity
        ApiService.logActivity(
          user: 'admin',
          action: 'SCAN',
          entityType: 'asset',
          entityId: asset.id,
          details: 'Scanned asset ${asset.id}',
        );

        AudioService.playSuccess();
        await _showQuickAuditModal(asset);
      } else if (matchedAssets.length > 1) {
        // Multiple assets found (e.g. Mouse & Keyboard with same number)
        AudioService.playSuccess();
        await _showMultipleAssetsPicker(matchedAssets, cleanQuery);
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

  Future<void> _showMultipleAssetsPicker(List<Asset> assets, String query) async {
    final themeProvider = context.read<ThemeProvider>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: themeProvider.cardBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.hub_rounded, color: Colors.blueAccent, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ditemukan ${assets.length} Aset',
                              style: TextStyle(
                                color: themeProvider.primaryTextColor,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Nomor "$query" digunakan pada beberapa kategori.',
                              style: TextStyle(
                                color: themeProvider.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: assets.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      IconData icon = Icons.devices_other;
                      Color iconColor = Colors.amber;
                      final typeUpper = asset.type.toUpperCase();
                      if (typeUpper.contains('PC')) {
                        icon = Icons.computer;
                        iconColor = Colors.blue;
                      } else if (typeUpper.contains('MON')) {
                        icon = Icons.desktop_windows;
                        iconColor = Colors.cyan;
                      } else if (typeUpper.contains('KB') || typeUpper.contains('KEY')) {
                        icon = Icons.keyboard;
                        iconColor = Colors.green;
                      } else if (typeUpper.contains('MS') || typeUpper.contains('MOU')) {
                        icon = Icons.mouse;
                        iconColor = Colors.orange;
                      } else if (typeUpper.contains('HD') || typeUpper.contains('HS')) {
                        icon = Icons.headset;
                        iconColor = Colors.purpleAccent;
                      } else if (typeUpper.contains('LAP')) {
                        icon = Icons.laptop;
                        iconColor = Colors.indigoAccent;
                      }

                      return Material(
                        color: themeProvider.isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.pop(context);
                            ApiService.logActivity(
                              user: 'admin',
                              action: 'SCAN',
                              entityType: 'asset',
                              entityId: asset.id,
                              details: 'Scanned asset ${asset.id} (${asset.type})',
                            );
                            _showQuickAuditModal(asset);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: iconColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(icon, color: iconColor, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            asset.id,
                                            style: TextStyle(
                                              color: themeProvider.primaryTextColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: iconColor.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              asset.type,
                                              style: TextStyle(
                                                color: iconColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${asset.location} • ${asset.status}',
                                        style: TextStyle(
                                          color: themeProvider.secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (asset.specs != null && asset.specs!.isNotEmpty)
                                        Text(
                                          asset.specs!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: themeProvider.secondaryTextColor.withValues(alpha: 0.8),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
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
