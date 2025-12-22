import 'dart:developer' as developer;

import '../../core/network/network_service.dart';

/// Data source for USDA FoodData Central API
/// Provides nutrition data for generic ingredients (egg, milk, chicken, etc.)
/// API docs: https://fdc.nal.usda.gov/api-guide.html
class UsdaFoodApi {
  final NetworkService _network;
  
  // USDA FoodData Central API key
  static const _apiKey = 'HGlldcQDTeVyjXetkhsasRODkWdz23JNPcfembng';
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  UsdaFoodApi(this._network);

  /// Search for foods by name
  /// Returns a list of food items with nutrition data
  /// 
  /// [query] - Search term (e.g., "egg", "milk", "chicken breast")
  /// [pageSize] - Number of results to return (default 15)
  /// [dataType] - Filter by data type: 'Foundation', 'SR Legacy', 'Survey (FNDDS)', 'Branded'
  Future<List<Map<String, dynamic>>> searchFoods(
    String query, {
    int pageSize = 15,
    List<String>? dataTypes,
  }) async {
    // Prefer Foundation and SR Legacy for generic ingredients
    // These contain raw/unbranded foods like "egg", "milk", etc.
    final dataTypeParam = dataTypes?.join(',') ?? 'Foundation,SR Legacy,Survey (FNDDS)';
    
    final uri = Uri.parse(
      '$_baseUrl/foods/search?query=${Uri.encodeComponent(query)}'
      '&api_key=$_apiKey'
      '&pageSize=$pageSize'
      '&dataType=${Uri.encodeComponent(dataTypeParam)}'
    );

    developer.log('[UsdaFoodApi] searching $uri', name: 'UsdaFoodApi');

    try {
      final json = await _network.getJson(uri);
      final foods = json['foods'] as List<dynamic>? ?? [];
      developer.log('[UsdaFoodApi] search returned ${foods.length} results', name: 'UsdaFoodApi');
      return foods.cast<Map<String, dynamic>>();
    } catch (e) {
      developer.log('[UsdaFoodApi] search error: $e', name: 'UsdaFoodApi');
      return [];
    }
  }

  /// Get detailed nutrition data for a specific food by FDC ID
  Future<Map<String, dynamic>?> getFoodDetails(int fdcId) async {
    final uri = Uri.parse('$_baseUrl/food/$fdcId?api_key=$_apiKey');

    developer.log('[UsdaFoodApi] fetching details for $fdcId', name: 'UsdaFoodApi');

    try {
      final json = await _network.getJson(uri);
      return json;
    } catch (e) {
      developer.log('[UsdaFoodApi] details error: $e', name: 'UsdaFoodApi');
      return null;
    }
  }

