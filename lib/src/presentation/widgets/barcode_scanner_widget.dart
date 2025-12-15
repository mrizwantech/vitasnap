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
  bool _isProcessing = false;

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
            onDetect: (capture) async {
              if (_isProcessing) return;
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isEmpty) return;
              final raw = barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;

              _isProcessing = true;
              // Capture local references before awaiting to avoid depending on
              // an invalid BuildContext later on.
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              final vm = context.read<ScanViewModel>();
              try {
                final ok = await vm.fetchByBarcode(raw);
                if (!ok) {
                  messenger.showSnackBar(SnackBar(content: Text('Scan error: ${vm.error}')));
                  // allow retrying by resetting the processing flag
                  _isProcessing = false;
                } else {
                  // On success, try to pop. If the route wasn't popped (maybePop
                  // returns false), stop the camera to avoid duplicate lookups.
                  bool popped = false;
                  if (mounted) {
                    try {
                      popped = await navigator.maybePop();
                    } catch (_) {
                      // swallow navigation errors - we don't want the app to crash
                    }
                  }
                  if (!popped) {
                    // Stop the camera stream; keep _isProcessing true so we don't
                    // process further detections on this screen.
                    try {
                      await _controller.stop();
                    } catch (_) {}
                  }
                }
              } finally {
                // only reset when we intend to allow retries (handled above)
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
