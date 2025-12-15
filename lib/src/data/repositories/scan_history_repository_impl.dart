import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/scan_history_repository.dart';

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _kKey = 'scan_history';
  final SharedPreferences _prefs;

  ScanHistoryRepositoryImpl(this._prefs);

  @override
  Future<bool> addScan(ScanResult scan) async {
    // Never add products with invalid/unknown names
    final name = scan.product.name.trim().toLowerCase();
    if (name.isEmpty || name == 'unknown') {
      return false;
    }
    
    final existing = _prefs.getString(_kKey);
    final list = existing != null ? ScanResult.decodeList(existing) : <ScanResult>[];
    // Allow duplicates - prepend the new scan with current timestamp
    list.insert(0, scan);
    // cap to 50
    final trimmed = list.take(50).toList();
    await _prefs.setString(_kKey, ScanResult.encodeList(trimmed));
    return true; // Always return true indicating it was added
  }

  @override
  Future<List<ScanResult>> getRecentScans({int limit = 10}) async {
    final existing = _prefs.getString(_kKey);
    if (existing == null) return [];
    final list = ScanResult.decodeList(existing);
    // Return scans as-is - duplicates are allowed (each add creates a new entry with timestamp)
    return list.take(limit).toList();
  }
}
