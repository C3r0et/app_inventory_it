import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../models/asset.dart';
import 'simple_scanner_screen.dart';

class RapidScanScreen extends StatefulWidget {
  const RapidScanScreen({super.key});

  @override
  State<RapidScanScreen> createState() => _RapidScanScreenState();
}

class _RapidScanScreenState extends State<RapidScanScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedLocation = 'Ruang IT';
  String _selectedBrand = 'Logitech';
  String _selectedIdPrefix = 'MON/';
  String _selectedIdSuffix = '/${DateTime.now().year}';
  
  final List<String> _brands = [
    'Logitech', 'Votre', 'HP', 'Lenovo', 'LG', 'Simbadda', 'Lainnya'
  ];

  final List<String> _locations = [
    'Ruang IT', 'Floor Lt2', 'Floor Lt3'
  ];

  final List<String> _statuses = [
    'AVAILABLE', 'IN_USE', 'BROKEN', 'REPAIRING', 'GHOST'
  ];

  final TextEditingController _deskNumberController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final FocusNode _idFocusNode = FocusNode();

  List<Asset> _stagedAssets = [];
  bool _isSaving = false;

  @override
  void dispose() {
    _deskNumberController.dispose();
    _idController.dispose();
    _idFocusNode.dispose();
    super.dispose();
  }

  void _addAsset(String number) {
    if (number.trim().isEmpty) return;
    
    String cleanNum = number.trim();
    cleanNum = cleanNum.replaceAll(RegExp(r'^(HD|PC|KB|MN|MS|LAP|MINI|AIO)[-/\s]*', caseSensitive: false), '');
    cleanNum = cleanNum.replaceAll(RegExp(r'/.*$'), '');

    final fullId = '$_selectedIdPrefix$cleanNum$_selectedIdSuffix';
    _commitAssetToList(fullId);
    
    _idController.clear();
    FocusScope.of(context).requestFocus(_idFocusNode);
  }

  void _commitAssetToList(String fullId) {
    if (_stagedAssets.any((a) => a.id == fullId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aset sudah ada di antrean!'), backgroundColor: Colors.amber)
      );
      return;
    }

    String t = 'PC';
    if (fullId.contains('LAP/')) t = 'LAPTOP';
    else if (fullId.contains('MON/')) t = 'MONITOR';
    else if (fullId.contains('KB/')) t = 'KEYBOARD';
    else if (fullId.contains('MS/')) t = 'MOUSE';
    else if (fullId.contains('HS/')) t = 'HEADSET';

    String computedLocation = _selectedLocation;
    if (_selectedLocation.startsWith('Floor')) {
       final deskNum = _deskNumberController.text.trim();
       if (deskNum.isNotEmpty) {
           computedLocation = '$_selectedLocation - Meja $deskNum';
       }
    }

    String finalSpecs = 'Merk: $_selectedBrand';

    setState(() {
      _stagedAssets.insert(0, Asset(
        id: fullId,
        type: t,
        status: 'AVAILABLE',
        location: computedLocation,
        specs: finalSpecs,
        isSynced: false,
      ));
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const SimpleScannerScreen()),
    );

    if (result != null && mounted) {
      if (result.contains('/')) {
        _commitAssetToList(result);
      } else {
        _addAsset(result);
      }
    }
  }

  Future<void> _saveAllAssets() async {
    if (_stagedAssets.isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final dbService = context.read<DatabaseService>();
    final apiService = context.read<ApiService>();

    int successCount = 0;
    List<Asset> assetsToSave = List.from(_stagedAssets);

    for (var asset in assetsToSave) {
      try {
        await dbService.insertAsset(asset);
        try {
          await apiService.createAsset(asset);
          await dbService.markAsSynced(asset.id);
        } catch (e) {
          print('Sync failed for ${asset.id}: $e');
        }
        successCount++;
        setState(() {
          _stagedAssets.removeWhere((a) => a.id == asset.id);
        });
      } catch (e) {
        print('DB save failed for ${asset.id}: $e');
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Gagal menyimpan ${asset.id}: $e'), backgroundColor: Colors.red)
           );
        }
      }
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✓ Berhasil menyimpan $successCount aset ke Gudang!'), backgroundColor: Colors.green)
      );
    }
  }

  Widget _buildPrefixChip(BuildContext context, String prefix) {
    final themeProvider = context.watch<ThemeProvider>();
    bool isSelected = _selectedIdPrefix == prefix;
    return ChoiceChip(
      label: Text(prefix, style: TextStyle(color: isSelected ? Colors.white : themeProvider.primaryTextColor, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedIdPrefix = prefix),
      selectedColor: Colors.blueAccent,
      backgroundColor: themeProvider.cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: themeProvider.borderStrokeColor)),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSuffixChip(BuildContext context, String suffix) {
    final themeProvider = context.watch<ThemeProvider>();
    bool isSelected = _selectedIdSuffix == suffix;
    return ChoiceChip(
      label: Text(suffix, style: TextStyle(color: isSelected ? Colors.white : themeProvider.primaryTextColor, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedIdSuffix = suffix),
      selectedColor: Colors.teal,
      backgroundColor: themeProvider.cardBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: themeProvider.borderStrokeColor)),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Mode Gudang (Rapid Input)', style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor)),
        backgroundColor: themeProvider.scaffoldBackgroundColor,
        elevation: 0,
        systemOverlayStyle: themeProvider.systemOverlayStyle,
      ),
      body: Column(
        children: [
          // HEADER CONFIGURATION PANEL
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: themeProvider.cardBackgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: themeProvider.borderStrokeColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚙️ Setel Konfigurasi Default Gudang', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedLocation,
                        dropdownColor: themeProvider.cardBackgroundColor,
                        style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Lokasi',
                          labelStyle: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: themeProvider.scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                        ),
                        items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                        onChanged: (val) => setState(() => _selectedLocation = val!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedBrand,
                        dropdownColor: themeProvider.cardBackgroundColor,
                        style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 14),
                        decoration: InputDecoration(
                          labelText: 'Merk',
                          labelStyle: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: themeProvider.scaffoldBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                        ),
                        items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                        onChanged: (val) => setState(() => _selectedBrand = val!),
                      ),
                    ),
                  ],
                ),
                if (_selectedLocation.startsWith('Floor')) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _deskNumberController,
                    style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Nomor Meja (Opsional)',
                      labelStyle: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: themeProvider.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPrefixChip(context, 'MON/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'PC/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'MINI/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'AIO/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'LAP/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'KB/'),
                      const SizedBox(width: 6),
                      _buildPrefixChip(context, 'MS/'),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSuffixChip(context, '/2024'),
                      const SizedBox(width: 6),
                      _buildSuffixChip(context, '/2025'),
                      const SizedBox(width: 6),
                      _buildSuffixChip(context, '/2026'),
                      const SizedBox(width: 6),
                      _buildSuffixChip(context, '/2027'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // INPUT BAR
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: themeProvider.cardBackgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeProvider.borderStrokeColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: themeProvider.scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: themeProvider.borderStrokeColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code, color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(_selectedIdPrefix, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 15)),
                        Expanded(
                          child: TextFormField(
                            controller: _idController,
                            focusNode: _idFocusNode,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 15),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText: 'Nomor',
                              hintStyle: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 14),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              border: InputBorder.none,
                            ),
                            onFieldSubmitted: _addAsset,
                          ),
                        ),
                        Text(_selectedIdSuffix, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _scanBarcode,
                  icon: Icon(Icons.qr_code_scanner, color: themeProvider.primaryTextColor),
                  style: IconButton.styleFrom(
                    backgroundColor: themeProvider.scaffoldBackgroundColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                IconButton(
                  onPressed: () => _addAsset(_idController.text),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          // STAGED LIST
          Expanded(
            child: _stagedAssets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, color: themeProvider.secondaryTextColor, size: 48),
                        const SizedBox(height: 12),
                        Text('Belum ada antrean aset.\nKetik nomor urut lalu tekan Enter atau tombol Kirim.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 14)
                        ),
                      ],
                    )
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _stagedAssets.length,
                    itemBuilder: (context, index) {
                      final asset = _stagedAssets[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: themeProvider.cardBackgroundColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: themeProvider.borderStrokeColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_getTypeIcon(asset.type), color: Colors.blueAccent, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(asset.id, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: themeProvider.primaryTextColor)),
                                  const SizedBox(height: 2),
                                  Text('${asset.location} • ${asset.specs}', style: TextStyle(fontSize: 12, color: themeProvider.secondaryTextColor)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 105,
                              child: DropdownButtonFormField<String>(
                                value: asset.status,
                                dropdownColor: themeProvider.cardBackgroundColor,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                style: TextStyle(fontSize: 11, color: themeProvider.primaryTextColor, fontWeight: FontWeight.w600),
                                items: _statuses.map((status) => DropdownMenuItem(
                                  value: status, 
                                  child: Text(status.length > 8 ? '${status.substring(0,7)}..' : status)
                                )).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _stagedAssets[index] = asset.copyWith(status: val!);
                                  });
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                              onPressed: () {
                                setState(() {
                                  _stagedAssets.removeAt(index);
                                });
                              }
                            )
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // BOTTOM ACTION
          if (_stagedAssets.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.cardBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: themeProvider.borderStrokeColor)),
              ),
              child: ElevatedButton.icon(
                icon: _isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_rounded, color: Colors.white),
                label: Text('Simpan Semua (${_stagedAssets.length} Aset)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSaving ? null : _saveAllAssets,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'PC': return Icons.computer;
      case 'LAPTOP': return Icons.laptop;
      case 'MONITOR': return Icons.monitor;
      case 'KEYBOARD': return Icons.keyboard;
      case 'MOUSE': return Icons.mouse;
      case 'HEADSET': return Icons.headset;
      default: return Icons.devices;
    }
  }
}
