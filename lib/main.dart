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
import 'src/core/services/meal_reminder_service.dart';
import 'src/core/services/ad_service.dart';
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

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// The main entry point for the VitaSnap app.
void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode 
          ? AndroidProvider.debug 
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode 
          ? AppleProvider.debug 
          : AppleProvider.appAttest,
    );
    
    if (kDebugMode) {
      FirebaseAppCheck.instance.onTokenChange.listen((token) {
        debugPrint('=== APP CHECK DEBUG TOKEN ===');
        debugPrint('Token: $token');
        debugPrint('If AI features fail, register this token in Firebase Console:');
        debugPrint('Firebase Console > App Check > Apps > [Your App] > Manage debug tokens');
        debugPrint('=============================');
      });
    }

    if (!kDebugMode) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    }

    await AdService.initialize();

    final prefs = await SharedPreferences.getInstance();
    runApp(MyApp(prefs: prefs));
  }, (error, stack) {
    if (!kDebugMode) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
  });
}

/// The root widget for the VitaSnap application.
class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp({super.key, required this.prefs});

  /// Builds the widget tree and sets up providers and theming.
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
        Provider(
          create: (ctx) => UsdaFoodApi(ctx.read<NetworkService>()),
        ),
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
        ChangeNotifierProvider(create: (_) => MealReminderService()),
        ChangeNotifierProvider(create: (_) => AdService()..loadRewardedAd()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) => MaterialApp(
          title: 'VitaSnap',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
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

/// Top-level wrapper for the app, used to inject the guest user ID and launch the main flow.
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  static const String guestUserId = 'guest_user';

  /// Builds the widget tree for the guest user flow.
  @override
  Widget build(BuildContext context) {
    return const AuthenticatedWrapper(userId: guestUserId);
  }
}

/// Main wrapper for user-specific app state, onboarding, and navigation.
class AuthenticatedWrapper extends StatefulWidget {
  final String userId;
  
  const AuthenticatedWrapper({super.key, required this.userId});

  /// Creates the state for AuthenticatedWrapper.
  @override
  State<AuthenticatedWrapper> createState() => _AuthenticatedWrapperState();
}

/// State for AuthenticatedWrapper, manages onboarding and user-specific services.
class _AuthenticatedWrapperState extends State<AuthenticatedWrapper> {
  bool? _onboardingComplete;
  String? _lastUserId;

  /// Initializes onboarding check on widget creation.
  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  /// Handles widget updates and re-checks onboarding if user changes.
  @override
  void didUpdateWidget(AuthenticatedWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      setState(() {
        _onboardingComplete = null;
      });
      _checkOnboarding();
    }
  }

  /// Checks if onboarding is complete for the current user.
  Future<void> _checkOnboarding() async {
    debugPrint('Checking onboarding for user: ${widget.userId}');
    final complete = await OnboardingPage.isCompleteForUser(widget.userId);
    debugPrint('Onboarding complete: $complete');
    if (!mounted) return;
    setState(() {
      _onboardingComplete = complete;
    });
  }

  /// Updates user-specific services and restores data if needed.
  void _updateUserServices(String? userId) {
    if (!mounted) return;
    
    final scanHistoryRepo = context.read<ScanHistoryRepository>();
    if (scanHistoryRepo is ScanHistoryRepositoryImpl) {
      scanHistoryRepo.setUserId(userId);
    }
    final dietaryPrefsService = context.read<DietaryPreferencesService>();
    dietaryPrefsService.setUserId(userId);
    final healthConditionsService = context.read<HealthConditionsService>();
    healthConditionsService.setUserId(userId);
    final cloudSyncService = context.read<CloudSyncService>();
    cloudSyncService.setUserId(userId);
    final mealReminderService = context.read<MealReminderService>();
    mealReminderService.initialize();
    
    MealReminderService.onNotificationTapped = () {
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        navigatorKey.currentState?.popUntil((route) => route.isFirst);
        MainNavigation.navigateToHome(navContext);
      }
    };
    
    final scanViewModel = context.read<ScanViewModel>();
    scanViewModel.setCloudSyncService(cloudSyncService);
    dietaryPrefsService.setCloudSyncService(cloudSyncService);

    () async {
      if (cloudSyncService.isEnabled) {
        final cloudData = await cloudSyncService.fetchFromCloud();
        debugPrint('Firestore data after login:');
        debugPrint(cloudData == null ? 'No data found.' : cloudData.toString());
        if (cloudData != null) {
          if (cloudData['scanHistory'] is List && scanHistoryRepo is ScanHistoryRepositoryImpl) {
            final scanList = (cloudData['scanHistory'] as List)
                .map((e) => ScanResult.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            scanList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
            await scanHistoryRepo.clearHistory();
            for (final scan in scanList) {
              await scanHistoryRepo.addScan(scan);
            }
            scanViewModel.refreshAfterRestore();
          }
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

  /// Builds the widget tree for onboarding and main navigation.
  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.userId;

    if (currentUserId != _lastUserId) {
      _lastUserId = currentUserId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateUserServices(currentUserId);
      });
    }

    if (_onboardingComplete == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

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

    return const MainNavigation();
  }
}

