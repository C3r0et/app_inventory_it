import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../models/asset.dart';

class QuickAuditModal extends StatefulWidget {
  final Map<String, dynamic> assetData;
  final String serverUrl;

  const QuickAuditModal({
    super.key,
    required this.assetData,
    required this.serverUrl,
  });

  @override
  State<QuickAuditModal> createState() => _QuickAuditModalState();
}

class _QuickAuditModalState extends State<QuickAuditModal> {
  late String _selectedLocation;
  late String _selectedStatus;
  late String _selectedStickerStatus;
  bool _dustCleaned = false;
  bool _showPartFlashback = false;

  late String _partName;
  String _partAction = 'REPLACED';
  final TextEditingController _oldSpecController = TextEditingController();
  final TextEditingController _newSpecController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _techController = TextEditingController(text: 'TIM IT');

  bool _isSubmitting = false;

  final List<String> _locations = [
    'Ruang IT',
    'Collection Floor Lantai 2',
    'Collection Floor Lantai 3',
    'Ruang Management Lantai 3',
  ];

  bool get _isCpuDevice {
    String type = (widget.assetData['type'] ?? '').toUpperCase();
    return type.contains('PC') || type.contains('CPU') || type.contains('LAP') || type.contains('AIO');
  }

  List<String> get _dynamicPartOptions {
    String type = (widget.assetData['type'] ?? '').toUpperCase();
    if (type.contains('HEADSET') || type.contains('HD') || type.contains('HS')) {
      return [
        'Kabel Headset',
        'Microphone / Mic',
        'Speaker / Driver Audio (Kanibal)',
        'Busa / Earpad',
        'Lainnya (Headset)',
      ];
    } else if (type.contains('MOUSE') || type.contains('MS')) {
      return [
        'Kabel Mouse (Putus)',
        'Switch Tombol Klik (Click Button)',
        'Scroll Wheel',
        'Lainnya (Mouse)',
      ];
    } else if (type.contains('KEYBOARD') || type.contains('KB')) {
      return [
        'Dikeringkan (Tersiram Basah)',
        'Keycap / Tombol',
        'Kabel Keyboard',
        'Lainnya (Keyboard)',
      ];
    }
    return [
      'Fan Processor',
      'Power Supply (PSU)',
      'RAM Memory',
      'SSD / HDD Storage',
      'Baterai CMOS',
      'Motherboard',
      'VGA / Graphic Card',
      'Lainnya (CPU)',
    ];
  }

  String get _partFlashbackTitle {
    String type = (widget.assetData['type'] ?? '').toUpperCase();
    if (type.contains('HEADSET') || type.contains('HD')) return '⚙️ Catat Perbaikan Headset';
    if (type.contains('MOUSE') || type.contains('MS')) return '⚙️ Catat Perbaikan Mouse';
    if (type.contains('KEYBOARD') || type.contains('KB')) return '⚙️ Catat Perbaikan Keyboard';
    return '⚙️ Catat / Flashback Pergantian Part CPU';
  }

