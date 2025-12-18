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
import 'src/core/services/favorites_service.dart';
import 'src/core/services/health_conditions_service.dart';
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
import 'src/presentation/views/main_navigation.dart';
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
        ChangeNotifierProvider(create: (ctx) => FavoritesService(ctx.read<SharedPreferences>())),
        ChangeNotifierProvider(create: (ctx) => HealthConditionsService(ctx.read<SharedPreferences>())),
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

/// Top-level wrapper that handles auth state
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();

    // Show login if not authenticated
    if (!authService.isAuthenticated) {
      return const LoginPage();
    }

    // Show onboarding/home flow for authenticated users
    return AuthenticatedWrapper(userId: authService.user!.uid);
  }
}

/// Wrapper for authenticated users - handles onboarding then home
class AuthenticatedWrapper extends StatefulWidget {
  final String userId;
  
  const AuthenticatedWrapper({super.key, required this.userId});

  @override
  State<AuthenticatedWrapper> createState() => _AuthenticatedWrapperState();
}

class _AuthenticatedWrapperState extends State<AuthenticatedWrapper> {
  bool? _onboardingComplete;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  @override
  void didUpdateWidget(AuthenticatedWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check onboarding if user changed
    if (oldWidget.userId != widget.userId) {
      _checkOnboarding();
    }
  }

  Future<void> _checkOnboarding() async {
    final complete = await OnboardingPage.isCompleteForUser(widget.userId);
    setState(() {
      _onboardingComplete = complete;
    });
  }

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
    final currentUserId = widget.userId;

    // Update user-specific data when user changes
    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      // Schedule service updates after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateUserServices(currentUserId);
      });
    }

    // Show loading while checking onboarding status
    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Show onboarding for first-time users (after login)
    if (!_onboardingComplete!) {
      return OnboardingPage(
        userId: currentUserId,
        onComplete: () {
          setState(() {
            _onboardingComplete = true;
          });
        },
      );
    }

    // Show main app for users who completed onboarding
    return MainNavigation(key: ValueKey(currentUserId));
  }
}

