import '../entities/scan_result.dart';
import '../repositories/scan_history_repository.dart';

class AddScanResult {
  final ScanHistoryRepository _repo;
  AddScanResult(this._repo);

  /// Returns `true` when the added scan replaced an existing entry (duplicate),
  /// otherwise `false`.
  Future<bool> call(ScanResult scan) => _repo.addScan(scan);
}
