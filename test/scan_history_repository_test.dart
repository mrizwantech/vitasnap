import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitasnap/src/data/repositories/scan_history_repository_impl.dart';
import 'package:vitasnap/src/domain/entities/product.dart';
import 'package:vitasnap/src/domain/entities/scan_result.dart';

void main() {
  test('adds scan and allows duplicates with separate timestamps', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ScanHistoryRepositoryImpl(prefs);

    final product1 = Product(barcode: '123', name: 'Milk', brand: 'BrandA', nutriments: {});
    final scan1 = ScanResult(product: product1, score: 50, timestamp: DateTime.parse('2020-01-01T00:00:00Z'));
    final scan2 = ScanResult(product: product1, score: 80, timestamp: DateTime.parse('2020-01-02T00:00:00Z'));

    final firstRes = await repo.addScan(scan1);
    expect(firstRes, isTrue); // Returns true when added
    var items = await repo.getRecentScans();
    expect(items.length, 1);
    expect(items.first.score, 50);

    // Add same product again with different score; should add as new entry (duplicates allowed)
    final secondRes = await repo.addScan(scan2);
    expect(secondRes, isTrue);
    items = await repo.getRecentScans();
    expect(items.length, 2); // Now we have 2 entries
    expect(items.first.score, 80); // Latest is first
    expect(items[1].score, 50);
  });

  test('getRecentScans returns all entries including duplicates', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = ScanHistoryRepositoryImpl(prefs);

    final p1 = Product(barcode: '111', name: 'A', brand: 'X', nutriments: {});
    final p2 = Product(barcode: '222', name: 'B', brand: 'Y', nutriments: {});

    final s1 = ScanResult(product: p1, score: 10, timestamp: DateTime.parse('2020-01-03T00:00:00Z'));
    final s2 = ScanResult(product: p1, score: 20, timestamp: DateTime.parse('2020-01-02T00:00:00Z'));
    final s3 = ScanResult(product: p2, score: 30, timestamp: DateTime.parse('2020-01-01T00:00:00Z'));
    final s4 = ScanResult(product: p1, score: 25, timestamp: DateTime.parse('2020-01-04T00:00:00Z'));
    // Simulate stored list with duplicates (latest-first)
    final encoded = ScanResult.encodeList([s4, s1, s2, s3]);
    await prefs.setString('scan_history', encoded);

    final items = await repo.getRecentScans();
    // Duplicates are allowed - all 4 entries returned
    expect(items.length, 4);
    expect(items[0].score, 25);
    expect(items[1].score, 10);
    expect(items[2].score, 20);
    expect(items[3].score, 30);
  });
}
