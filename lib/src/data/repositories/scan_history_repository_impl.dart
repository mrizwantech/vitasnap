import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/scan_history_repository.dart';

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _kKey = 'scan_history';
  final SharedPreferences _prefs;

  ScanHistoryRepositoryImpl(this._prefs);

  @override
  Future<void> addScan(ScanResult scan) async {
    final existing = _prefs.getString(_kKey);
    final list = existing != null ? ScanResult.decodeList(existing) : <ScanResult>[];
    // Remove any previous entries for the same barcode so we don't show duplicates
    list.removeWhere((s) => s.product.barcode == scan.product.barcode);
    // prepend the latest scan
    list.insert(0, scan);
    // cap to 50
    final trimmed = list.take(50).toList();
    await _prefs.setString(_kKey, ScanResult.encodeList(trimmed));
  }

  @override
  Future<List<ScanResult>> getRecentScans({int limit = 10}) async {
    final existing = _prefs.getString(_kKey);
    if (existing == null) return [];
    final list = ScanResult.decodeList(existing);
    return list.take(limit).toList();
  }
}
