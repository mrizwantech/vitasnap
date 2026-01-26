import '../entities/scan_result.dart';
import '../entities/recipe.dart'; // For MealType

abstract class ScanHistoryRepository {
  /// Adds a scan to history.
  ///
  /// Returns `true` if an existing entry with the same barcode was replaced
  /// (i.e. this product already existed in history), otherwise `false`.
  Future<bool> addScan(ScanResult scan);
  Future<List<ScanResult>> getRecentScans({int limit = 10});
  
  /// Clears all scan history
  Future<void> clearHistory();
  
  /// Gets the total count of scans in history
  Future<int> getScanCount();
  
  /// Find today's meal by type (for merging)
  Future<ScanResult?> findTodaysMealByType(MealType mealType);
  
  /// Find meal by type and date (for merging past meals)
  Future<ScanResult?> findMealByTypeAndDate(MealType mealType, DateTime date);
  
  /// Update an existing scan result (for merging meals)
  Future<void> updateScan(ScanResult oldScan, ScanResult newScan);
}
