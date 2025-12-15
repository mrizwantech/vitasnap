import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../viewmodels/scan_viewmodel.dart';
import '../views/product_not_found_page.dart';
import '../views/product_details_page.dart';
import 'vitasnap_logo.dart';

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
        appBar: AppBar(title: const VitaSnapLogo(fontSize: 20)),
        body: const Center(child: Text('Camera scanning is not supported on web in this demo.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const VitaSnapLogo(fontSize: 20)),
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
              final navigator = Navigator.of(context);
              final vm = context.read<ScanViewModel>();
              
              try {
                developer.log('[Scanner] fetching barcode: $raw', name: 'vitasnap.scanner');
                final scanResult = await vm.fetchByBarcode(raw);
                
                // Stop camera before navigating
                try {
                  await _controller.stop();
                } catch (_) {}
                
                if (scanResult == null) {
                  // Product not found - navigate to not found page
                  if (mounted) {
                    navigator.pushReplacement(
                      MaterialPageRoute(builder: (_) => ProductNotFoundPage(barcode: raw)),
                    );
                  }
                  return;
                }
                
                // Product found - navigate to details page
                if (mounted) {
                  final result = await navigator.push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsPage(scanResult: scanResult),
                    ),
                  );
                  
                  // If user added the product, save it and return result to home
                  if (result != null && result['added'] == true) {
                    await vm.addToHistory(scanResult);
                    // Pop scanner back to home with the result
                    if (mounted) {
                      navigator.pop({'added': true});
                    }
                  } else {
                    // User didn't add - just go back to home
                    if (mounted) {
                      navigator.pop();
                    }
                  }
                }
              } catch (e) {
                developer.log('[Scanner] error: $e', name: 'vitasnap.scanner');
                _isProcessing = false;
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
