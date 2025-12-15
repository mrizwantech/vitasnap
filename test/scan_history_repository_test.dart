import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitasnap/src/data/repositories/scan_history_repository_impl.dart';
import 'package:vitasnap/src/domain/entities/product.dart';
import 'package:vitasnap/src/domain/entities/scan_result.dart';

void main() {
  test('adds scan and deduplicates by barcode', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ScanHistoryRepositoryImpl(prefs);

    final product1 = Product(barcode: '123', name: 'Milk', brand: 'BrandA', nutriments: {});
    final scan1 = ScanResult(product: product1, score: 50, timestamp: DateTime.parse('2020-01-01T00:00:00Z'));
    final scan2 = ScanResult(product: product1, score: 80, timestamp: DateTime.parse('2020-01-02T00:00:00Z'));

    await repo.addScan(scan1);
    var items = await repo.getRecentScans();
    expect(items.length, 1);
    expect(items.first.score, 50);

    // Add same product again with different score; should replace previous entry
    await repo.addScan(scan2);
    items = await repo.getRecentScans();
    expect(items.length, 1);
    expect(items.first.score, 80);
    expect(items.first.timestamp, scan2.timestamp);
  });
}