  String get _partFlashbackSubtitle {
    String type = (widget.assetData['type'] ?? '').toUpperCase();
    if (type.contains('HEADSET') || type.contains('HD')) return 'Centang jika pernah perbaiki Mic, Kabel, Speaker kanibal, atau Busa';
    if (type.contains('MOUSE') || type.contains('MS')) return 'Centang jika pernah ganti Kabel putus atau Switch Klik Button';
    if (type.contains('KEYBOARD') || type.contains('KB')) return 'Centang jika pernah dikeringkan karena basah atau ganti keycap';
    return 'Centang jika pernah ganti Fan, RAM, SSD, PSU, CMOS, dll';
  }

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.assetData['location'] ?? 'Ruang IT';
    if (!_locations.contains(_selectedLocation)) {
      _locations.add(_selectedLocation);
    }
    _selectedStatus = widget.assetData['status'] ?? 'IN_USE';
    _selectedStickerStatus = widget.assetData['sticker_status'] ?? 'STICKERED';
    _partName = _dynamicPartOptions.first;
  }

  Future<void> _submitAudit() async {
    setState(() {
      _isSubmitting = true;
    });

    final assetId = widget.assetData['id'];
    final base = widget.serverUrl.endsWith('/api') 
        ? widget.serverUrl 
        : '${widget.serverUrl}/api';
    final url = Uri.parse('$base/assets/audit-submit');

    Map<String, dynamic> payload = {
      'asset_id': assetId,
      'location': _selectedLocation,
      'status': _selectedStatus,
      'sticker_status': _selectedStickerStatus,
      'dust_cleaned': _isCpuDevice ? _dustCleaned : false,
      'technician': _techController.text.trim(),
      'notes': _notesController.text.trim(),
    };

    if (_showPartFlashback) {
      payload['part_replacement'] = {
        'part_name': _partName,
        'action_type': _partAction,
        'old_spec': _oldSpecController.text.trim(),
        'new_spec': _newSpecController.text.trim(),
        'reason': _reasonController.text.trim(),
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Audit & Riwayat perbaikan berhasil disimpan!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception('Status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // OFFLINE FALLBACK: Save locally to SQLite when network connection fails or times out
      try {
        final dbService = context.read<DatabaseService>();
        final asset = Asset(
          id: assetId,
          type: widget.assetData['type'] ?? 'CPU',
          status: _selectedStatus,
          location: _selectedLocation,
          specs: widget.assetData['specs'],
          legacyInvCode: widget.assetData['legacy_inv_code'],
          stickerStatus: _selectedStickerStatus,
          note: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
          isSynced: false,
        );
        await dbService.insertAsset(asset);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📱 Sinyal Buruk / Offline: Audit tersimpan di HP! Akan otomatis sync saat internet stabil.'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (dbErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menyimpan audit: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetId = widget.assetData['id'] ?? '-';
    final legacyCode = widget.assetData['legacy_inv_code'] ?? '';
    final assetType = widget.assetData['type'] ?? 'Aset';

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audit Lapangan: $assetId',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (legacyCode.isNotEmpty)
                      Text(
                        'Stiker GA: $legacyCode',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    assetType,
                    style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            const SizedBox(height: 10),

            // 1. Lokasi Aset
            const Text('📍 Lokasi Saat Ini', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: _selectedLocation,
              dropdownColor: const Color(0xFF0F172A),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              items: _locations.map((loc) {
                return DropdownMenuItem(value: loc, child: Text(loc));
              }).toList(),
              onChanged: (val) => setState(() => _selectedLocation = val!),
            ),
            const SizedBox(height: 12),

            // 2. Kondisi Operasional
            const Text('⚙️ Kondisi Aset', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Terpakai'),
                    selected: _selectedStatus == 'IN_USE',
                    selectedColor: Colors.blue,
                    onSelected: (selected) => setState(() => _selectedStatus = 'IN_USE'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Normal (Stok)'),
                    selected: _selectedStatus == 'AVAILABLE',
                    selectedColor: Colors.green,
                    onSelected: (selected) => setState(() => _selectedStatus = 'AVAILABLE'),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Rusak'),
                    selected: _selectedStatus == 'BROKEN',
                    selectedColor: Colors.red,
                    onSelected: (selected) => setState(() => _selectedStatus = 'BROKEN'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Stiker GA Status
            SwitchListTile(
              title: const Text('🏷️ Stiker GA Fisik Tertempel', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(
                _selectedStickerStatus == 'STICKERED' ? 'Sudah ditempel stiker oleh GA' : 'Belum ditempel stiker',
                style: TextStyle(color: _selectedStickerStatus == 'STICKERED' ? Colors.greenAccent : Colors.amberAccent),
              ),
              value: _selectedStickerStatus == 'STICKERED',
              onChanged: (val) {
                setState(() {
                  _selectedStickerStatus = val ? 'STICKERED' : 'UNSTICKERED';
                });
              },
            ),

            // 4. Pembersihan Debu Bulanan IT (Khusus CPU)
            if (_isCpuDevice)
              CheckboxListTile(
                title: const Text('🧹 Telah Dibersihkan dari Debu (Bulan Ini)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('Pembersihan debu rutin bulanan CPU oleh Tim IT', style: TextStyle(color: Colors.white54, fontSize: 12)),
                value: _dustCleaned,
                activeColor: Colors.green,
                onChanged: (val) => setState(() => _dustCleaned = val ?? false),
              )
            else
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text('ℹ️ Pembersihan debu bulanan khusus untuk perangkat CPU / PC.', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
            const SizedBox(height: 10),

            // 5. Form Flashback Perbaikan / Ganti Part
            CheckboxListTile(
              title: Text(_partFlashbackTitle, style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Text(_partFlashbackSubtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              value: _showPartFlashback,
              activeColor: Colors.amber,
              onChanged: (val) => setState(() => _showPartFlashback = val ?? false),
            ),

            if (_showPartFlashback) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Komponen / Jenis Perbaikan', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    DropdownButtonFormField<String>(
                      value: _partName,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      items: _dynamicPartOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (v) => setState(() => _partName = v!),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _oldSpecController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Part Lama / Kondisi Awal (contoh: Kabel Putus / Mic Bawaan)',
                        labelStyle: TextStyle(color: Colors.white60),
                      ),
                    ),
                    TextField(
                      controller: _newSpecController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Part Baru / Hasil Perbaikan (contoh: Ganti Kabel / Kanibal Mic)',
                        labelStyle: TextStyle(color: Colors.white60),
                      ),
                    ),
                    TextField(
                      controller: _reasonController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Alasan / Catatan (contoh: Kebasahan / Mati sebelah)',
                        labelStyle: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitAudit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Simpan Audit & History Perbaikan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
