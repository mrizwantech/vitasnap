import '../entities/scan_result.dart';
import '../repositories/scan_history_repository.dart';

class GetRecentScans {
  final ScanHistoryRepository _repo;
  GetRecentScans(this._repo);

  Future<List<ScanResult>> call({int limit = 10}) => _repo.getRecentScans(limit: limit);
}
