import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/scanner_overlay.dart';

class BulkScanScreen extends StatefulWidget {
  const BulkScanScreen({super.key});

  @override
  State<BulkScanScreen> createState() => _BulkScanScreenState();
}

class _BulkScanScreenState extends State<BulkScanScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  final List<String> _scannedCodes = [];
  bool _isProcessing = false;
  bool _isBoxShape = true; // true = Square (QR), false = Rect (Barcode)

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _addScannedCode(barcode.rawValue!);
      }
    }
  }

  void _addScannedCode(String code) {
    if (_scannedCodes.contains(code)) {
      // DUPLICATE
      AudioService.playDuplicate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Already Scanned: $code'),
          backgroundColor: Colors.orange,
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      // SUCCESS
      setState(() {
        _scannedCodes.add(code);
      });
      AudioService.playSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added: $code'),
          backgroundColor: Colors.green,
          duration: const Duration(milliseconds: 500),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showActionModal() {
    _cameraController.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BulkActionSheet(
        scannedCodes: _scannedCodes,
        onReset: () {
          setState(() {
            _scannedCodes.clear();
          });
          _cameraController.start();
        },
        onRestartCamera: () {
          _cameraController.start();
        },
        onRemove: (code) {
          setState(() {
            _scannedCodes.remove(code);
          });
        },
      ),
    ).then((_) => _cameraController.start());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bulk Scan (${_scannedCodes.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: Icon(
              _isBoxShape ? Icons.crop_square : Icons.crop_16_9,
            ),
            onPressed: () {
              setState(() {
                _isBoxShape = !_isBoxShape;
              });
            },
            tooltip: 'Toggle Scan Shape',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showActionModal,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          
          // Scanner Overlay
          ScannerOverlay(
            overlayAspectRatio: _isBoxShape ? 1.0 : 2.0,
          ),
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: _scannedCodes.isEmpty ? null : _showActionModal,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Process ${_scannedCodes.length} Assets',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showManualEntryDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.keyboard),
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController manualController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Asset ID'),
        content: TextField(
          controller: manualController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. PC-001',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              Navigator.pop(context);
              _addScannedCode(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (manualController.text.isNotEmpty) {
                Navigator.pop(context);
                _addScannedCode(manualController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _BulkActionSheet extends StatefulWidget {
  final List<String> scannedCodes;
  final VoidCallback onReset;
  final VoidCallback onRestartCamera;
  final Function(String) onRemove;

  const _BulkActionSheet({
    required this.scannedCodes,
    required this.onReset,
    required this.onRestartCamera,
    required this.onRemove,
  });

  @override
  State<_BulkActionSheet> createState() => _BulkActionSheetState();
}

class _BulkActionSheetState extends State<_BulkActionSheet> {
  final List<String> _statuses = ['AVAILABLE', 'IN_USE', 'BROKEN', 'GHOST'];
  bool _isSubstituting = false;
  
  // Action Selection
  String? _selectedAction; // 'STATUS' or 'LOCATION'
  String? _targetStatus;
  final TextEditingController _locationController = TextEditingController();

  Future<void> _executeBulkAction() async {
    if (_selectedAction == null) return;

    setState(() => _isSubstituting = true);
    
    try {
      if (_selectedAction == 'STATUS' && _targetStatus != null) {
        await ApiService.bulkUpdateStatus(widget.scannedCodes, _targetStatus!);
      } else if (_selectedAction == 'LOCATION' && _locationController.text.isNotEmpty) {
        await ApiService.bulkUpdateLocation(widget.scannedCodes, _locationController.text);
      } else {
        throw Exception('Please fill all fields');
      }

      if (mounted) {
        Navigator.pop(context); // Close sheet
        Navigator.pop(context); // Close scanner screen to return to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bulk operation successful!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubstituting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Scanned Items: ${widget.scannedCodes.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
          const Divider(),
          
          // List Preview (Limited to 5 items)
          SizedBox(
            height: 100,
            child: ListView.builder(
              itemCount: widget.scannedCodes.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.scannedCodes[index])),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () {
                          widget.onRemove(widget.scannedCodes[index]);
                          setState(() {}); // Refresh local list view
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          
          const Text('Select Action:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Row(
            children: [
              Expanded(
                child: _buildTypeButton('Update Status', 'STATUS', Icons.info),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTypeButton('Move Location', 'LOCATION', Icons.location_on),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Dynamic Inputs based on Action
          if (_selectedAction == 'STATUS') ...[
            DropdownButtonFormField<String>(
              value: _targetStatus,
              decoration: const InputDecoration(
                labelText: 'New Status',
                border: OutlineInputBorder(),
              ),
              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _targetStatus = v),
            ),
          ],
          
          if (_selectedAction == 'LOCATION') ...[
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'New Location',
                hintText: 'Scan or type location',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
          
          const SizedBox(height: 20),
          
          if (_isSubstituting)
            const Center(child: CircularProgressIndicator())
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedAction == null ? null : _executeBulkAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('EXECUTE BULK ACTION'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, IconData icon) {
    final isSelected = _selectedAction == value;
    return InkWell(
      onTap: () => setState(() => _selectedAction = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
