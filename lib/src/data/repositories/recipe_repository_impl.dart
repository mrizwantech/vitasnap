import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';
import '../datasources/open_food_facts_api.dart';
import '../datasources/usda_food_api.dart';

/// Implementation of RecipeRepository using SharedPreferences for persistence
/// and USDA FoodData Central API for ingredient nutrition data
class RecipeRepositoryImpl implements RecipeRepository {
  final SharedPreferences _prefs;
  final OpenFoodFactsApi _openFoodFactsApi;
  final UsdaFoodApi _usdaApi;
  static const _recipesKey = 'saved_recipes';

  RecipeRepositoryImpl(this._prefs, this._openFoodFactsApi, this._usdaApi);

  @override
  Future<List<Recipe>> getRecipes() async {
    final jsonString = _prefs.getString(_recipesKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e)))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Recipe>> getRecipesByMealType(MealType mealType) async {
    final recipes = await getRecipes();
    return recipes.where((r) => r.mealType == mealType).toList();
  }

  @override
  Future<Recipe?> getRecipeById(String id) async {
    final recipes = await getRecipes();
    try {
      return recipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRecipe(Recipe recipe) async {
    final recipes = await getRecipes();
    final existingIndex = recipes.indexWhere((r) => r.id == recipe.id);

    if (existingIndex >= 0) {
      recipes[existingIndex] = recipe.copyWith(updatedAt: DateTime.now());
    } else {
      recipes.add(recipe);
    }

    final jsonList = recipes.map((e) => e.toJson()).toList();
    await _prefs.setString(_recipesKey, jsonEncode(jsonList));
  }

  @override
  Future<void> deleteRecipe(String id) async {
    final recipes = await getRecipes();
    recipes.removeWhere((r) => r.id == id);

    final jsonList = recipes.map((e) => e.toJson()).toList();
    await _prefs.setString(_recipesKey, jsonEncode(jsonList));
  }

  @override
  Future<List<RecipeIngredient>> getPresetIngredients() async {
    // Return preset ingredients - these are fallback/quick-pick options
    // Real nutrition data comes from searchIngredients() via USDA API
    return _presetIngredients;
  }

  @override
  Future<List<RecipeIngredient>> searchIngredients(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // Use USDA FoodData Central for generic ingredients
      // This provides accurate nutrition data for raw foods like "egg", "milk", etc.
      final foods = await _usdaApi.searchFoods(query, pageSize: 15);
      
      return foods
          .where((f) => f['description'] != null)
          .map((f) => _usdaFoodToIngredient(f))
          .toList();
    } catch (e) {
      // If API fails, return empty list - UI can show error
      return [];
    }
  }

  /// Convert a USDA food item to a RecipeIngredient
  RecipeIngredient _usdaFoodToIngredient(Map<String, dynamic> food) {
    final nutriments = UsdaFoodApi.toNutrimentsMap(food);
    final name = food['description']?.toString() ?? 'Unknown';
    
    // Clean up USDA names (they can be verbose like "Egg, whole, raw, fresh")
    final displayName = _cleanUsdaName(name);

    // Infer Nutri-Score from nutrition data
    final nutriscoreGrade = UsdaFoodApi.inferNutriScore(nutriments);
    final nutriScore = NutriScoreGrade.fromString(nutriscoreGrade);

    // Infer category from USDA food category or name
    final foodCategory = food['foodCategory']?.toString().toLowerCase() ?? '';
    final category = _inferCategoryFromUsda(foodCategory, name.toLowerCase());

    // Get appropriate emoji based on category and name
    final emoji = _getCategoryEmoji(category, name.toLowerCase());

    return RecipeIngredient(
      id: 'usda_${food['fdcId']?.toString() ?? DateTime.now().millisecondsSinceEpoch}',
      name: displayName,
      iconEmoji: emoji,
      quantity: 100,
      unit: IngredientUnit.gram,
      category: category,
      nutriScore: nutriScore,
      nutriments: nutriments,
    );
  }

  /// Clean up verbose USDA food names
  String _cleanUsdaName(String name) {
    // USDA names are often like "Egg, whole, raw, fresh" - simplify them
    final parts = name.split(',');
    if (parts.length > 2) {
      // Take first two meaningful parts
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return name;
  }

  /// Infer category from USDA food category
  String _inferCategoryFromUsda(String foodCategory, String name) {
    // Check USDA food category first
    if (foodCategory.contains('egg')) return 'protein';
    if (foodCategory.contains('poultry') || foodCategory.contains('meat') || 
        foodCategory.contains('beef') || foodCategory.contains('pork') ||
        foodCategory.contains('fish') || foodCategory.contains('seafood')) {
      return 'protein';
    }
    if (foodCategory.contains('dairy') || foodCategory.contains('milk') ||
        foodCategory.contains('cheese')) {
      return 'dairy';
    }
    if (foodCategory.contains('vegetable')) return 'veggies';
    if (foodCategory.contains('fruit')) return 'fruits';
    if (foodCategory.contains('grain') || foodCategory.contains('cereal') ||
        foodCategory.contains('bread') || foodCategory.contains('pasta')) {
      return 'grains';
    }
    
    // Fall back to name-based inference
    if (name.contains('egg')) return 'protein';
    if (name.contains('chicken') || name.contains('beef') || name.contains('pork') ||
        name.contains('fish') || name.contains('salmon') || name.contains('tuna')) {
      return 'protein';
    }
    if (name.contains('milk') || name.contains('cheese') || name.contains('yogurt')) {
      return 'dairy';
    }
    if (name.contains('apple') || name.contains('banana') || name.contains('orange') ||
        name.contains('berry') || name.contains('fruit')) {
      return 'fruits';
    }
    if (name.contains('broccoli') || name.contains('spinach') || name.contains('carrot') ||
        name.contains('tomato') || name.contains('lettuce')) {
      return 'veggies';
    }
    if (name.contains('bread') || name.contains('rice') || name.contains('pasta') ||
        name.contains('oat') || name.contains('wheat')) {
      return 'grains';
    }
    
    return 'other';
  }

  /// Convert an OpenFoodFacts product to a RecipeIngredient (kept for barcode scans)
  RecipeIngredient _productToIngredient(Map<String, dynamic> product) {
    final nutriments = Map<String, dynamic>.from(product['nutriments'] ?? {});
    final name = product['product_name']?.toString() ?? 'Unknown';
    final brands = product['brands']?.toString();
    final displayName = brands != null && brands.isNotEmpty 
        ? '$name ($brands)' 
        : name;

    // Get Nutri-Score from API or calculate from nutriments
    final nutriscoreGrade = product['nutriscore_grade']?.toString().toLowerCase();
    final nutriScore = NutriScoreGrade.fromString(nutriscoreGrade);

    // Try to determine category from OpenFoodFacts categories
    final categories = product['categories']?.toString().toLowerCase() ?? '';
    final category = _inferCategory(categories);

    // Get appropriate emoji based on category
    final emoji = _getCategoryEmoji(category, name.toLowerCase());

    return RecipeIngredient(
      id: product['code']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: displayName,
      iconEmoji: emoji,
      quantity: 1,
      unit: IngredientUnit.gram,
      category: category,
      nutriScore: nutriScore,
      nutriments: nutriments,
    );
  }

  /// Infer ingredient category from OpenFoodFacts categories
  String _inferCategory(String categories) {
    if (categories.contains('meat') || 
        categories.contains('fish') || 
        categories.contains('egg') ||
        categories.contains('poultry') ||
        categories.contains('seafood')) {
      return 'protein';
    }
    if (categories.contains('vegetable') || categories.contains('salad')) {
      return 'veggies';
    }
    if (categories.contains('fruit') || categories.contains('berry')) {
      return 'fruits';
    }
    if (categories.contains('bread') || 
        categories.contains('cereal') || 
        categories.contains('grain') ||
        categories.contains('pasta') ||
        categories.contains('rice')) {
      return 'grains';
    }
    if (categories.contains('dairy') || 
        categories.contains('milk') || 
        categories.contains('cheese') ||
        categories.contains('yogurt')) {
      return 'dairy';
    }
    return 'other';
  }

  /// Get an appropriate emoji for the ingredient
  String _getCategoryEmoji(String category, String name) {
    // Try to match specific foods first
    if (name.contains('egg')) return '🥚';
    if (name.contains('chicken')) return '🍗';
    if (name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('fish') || name.contains('salmon') || name.contains('tuna')) return '🐟';
    if (name.contains('bacon')) return '🥓';
    if (name.contains('avocado')) return '🥑';
    if (name.contains('tomato')) return '🍅';
    if (name.contains('carrot')) return '🥕';
    if (name.contains('broccoli')) return '🥦';
    if (name.contains('spinach') || name.contains('lettuce')) return '🥬';
    if (name.contains('apple')) return '🍎';
    if (name.contains('banana')) return '🍌';
    if (name.contains('orange')) return '🍊';
    if (name.contains('berry') || name.contains('blueberry')) return '🫐';
    if (name.contains('bread') || name.contains('toast')) return '🍞';
    if (name.contains('rice')) return '🍚';
    if (name.contains('cheese')) return '🧀';
    if (name.contains('milk') || name.contains('yogurt')) return '🥛';
    if (name.contains('honey')) return '🍯';
    if (name.contains('nut') || name.contains('almond')) return '🌰';
    if (name.contains('oil') || name.contains('olive')) return '🫒';
    if (name.contains('peanut')) return '🥜';

    // Fall back to category emoji
    switch (category) {
      case 'protein':
        return '🍖';
      case 'veggies':
        return '🥗';
      case 'fruits':
        return '🍇';
      case 'grains':
        return '🌾';
      case 'dairy':
        return '🧈';
      default:
        return '🍽️';
    }
  }
}

/// Preset ingredients with emoji icons, nutrition data, and Nutri-Score grades
/// Nutri-Score grades based on official scoring criteria:
/// A = Excellent, B = Good, C = Average, D = Poor, E = Bad
final List<RecipeIngredient> _presetIngredients = [
  // Proteins
  RecipeIngredient(
    id: 'egg',
    name: 'Egg',
    iconEmoji: '🥚',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'protein',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 155,
      'proteins_100g': 13,
      'carbohydrates_100g': 1.1,
      'fat_100g': 11,
      'sugars_100g': 1.1,
      'fiber_100g': 0,
      'sodium_100g': 0.124,
    },
  ),
  RecipeIngredient(
    id: 'chicken_breast',
    name: 'Chicken Breast',
    iconEmoji: '🍗',
    quantity: 1,
    unit: IngredientUnit.piece,
    category: 'protein',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 165,
      'proteins_100g': 31,
      'carbohydrates_100g': 0,
      'fat_100g': 3.6,
      'sugars_100g': 0,
      'fiber_100g': 0,
      'sodium_100g': 0.074,
    },
  ),
  RecipeIngredient(
    id: 'salmon',
    name: 'Salmon',
    iconEmoji: '🐟',
    quantity: 1,
    unit: IngredientUnit.piece,
    category: 'protein',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 208,
      'proteins_100g': 20,
      'carbohydrates_100g': 0,
      'fat_100g': 13,
      'sugars_100g': 0,
      'fiber_100g': 0,
      'sodium_100g': 0.059,
    },
  ),
  RecipeIngredient(
    id: 'bacon',
    name: 'Bacon',
    iconEmoji: '🥓',
    quantity: 1,
    unit: IngredientUnit.slice,
    category: 'protein',
    nutriScore: NutriScoreGrade.e, // High fat, high sodium
    nutriments: {
      'energy-kcal_100g': 541,
      'proteins_100g': 37,
      'carbohydrates_100g': 1.4,
      'fat_100g': 42,
      'sugars_100g': 0,
      'fiber_100g': 0,
      'sodium_100g': 1.717,
    },
  ),
  RecipeIngredient(
    id: 'tofu',
    name: 'Tofu',
    iconEmoji: '🧈',
    quantity: 1,
    unit: IngredientUnit.piece,
    category: 'protein',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 76,
      'proteins_100g': 8,
      'carbohydrates_100g': 1.9,
      'fat_100g': 4.8,
      'sugars_100g': 0.6,
      'fiber_100g': 0.3,
      'sodium_100g': 0.007,
    },
  ),

  // Vegetables
  RecipeIngredient(
    id: 'avocado',
    name: 'Avocado',
    iconEmoji: '🥑',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'veggies',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 160,
      'proteins_100g': 2,
      'carbohydrates_100g': 9,
      'fat_100g': 15,
      'sugars_100g': 0.7,
      'fiber_100g': 7,
      'sodium_100g': 0.007,
    },
  ),
  RecipeIngredient(
    id: 'spinach',
    name: 'Spinach',
    iconEmoji: '🥬',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'veggies',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 23,
      'proteins_100g': 2.9,
      'carbohydrates_100g': 3.6,
      'fat_100g': 0.4,
      'sugars_100g': 0.4,
      'fiber_100g': 2.2,
      'sodium_100g': 0.079,
    },
  ),
  RecipeIngredient(
    id: 'broccoli',
    name: 'Broccoli',
    iconEmoji: '🥦',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'veggies',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 34,
      'proteins_100g': 2.8,
      'carbohydrates_100g': 7,
      'fat_100g': 0.4,
      'sugars_100g': 1.7,
      'fiber_100g': 2.6,
      'sodium_100g': 0.033,
    },
  ),
  RecipeIngredient(
    id: 'tomato',
    name: 'Tomato',
    iconEmoji: '🍅',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'veggies',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 18,
      'proteins_100g': 0.9,
      'carbohydrates_100g': 3.9,
      'fat_100g': 0.2,
      'sugars_100g': 2.6,
      'fiber_100g': 1.2,
      'sodium_100g': 0.005,
    },
  ),
  RecipeIngredient(
    id: 'carrot',
    name: 'Carrot',
    iconEmoji: '🥕',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'veggies',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 41,
      'proteins_100g': 0.9,
      'carbohydrates_100g': 10,
      'fat_100g': 0.2,
      'sugars_100g': 4.7,
      'fiber_100g': 2.8,
      'sodium_100g': 0.069,
    },
  ),

  // Fruits
  RecipeIngredient(
    id: 'banana',
    name: 'Banana',
    iconEmoji: '🍌',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'fruits',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 89,
      'proteins_100g': 1.1,
      'carbohydrates_100g': 23,
      'fat_100g': 0.3,
      'sugars_100g': 12,
      'fiber_100g': 2.6,
      'sodium_100g': 0.001,
    },
  ),
  RecipeIngredient(
    id: 'apple',
    name: 'Apple',
    iconEmoji: '🍎',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'fruits',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 52,
      'proteins_100g': 0.3,
      'carbohydrates_100g': 14,
      'fat_100g': 0.2,
      'sugars_100g': 10,
      'fiber_100g': 2.4,
      'sodium_100g': 0.001,
    },
  ),
  RecipeIngredient(
    id: 'berries',
    name: 'Berries',
    iconEmoji: '🫐',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'fruits',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 57,
      'proteins_100g': 0.7,
      'carbohydrates_100g': 14,
      'fat_100g': 0.3,
      'sugars_100g': 10,
      'fiber_100g': 2.4,
      'sodium_100g': 0.001,
    },
  ),
  RecipeIngredient(
    id: 'orange',
    name: 'Orange',
    iconEmoji: '🍊',
    quantity: 1,
    unit: IngredientUnit.whole,
    category: 'fruits',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 47,
      'proteins_100g': 0.9,
      'carbohydrates_100g': 12,
      'fat_100g': 0.1,
      'sugars_100g': 9,
      'fiber_100g': 2.4,
      'sodium_100g': 0,
    },
  ),

  // Grains
  RecipeIngredient(
    id: 'whole_wheat_toast',
    name: 'Whole Wheat Toast',
    iconEmoji: '🍞',
    quantity: 1,
    unit: IngredientUnit.slice,
    category: 'grains',
    nutriScore: NutriScoreGrade.b,
    nutriments: {
      'energy-kcal_100g': 247,
      'proteins_100g': 13,
      'carbohydrates_100g': 41,
      'fat_100g': 3.4,
      'sugars_100g': 6,
      'fiber_100g': 7,
      'sodium_100g': 0.4,
    },
  ),
  RecipeIngredient(
    id: 'oatmeal',
    name: 'Oatmeal',
    iconEmoji: '🥣',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'grains',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 68,
      'proteins_100g': 2.4,
      'carbohydrates_100g': 12,
      'fat_100g': 1.4,
      'sugars_100g': 0.5,
      'fiber_100g': 1.7,
      'sodium_100g': 0.049,
    },
  ),
  RecipeIngredient(
    id: 'rice',
    name: 'Brown Rice',
    iconEmoji: '🍚',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'grains',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 111,
      'proteins_100g': 2.6,
      'carbohydrates_100g': 23,
      'fat_100g': 0.9,
      'sugars_100g': 0.4,
      'fiber_100g': 1.8,
      'sodium_100g': 0.005,
    },
  ),
  RecipeIngredient(
    id: 'quinoa',
    name: 'Quinoa',
    iconEmoji: '🌾',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'grains',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 120,
      'proteins_100g': 4.4,
      'carbohydrates_100g': 21,
      'fat_100g': 1.9,
      'sugars_100g': 0.9,
      'fiber_100g': 2.8,
      'sodium_100g': 0.007,
    },
  ),

  // Dairy
  RecipeIngredient(
    id: 'cheese',
    name: 'Cheese',
    iconEmoji: '🧀',
    quantity: 1,
    unit: IngredientUnit.slice,
    category: 'dairy',
    nutriScore: NutriScoreGrade.d, // High saturated fat, sodium
    nutriments: {
      'energy-kcal_100g': 402,
      'proteins_100g': 25,
      'carbohydrates_100g': 1.3,
      'fat_100g': 33,
      'sugars_100g': 0.5,
      'fiber_100g': 0,
      'sodium_100g': 0.621,
    },
  ),
  RecipeIngredient(
    id: 'yogurt',
    name: 'Greek Yogurt',
    iconEmoji: '🥛',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'dairy',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 59,
      'proteins_100g': 10,
      'carbohydrates_100g': 3.6,
      'fat_100g': 0.7,
      'sugars_100g': 3.2,
      'fiber_100g': 0,
      'sodium_100g': 0.036,
    },
  ),
  RecipeIngredient(
    id: 'milk',
    name: 'Milk',
    iconEmoji: '🥛',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'dairy',
    nutriScore: NutriScoreGrade.b,
    nutriments: {
      'energy-kcal_100g': 42,
      'proteins_100g': 3.4,
      'carbohydrates_100g': 5,
      'fat_100g': 1,
      'sugars_100g': 5,
      'fiber_100g': 0,
      'sodium_100g': 0.044,
    },
  ),

  // Other/Extras
  RecipeIngredient(
    id: 'honey',
    name: 'Honey',
    iconEmoji: '🍯',
    quantity: 1,
    unit: IngredientUnit.tbsp,
    category: 'other',
    nutriScore: NutriScoreGrade.d, // High sugar
    nutriments: {
      'energy-kcal_100g': 304,
      'proteins_100g': 0.3,
      'carbohydrates_100g': 82,
      'fat_100g': 0,
      'sugars_100g': 82,
      'fiber_100g': 0.2,
      'sodium_100g': 0.004,
    },
  ),
  RecipeIngredient(
    id: 'peanut_butter',
    name: 'Peanut Butter',
    iconEmoji: '🥜',
    quantity: 1,
    unit: IngredientUnit.tbsp,
    category: 'other',
    nutriScore: NutriScoreGrade.c,
    nutriments: {
      'energy-kcal_100g': 588,
      'proteins_100g': 25,
      'carbohydrates_100g': 20,
      'fat_100g': 50,
      'sugars_100g': 9,
      'fiber_100g': 6,
      'sodium_100g': 0.17,
    },
  ),
  RecipeIngredient(
    id: 'olive_oil',
    name: 'Olive Oil',
    iconEmoji: '🫒',
    quantity: 1,
    unit: IngredientUnit.tbsp,
    category: 'other',
    nutriScore: NutriScoreGrade.c, // Pure fat but healthy fats
    nutriments: {
      'energy-kcal_100g': 884,
      'proteins_100g': 0,
      'carbohydrates_100g': 0,
      'fat_100g': 100,
      'sugars_100g': 0,
      'fiber_100g': 0,
      'sodium_100g': 0.002,
    },
  ),
  RecipeIngredient(
    id: 'almonds',
    name: 'Almonds',
    iconEmoji: '🌰',
    quantity: 1,
    unit: IngredientUnit.cup,
    category: 'other',
    nutriScore: NutriScoreGrade.a,
    nutriments: {
      'energy-kcal_100g': 579,
      'proteins_100g': 21,
      'carbohydrates_100g': 22,
      'fat_100g': 50,
      'sugars_100g': 4.4,
      'fiber_100g': 12,
      'sodium_100g': 0.001,
    },
  ),
];
