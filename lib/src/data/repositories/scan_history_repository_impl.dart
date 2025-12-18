import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/scan_history_repository.dart';

class ScanHistoryRepositoryImpl implements ScanHistoryRepository {
  static const _kKeyPrefix = 'scan_history_';
  final SharedPreferences _prefs;
  String? _userId;

  ScanHistoryRepositoryImpl(this._prefs);

  /// Set the current user ID to isolate data per user
  void setUserId(String? userId) {
    _userId = userId;
  }

  String get _storageKey => _userId != null ? '$_kKeyPrefix$_userId' : '${_kKeyPrefix}anonymous';

  @override
  Future<bool> addScan(ScanResult scan) async {
    // Never add products with invalid/unknown names
    final name = scan.product.name.trim().toLowerCase();
    if (name.isEmpty || name == 'unknown') {
      return false;
    }
    
    final existing = _prefs.getString(_storageKey);
    final list = existing != null ? ScanResult.decodeList(existing) : <ScanResult>[];
    // Allow duplicates - prepend the new scan with current timestamp
    list.insert(0, scan);
    // cap to 50
    final trimmed = list.take(50).toList();
    await _prefs.setString(_storageKey, ScanResult.encodeList(trimmed));
    return true; // Always return true indicating it was added
  }

  @override
  Future<List<ScanResult>> getRecentScans({int limit = 10}) async {
    final existing = _prefs.getString(_storageKey);
    if (existing == null) return [];
    final list = ScanResult.decodeList(existing);
    // Return scans as-is - duplicates are allowed (each add creates a new entry with timestamp)
    return list.take(limit).toList();
  }

  @override
  Future<void> clearHistory() async {
    await _prefs.remove(_storageKey);
  }

  @override
  Future<int> getScanCount() async {
    final existing = _prefs.getString(_storageKey);
    if (existing == null) return 0;
    final list = ScanResult.decodeList(existing);
    return list.length;
  }
}
