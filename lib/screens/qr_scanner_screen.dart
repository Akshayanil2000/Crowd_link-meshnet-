import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/auth_service.dart';
import '../main.dart';

class QrScannerScreen extends StatefulWidget {
  final void Function(String meshId) onScanned;
  const QrScannerScreen({super.key, required this.onScanned});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool _scanned = false;
  final MobileScannerController _ctrl = MobileScannerController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw != null && raw.startsWith('CROWDLINK:')) {
      _scanned = true;
      final meshId = raw.replaceFirst('CROWDLINK:', '');
      _ctrl.stop();
      widget.onScanned(meshId);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Friend\'s QR Code'),
        leading: const BackButton(),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          // Overlay frame
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0, right: 0,
            child: Center(
              child: Text(
                'Point camera at a CrowdLink QR code',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
