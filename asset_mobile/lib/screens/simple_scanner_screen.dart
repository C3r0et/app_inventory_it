import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/audio_service.dart';
import '../widgets/scanner_overlay.dart';
import 'text_scanner_screen.dart';

class SimpleScannerScreen extends StatefulWidget {
  const SimpleScannerScreen({super.key});

  @override
  State<SimpleScannerScreen> createState() => _SimpleScannerScreenState();
}

class _SimpleScannerScreenState extends State<SimpleScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isScanned = false;
  bool _isBoxShape = true; // true = Square (QR), false = Rect (Barcode)

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        AudioService.playSuccess();
        setState(() => _isScanned = true);
        Navigator.pop(context, barcode.rawValue);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _cameraController.switchCamera(),
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
            icon: const Icon(Icons.text_fields),
            onPressed: () async {
              setState(() => _isScanned = true);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TextScannerScreen()),
              );
              if (result != null && result is String) {
                if (mounted) Navigator.pop(context, result);
              } else {
                setState(() => _isScanned = false);
              }
            },
            tooltip: 'Scan Text ID',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),
          ScannerOverlay(
            overlayAspectRatio: _isBoxShape ? 1.0 : 2.0,
          ),
        ],
      )
    );
  }
}
