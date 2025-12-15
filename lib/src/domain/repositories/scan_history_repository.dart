import '../entities/scan_result.dart';

abstract class ScanHistoryRepository {
  /// Adds a scan to history.
  ///
  /// Returns `true` if an existing entry with the same barcode was replaced
  /// (i.e. this product already existed in history), otherwise `false`.
  Future<bool> addScan(ScanResult scan);
  Future<List<ScanResult>> getRecentScans({int limit = 10});
}
