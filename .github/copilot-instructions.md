<!-- Project-specific instructions for AI coding agents -->
# Copilot / AI Assistant Instructions — VitaSnap

Keep guidance short and actionable. Follow this checklist when making changes:

- **Big picture**: This is a Flutter app using a Clean/MVVM structure (see [lib/ARCHITECTURE.md](lib/ARCHITECTURE.md)).
  - Layers: `presentation/` (Widgets, ViewModels), `domain/` (Entities, Use Cases, Repositories), `data/` (Models, DataSources, Repository impls), `core/` (Network, DI, utils).
  - Feature-first organization is preferred (e.g., `features/scan`).

- **Primary data flow**: UI -> `ScanViewModel` -> `GetProductByBarcode` (use case) -> `ProductRepositoryImpl` -> `OpenFoodFactsApi` -> `NetworkService.getJson`.
  - Example files: [scan_viewmodel.dart](lib/src/presentation/viewmodels/scan_viewmodel.dart), [get_product_by_barcode.dart](lib/src/domain/usecases/get_product_by_barcode.dart), [open_food_facts_api.dart](lib/src/data/datasources/open_food_facts_api.dart), [network_service.dart](lib/src/core/network/network_service.dart).

- **Dependency injection / runtime conventions**:
  - App uses `provider` for DI in [main.dart](lib/main.dart). Register providers in `MaterialApp.builder` to make them available globally.
  - `NetworkService` accepts an optional `http.Client` (`NetworkService({http.Client? client})`) — use this to inject mocked clients in tests.
  - ViewModels use `ChangeNotifier` (`ScanViewModel`) and are provided via `ChangeNotifierProvider`.

- **Testing / mocks**:
  - Use `flutter test` for unit/widget tests. The project uses `flutter_test` and `flutter_lints`.
  - To stub network in widget/unit tests, either pass a fake `http.Client` into `NetworkService` or override the `Provider<NetworkService>` in the test `Widget` tree. Example pattern:

```dart
// test example
final mockClient = MockClient((request) async => http.Response('{"product": {...}, "status":1}', 200));
final svc = NetworkService(client: mockClient);
// inject svc via Provider when pumping widget
```

- **Platform specifics**:
  - Camera barcode scanning uses `mobile_scanner`; `BarcodeScannerWidget` has a web/desktop fallback (see [barcode_scanner_widget.dart](lib/src/presentation/widgets/barcode_scanner_widget.dart)). Tests that require camera should use the text-field lookup flow instead.

- **Linting & style**:
  - Respect `analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`). Run `flutter analyze` before raising PRs.
  - Keep `NetworkService` small and testable; prefer adding behavior in small, injectable helpers rather than large singletons.

- **Build / common commands**:
  - Setup: `flutter pub get`
  - Analyze: `flutter analyze`
  - Run tests: `flutter test`
  - Run app: `flutter run` (or `flutter run -d <deviceId>`)
  - Build: `flutter build apk` / `flutter build ios` / `flutter build windows` as appropriate.

- **What to look for in PR reviews**:
  - Did the change preserve the layer boundaries (presentation/domain/data/core)?
  - Are DI and testability preserved (no global state, injectable clients)?
  - Are platform fallbacks (camera on web/desktop) handled conscientiously?

If anything above is unclear or you'd like more specifics (example tests, mocks, or a checklist for PRs), ask and I will iterate.
