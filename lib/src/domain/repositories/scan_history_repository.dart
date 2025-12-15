import '../entities/scan_result.dart';

abstract class ScanHistoryRepository {
  Future<void> addScan(ScanResult scan);
  Future<List<ScanResult>> getRecentScans({int limit = 10});
}
