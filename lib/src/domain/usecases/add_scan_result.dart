import '../entities/scan_result.dart';
import '../repositories/scan_history_repository.dart';

class AddScanResult {
  final ScanHistoryRepository _repo;
  AddScanResult(this._repo);

  Future<void> call(ScanResult scan) => _repo.addScan(scan);
}
