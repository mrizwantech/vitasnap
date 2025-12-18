import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'src/core/network/network_service.dart';
import 'src/core/services/auth_service.dart';
import 'src/core/services/theme_service.dart';
import 'src/core/services/dietary_preferences_service.dart';
import 'src/core/services/cloud_sync_service.dart';
import 'src/data/datasources/open_food_facts_api.dart';
import 'src/data/repositories/product_repository_impl.dart';
import 'src/data/repositories/scan_history_repository_impl.dart';
import 'src/data/repositories/user_repository_impl.dart';
import 'src/domain/usecases/get_product_by_barcode.dart';
import 'src/domain/usecases/add_scan_result.dart';
import 'src/domain/usecases/get_recent_scans.dart';
import 'src/domain/usecases/compute_health_score.dart';
import 'src/domain/usecases/search_products.dart';
import 'src/domain/repositories/scan_history_repository.dart';
import 'src/domain/repositories/user_repository.dart';
import 'src/presentation/viewmodels/scan_viewmodel.dart';
import 'src/presentation/views/home_dashboard.dart';
import 'src/features/auth/login_page.dart';
import 'src/features/onboarding/onboarding_page.dart';

void main() async {
  // Use runZonedGuarded to catch all errors
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp();

    // Initialize Crashlytics (only in release mode)
    if (!kDebugMode) {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    final prefs = await SharedPreferences.getInstance();
    runApp(MyApp(prefs: prefs));
  }, (error, stack) {
    // Pass all uncaught asynchronous errors to Crashlytics
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>(create: (_) => prefs),
        Provider<NetworkService>(create: (_) => NetworkService()),
        Provider(create: (ctx) => OpenFoodFactsApi(ctx.read<NetworkService>())),
        Provider(
          create: (ctx) => ProductRepositoryImpl(ctx.read<OpenFoodFactsApi>()),
        ),
        Provider(
          create: (ctx) =>
              GetProductByBarcode(ctx.read<ProductRepositoryImpl>()),
        ),
        Provider<ScanHistoryRepository>(
          create: (ctx) => ScanHistoryRepositoryImpl(prefs),
        ),
        Provider<UserRepository>(create: (ctx) => UserRepositoryImpl(prefs)),
        Provider(
          create: (ctx) => AddScanResult(ctx.read<ScanHistoryRepository>()),
        ),
        Provider(
          create: (ctx) => GetRecentScans(ctx.read<ScanHistoryRepository>()),
        ),
        Provider(create: (ctx) => ComputeHealthScore()),
        Provider(
          create: (ctx) => SearchProducts(ctx.read<ProductRepositoryImpl>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ScanViewModel(
            ctx.read<GetProductByBarcode>(),
            ctx.read<AddScanResult>(),
            ctx.read<GetRecentScans>(),
            ctx.read<ComputeHealthScore>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (ctx) => ThemeService(ctx.read<SharedPreferences>())),
        ChangeNotifierProvider(create: (ctx) => DietaryPreferencesService(ctx.read<SharedPreferences>())),
        ChangeNotifierProvider(create: (ctx) => CloudSyncService(ctx.read<SharedPreferences>())),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) => MaterialApp(
          title: 'VitaSnap',
          debugShowCheckedModeBanner: false,
          themeMode: themeService.flutterThemeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00C17B),
              brightness: Brightness.light,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00C17B),
              brightness: Brightness.dark,
            ),
          ),
          home: const AppWrapper(),
        ),
      ),
    );
  }
}

/// Top-level wrapper that handles onboarding flow
class AppWrapper extends StatefulWidget {
  const AppWrapper({super.key});

  @override
  State<AppWrapper> createState() => _AppWrapperState();
}

class _AppWrapperState extends State<AppWrapper> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final complete = await OnboardingPage.isComplete();
    setState(() {
      _onboardingComplete = complete;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking onboarding status
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show onboarding for first-time users
    if (!_onboardingComplete!) {
      return OnboardingPage(
        onComplete: () {
          setState(() {
            _onboardingComplete = true;
          });
        },
      );
    }

    // Show auth flow for returning users
    return const AuthWrapper();
  }
}

/// Wrapper widget that shows login or home based on auth state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastUserId;

  void _updateUserServices(String? userId) {
    // Set user ID on scan history repository
    final scanHistoryRepo = context.read<ScanHistoryRepository>();
    if (scanHistoryRepo is ScanHistoryRepositoryImpl) {
      scanHistoryRepo.setUserId(userId);
    }
    // Set user ID on dietary preferences service
    final dietaryPrefsService = context.read<DietaryPreferencesService>();
    dietaryPrefsService.setUserId(userId);
    // Set user ID on cloud sync service
    final cloudSyncService = context.read<CloudSyncService>();
    cloudSyncService.setUserId(userId);
    // Wire up cloud sync to scan viewmodel for auto-sync
    context.read<ScanViewModel>().setCloudSyncService(cloudSyncService);
    // Wire up cloud sync to dietary preferences for auto-sync
    dietaryPrefsService.setCloudSyncService(cloudSyncService);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final currentUserId = authService.user?.uid;

    // Update user-specific data when user changes
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      // Schedule service updates after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateUserServices(currentUserId);
      });
    }

    // Show home if authenticated, login if not
    if (authService.isAuthenticated) {
      // Use key to force rebuild when user changes
      return HomeDashboard(key: ValueKey(currentUserId));
    } else {
      return const LoginPage();
    }
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
