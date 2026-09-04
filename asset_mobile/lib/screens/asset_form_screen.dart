import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../services/database_service.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../models/asset.dart';
import 'simple_scanner_screen.dart';
import '../utils/watermark_utils.dart';

class AssetFormScreen extends StatefulWidget {
  final Asset? asset;

  const AssetFormScreen({super.key, this.asset});

  @override
  State<AssetFormScreen> createState() => _AssetFormScreenState();
}

class _AssetFormScreenState extends State<AssetFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idController;
  late TextEditingController _deskNumberController;
  late TextEditingController _specsController;
  late FocusNode _idFocusNode;
  bool _isBulkMode = false;
  
  List<File> _newPickedImages = [];
  List<String> _existingImages = [];
  final ImagePicker _picker = ImagePicker();
  bool _isProcessingImage = false;

  String _selectedStatus = 'AVAILABLE';
  String _selectedLocation = 'Ruang IT';
  String _selectedBrand = 'Logitech';
  String _selectedIdPrefix = 'PC/';
  String _selectedIdSuffix = '/${DateTime.now().year}';

  // Log History State
  List<Map<String, dynamic>> _assetLogs = [];
  bool _isLoadingLogs = false;
  
  String get _computedType {
    if (widget.asset != null) return widget.asset!.type;
    if (_selectedIdPrefix.contains('LAP')) return 'LAPTOP';
    if (_selectedIdPrefix.contains('MON')) return 'MONITOR';
    if (_selectedIdPrefix.contains('KB')) return 'KEYBOARD';
    if (_selectedIdPrefix.contains('MS')) return 'MOUSE';
    if (_selectedIdPrefix.contains('HS') || _selectedIdPrefix.contains('HD')) return 'HEADSET';
    return 'PC';
  }

  final List<String> _brands = [
    'Logitech', 'Votre', 'HP', 'Lenovo', 'LG', 'Simbadda', 'Lainnya'
  ];

  final List<String> _locations = [
    'Ruang IT', 'Floor Lt2', 'Floor Lt3'
  ];

  final List<String> _statuses = [
    'AVAILABLE', 'IN_USE', 'BROKEN', 'REPAIRING', 'GHOST'
  ];

  List<String> get _currentRepairNotes {
    return [
      'RAM Tidak Terdeteksi', 'No Display', 'Mati Nyala', 'Socket Audio Rusak',
      'Socket RJ45 Rusak', 'Klik Button Patah/Rusak',
      'Kabel Putus', 'Speaker Rusak', 'Microphone Rusak', 'Layar Rusak', 'Baterai Drop'
    ];
  }
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController();
    
    // Parse passed asset ID (from OCR scan or manual trigger)
    String initialCode = widget.asset?.legacyInvCode ?? widget.asset?.id ?? '';
    if (initialCode.isNotEmpty) {
      if (initialCode.contains('/')) {
        final parts = initialCode.split('/');
        if (parts.length >= 3) {
          _selectedIdPrefix = '${parts[0].toUpperCase()}/';
          _idController.text = parts[1];
          _selectedIdSuffix = '/${parts[2]}';
        } else if (parts.length == 2) {
          _selectedIdPrefix = '${parts[0].toUpperCase()}/';
          _idController.text = parts[1];
        }
      } else if (initialCode.contains('-')) {
        final parts = initialCode.split('-');
        if (parts.length >= 2) {
          _selectedIdPrefix = '${parts[0].toUpperCase()}/';
          _idController.text = parts[1];
        } else {
          _idController.text = initialCode;
        }
      } else {
        _idController.text = initialCode;
      }
    }

    // Auto set prefix chip if category passed
    if (widget.asset?.type != null) {
      String t = widget.asset!.type.toUpperCase();
      if (t.contains('MON')) _selectedIdPrefix = 'MN/';
      else if (t.contains('KB') || t.contains('KEY')) _selectedIdPrefix = 'KB/';
      else if (t.contains('MS') || t.contains('MOU')) _selectedIdPrefix = 'MS/';
      else if (t.contains('HD') || t.contains('HS') || t.contains('HEAD')) _selectedIdPrefix = 'HD/';
      else if (t.contains('LAP')) _selectedIdPrefix = 'LAP/';
      else _selectedIdPrefix = 'PC/';
    }
    
    // Parse specs and brand
    String dbSpecs = widget.asset?.specs ?? '';
    if (dbSpecs.startsWith('Merk: ')) {
      final parts = dbSpecs.split('|');
      String possibleBrand = parts[0].replaceFirst('Merk: ', '').trim();
      if (_brands.contains(possibleBrand)) {
        _selectedBrand = possibleBrand;
      } else {
        _selectedBrand = 'Lainnya';
      }
      if (parts.length > 1) {
        _specsController = TextEditingController(text: parts.skip(1).join('|').trim());
      } else {
        _specsController = TextEditingController(text: '');
      }
    } else {
      _specsController = TextEditingController(text: dbSpecs);
    }

    if (widget.asset?.imagePath != null && widget.asset!.imagePath!.isNotEmpty) {
      _existingImages = widget.asset!.imagePath!.split(',').where((p) => p.trim().isNotEmpty).toList();
    }

    _noteController.text = widget.asset?.note ?? '';
    _selectedStatus = widget.asset?.status ?? 'AVAILABLE';
    _idFocusNode = FocusNode();

    // Parse location
    String dbLoc = widget.asset?.location ?? 'Ruang IT';
    String deskStr = '';
    
    if (dbLoc.startsWith('Floor Lt2')) {
      _selectedLocation = 'Floor Lt2';
      if (dbLoc.contains('Meja')) {
        deskStr = dbLoc.split('Meja').last.trim();
      } else if (dbLoc.length > 'Floor Lt2'.length) {
        deskStr = dbLoc.replaceFirst('Floor Lt2', '').replaceAll('-', '').trim();
      }
    } else if (dbLoc.startsWith('Floor Lt3')) {
      _selectedLocation = 'Floor Lt3';
      if (dbLoc.contains('Meja')) {
        deskStr = dbLoc.split('Meja').last.trim();
      } else if (dbLoc.length > 'Floor Lt3'.length) {
        deskStr = dbLoc.replaceFirst('Floor Lt3', '').replaceAll('-', '').trim();
      }
    } else {
      if (_locations.contains(dbLoc)) {
         _selectedLocation = dbLoc;
      } else {
         _selectedLocation = 'Ruang IT';
      }
    }

    _deskNumberController = TextEditingController(text: deskStr);

    // Auto focus if creating new asset
    if (widget.asset == null || widget.asset!.id.isEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _idFocusNode.requestFocus();
      });
    }

    // Load History Logs if editing an existing asset
    if (widget.asset != null) {
      _loadAssetLogs();
    }
  }

  @override
  void dispose() {
    _idFocusNode.dispose();
    _idController.dispose();
    _deskNumberController.dispose();
    _specsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetLogs() async {
    if (widget.asset == null) return;
    setState(() => _isLoadingLogs = true);
    try {
      final logs = await ApiService.getAssetLogs(widget.asset!.id);
      if (mounted) {
        setState(() {
          _assetLogs = logs;
          _isLoadingLogs = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLogs = false);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          _isProcessingImage = true;
        });
        
        // Add watermark
        File pickedLocalFile = File(image.path);
        File? watermarkedFile = await WatermarkUtils.addWatermarkToImage(pickedLocalFile);

        setState(() {
          _newPickedImages.add(watermarkedFile ?? pickedLocalFile);
          _isProcessingImage = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error mengambil gambar: $e')),
      );
    }
  }

  void _showImageSourceActionSheet() {
    final themeProvider = context.read<ThemeProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: themeProvider.cardBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF60A5FA)),
                title: Text('Ambil Foto Kamera', style: TextStyle(color: themeProvider.primaryTextColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFFA78BFA)),
                title: Text('Pilih dari Galeri', style: TextStyle(color: themeProvider.primaryTextColor)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http')) {
       return NetworkImage(path);
    } else if (path.startsWith('/uploads')) {
       return NetworkImage(ApiService.getImageUrl(path));
    } else {
       return FileImage(File(path));
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const SimpleScannerScreen(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (widget.asset == null && result.contains('/')) {
           List<String> parts = result.split('/');
           if (parts.length >= 3) {
             _selectedIdPrefix = '${parts.first}/';
             _selectedIdSuffix = '/${parts.last}';
             _idController.text = parts.sublist(1, parts.length - 1).join('/');
           } else {
             _idController.text = result;
             _selectedIdPrefix = '';
             _selectedIdSuffix = '';
           }
        } else {
           _idController.text = result;
        }
      });
    }
  }

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate if Photo is selected when Status is REPAIRING
    if (_selectedStatus == 'REPAIRING') {
      bool hasNewPhoto = _newPickedImages.isNotEmpty;
      bool hasExistingPhoto = _existingImages.isNotEmpty;
      
      if (!hasNewPhoto && !hasExistingPhoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto kerusakan WAJIB dilampirkan jika status REPAIRING!'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        return;
      }
    }

    String finalLocation = _selectedLocation;
    if (_selectedLocation.startsWith('Floor')) {
       final deskNum = _deskNumberController.text.trim();
       if (deskNum.isNotEmpty) {
           finalLocation = '$_selectedLocation - Meja $deskNum';
       }
    }

    String finalSpecs = 'Merk: $_selectedBrand';
    if (_computedType == 'PC' && _specsController.text.isNotEmpty) {
      finalSpecs += ' | ${_specsController.text}';
    }
    
    String finalNote = '';
    if (_selectedStatus == 'REPAIRING') {
      finalNote = _noteController.text.trim();
    }

    List<String> combinedPaths = [];
    combinedPaths.addAll(_existingImages);
    for (var f in _newPickedImages) {
      combinedPaths.add(f.path);
    }
    String finalImagePath = combinedPaths.join(',');

    final prefixClean = _selectedIdPrefix.replaceAll('/', '');
    String numberClean = _idController.text.trim();
    numberClean = numberClean.replaceAll(RegExp(r'^(HD|PC|KB|MN|MS|LAP|MINI|AIO)[-/\s]*', caseSensitive: false), '');
    numberClean = numberClean.replaceAll(RegExp(r'/.*$'), '');

    final primaryId = widget.asset == null || widget.asset!.id.isEmpty 
        ? '$prefixClean-$numberClean' 
        : widget.asset!.id;
    
    final legacyCode = '$_selectedIdPrefix$numberClean$_selectedIdSuffix';

    final asset = Asset(
      id: primaryId,
      type: _computedType,
      status: _selectedStatus,
      location: finalLocation,
      specs: finalSpecs,
      legacyInvCode: legacyCode,
      stickerStatus: 'STICKERED',
      imagePath: finalImagePath.isEmpty ? null : finalImagePath,
      note: finalNote.isEmpty ? null : finalNote,
      isSynced: false,
    );

    final dbService = context.read<DatabaseService>();
    final apiService = context.read<ApiService>();

    try {
      // Save to local DB first (upsert)
      try {
        await dbService.insertAsset(asset);
      } catch (_) {
        await dbService.updateAsset(asset);
      }

      // Try to sync to API (try createAsset first, fallback to updateAsset)
      try {
        try {
          await apiService.createAsset(asset);
        } catch (_) {
          await apiService.updateAsset(asset);
        }
        await dbService.markAsSynced(asset.id);
      } catch (e) {
        print('Failed to sync API: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Data aset berhasil disimpan'),
          backgroundColor: Color(0xFF10B981),
        ),
      );

      if (_isBulkMode && widget.asset == null) {
        setState(() {
          _idController.clear();
          _newPickedImages.clear();
        });
        _idFocusNode.requestFocus();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _deleteAsset() async {
    final themeProvider = context.read<ThemeProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: themeProvider.cardBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Aset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Yakin ingin menghapus aset ${widget.asset?.id} ini secara permanen?',
          style: TextStyle(color: themeProvider.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: themeProvider.secondaryTextColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF87171)),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final dbService = context.read<DatabaseService>();
    final apiService = context.read<ApiService>();

    try {
      await dbService.deleteAsset(widget.asset!.id);
      try {
        await apiService.deleteAsset(widget.asset!.id);
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aset berhasil dihapus'), backgroundColor: Color(0xFFEF4444)),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: themeProvider.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackgroundColor,
        elevation: 0,
        systemOverlayStyle: themeProvider.systemOverlayStyle,
        title: Text(
          widget.asset == null ? 'Tambah Aset Baru' : 'Edit Aset: ${widget.asset!.id}',
          style: TextStyle(
            color: themeProvider.primaryTextColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: themeProvider.primaryTextColor, size: 20),
          onPressed: () => Navigator.pop(context, true),
        ),
        actions: widget.asset != null
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171)),
                  tooltip: 'Hapus Aset',
                  onPressed: _deleteAsset,
                ),
              ]
            : null,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) Navigator.pop(context, true);
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            children: [
              // SECTION 1: FOTO ASET
              _buildSectionCard(
                title: 'Foto & Bukti Fisik',
                icon: Icons.photo_camera_rounded,
                accentColor: const Color(0xFF60A5FA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isProcessingImage)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12.0),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent)),
                      ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Existing Images
                          ..._existingImages.map((path) => Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: themeProvider.borderStrokeColor),
                                    image: DecorationImage(
                                      image: _getImageProvider(path),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _existingImages.remove(path);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )),
                          // New Picked Images
                          ..._newPickedImages.map((file) => Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 90,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.6)),
                                    image: DecorationImage(
                                      image: FileImage(file),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _newPickedImages.remove(file);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          )),
                          // Add Button
                          GestureDetector(
                            onTap: _showImageSourceActionSheet,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: themeProvider.inputBackgroundColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: (_selectedStatus == 'REPAIRING' && _existingImages.isEmpty && _newPickedImages.isEmpty)
                                      ? const Color(0xFFF87171)
                                      : themeProvider.borderStrokeColor,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 26,
                                    color: (_selectedStatus == 'REPAIRING' && _existingImages.isEmpty && _newPickedImages.isEmpty)
                                        ? const Color(0xFFF87171)
                                        : themeProvider.secondaryTextColor,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    (_selectedStatus == 'REPAIRING' && _existingImages.isEmpty && _newPickedImages.isEmpty)
                                        ? 'Foto Wajib' : 'Tambah',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (_selectedStatus == 'REPAIRING' && _existingImages.isEmpty && _newPickedImages.isEmpty)
                                          ? const Color(0xFFF87171)
                                          : themeProvider.secondaryTextColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // SECTION 2: IDENTITAS ASET
              _buildSectionCard(
                title: 'Identitas Aset',
                icon: Icons.badge_rounded,
                accentColor: const Color(0xFF38BDF8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.asset == null) ...[
                      // Prefix Chips
                      Text('Pilih Kategori:', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPrefixChip('HS/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('MS/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('PC/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('MINI/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('AIO/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('LAP/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('MON/'),
                            const SizedBox(width: 6),
                            _buildPrefixChip('KB/'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Suffix Chips
                      Text('Tahun Registrasi:', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12)),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSuffixChip('/2024'),
                            const SizedBox(width: 6),
                            _buildSuffixChip('/2025'),
                            const SizedBox(width: 6),
                            _buildSuffixChip('/2026'),
                            const SizedBox(width: 6),
                            _buildSuffixChip('/2027'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Input Asset ID Display / Field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: themeProvider.inputBackgroundColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeProvider.borderStrokeColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getTypeIcon(_computedType),
                            color: const Color(0xFF60A5FA),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          if (widget.asset == null) ...[
                            Text(
                              _selectedIdPrefix, 
                              style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 17)
                            ),
                            Container(
                              width: 80,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: TextFormField(
                                controller: _idController,
                                focusNode: _idFocusNode,
                                keyboardType: TextInputType.number,
                                style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 17),
                                decoration: InputDecoration(
                                  isDense: true,
                                  hintText: '2393',
                                  hintStyle: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.5)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                                  border: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent, width: 2)),
                                ),
                                validator: (val) => (val == null || val.isEmpty) ? 'Wajib isi' : null,
                              ),
                            ),
                            Text(
                              _selectedIdSuffix, 
                              style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 17)
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.blueAccent),
                              onPressed: _scanBarcode,
                            ),
                          ] else ...[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.asset!.id,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: themeProvider.primaryTextColor, fontSize: 18),
                                  ),
                                  if (widget.asset!.legacyInvCode != null && widget.asset!.legacyInvCode!.isNotEmpty)
                                    Text(
                                      'Kode Stiker: ${widget.asset!.legacyInvCode}',
                                      style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF60A5FA).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _computedType,
                                style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Merk / Brand Dropdown
                    _buildDropdownField<String>(
                      label: 'Merk / Brand',
                      value: _selectedBrand,
                      icon: Icons.branding_watermark_rounded,
                      items: _brands.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedBrand = val);
                      },
                    ),
                  ],
                ),
              ),

              // SECTION 3: STATUS & LOKASI
              _buildSectionCard(
                title: 'Status & Lokasi Unit',
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFFFACC15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status Kondisi Aset:', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statuses.map((s) {
                        final isSelected = _selectedStatus == s;
                        final sColor = _getStatusColor(s);
                        return ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : sColor),
                              ),
                              const SizedBox(width: 6),
                              Text(s),
                            ],
                          ),
                          selected: isSelected,
                          selectedColor: sColor,
                          backgroundColor: themeProvider.inputBackgroundColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : themeProvider.primaryTextColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: isSelected ? sColor : themeProvider.borderStrokeColor,
                              width: 1.2,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedStatus = s);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Location Group
                    if (_selectedStatus != 'REPAIRING') ...[
                      _buildDropdownField<String>(
                        label: 'Lokasi Penempatan',
                        value: _selectedLocation,
                        icon: Icons.place_rounded,
                        items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedLocation = val);
                        },
                      ),
                      if (_selectedLocation.startsWith('Floor')) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _deskNumberController,
                          style: TextStyle(color: themeProvider.primaryTextColor),
                          decoration: InputDecoration(
                            labelText: 'Nomor Meja',
                            hintText: 'Contoh: 12 atau Meja 4',
                            hintStyle: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.6)),
                            labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
                            prefixIcon: const Icon(Icons.table_restaurant_rounded, color: Color(0xFF38BDF8), size: 20),
                            filled: true,
                            fillColor: themeProvider.inputBackgroundColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),

              // SECTION 4: SPESIFIKASI & CATATAN
              _buildSectionCard(
                title: 'Spesifikasi & Detail',
                icon: Icons.description_rounded,
                accentColor: const Color(0xFFA78BFA),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _specsController,
                      style: TextStyle(color: themeProvider.primaryTextColor),
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Spesifikasi / Keterangan',
                        hintText: 'Misal: Core i5, RAM 16GB, SSD 512GB...',
                        hintStyle: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.6)),
                        labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
                        prefixIcon: const Icon(Icons.memory_rounded, color: Color(0xFFA78BFA), size: 20),
                        filled: true,
                        fillColor: themeProvider.inputBackgroundColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                      ),
                    ),

                    if (_selectedStatus == 'REPAIRING') ...[
                      const SizedBox(height: 14),
                      Text('Tag Kerusakan Cepat:', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _currentRepairNotes.map((note) {
                          return ActionChip(
                            label: Text(note, style: TextStyle(fontSize: 11, color: themeProvider.primaryTextColor)),
                            backgroundColor: const Color(0xFFFB923C).withValues(alpha: 0.2),
                            side: const BorderSide(color: Color(0xFFFB923C), width: 0.8),
                            onPressed: () {
                              setState(() {
                                if (_noteController.text.isEmpty) {
                                  _noteController.text = note;
                                } else if (!_noteController.text.contains(note)) {
                                  _noteController.text = '${_noteController.text}, $note';
                                }
                                _noteController.selection = TextSelection.fromPosition(
                                  TextPosition(offset: _noteController.text.length),
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _noteController,
                        style: TextStyle(color: themeProvider.primaryTextColor),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Detail Catatan Kerusakan',
                          hintText: 'Misal: Layar kedip-kedip, port USB longgar',
                          hintStyle: TextStyle(color: themeProvider.secondaryTextColor.withValues(alpha: 0.6)),
                          labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
                          prefixIcon: const Icon(Icons.build_rounded, color: Color(0xFFFB923C), size: 20),
                          filled: true,
                          fillColor: themeProvider.inputBackgroundColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Bulk Add Checkbox (Only if New Asset)
              if (widget.asset == null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: themeProvider.cardBackgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeProvider.borderStrokeColor),
                  ),
                  child: CheckboxListTile(
                    title: Text('Mode Input Berurutan (Bulk Add)', style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('Simpan & langsung siapkan form aset berikutnya', style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 11)),
                    value: _isBulkMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => setState(() => _isBulkMode = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),

              // TOMBOL SIMPAN
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveAsset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        widget.asset == null ? 'Simpan Aset Baru' : 'Simpan Perubahan',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              // SECTION 5: LOG HISTORY (Hanya tampil saat Edit Asset)
              if (widget.asset != null)
                _buildSectionCard(
                  title: 'Riwayat Aktivitas & Audit',
                  icon: Icons.history_rounded,
                  accentColor: const Color(0xFFA855F7),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_assetLogs.length} catatan',
                          style: const TextStyle(color: Color(0xFFA855F7), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: _isLoadingLogs 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA855F7)))
                            : const Icon(Icons.refresh_rounded, color: Color(0xFFA855F7), size: 18),
                        onPressed: _isLoadingLogs ? null : _loadAssetLogs,
                        tooltip: 'Muat Ulang Log',
                      ),
                    ],
                  ),
                  child: _isLoadingLogs
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFA855F7))),
                        )
                      : _assetLogs.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.history_toggle_off_rounded, color: themeProvider.secondaryTextColor.withValues(alpha: 0.5), size: 40),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Belum ada catatan aktivitas untuk aset ini.',
                                    style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 13),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _assetLogs.asMap().entries.map((entry) {
                                final index = entry.key;
                                final log = entry.value;
                                final isLast = index == _assetLogs.length - 1;
                                return _buildLogTimelineItem(log, isLast: isLast);
                              }).toList(),
                            ),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color accentColor = const Color(0xFF60A5FA),
    Widget? trailing,
  }) {
    final themeProvider = context.watch<ThemeProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: themeProvider.cardBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: themeProvider.borderStrokeColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: themeProvider.primaryTextColor,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final themeProvider = context.watch<ThemeProvider>();

    return DropdownButtonFormField<T>(
      value: value,
      dropdownColor: themeProvider.cardBackgroundColor,
      style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: themeProvider.secondaryTextColor),
        prefixIcon: Icon(icon, color: const Color(0xFF60A5FA), size: 20),
        filled: true,
        fillColor: themeProvider.inputBackgroundColor,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: themeProvider.borderStrokeColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildLogTimelineItem(Map<String, dynamic> log, {required bool isLast}) {
    final themeProvider = context.watch<ThemeProvider>();
    final action = (log['action'] ?? '').toString().toUpperCase();
    final user = log['user'] ?? 'System';
    final details = log['details'] ?? '';
    final source = log['source'] ?? '';
    final timestampStr = log['timestamp'] ?? '';

    DateTime? dt;
    try {
      if (timestampStr.isNotEmpty) {
        dt = DateTime.parse(timestampStr).toLocal();
      }
    } catch (_) {}

    final formattedTime = dt != null 
        ? DateFormat('dd MMM yyyy, HH:mm').format(dt)
        : timestampStr;

    Color actionColor = const Color(0xFF60A5FA); // blue
    if (action.contains('AUDIT')) {
      actionColor = const Color(0xFF4ADE80); // green
    } else if (action.contains('DELETE')) {
      actionColor = const Color(0xFFF87171); // red
    } else if (action.contains('SCAN')) {
      actionColor = const Color(0xFFA78BFA); // purple
    } else if (action.contains('UPDATE') || action.contains('EDIT')) {
      actionColor = const Color(0xFFFACC15); // yellow
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: actionColor,
                  boxShadow: [
                    BoxShadow(color: actionColor.withValues(alpha: 0.4), blurRadius: 4),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: themeProvider.borderStrokeColor,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: themeProvider.inputBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.borderStrokeColor, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              action,
                              style: TextStyle(color: actionColor, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            user,
                            style: TextStyle(color: themeProvider.primaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (source.isNotEmpty)
                        Text(
                          source.toString().toUpperCase(),
                          style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 10),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    details,
                    style: TextStyle(color: themeProvider.primaryTextColor.withValues(alpha: 0.85), fontSize: 12, height: 1.3),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: themeProvider.secondaryTextColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        formattedTime,
                        style: TextStyle(color: themeProvider.secondaryTextColor, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrefixChip(String prefix) {
    final themeProvider = context.watch<ThemeProvider>();
    bool isSelected = _selectedIdPrefix == prefix;
    return ActionChip(
      label: Text(prefix),
      onPressed: () {
        setState(() {
          _selectedIdPrefix = prefix;
          _idFocusNode.requestFocus();
        });
      },
      backgroundColor: isSelected ? const Color(0xFF2563EB) : themeProvider.inputBackgroundColor,
      side: BorderSide(color: isSelected ? const Color(0xFF60A5FA) : themeProvider.borderStrokeColor),
      labelStyle: TextStyle(color: isSelected ? Colors.white : themeProvider.primaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSuffixChip(String suffix) {
    final themeProvider = context.watch<ThemeProvider>();
    bool isSelected = _selectedIdSuffix == suffix;
    return ActionChip(
      label: Text(suffix),
      onPressed: () {
        setState(() {
          _selectedIdSuffix = suffix;
          _idFocusNode.requestFocus();
        });
      },
      backgroundColor: isSelected ? const Color(0xFF0D9488) : themeProvider.inputBackgroundColor,
      side: BorderSide(color: isSelected ? const Color(0xFF2DD4BF) : themeProvider.borderStrokeColor),
      labelStyle: TextStyle(color: isSelected ? Colors.white : themeProvider.primaryTextColor, fontSize: 12, fontWeight: FontWeight.w600),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'AVAILABLE': return const Color(0xFF4ADE80); // Green 400
      case 'IN_USE': return const Color(0xFFFACC15); // Yellow 400
      case 'BROKEN': return const Color(0xFFF87171); // Red 400
      case 'REPAIRING': return const Color(0xFFFB923C); // Orange 400
      case 'GHOST': return const Color(0xFFA78BFA); // Violet 400
      default: return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PC':
      case 'CPU': return Icons.computer_rounded;
      case 'LAPTOP':
      case 'LAP': return Icons.laptop_rounded;
      case 'MONITOR':
      case 'MN': return Icons.monitor_rounded;
      case 'KEYBOARD':
      case 'KB': return Icons.keyboard_rounded;
      case 'MOUSE':
      case 'MS': return Icons.mouse_rounded;
      case 'HEADSET':
      case 'HD':
      case 'HS': return Icons.headset_rounded;
      default: return Icons.devices_rounded;
    }
  }
}
