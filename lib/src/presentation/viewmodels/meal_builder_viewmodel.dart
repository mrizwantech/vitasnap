import 'package:flutter/foundation.dart';

import '../../domain/entities/recipe.dart';
import '../../domain/usecases/compute_recipe_score.dart';
import '../../domain/usecases/get_preset_ingredients.dart';
import '../../domain/usecases/search_ingredients.dart';
import '../../domain/usecases/get_recipes.dart';
import '../../domain/usecases/save_recipe.dart';

/// ViewModel for the Meal Builder feature
/// Manages the state of the current meal being built
class MealBuilderViewModel extends ChangeNotifier {
  final ComputeRecipeScore _computeRecipeScore;
  final GetPresetIngredients _getPresetIngredients;
  final SearchIngredients _searchIngredients;
  final GetRecipes _getRecipes;
  final SaveRecipe _saveRecipe;

  MealBuilderViewModel(
    this._computeRecipeScore,
    this._getPresetIngredients,
    this._searchIngredients,
    this._getRecipes,
    this._saveRecipe,
  );

  // Current state
  MealType _selectedMealType = MealType.breakfast;
  List<RecipeIngredient> _currentIngredients = [];
  List<RecipeIngredient> _presetIngredients = [];
  List<RecipeIngredient> _searchResults = []; // Results from OpenFoodFacts API
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isLoading = false;
  bool _isSearching = false;
  String? _error;

  // Getters
  MealType get selectedMealType => _selectedMealType;
  List<RecipeIngredient> get currentIngredients => List.unmodifiable(_currentIngredients);
  List<RecipeIngredient> get presetIngredients => List.unmodifiable(_presetIngredients);
  List<RecipeIngredient> get searchResults => List.unmodifiable(_searchResults);
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get error => _error;

  /// Whether we have API search results to show
  bool get hasSearchResults => _searchResults.isNotEmpty;

  /// Get the total health score for current meal using Nutri-Score values
  int get totalHealthScore {
    if (_currentIngredients.isEmpty) return 0;
    int total = 0;
    for (final ingredient in _currentIngredients) {
      total += (ingredient.scoreValue * ingredient.quantity * 0.5).round();
    }
    return total;
  }

  /// Get the health score rating
  HealthScoreRating get scoreRating => _computeRecipeScore.getRating(totalHealthScore);

  /// Get score message for display
  String get scoreMessage => _computeRecipeScore.getScoreMessage(totalHealthScore, _selectedMealType);

  /// Get total nutrition values
  Map<String, double> get totalNutrition {
    final totals = <String, double>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
    };

    for (final ingredient in _currentIngredients) {
      final adjusted = ingredient.adjustedNutriments;
      totals['calories'] = totals['calories']! + adjusted['calories']!;
      totals['protein'] = totals['protein']! + adjusted['protein']!;
      totals['carbs'] = totals['carbs']! + adjusted['carbs']!;
      totals['fat'] = totals['fat']! + adjusted['fat']!;
    }

    return totals;
  }

  /// Get filtered preset ingredients based on search and category
  List<RecipeIngredient> get filteredPresetIngredients {
    var filtered = _presetIngredients;

    // Filter by category
    if (_selectedCategory != 'all') {
      filtered = filtered.where((i) => i.category == _selectedCategory).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((i) => i.name.toLowerCase().contains(query)).toList();
    }

    return filtered;
  }

  /// Get unique categories from preset ingredients
  List<String> get categories {
    final cats = _presetIngredients.map((i) => i.category).toSet().toList();
    return ['all', ...cats];
  }

  /// Initialize the view model - load preset ingredients
  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _presetIngredients = await _getPresetIngredients.call();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load ingredients';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Set the selected meal type
  void setMealType(MealType type) {
    _selectedMealType = type;
    notifyListeners();
  }

  /// Set search query (for filtering preset ingredients)
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Search for ingredients from OpenFoodFacts API
  /// This fetches real nutrition data from the database
  Future<void> searchIngredientsFromApi(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      _isSearching = false;
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _searchResults = await _searchIngredients.call(query);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _searchResults = [];
      _isSearching = false;
      _error = 'Search failed. Check your connection.';
      notifyListeners();
    }
  }

  /// Clear API search results
  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  /// Set selected category filter
  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  /// Add an ingredient to the current meal
  void addIngredient(RecipeIngredient ingredient, double quantity, IngredientUnit unit) {
    // Check if ingredient already exists
    final existingIndex = _currentIngredients.indexWhere((i) => i.id == ingredient.id);

    if (existingIndex >= 0) {
      // Update quantity of existing ingredient
      final existing = _currentIngredients[existingIndex];
      _currentIngredients[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        unit: unit,
      );
    } else {
      // Add new ingredient
      _currentIngredients.add(ingredient.copyWith(
        quantity: quantity,
        unit: unit,
      ));
    }

    notifyListeners();
  }

  /// Remove an ingredient from the current meal
  void removeIngredient(String ingredientId) {
    _currentIngredients.removeWhere((i) => i.id == ingredientId);
    notifyListeners();
  }

  /// Update ingredient quantity
  void updateIngredientQuantity(String ingredientId, double quantity) {
    final index = _currentIngredients.indexWhere((i) => i.id == ingredientId);
    if (index >= 0) {
      _currentIngredients[index] = _currentIngredients[index].copyWith(
        quantity: quantity,
      );
      notifyListeners();
    }
  }

  /// Clear all ingredients
  void clearAll() {
    _currentIngredients = [];
    notifyListeners();
  }

  /// Build and return the current meal as a recipe
  Recipe buildRecipe(String name) {
    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      mealType: _selectedMealType,
      ingredients: List.from(_currentIngredients),
      createdAt: DateTime.now(),
    );
  }

  /// Save the current meal
  Future<void> saveCurrentRecipe(String name) async {
    final recipe = buildRecipe(name);
    await _saveRecipe.call(recipe);
    clearAll();
  }

  /// Get saved meals
  Future<List<Recipe>> getSavedRecipes() async {
    return _getRecipes.call();
  }

  /// Get saved meals by meal type
  Future<List<Recipe>> getSavedRecipesByMealType(MealType mealType) async {
    return _getRecipes.byMealType(mealType);
  }

  /// Calculate the score contribution for a specific quantity
  int calculateScoreForQuantity(RecipeIngredient ingredient, double quantity) {
    return _computeRecipeScore.computeIngredientScore(ingredient, quantity);
  }
}
