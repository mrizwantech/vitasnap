import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/scan_result.dart';
import '../../presentation/viewmodels/meal_builder_viewmodel.dart';
import '../../presentation/viewmodels/scan_viewmodel.dart';
import '../../presentation/views/main_navigation.dart';
import '../../presentation/widgets/vitasnap_logo.dart';
import 'widgets/meal_type_tabs.dart';
import 'widgets/ingredient_grid.dart';
import 'widgets/current_recipe_card.dart';
import 'widgets/recipe_health_score.dart';
import 'widgets/add_ingredient_modal.dart';

/// Meal Builder Page - Main UI for building meals and calculating nutrition
class MealBuilderPage extends StatefulWidget {
  const MealBuilderPage({super.key});

  @override
  State<MealBuilderPage> createState() => _MealBuilderPageState();
}

class _MealBuilderPageState extends State<MealBuilderPage> {
  final _searchController = TextEditingController();
  final _apiSearchController = TextEditingController();

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
    super.dispose();
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

  Future<void> _logMealToTracker(MealBuilderViewModel viewModel) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mealType = viewModel.selectedMealType;
    final ingredients = viewModel.currentIngredients;
    
    if (ingredients.isEmpty) return;
    
    // Create a combined name from ingredients
    final mealName = ingredients.length == 1
        ? ingredients.first.name
        : '${mealType.displayName} (${ingredients.length} items)';
    
    // Combine all nutriments
    final totalNutrition = viewModel.totalNutrition;
    final nutriments = <String, dynamic>{
      'energy-kcal_100g': totalNutrition['calories'] ?? 0,
      'proteins_100g': totalNutrition['protein'] ?? 0,
      'carbohydrates_100g': totalNutrition['carbs'] ?? 0,
      'fat_100g': totalNutrition['fat'] ?? 0,
      'fiber_100g': totalNutrition['fiber'] ?? 0,
      'sugars_100g': totalNutrition['sugar'] ?? 0,
      'sodium_100g': totalNutrition['sodium'] ?? 0,
    };
    
    // Create Product from meal
    final product = Product(
      barcode: 'meal_${DateTime.now().millisecondsSinceEpoch}',
      name: mealName,
      brand: '${mealType.emoji} ${mealType.displayName}',
      nutriments: nutriments,
    );
    
    // Create ScanResult with meal type
    final scanResult = ScanResult(
      product: product,
      score: viewModel.totalHealthScore,
      mealType: mealType,
    );
    
    // Add to scan history via ScanViewModel to trigger proper refresh
    final scanViewModel = context.read<ScanViewModel>();
    await scanViewModel.addToHistory(scanResult);
    
    // Clear the meal builder
    viewModel.clearAll();
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(mealType.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${mealType.displayName} logged! Redirecting to home...'),
              ),
            ],
          ),
          backgroundColor: isDark ? const Color(0xFF252542) : const Color(0xFF1B8A4E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF6FBF8);
    final cardColor = isDark ? const Color(0xFF252542) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: false),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SafeArea(
        child: Consumer<MealBuilderViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return CustomScrollView(
              slivers: [
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
                                      color: isDark ? Colors.white70 : Colors.black54,
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
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
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
                                    hintText: 'Search ingredients...',
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
                                  onSubmitted: (_) => _performApiSearch(viewModel),
                                  onChanged: (value) {
                                    setState(() {}); // Rebuild to update clear button
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
                            'Search for ingredients',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type ingredient names like "egg", "chicken", "rice"\nto find nutritional information',
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
        ),
      ),
    );
  }

}
