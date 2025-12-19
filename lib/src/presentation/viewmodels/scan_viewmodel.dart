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
import '../../core/services/cloud_sync_service.dart';

class ScanViewModel extends ChangeNotifier {
	final GetProductByBarcode _getProduct;
	final AddScanResult _addScan;
	final GetRecentScans _getRecent;
	final ComputeHealthScore _computeScore;
	CloudSyncService? _cloudSyncService;
	
	ScanViewModel(this._getProduct, this._addScan, this._getRecent, this._computeScore);

	/// Callback for when scan history is restored from cloud
	VoidCallback? onScanHistoryRestored;

	/// Set the cloud sync service for auto-syncing scans
	void setCloudSyncService(CloudSyncService service) {
		_cloudSyncService = service;
	}

	bool _loading = false;
	bool get loading => _loading;

	Product? _product;
	Product? get product => _product;

	String? _error;
	String? get error => _error;

	ScanResult? _lastScan;
	ScanResult? get lastScan => _lastScan;

	/// Outcome of a barcode fetch.
	///
	/// Returns a ScanResult if successful (not persisted yet), null if failed.
	/// Call `addToHistory` to persist the scan after user confirms.
	Future<ScanResult?> fetchByBarcode(String barcode) async {
		_loading = true;
		_error = null;
		notifyListeners();
		try {
			developer.log('[ScanViewModel] fetchByBarcode: $barcode', name: 'ScanViewModel');
			final p = await _getProduct(barcode);
			developer.log('[ScanViewModel] product received: ${p.name}', name: 'ScanViewModel');
			_product = p;
			// compute score but DON'T persist yet
			final score = _computeScore(p);
			final scan = ScanResult(product: p, score: score);
			_lastScan = scan;
			return scan;
		} catch (e) {
			developer.log('[ScanViewModel] fetch error: $e', name: 'ScanViewModel');
			_error = e.toString();
			_product = null;
			return null;
		} finally {
			_loading = false;
			notifyListeners();
		}
	}

	/// Persists a scan result to history. Returns true if it was a duplicate.
	Future<bool> addToHistory(ScanResult scan) async {
		final wasDuplicate = await _addScan(scan);
		_lastScan = scan;
		notifyListeners();
		
		// Auto-sync to cloud if enabled
		_syncToCloudIfEnabled();
		
		return wasDuplicate;
	}

	/// Sync scan history to cloud if cloud sync is enabled
	Future<void> _syncToCloudIfEnabled() async {
		if (_cloudSyncService == null || !_cloudSyncService!.isEnabled) return;
		
		try {
			final scans = await _getRecent(limit: 100);
			final scanHistory = scans.map((s) => s.toJson()).toList();
			await _cloudSyncService!.syncScanHistory(scanHistory);
		} catch (e) {
			developer.log('[ScanViewModel] Cloud sync error: $e', name: 'ScanViewModel');
		}
	}

	Future<List<ScanResult>> recentScans({int limit = 10}) => _getRecent(limit: limit);
}
