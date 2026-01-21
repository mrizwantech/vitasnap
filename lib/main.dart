import 'src/domain/entities/scan_result.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

import 'src/core/network/network_service.dart';
import 'src/core/services/auth_service.dart';
import 'src/core/services/theme_service.dart';
import 'src/core/services/dietary_preferences_service.dart';
import 'src/core/services/cloud_sync_service.dart';
import 'src/core/services/favorites_service.dart';
import 'src/core/services/health_conditions_service.dart';
import 'src/data/datasources/open_food_facts_api.dart';
import 'src/data/datasources/usda_food_api.dart';
import 'src/data/repositories/product_repository_impl.dart';
import 'src/data/repositories/scan_history_repository_impl.dart';
import 'src/data/repositories/user_repository_impl.dart';
import 'src/data/repositories/recipe_repository_impl.dart';
import 'src/domain/usecases/get_product_by_barcode.dart';
import 'src/domain/usecases/add_scan_result.dart';
import 'src/domain/usecases/get_recent_scans.dart';
import 'src/domain/usecases/compute_health_score.dart';
import 'src/domain/usecases/search_products.dart';
import 'src/domain/usecases/compute_recipe_score.dart';
import 'src/domain/usecases/get_preset_ingredients.dart';
import 'src/domain/usecases/get_recipes.dart';
import 'src/domain/usecases/save_recipe.dart';
import 'src/domain/usecases/search_ingredients.dart';
import 'src/domain/repositories/scan_history_repository.dart';
import 'src/domain/repositories/user_repository.dart';
import 'src/domain/repositories/recipe_repository.dart';
import 'src/presentation/viewmodels/scan_viewmodel.dart';
import 'src/presentation/viewmodels/meal_builder_viewmodel.dart';
import 'src/presentation/views/main_navigation.dart';
import 'src/features/onboarding/onboarding_page.dart';

void main() async {
  // Use runZonedGuarded to catch all errors
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Activate Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
          ? AppleProvider.debug 
          : AppleProvider.appAttest,
    );

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
        // USDA Food API for generic ingredients
        Provider(
          create: (ctx) => UsdaFoodApi(ctx.read<NetworkService>()),
        ),
        // Recipe Builder providers
        Provider<RecipeRepository>(
          create: (ctx) => RecipeRepositoryImpl(
            ctx.read<SharedPreferences>(),
            ctx.read<UsdaFoodApi>(),
          ),
        ),
        Provider(create: (ctx) => ComputeRecipeScore()),
        Provider(
          create: (ctx) => GetPresetIngredients(ctx.read<RecipeRepository>()),
        ),
        Provider(
          create: (ctx) => SearchIngredients(ctx.read<RecipeRepository>()),
        ),
        Provider(
          create: (ctx) => GetRecipes(ctx.read<RecipeRepository>()),
        ),
        Provider(
          create: (ctx) => SaveRecipe(ctx.read<RecipeRepository>()),
        ),
        ChangeNotifierProvider(
          create: (ctx) => ScanViewModel(
            ctx.read<GetProductByBarcode>(),
            ctx.read<AddScanResult>(),
            ctx.read<GetRecentScans>(),
            ctx.read<ComputeHealthScore>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MealBuilderViewModel(
            ctx.read<ComputeRecipeScore>(),
            ctx.read<GetPresetIngredients>(),
            ctx.read<SearchIngredients>(),
            ctx.read<GetRecipes>(),
            ctx.read<SaveRecipe>(),
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

/// Top-level wrapper - direct access without login
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  // Constant guest user ID for local storage keys
  static const String guestUserId = 'guest_user';

  @override
  Widget build(BuildContext context) {
    // Direct access - bypass login, use guest user ID for onboarding tracking
    return const AuthenticatedWrapper(userId: guestUserId);
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
      // Reset to loading state to allow old widgets to dispose properly
      setState(() {
        _onboardingComplete = null;
      });
      _checkOnboarding();
    }
  }

  Future<void> _checkOnboarding() async {
    debugPrint('Checking onboarding for user: ${widget.userId}');
    final complete = await OnboardingPage.isCompleteForUser(widget.userId);
    debugPrint('Onboarding complete: $complete');
    // Guard: ensure widget is still mounted before calling setState
    if (!mounted) return;
    setState(() {
      _onboardingComplete = complete;
    });
  }

  void _updateUserServices(String? userId) {
    // Guard: ensure widget is still mounted
    if (!mounted) return;
    
    // Set user ID on scan history repository
    final scanHistoryRepo = context.read<ScanHistoryRepository>();
    if (scanHistoryRepo is ScanHistoryRepositoryImpl) {
      scanHistoryRepo.setUserId(userId);
    }
    // Set user ID on dietary preferences service
    final dietaryPrefsService = context.read<DietaryPreferencesService>();
    dietaryPrefsService.setUserId(userId);
    // Set user ID on health conditions service
    final healthConditionsService = context.read<HealthConditionsService>();
    healthConditionsService.setUserId(userId);
    // Set user ID on cloud sync service
    final cloudSyncService = context.read<CloudSyncService>();
    cloudSyncService.setUserId(userId);
    // Wire up cloud sync to scan viewmodel for auto-sync
    final scanViewModel = context.read<ScanViewModel>();
    scanViewModel.setCloudSyncService(cloudSyncService);
    // Wire up cloud sync to dietary preferences for auto-sync
    dietaryPrefsService.setCloudSyncService(cloudSyncService);

    // Restore data from Firestore if cloud sync is enabled
    // Note: We capture all references above BEFORE the async block
    () async {
      if (cloudSyncService.isEnabled) {
        final cloudData = await cloudSyncService.fetchFromCloud();
        debugPrint('Firestore data after login:');
        debugPrint(cloudData == null ? 'No data found.' : cloudData.toString());
        if (cloudData != null) {
          // Restore scan history
          if (cloudData['scanHistory'] is List && scanHistoryRepo is ScanHistoryRepositoryImpl) {
            final scanList = (cloudData['scanHistory'] as List)
                .map((e) => ScanResult.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            // Sort by timestamp ascending (earliest first)
            scanList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            // Save to local storage
            await scanHistoryRepo.clearHistory();
            for (final scan in scanList) {
              await scanHistoryRepo.addScan(scan);
            }
            // Notify ScanViewModel to refresh UI and fire callback
            // Using the public refresh method
            scanViewModel.refreshAfterRestore();
          }
          // Restore dietary preferences
          if (cloudData['dietaryPreferences'] is List) {
            final restrictions = (cloudData['dietaryPreferences'] as List)
                .map((e) => DietaryRestriction.values.firstWhere(
                      (r) => r.name == e,
                      orElse: () => DietaryRestriction.vegan, // fallback, will filter below
                    ))
                .where((r) => (cloudData['dietaryPreferences'] as List).contains(r.name))
                .toSet();
            await dietaryPrefsService.setRestrictions(restrictions);
          }
        }
      }
    }();
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
    return const MainNavigation();
  }
}

