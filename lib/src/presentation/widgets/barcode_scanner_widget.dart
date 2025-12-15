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
class BarcodeScannerWidget extends StatelessWidget {
  const BarcodeScannerWidget({super.key});

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
      body: MobileScanner(
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
    );
  }
}