  /// Extract nutrient value from USDA food nutrients array
  /// 
  /// Common nutrient IDs:
  /// - 1008: Energy (kcal)
  /// - 1003: Protein
  /// - 1004: Total lipid (fat)
  /// - 1005: Carbohydrate
  /// - 1079: Fiber
  /// - 2000: Sugars, total
  /// - 1093: Sodium
  /// - 1087: Calcium
  /// - 1089: Iron
  static double getNutrientValue(List<dynamic> nutrients, int nutrientId) {
    for (final nutrient in nutrients) {
      if (nutrient['nutrientId'] == nutrientId) {
        return (nutrient['value'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return 0.0;
  }

  /// Convert USDA food data to a standardized nutriments map (per 100g)
  /// Compatible with our RecipeIngredient format
  static Map<String, dynamic> toNutrimentsMap(Map<String, dynamic> food) {
    final nutrients = food['foodNutrients'] as List<dynamic>? ?? [];
    
    return {
      'energy-kcal_100g': getNutrientValue(nutrients, 1008),
      'proteins_100g': getNutrientValue(nutrients, 1003),
      'fat_100g': getNutrientValue(nutrients, 1004),
      'carbohydrates_100g': getNutrientValue(nutrients, 1005),
      'fiber_100g': getNutrientValue(nutrients, 1079),
      'sugars_100g': getNutrientValue(nutrients, 2000),
      'sodium_100g': getNutrientValue(nutrients, 1093) / 1000, // mg to g
      'saturated-fat_100g': getNutrientValue(nutrients, 1258),
      'salt_100g': getNutrientValue(nutrients, 1093) / 1000 * 2.5, // sodium to salt
    };
  }

  /// Infer a simple Nutri-Score based on USDA nutrient data
  /// This is an approximation since USDA doesn't provide Nutri-Score
  /// Uses simplified Nutri-Score algorithm principles
  static String inferNutriScore(Map<String, dynamic> nutriments) {
    // Get nutrient values per 100g
    final kcal = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0;
    final sugars = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0;
    final satFat = (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 0;
    final sodium = (nutriments['sodium_100g'] as num?)?.toDouble() ?? 0;
    final protein = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0;
    final fiber = (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0;
    
    // Calculate negative points (0-40 scale)
    int negativePoints = 0;
    
    // Energy points (0-10)
    if (kcal > 335) negativePoints += 10;
    else if (kcal > 270) negativePoints += 8;
    else if (kcal > 200) negativePoints += 6;
    else if (kcal > 135) negativePoints += 4;
    else if (kcal > 70) negativePoints += 2;
    else if (kcal > 0) negativePoints += 1;
    
    // Sugars points (0-10)
    if (sugars > 45) negativePoints += 10;
    else if (sugars > 36) negativePoints += 8;
    else if (sugars > 27) negativePoints += 6;
    else if (sugars > 18) negativePoints += 4;
    else if (sugars > 9) negativePoints += 2;
    else if (sugars > 4.5) negativePoints += 1;
    
    // Saturated fat points (0-10)
    if (satFat > 10) negativePoints += 10;
    else if (satFat > 8) negativePoints += 8;
    else if (satFat > 6) negativePoints += 6;
    else if (satFat > 4) negativePoints += 4;
    else if (satFat > 2) negativePoints += 2;
    else if (satFat > 1) negativePoints += 1;
    
    // Sodium points (0-10) - sodium in g
    final sodiumMg = sodium * 1000;
    if (sodiumMg > 900) negativePoints += 10;
    else if (sodiumMg > 720) negativePoints += 8;
    else if (sodiumMg > 540) negativePoints += 6;
    else if (sodiumMg > 360) negativePoints += 4;
    else if (sodiumMg > 180) negativePoints += 2;
    else if (sodiumMg > 90) negativePoints += 1;
    
    // Calculate positive points (0-15 scale)
    int positivePoints = 0;
    
    // Fiber points (0-5)
    if (fiber > 4.7) positivePoints += 5;
    else if (fiber > 3.5) positivePoints += 4;
    else if (fiber > 2.4) positivePoints += 3;
    else if (fiber > 1.2) positivePoints += 2;
    else if (fiber > 0.6) positivePoints += 1;
    
    // Protein points (0-5)
    if (protein > 8) positivePoints += 5;
    else if (protein > 6.4) positivePoints += 4;
    else if (protein > 4.8) positivePoints += 3;
    else if (protein > 3.2) positivePoints += 2;
    else if (protein > 1.6) positivePoints += 1;
    
    // Fruits/vegetables bonus - assume whole foods get some credit
    // This is a simplification since USDA doesn't track this
    if (kcal < 100 && fiber > 1 && sugars < 10 && satFat < 2) {
      positivePoints += 5; // Likely a fruit/vegetable
    }
    
    // Final score: negative - positive (lower is better)
    final finalScore = negativePoints - positivePoints;
    
    // Map to Nutri-Score grade
    if (finalScore <= -1) return 'a';
    if (finalScore <= 2) return 'b';
    if (finalScore <= 10) return 'c';
    if (finalScore <= 18) return 'd';
    return 'e';
  }
}
