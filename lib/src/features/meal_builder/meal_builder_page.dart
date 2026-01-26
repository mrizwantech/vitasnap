import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/services/menu_analysis_service.dart';
import '../../core/services/health_conditions_service.dart';
import '../../core/services/dietary_preferences_service.dart';
import '../../core/services/ad_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/scan_result.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../../domain/usecases/search_products.dart';
import '../../presentation/viewmodels/meal_builder_viewmodel.dart';
import '../../presentation/viewmodels/scan_viewmodel.dart';
import '../../presentation/views/main_navigation.dart';
import '../../presentation/widgets/barcode_scanner_widget.dart';
import '../../presentation/widgets/vitasnap_logo.dart';
import 'widgets/meal_type_tabs.dart';
import 'widgets/ingredient_grid.dart';
import 'widgets/current_recipe_card.dart';
import 'widgets/recipe_health_score.dart';
import 'widgets/add_ingredient_modal.dart';

/// Meal Builder Page - Main UI for building meals and calculating nutrition
/// Can be used as a standalone page or embedded in navigation
class MealBuilderPage extends StatefulWidget {
  /// If true, shows without Scaffold/AppBar (for embedding in navigation)
  final bool embedded;

  /// Callback when back is pressed in embedded mode
  final VoidCallback? onBack;

  const MealBuilderPage({super.key, this.embedded = false, this.onBack});

  @override
  State<MealBuilderPage> createState() => _MealBuilderPageState();
}

class _MealBuilderPageState extends State<MealBuilderPage> {
  final _searchController = TextEditingController();
  final _apiSearchController = TextEditingController();
  final _productSearchController = TextEditingController();
  bool _showProductSearch = false;

