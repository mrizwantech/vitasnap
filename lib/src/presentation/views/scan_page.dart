import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/scan_viewmodel.dart';
import '../widgets/barcode_scanner_widget.dart';

/// Scan page: barcode scanner UI and scan actions.
///
/// Minimal implementation: a text field for barcode input (works on all platforms)
/// and a button to fetch product data from Open Food Facts.
class ScanPage extends StatefulWidget {
	const ScanPage({super.key});

	@override
	State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
	final _controller = TextEditingController();

	@override
	Widget build(BuildContext context) {
		final vm = context.watch<ScanViewModel>();
		return Scaffold(
			appBar: AppBar(title: const Text('Scan / Search')),
			body: Padding(
				padding: const EdgeInsets.all(16.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						TextField(
							controller: _controller,
							decoration: const InputDecoration(labelText: 'Barcode or UPC'),
							keyboardType: TextInputType.number,
						),
						const SizedBox(height: 12),
						Row(
							children: [
								Expanded(
									child: ElevatedButton.icon(
										onPressed: vm.loading
												? null
												: () => vm.fetchByBarcode(_controller.text.trim()),
										icon: const Icon(Icons.search),
										label: vm.loading ? const Text('Searching...') : const Text('Search'),
									),
								),
								const SizedBox(width: 8),
								ElevatedButton.icon(
									onPressed: () async {
											// Open camera scanner
											await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BarcodeScannerWidget()));
									},
									icon: const Icon(Icons.camera_alt),
									label: const Text('Use Camera'),
								),
							],
						),
						const SizedBox(height: 20),
						if (vm.error != null) Text('Error: ${vm.error}', style: const TextStyle(color: Colors.red)),
						if (vm.product != null) ...[
							Text(vm.product!.name, style: Theme.of(context).textTheme.titleLarge),
							const SizedBox(height: 8),
							Text('Brand: ${vm.product!.brand}'),
							if (vm.product!.imageUrl != null) Padding(
								padding: const EdgeInsets.only(top: 8.0),
								child: Image.network(vm.product!.imageUrl!),
							),
							const SizedBox(height: 8),
							Text(vm.product!.ingredients ?? 'No ingredients data'),
						]
					],
				),
			),
		);
	}
}
