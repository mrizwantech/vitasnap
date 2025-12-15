import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../viewmodels/scan_viewmodel.dart';

/// A simple camera-based barcode scanner that works on mobile platforms.
///
/// Behavior:
/// - When a barcode is detected, the widget pops and forwards the code to
///   the `ScanViewModel` to trigger a lookup.
class BarcodeScannerWidget extends StatefulWidget {
  const BarcodeScannerWidget({super.key});

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final MobileScannerController _controller = MobileScannerController();
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show a helpful fallback if camera isn't available (e.g., web/desktop).
    if (kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scanner')),
        body: const Center(child: Text('Camera scanning is not supported on web in this demo.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final raw = barcodes.first.rawValue;
                if (raw != null && raw.isNotEmpty) {
                  // Forward to ViewModel and close scanner
                  context.read<ScanViewModel>().fetchByBarcode(raw);
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    // Toggle torch to help on dark previews
                    await _controller.toggleTorch();
                    setState(() => _torchOn = !_torchOn);
                  },
                  icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
                  label: Text(_torchOn ? 'Torch On' : 'Torch Off'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    await _controller.switchCamera();
                  },
                  icon: const Icon(Icons.cameraswitch),
                  label: const Text('Switch'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
