import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scan_result.dart';
import '../../domain/entities/recipe.dart'; // For MealType
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

  /// Check if two dates are on the same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Future<ScanResult?> findTodaysMealByType(MealType mealType) async {
    return findMealByTypeAndDate(mealType, DateTime.now());
  }

  @override
  Future<ScanResult?> findMealByTypeAndDate(MealType mealType, DateTime date) async {
    final existing = _prefs.getString(_storageKey);
    if (existing == null) return null;
    
    final list = ScanResult.decodeList(existing);
    
    // Find a meal with the same type from the specified date
    for (final scan in list) {
      if (scan.mealType == mealType && _isSameDay(scan.timestamp, date)) {
        return scan;
      }
    }
    return null;
  }

  @override
  Future<void> updateScan(ScanResult oldScan, ScanResult newScan) async {
    final existing = _prefs.getString(_storageKey);
    if (existing == null) return;
    
    final list = ScanResult.decodeList(existing);
    
    // Find and replace the old scan
    for (int i = 0; i < list.length; i++) {
      if (list[i].timestamp == oldScan.timestamp && 
          list[i].mealType == oldScan.mealType) {
        list[i] = newScan;
        break;
      }
    }
    
    await _prefs.setString(_storageKey, ScanResult.encodeList(list));
  }

  @override
  Future<bool> addScan(ScanResult scan) async {
    // Never add products with invalid/unknown names
    final name = scan.product.name.trim().toLowerCase();
    if (name.isEmpty || name == 'unknown') {
      return false;
    }
    
    final existing = _prefs.getString(_storageKey);
    final list = existing != null ? ScanResult.decodeList(existing) : <ScanResult>[];
    
    bool wasMerged = false;
    
    // Priority 1: Check if there's an existing meal with same mealType + same day
    // This handles merging items into the same meal (e.g., adding to today's lunch)
    if (scan.mealType != null) {
      final existingMealIndex = list.indexWhere(
        (s) => s.mealType == scan.mealType && _isSameDay(s.timestamp, scan.timestamp),
      );
      
      if (existingMealIndex >= 0) {
        // Found existing meal of same type on same day - this is a merge
        // The caller should handle merging meal items before calling addScan
        // Here we just replace the old entry but KEEP its position in the list
        // (so the order stays based on when the meal was first added)
        print('[ScanHistory] Merging with existing ${scan.mealType?.displayName} at index $existingMealIndex');
        list.removeAt(existingMealIndex);
        list.insert(existingMealIndex, scan);
        wasMerged = true;
      }
    }
    
    // Priority 2: Check if there's an existing scan with the same barcode ON THE SAME DAY
    // This handles updating a product entry (e.g., changing meal type)
    // Different days should be separate entries even for the same product
    if (!wasMerged) {
      final existingBarcodeIndex = list.indexWhere(
        (s) => s.product.barcode == scan.product.barcode && 
               _isSameDay(s.timestamp, scan.timestamp),
      );
      
      if (existingBarcodeIndex >= 0) {
        // Replace existing scan with updated one, keep its position
        print('[ScanHistory] Replacing same barcode on same day at index $existingBarcodeIndex, meal type: ${scan.mealType?.displayName}');
        list.removeAt(existingBarcodeIndex);
        list.insert(existingBarcodeIndex, scan);
        wasMerged = true;
      }
    }
    
    // If no merge happened, prepend as new entry (most recent at top)
    if (!wasMerged) {
      print('[ScanHistory] Adding new entry at top, meal type: ${scan.mealType?.displayName}');
      list.insert(0, scan);
    }
    
    // cap to 50
    final trimmed = list.take(50).toList();
    await _prefs.setString(_storageKey, ScanResult.encodeList(trimmed));
    return wasMerged;
  }

  @override
  Future<List<ScanResult>> getRecentScans({int limit = 10}) async {
    final existing = _prefs.getString(_storageKey);
    if (existing == null) return [];
    final list = ScanResult.decodeList(existing);
    // Return in storage order (most recently added first)
    // DO NOT sort by timestamp - keep insertion order
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