  @override
  void initState() {
    super.initState();
    // Initialize the view model
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealBuilderViewModel>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _apiSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  /// Check if the input looks like a barcode (only digits, 8-14 characters)
  bool _looksLikeBarcode(String input) {
    return RegExp(r'^\d{8,14}$').hasMatch(input.trim());
  }

  /// Show dialog when product not found with option to use AI camera
  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.search_off, color: Colors.orange.shade400),
            const SizedBox(width: 12),
            const Expanded(child: Text('Product Not Found')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We couldn\'t find a product with barcode:',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                barcode,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Would you like to take a photo and use AI to analyze it?',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showAdThenAnalyze(barcode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C17B),
            ),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Use AI Camera'),
          ),
        ],
      ),
    );
  }

  /// Shows rewarded ad then analyzes with AI camera
  Future<void> _showAdThenAnalyze(String barcode) async {
    final adService = context.read<AdService>();
    
    await adService.showRewardedAd(
      onRewarded: () {
        _analyzeWithAICamera(barcode);
      },
    );
  }

  /// Analyze a product with AI camera
  Future<void> _analyzeWithAICamera(String barcode) async {
    final ImagePicker picker = ImagePicker();
    final MenuAnalysisService menuService = MenuAnalysisService();

    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing with AI...'),
                ],
              ),
            ),
          ),
        ),
      );

      final Uint8List imageBytes = await image.readAsBytes();

      // Get user's health conditions and dietary preferences
      final healthService = context.read<HealthConditionsService>();
      final dietaryService = context.read<DietaryPreferencesService>();
      
      final healthConditions = healthService.selectedConditions
          .map((c) => c.displayName)
          .toList();
      final dietaryPreferences = dietaryService.selectedRestrictions
          .map((r) => r.displayName)
          .toList();

      final result = await menuService.analyzeFoodProductImage(
        imageBytes: imageBytes,
        productName: null,
        healthConditions: healthConditions,
        dietaryPreferences: dietaryPreferences,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      // Convert to Product and add to meal builder
      int score;
      switch (result.recommendation) {
        case DishRecommendation.best:
          score = 80;
          break;
        case DishRecommendation.caution:
          score = 50;
          break;
        case DishRecommendation.avoid:
          score = 25;
          break;
      }

      final product = Product(
        barcode: barcode,
        name: result.productName,
        brand: result.brand ?? 'AI Analyzed',
        imageUrl: null,
        ingredients: result.ingredients,
        nutriments: {
          'energy-kcal_100g': result.estimatedCalories.toDouble(),
          'proteins_100g': result.estimatedProtein.toDouble(),
          'carbohydrates_100g': result.estimatedCarbs.toDouble(),
          'fat_100g': result.estimatedFat.toDouble(),
          'sodium_100g': result.estimatedSodium.toDouble() / 1000,
          'fiber_100g': result.estimatedFiber.toDouble(),
          'sugars_100g': result.estimatedSugar.toDouble(),
        },
        labels: ['AI Analyzed', result.confidence],
      );

      _addProductToMealBuilder(product, score);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${result.productName} analyzed and added! (${result.confidence} confidence)',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C17B),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to analyze: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Convert a Product to a RecipeIngredient for adding to meal builder
  RecipeIngredient _productToIngredient(Product product, int score) {
    // Determine NutriScoreGrade from score
    NutriScoreGrade nutriScore;
    if (score >= 80) {
      nutriScore = NutriScoreGrade.a;
    } else if (score >= 60) {
      nutriScore = NutriScoreGrade.b;
    } else if (score >= 40) {
      nutriScore = NutriScoreGrade.c;
    } else if (score >= 20) {
      nutriScore = NutriScoreGrade.d;
    } else {
      nutriScore = NutriScoreGrade.e;
    }

    // Determine category from product data
    String category = 'other';
    final name = product.name.toLowerCase();
    if (name.contains('protein') ||
        name.contains('chicken') ||
        name.contains('beef') ||
        name.contains('fish') ||
        name.contains('meat') ||
        name.contains('egg')) {
      category = 'protein';
    } else if (name.contains('milk') ||
        name.contains('cheese') ||
        name.contains('yogurt') ||
        name.contains('dairy')) {
      category = 'dairy';
    } else if (name.contains('fruit') ||
        name.contains('apple') ||
        name.contains('banana') ||
        name.contains('orange') ||
        name.contains('berry')) {
      category = 'fruits';
    } else if (name.contains('vegetable') ||
        name.contains('salad') ||
        name.contains('carrot') ||
        name.contains('broccoli') ||
        name.contains('spinach')) {
      category = 'veggies';
    } else if (name.contains('bread') ||
        name.contains('rice') ||
        name.contains('pasta') ||
        name.contains('grain') ||
        name.contains('cereal') ||
        name.contains('oat')) {
      category = 'grains';
    }

    return RecipeIngredient(
      id: product.barcode,
      name: product.name,
      iconEmoji: '📦', // Package emoji for scanned products
      quantity: 1,
      unit: IngredientUnit.whole,
      nutriments: product.nutriments ?? {},
      nutriScore: nutriScore,
      category: category,
    );
  }

  /// Add a scanned/searched product to the meal builder
  void _addProductToMealBuilder(Product product, int score) {
    final ingredient = _productToIngredient(product, score);
    final viewModel = context.read<MealBuilderViewModel>();
    viewModel.addIngredient(ingredient, 1, IngredientUnit.whole);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('📦', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text('${product.name} added to meal')),
          ],
        ),
        backgroundColor: const Color(0xFF1B8A4E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Handle product search (barcode or name) - adds directly to meal builder
  Future<void> _doProductSearch() async {
    final query = _productSearchController.text.trim();
    if (query.isEmpty) return;

    final vm = context.read<ScanViewModel>();

    // Close search UI
    setState(() {
      _showProductSearch = false;
      _productSearchController.clear();
    });

    // If it looks like a barcode, do barcode lookup
    if (_looksLikeBarcode(query)) {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final scanResult = await vm.fetchByBarcode(query);
      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (scanResult == null) {
        if (!mounted) return;
        // Show dialog with option to use AI camera
        _showProductNotFoundDialog(query);
        return;
      }

      // Add directly to meal builder
      if (mounted) {
        _addProductToMealBuilder(scanResult.product, scanResult.score);
      }
    } else {
      // Text search - search by product name
      if (!mounted) return;
      final searchProducts = context.read<SearchProducts>();

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final results = await searchProducts(query);
        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        if (results.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.noProductsFoundFor(query))),
            );
          }
          return;
        }

        // Show results in a bottom sheet for selection
        if (!mounted) return;
        _showProductSelectionSheet(results);
      } catch (e) {
        if (mounted) Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Search failed: $e')));
        }
      }
    }
  }

  /// Show a bottom sheet to select from search results
  void _showProductSelectionSheet(List<Product> results) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF252542) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.search, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Select a product (${results.length} results)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Results list
            Expanded(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (context, index) {
                  final product = results[index];
                  // Estimate score based on nutriments (simple heuristic)
                  final score = _estimateProductScore(product);
                  return ListTile(
                    leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: Stack(
                        children: [
                          // Product image or placeholder
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                product.imageUrl != null &&
                                    product.imageUrl!.isNotEmpty
                                ? Image.network(
                                    product.imageUrl!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 50,
                                      height: 50,
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade200,
                                      child: Icon(
                                        Icons.fastfood,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.black26,
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 50,
                                    height: 50,
                                    color: isDark
                                        ? Colors.grey.shade800
                                        : Colors.grey.shade200,
                                    child: Icon(
                                      Icons.fastfood,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black26,
                                    ),
                                  ),
                          ),
                          // Score badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getScoreColor(score),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                score.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      product.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      product.brand ?? 'Unknown brand',
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    trailing: Icon(
                      Icons.add_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _addProductToMealBuilder(product, score);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.lightGreen;
    if (score >= 40) return Colors.orange;
    if (score >= 20) return Colors.deepOrange;
    return Colors.red;
  }

  /// Estimate a health score for a product based on nutriments
  int _estimateProductScore(Product product) {
    final nutriments = product.nutriments ?? {};
    int score = 50; // Start with neutral score

    // Penalize high sugar
    final sugar = (nutriments['sugars_100g'] ?? nutriments['sugars'] ?? 0)
        .toDouble();
    if (sugar > 20) {
      score -= 20;
    } else if (sugar > 10)
      score -= 10;
    else if (sugar < 5)
      score += 10;

    // Penalize high fat
    final fat = (nutriments['fat_100g'] ?? nutriments['fat'] ?? 0).toDouble();
    if (fat > 20) {
      score -= 15;
    } else if (fat > 10)
      score -= 5;

    // Penalize high sodium
    final sodium = (nutriments['sodium_100g'] ?? nutriments['sodium'] ?? 0)
        .toDouble();
    if (sodium > 1) {
      score -= 15;
    } else if (sodium > 0.5)
      score -= 5;

    // Reward high protein
    final protein = (nutriments['proteins_100g'] ?? nutriments['proteins'] ?? 0)
        .toDouble();
    if (protein > 20) {
      score += 20;
    } else if (protein > 10)
      score += 10;

    // Reward high fiber
    final fiber = (nutriments['fiber_100g'] ?? nutriments['fiber'] ?? 0)
        .toDouble();
    if (fiber > 5) {
      score += 15;
    } else if (fiber > 2)
      score += 5;

    return score.clamp(0, 100);
  }

  /// Open barcode scanner - adds directly to meal builder
  Future<void> _openBarcodeScanner() async {
    final vm = context.read<ScanViewModel>();

    // Navigate to barcode scanner in "meal builder" mode
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerWidget(addToMealBuilder: true),
      ),
    );

    // If a product was returned, add it to meal builder
    if (result != null && result['product'] != null && mounted) {
      final product = result['product'] as Product;
      final score = result['score'] as int? ?? 50;
      _addProductToMealBuilder(product, score);
    }
  }

  void _showAddIngredientModal(RecipeIngredient ingredient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddIngredientModal(
        ingredient: ingredient,
        onAdded: () => _apiSearchController.clear(),
      ),
    );
  }

  /// Convert internal meal score to 0-100 scale for tracker display
  int _convertToTrackerScore(int internalScore, int ingredientCount) {
    // Internal score uses A=20, B=10, C=0, D=-10, E=-20 per ingredient
    // Convert to 0-100 scale based on average ingredient score
    if (ingredientCount == 0) return 50;

    // Calculate average score per ingredient
    final avgScore = internalScore / ingredientCount;

    // Map from [-20, 20] range to [0, 100] range
    // -20 -> 0, 0 -> 50, 20 -> 100
    final trackerScore = ((avgScore + 20) / 40 * 100).round().clamp(0, 100);
    return trackerScore;
  }

  /// Convert NutriScoreGrade to 0-100 scale for individual items
  int _nutriScoreToTrackerScore(NutriScoreGrade grade) {
    switch (grade) {
      case NutriScoreGrade.a:
        return 90;
      case NutriScoreGrade.b:
        return 75;
      case NutriScoreGrade.c:
        return 60;
      case NutriScoreGrade.d:
        return 45;
      case NutriScoreGrade.e:
        return 20;
    }
  }

  /// Check if current time is appropriate for the selected meal type
  bool _isAppropriateTimeForMeal(MealType mealType) {
    final now = DateTime.now();
    final hour = now.hour;

    switch (mealType) {
      case MealType.breakfast:
        return hour >= 5 && hour < 11; // 5am - 11am
      case MealType.lunch:
        return hour >= 11 && hour < 15; // 11am - 3pm
      case MealType.dinner:
        return hour >= 17 && hour < 22; // 5pm - 10pm
      case MealType.snack:
        return true; // Snacks are always appropriate
    }
  }

  /// Get the suggested meal type based on current time
  MealType _getSuggestedMealType() {
    final now = DateTime.now();
    final hour = now.hour;

    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 22) return MealType.dinner;
    return MealType.snack;
  }

  /// Show dialog asking if user wants to proceed with unusual meal time
  Future<Map<String, dynamic>?> _showMealTimeConfirmation(
    MealType selectedMeal,
  ) async {
    final suggestedMeal = _getSuggestedMealType();
    DateTime selectedDate = DateTime.now();
    MealType chosenMealType = selectedMeal;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isPastDate = !_isToday(selectedDate);

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPastDate ? Icons.calendar_today : Icons.access_time,
                  color: isPastDate ? const Color(0xFF1B8A4E) : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(isPastDate ? 'Add to Past Date' : 'Unusual Time'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isPastDate) ...[
                  Text(
                    'It looks like ${selectedMeal.displayName.toLowerCase()} time has passed. '
                    'Would you like to:',
                  ),
                  const SizedBox(height: 12),
                  Text('• Continue adding as ${selectedMeal.displayName}'),
                  Text('• Change to ${suggestedMeal.displayName} instead'),
                  Text('• Add to a different date'),
                ] else ...[
                  Text(
                    'Adding meal to ${_isYesterday(selectedDate) ? "yesterday" : "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
                const SizedBox(height: 16),

                // Date picker row
                Row(
                  children: [
                    const Text(
                      'Date: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 30),
                            ),
                            lastDate: DateTime.now(),
                            helpText: 'Select date for this meal',
                          );
                          if (picked != null) {
                            setDialogState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isToday(selectedDate)
                                    ? 'Today'
                                    : _isYesterday(selectedDate)
                                    ? 'Yesterday'
                                    : '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _isToday(selectedDate)
                                      ? Colors.black87
                                      : const Color(0xFF1B8A4E),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Show meal type selector when past date is selected
                if (isPastDate) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Meal Type:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mealType in [
                        MealType.breakfast,
                        MealType.lunch,
                        MealType.dinner,
                        MealType.snack,
                      ])
                        ChoiceChip(
                          label: Text(
                            '${mealType.emoji} ${mealType.displayName}',
                          ),
                          selected: chosenMealType == mealType,
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => chosenMealType = mealType);
                            }
                          },
                          selectedColor: const Color(
                            0xFF1B8A4E,
                          ).withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            color: chosenMealType == mealType
                                ? const Color(0xFF1B8A4E)
                                : Colors.black87,
                            fontWeight: chosenMealType == mealType
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
              if (!isPastDate)
                TextButton(
                  onPressed: () => Navigator.pop(context, {
                    'action': 'change',
                    'mealType': suggestedMeal,
                    'date': selectedDate,
                  }),
                  child: Text('Change to ${suggestedMeal.displayName}'),
                ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, {
                  'action': 'continue',
                  'mealType': isPastDate ? chosenMealType : selectedMeal,
                  'date': selectedDate,
                }),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B8A4E),
                ),
                child: Text(
                  isPastDate
                      ? 'Add ${chosenMealType.displayName}'
                      : 'Keep ${selectedMeal.displayName}',
                ),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  Future<void> _logMealToTracker(MealBuilderViewModel viewModel) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var mealType = viewModel.selectedMealType;
    final ingredients = viewModel.currentIngredients;
    DateTime mealDate = DateTime.now();

    if (ingredients.isEmpty) return;

    // Check if time is appropriate for selected meal
    if (!_isAppropriateTimeForMeal(mealType)) {
      final dialogResult = await _showMealTimeConfirmation(mealType);
      if (dialogResult == null) return; // User cancelled

      // Update meal type if user chose to change
      if (dialogResult['action'] == 'change') {
        mealType = dialogResult['mealType'] as MealType;
        context.read<MealBuilderViewModel>().setMealType(mealType);
      }

      // Get the selected date
      mealDate = dialogResult['date'] as DateTime;
    }

    // Check if there's already a meal of this type for the selected date
    final historyRepo = context.read<ScanHistoryRepository>();
    final existingMeal = await historyRepo.findMealByTypeAndDate(
      mealType,
      mealDate,
    );

    // Create MealItems for individual ingredient tracking
    final newMealItems = ingredients.map((ing) {
      final adjusted = ing.adjustedNutriments;
      return MealItem(
        name: ing.name,
        category: ing.category,
        quantity: ing.quantity,
        unit: ing.unit.displayName,
        score: _nutriScoreToTrackerScore(ing.nutriScore),
        nutrition: {
          'calories': adjusted['calories'] ?? 0,
          'protein': adjusted['protein'] ?? 0,
          'carbs': adjusted['carbs'] ?? 0,
          'fat': adjusted['fat'] ?? 0,
          'fiber': adjusted['fiber'] ?? 0,
          'sugar': adjusted['sugar'] ?? 0,
        },
      );
    }).toList();

    // Merge with existing meal if one exists today
    List<MealItem> allMealItems;
    if (existingMeal != null) {
      if (existingMeal.mealItems != null &&
          existingMeal.mealItems!.isNotEmpty) {
        // Existing meal already has mealItems, just append new ones
        allMealItems = [...existingMeal.mealItems!, ...newMealItems];
      } else {
        // Existing meal was scanned directly (no mealItems), convert it to a MealItem first
        final existingProduct = existingMeal.product;
        final existingNutriments = existingProduct.nutriments ?? {};
        final existingMealItem = MealItem(
          name: existingProduct.name,
          category: existingProduct.brand ?? '',
          quantity: 1,
          unit: 'serving',
          score: existingMeal.score,
          nutrition: {
            'calories':
                (existingNutriments['energy-kcal_100g'] ??
                        existingNutriments['energy-kcal'] ??
                        0)
                    .toDouble(),
            'protein':
                (existingNutriments['proteins_100g'] ??
                        existingNutriments['proteins'] ??
                        0)
                    .toDouble(),
            'carbs':
                (existingNutriments['carbohydrates_100g'] ??
                        existingNutriments['carbohydrates'] ??
                        0)
                    .toDouble(),
            'fat':
                (existingNutriments['fat_100g'] ??
                        existingNutriments['fat'] ??
                        0)
                    .toDouble(),
            'fiber':
                (existingNutriments['fiber_100g'] ??
                        existingNutriments['fiber'] ??
                        0)
                    .toDouble(),
            'sugar':
                (existingNutriments['sugars_100g'] ??
                        existingNutriments['sugars'] ??
                        0)
                    .toDouble(),
          },
        );
        allMealItems = [existingMealItem, ...newMealItems];
      }
    } else {
      allMealItems = newMealItems;
    }

    // Calculate combined nutrition
    final combinedNutrition = <String, double>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
    };

    for (final item in allMealItems) {
      for (final key in combinedNutrition.keys) {
        combinedNutrition[key] =
            (combinedNutrition[key] ?? 0) + (item.nutrition[key] ?? 0);
      }
    }

    // Calculate average score
    final avgScore = allMealItems.isEmpty
        ? 50
        : (allMealItems.map((e) => e.score).reduce((a, b) => a + b) /
                  allMealItems.length)
              .round();

    // Create a combined name from all items
    final mealName = allMealItems.length == 1
        ? allMealItems.first.name
        : '${mealType.displayName} (${allMealItems.length} items)';

    final nutriments = <String, dynamic>{
      'energy-kcal_100g': combinedNutrition['calories'] ?? 0,
      'proteins_100g': combinedNutrition['protein'] ?? 0,
      'carbohydrates_100g': combinedNutrition['carbs'] ?? 0,
      'fat_100g': combinedNutrition['fat'] ?? 0,
      'fiber_100g': combinedNutrition['fiber'] ?? 0,
      'sugars_100g': combinedNutrition['sugar'] ?? 0,
      'sodium_100g': 0,
    };

    // Create Product from meal
    final product = Product(
      barcode:
          existingMeal?.product.barcode ??
          'meal_${DateTime.now().millisecondsSinceEpoch}',
      name: mealName,
      brand: '${mealType.emoji} ${mealType.displayName}',
      nutriments: nutriments,
    );

    // Use existing timestamp, or create one for the selected date
    // For today, always use current time so it shows as "just now"
    DateTime mealTimestamp;
    if (_isToday(mealDate)) {
      mealTimestamp = DateTime.now();
    } else {
      // For past dates, set to noon on that day
      mealTimestamp = DateTime(
        mealDate.year,
        mealDate.month,
        mealDate.day,
        12,
        0,
      );
    }

    // Create ScanResult with meal type, score, and individual items
    final scanResult = ScanResult(
      product: product,
      score: avgScore,
      timestamp: mealTimestamp,
      mealType: mealType,
      mealItems: allMealItems,
    );

    // Update existing or add new
    final scanViewModel = context.read<ScanViewModel>();
    if (existingMeal != null) {
      await historyRepo.updateScan(existingMeal, scanResult);
      // Refresh the scan history
      scanViewModel.refreshAfterRestore();
    } else {
      await scanViewModel.addToHistory(scanResult);
    }

    // Clear the meal builder
    viewModel.clearAll();

    // Show success message
    if (mounted) {
      String dateInfo = '';
      if (!_isToday(mealDate)) {
        dateInfo = _isYesterday(mealDate)
            ? ' for yesterday'
            : ' for ${mealDate.day}/${mealDate.month}';
      }

      final message = existingMeal != null
          ? '${mealType.displayName}$dateInfo updated with ${ingredients.length} item${ingredients.length > 1 ? 's' : ''}!'
          : '${mealType.displayName}$dateInfo logged!';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(mealType.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(child: Text('$message Redirecting to home...')),
            ],
          ),
          backgroundColor: isDark
              ? const Color(0xFF252542)
              : const Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to home tab
      if (mounted) {
        MainNavigation.navigateToHome(context);
      }
    }
  }

  void _performApiSearch(MealBuilderViewModel viewModel) {
    final query = _apiSearchController.text.trim();
    if (query.isNotEmpty) {
      viewModel.searchIngredientsFromApi(query);
    }
  }

  /// Build the Quick Add card with scan and search options for packaged products
  Widget _buildQuickAddCard(bool isDark, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.add_circle,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Add',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Text(
                'Add packaged products',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Show search bar or buttons based on state
          if (_showProductSearch)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: Theme.of(context).primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _productSearchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search by name or barcode...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _doProductSearch(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Go button
                Material(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: _doProductSearch,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Cancel button
                Material(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => setState(() {
                      _showProductSearch = false;
                      _productSearchController.clear();
                    }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                // Scan Barcode Button
                Expanded(
                  child: Material(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: _openBarcodeScanner,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Scan Barcode',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Search Product Button
                Expanded(
                  child: Material(
                    color: isDark
                        ? const Color(0xFF3A3A5C)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => setState(() => _showProductSearch = true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Search Product',
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black54,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A1A2E)
        : const Color(0xFFF6FBF8);
    final cardColor = isDark ? const Color(0xFF252542) : Colors.white;

    // Build the main content
    final content = _buildContent(context, isDark, cardColor);

    // If embedded, return content without Scaffold but with FABs
    if (widget.embedded) {
      return Container(
        color: backgroundColor,
        child: SafeArea(child: content),
      );
    }

    // Standalone mode with Scaffold
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: false),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, Color cardColor) {
    return Consumer<MealBuilderViewModel>(
      builder: (context, viewModel, _) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return CustomScrollView(
          slivers: [
            // Back button for embedded mode
            if (widget.embedded && widget.onBack != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: widget.onBack,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ),

            // Header Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_menu,
                          color: Theme.of(context).primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Meal Builder',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Build & analyze your meal',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search Box
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _apiSearchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search ingredients or products (e.g., egg, rice, Coca Cola)',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black38,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _performApiSearch(viewModel),
                              onChanged: (value) {
                                setState(
                                  () {},
                                ); // Rebuild to update clear button
                                if (value.isEmpty) {
                                  viewModel.clearSearchResults();
                                }
                              },
                            ),
                          ),
                          if (viewModel.isSearching)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_apiSearchController.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () {
                                _apiSearchController.clear();
                                viewModel.clearSearchResults();
                                setState(() {});
                              },
                              color: isDark ? Colors.white54 : Colors.black45,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            IconButton(
                              icon: const Icon(Icons.search, size: 22),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                _performApiSearch(viewModel);
                              },
                              color: Theme.of(context).primaryColor,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Meal Type Tabs
                    MealTypeTabs(
                      selectedType: viewModel.selectedMealType,
                      onTypeSelected: viewModel.setMealType,
                    ),
                  ],
                ),
              ),
            ),

            // Quick Add Section - Scan or Search Products
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _buildQuickAddCard(isDark, cardColor),
              ),
            ),

            // Current Recipe Card (My Breakfast/Lunch/etc)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CurrentRecipeCard(
                  mealType: viewModel.selectedMealType,
                  ingredients: viewModel.currentIngredients,
                  onRemoveIngredient: viewModel.removeIngredient,
                  onClearAll: viewModel.clearAll,
                  cardColor: cardColor,
                  isDark: isDark,
                ),
              ),
            ),

            // Health Score Display (only shown when there are ingredients)
            if (viewModel.currentIngredients.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: RecipeHealthScore(
                    score: viewModel.totalHealthScore,
                    rating: viewModel.scoreRating,
                    message: viewModel.scoreMessage,
                    nutrition: viewModel.totalNutrition,
                    isDark: isDark,
                    onLogMeal: () => _logMealToTracker(viewModel),
                  ),
                ),
              ),

            // Show Search Results if available
            if (viewModel.hasSearchResults) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${viewModel.searchResults.length} results found',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                sliver: IngredientGrid(
                  ingredients: viewModel.searchResults,
                  onIngredientTap: _showAddIngredientModal,
                  cardColor: cardColor,
                  isDark: isDark,
                ),
              ),
            ],

            // Empty state when no search results
            if (!viewModel.hasSearchResults) ...[
              // Search hint
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 100),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search,
                        size: 64,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search for ingredients or products',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Type ingredient names like "egg", "chicken", "rice"\nor product names like "Coca Cola", "Doritos"',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
