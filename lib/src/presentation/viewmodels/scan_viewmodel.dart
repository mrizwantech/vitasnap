/// ViewModel for scanning flows (MVVM).
///
library;
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_product_by_barcode.dart';
import '../../domain/usecases/add_scan_result.dart';
import '../../domain/usecases/get_recent_scans.dart';
import '../../domain/usecases/compute_health_score.dart';
import '../../domain/entities/scan_result.dart';

class ScanViewModel extends ChangeNotifier {
	final GetProductByBarcode _getProduct;
	final AddScanResult _addScan;
	final GetRecentScans _getRecent;
	final ComputeHealthScore _computeScore;
	ScanViewModel(this._getProduct, this._addScan, this._getRecent, this._computeScore);

	bool _loading = false;
	bool get loading => _loading;

	Product? _product;
	Product? get product => _product;

	String? _error;
	String? get error => _error;

	ScanResult? _lastScan;
	ScanResult? get lastScan => _lastScan;

	Future<bool> fetchByBarcode(String barcode) async {
		_loading = true;
		_error = null;
		notifyListeners();
		try {
			developer.log('[ScanViewModel] fetchByBarcode: $barcode', name: 'ScanViewModel');
			final p = await _getProduct(barcode);
			developer.log('[ScanViewModel] product received: ${p.name}', name: 'ScanViewModel');
			_product = p;
			// compute score and persist
			final score = _computeScore(p);
			final scan = ScanResult(product: p, score: score);
			await _addScan(scan);
			_lastScan = scan;
			return true;
		} catch (e) {
			developer.log('[ScanViewModel] fetch error: $e', name: 'ScanViewModel');
			_error = e.toString();
			_product = null;
			return false;
		} finally {
			_loading = false;
			notifyListeners();
		}
	}

	Future<List<ScanResult>> recentScans({int limit = 10}) => _getRecent(limit: limit);
}
