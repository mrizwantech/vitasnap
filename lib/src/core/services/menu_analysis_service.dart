import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Service for analyzing restaurant menus using Firebase AI (Gemini)
class MenuAnalysisService {
  late final GenerativeModel _model;

  MenuAnalysisService() {
    // Initialize the Gemini model via Firebase AI
    // Using gemini-2.5-flash as recommended by Firebase docs
    _model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');
  }

  /// Analyzes a menu image and extracts dish information with health recommendations
  ///
  /// [imageBytes] - The image data of the menu
  /// [healthConditions] - List of user's health conditions (e.g., 'diabetes', 'hypertension')
  /// [dietaryPreferences] - List of dietary preferences (e.g., 'vegetarian', 'low-sodium')
  Future<MenuAnalysisResult> analyzeMenuImage({
    required Uint8List imageBytes,
    required List<String> healthConditions,
    required List<String> dietaryPreferences,
  }) async {
    try {
      final prompt = _buildAnalysisPrompt(healthConditions, dietaryPreferences);

      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('No response from AI model');
      }

      return _parseResponse(text);
    } catch (e) {
      debugPrint('Menu analysis error: $e');
      // Provide user-friendly error messages
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('app check') || errorStr.contains('token is invalid')) {
        throw Exception(
          'AI service temporarily unavailable. Please try again in a moment, '
          'or restart the app if the issue persists.'
        );
      }
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Analyzes dish names provided as text (for manual entry or OCR results)
  Future<MenuAnalysisResult> analyzeDishNames({
    required List<String> dishNames,
    required List<String> healthConditions,
    required List<String> dietaryPreferences,
  }) async {
    try {
      final prompt = _buildTextAnalysisPrompt(
        dishNames,
        healthConditions,
        dietaryPreferences,
      );

      final response = await _model.generateContent([Content.text(prompt)]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('No response from AI model');
      }

      return _parseResponse(text);
    } catch (e) {
      debugPrint('Dish analysis error: $e');
      // Provide user-friendly error messages
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('app check') || errorStr.contains('token is invalid')) {
        throw Exception(
          'AI service temporarily unavailable. Please try again in a moment, '
          'or restart the app if the issue persists.'
        );
      }
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Analyzes a photo of a food product (e.g., packaged food, prepared meal)
  /// Returns estimated nutritional info based on visual analysis
  ///
  /// [imageBytes] - The image data of the food product
  /// [productName] - Optional: Known name of the product (e.g., from package)
  /// [healthConditions] - List of user's health conditions
  /// [dietaryPreferences] - List of dietary preferences
  Future<FoodProductAnalysis> analyzeFoodProductImage({
    required Uint8List imageBytes,
    String? productName,
    required List<String> healthConditions,
    required List<String> dietaryPreferences,
  }) async {
    try {
      final prompt = _buildFoodProductPrompt(
        productName,
        healthConditions,
        dietaryPreferences,
      );

      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          InlineDataPart('image/jpeg', imageBytes),
        ]),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('No response from AI model');
      }

      return _parseFoodProductResponse(text);
    } catch (e) {
      debugPrint('Food product analysis error: $e');
      // Provide user-friendly error messages
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('app check') || errorStr.contains('token is invalid')) {
        throw Exception(
          'AI service temporarily unavailable. Please try again in a moment, '
          'or restart the app if the issue persists.'
        );
      }
      if (errorStr.contains('network') || errorStr.contains('connection')) {
        throw Exception('Network error. Please check your internet connection.');
      }
      rethrow;
    }
  }

  String _buildFoodProductPrompt(
    String? productName,
    List<String> healthConditions,
    List<String> dietaryPreferences,
  ) {
    final conditions = healthConditions.isEmpty
        ? 'None specified'
        : healthConditions.join(', ');
    final preferences = dietaryPreferences.isEmpty
        ? 'None specified'
        : dietaryPreferences.join(', ');
    final nameHint = productName != null && productName.isNotEmpty
        ? 'The product may be: $productName'
        : 'Identify the food product from the image.';

    return '''
You are a nutritionist AI with PRECISE OCR capabilities for reading nutrition labels.

CRITICAL TASK: Read the nutrition label EXACTLY. Do NOT estimate or guess if numbers are visible.

$nameHint

STEP 1 - FIND THE NUTRITION FACTS PANEL:
Look for "Nutrition Facts" or "Datos de Nutrición" label on the packaging.

STEP 2 - READ EACH NUMBER EXACTLY AS PRINTED:
- Calories: Read the EXACT number next to "Calories" or "Calorías" (e.g., if it says "150", return 150, NOT 160)
- Total Fat: Read exact grams (e.g., "2.5g" means 2.5)
- Saturated Fat: Read exact grams
- Sodium: Read exact milligrams
- Total Carbohydrate: Read exact grams (e.g., "24g" means 24, NOT 30)
- Dietary Fiber: Read exact grams
- Total Sugars: Read exact grams
- Protein: Read exact grams

STEP 3 - READ SERVING SIZE:
Copy the serving size text exactly (e.g., "1 cup/1 taza (37g)")

STEP 4 - READ PRODUCT NAME:
Read the product name from the front of the package exactly as written.

IMPORTANT: If you see TWO columns (e.g., "Cereal" and "With Milk"), use the FIRST column values (cereal only).

User's Health Conditions: $conditions
User's Dietary Preferences: $preferences

Respond ONLY with a valid JSON object:
{
  "productName": "EXACT product name from package",
  "brand": "Brand name or null",
  "servingSize": "EXACT serving size text from label",
  "estimatedCalories": <EXACT number from label>,
  "estimatedProtein": <EXACT grams from label>,
  "estimatedCarbs": <EXACT grams from label>,
  "estimatedFat": <EXACT grams from label>,
  "estimatedSodium": <EXACT mg from label>,
  "estimatedFiber": <EXACT grams from label>,
  "estimatedSugar": <EXACT grams from label>,
  "ingredients": "Ingredients if visible",
  "recommendation": "best" | "caution" | "avoid",
  "reason": "Why this recommendation",
  "healthTips": "Any tips for the user",
  "confidence": "high" | "medium" | "low"
}

ACCURACY RULES:
- If label says 150 calories, return 150 (not 160, not 145)
- If label says 24g carbs, return 24 (not 30, not 25)
- If label says 2.5g fat, return 2.5 (not 3)
- confidence = "high" ONLY if you read values directly from a visible nutrition label
- confidence = "medium" or "low" if you had to estimate

Recommendation categories:
- "best": Safe and healthy for user's conditions
- "caution": Consume occasionally or with modifications
- "avoid": Not recommended due to health conditions
''';
  }

  FoodProductAnalysis _parseFoodProductResponse(String responseText) {
    try {
      String jsonStr = responseText;

      // Remove markdown code blocks if present
      final jsonMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)\s*```',
      ).firstMatch(responseText);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1) ?? responseText;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return FoodProductAnalysis.fromJson(json);
    } catch (e) {
      debugPrint('Failed to parse food product response: $e');
      debugPrint('Response was: $responseText');
      throw Exception('Failed to parse food product analysis results');
    }
  }

  String _buildAnalysisPrompt(
    List<String> healthConditions,
    List<String> dietaryPreferences,
  ) {
    final conditions = healthConditions.isEmpty
        ? 'None specified'
        : healthConditions.join(', ');
    final preferences = dietaryPreferences.isEmpty
        ? 'None specified'
        : dietaryPreferences.join(', ');

    return '''
You are a nutritionist AI assistant with expert OCR capabilities for reading restaurant menus.

TASK: Carefully read and analyze this restaurant menu image.

PRIORITY 1 - READ MENU TEXT ACCURATELY:
- Read each dish name EXACTLY as written on the menu
- Read prices if visible
- Read any descriptions or ingredients listed
- Pay attention to section headers (Appetizers, Mains, Desserts, etc.)
- Note any dietary symbols (V for vegetarian, GF for gluten-free, etc.)

PRIORITY 2 - ANALYZE EACH DISH:
For each dish you can clearly read, provide:
1. The exact dish name as written
2. Description from menu or inferred from name
3. Estimated nutritional values based on typical preparation
4. Health recommendation for this user

User's Health Conditions: $conditions
User's Dietary Preferences: $preferences

Respond ONLY with a valid JSON object in this exact format:
{
  "dishes": [
    {
      "name": "Exact Dish Name from Menu",
      "description": "Description from menu or typical preparation",
      "estimatedCalories": 500,
      "estimatedProtein": 25,
      "estimatedCarbs": 45,
      "estimatedFat": 20,
      "estimatedSodium": 800,
      "recommendation": "best" | "caution" | "avoid",
      "reason": "Why this recommendation based on user's health conditions",
      "healthTips": "Tips to make it healthier (ask for sauce on side, etc.)"
    }
  ],
  "summary": "Overview of best choices and items to avoid for this user"
}

Recommendation categories:
- "best": Safe and healthy choice for the user's conditions
- "caution": Can be consumed occasionally or with modifications  
- "avoid": Not recommended due to health conditions

IMPORTANT:
- Only include dishes you can clearly read from the menu
- If text is blurry or unclear, skip that item
- Be conservative with nutritional estimates
''';
  }

  String _buildTextAnalysisPrompt(
    List<String> dishNames,
    List<String> healthConditions,
    List<String> dietaryPreferences,
  ) {
    final dishes = dishNames.join('\n- ');
    final conditions = healthConditions.isEmpty
        ? 'None specified'
        : healthConditions.join(', ');
    final preferences = dietaryPreferences.isEmpty
        ? 'None specified'
        : dietaryPreferences.join(', ');

    return '''
You are a nutritionist AI assistant. Analyze these restaurant menu items and provide health recommendations.

Menu Items:
- $dishes

User's Health Conditions: $conditions
User's Dietary Preferences: $preferences

Respond ONLY with a valid JSON object in this exact format:
{
  "dishes": [
    {
      "name": "Dish Name",
      "description": "Brief description of what this dish typically contains",
      "estimatedCalories": 500,
      "estimatedProtein": 25,
      "estimatedCarbs": 45,
      "estimatedFat": 20,
      "estimatedSodium": 800,
      "recommendation": "best" | "caution" | "avoid",
      "reason": "Why this recommendation was made based on health conditions",
      "healthTips": "Optional tips to make this dish healthier"
    }
  ],
  "summary": "Overall summary of menu options for this user"
}

Recommendation categories:
- "best": Safe and healthy choice for the user's conditions
- "caution": Can be consumed occasionally or with modifications
- "avoid": Not recommended due to health conditions

Provide reasonable estimates based on typical restaurant portions.
''';
  }

  MenuAnalysisResult _parseResponse(String responseText) {
    try {
      // Extract JSON from response (handle markdown code blocks)
      String jsonStr = responseText;

      // Remove markdown code blocks if present
      final jsonMatch = RegExp(
        r'```(?:json)?\s*([\s\S]*?)\s*```',
      ).firstMatch(responseText);
      if (jsonMatch != null) {
        jsonStr = jsonMatch.group(1) ?? responseText;
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return MenuAnalysisResult.fromJson(json);
    } catch (e) {
      debugPrint('Failed to parse AI response: $e');
      debugPrint('Response was: $responseText');
      throw Exception('Failed to parse menu analysis results');
    }
  }
}

/// Result of menu analysis
class MenuAnalysisResult {
  final List<DishAnalysis> dishes;
  final String summary;

  MenuAnalysisResult({required this.dishes, required this.summary});

  factory MenuAnalysisResult.fromJson(Map<String, dynamic> json) {
    return MenuAnalysisResult(
      dishes:
          (json['dishes'] as List<dynamic>?)
              ?.map((d) => DishAnalysis.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      summary: json['summary'] as String? ?? '',
    );
  }

  List<DishAnalysis> get bestChoices =>
      dishes.where((d) => d.recommendation == DishRecommendation.best).toList();

  List<DishAnalysis> get cautionChoices => dishes
      .where((d) => d.recommendation == DishRecommendation.caution)
      .toList();

  List<DishAnalysis> get avoidChoices => dishes
      .where((d) => d.recommendation == DishRecommendation.avoid)
      .toList();
}

/// Analysis of a single dish
class DishAnalysis {
  final String name;
  final String description;
  final int estimatedCalories;
  final int estimatedProtein;
  final int estimatedCarbs;
  final int estimatedFat;
  final int estimatedSodium;
  final DishRecommendation recommendation;
  final String reason;
  final String? healthTips;

  DishAnalysis({
    required this.name,
    required this.description,
    required this.estimatedCalories,
    required this.estimatedProtein,
    required this.estimatedCarbs,
    required this.estimatedFat,
    required this.estimatedSodium,
    required this.recommendation,
    required this.reason,
    this.healthTips,
  });

  factory DishAnalysis.fromJson(Map<String, dynamic> json) {
    return DishAnalysis(
      name: json['name'] as String? ?? 'Unknown Dish',
      description: json['description'] as String? ?? '',
      estimatedCalories: (json['estimatedCalories'] as num?)?.toInt() ?? 0,
      estimatedProtein: (json['estimatedProtein'] as num?)?.toInt() ?? 0,
      estimatedCarbs: (json['estimatedCarbs'] as num?)?.toInt() ?? 0,
      estimatedFat: (json['estimatedFat'] as num?)?.toInt() ?? 0,
      estimatedSodium: (json['estimatedSodium'] as num?)?.toInt() ?? 0,
      recommendation: DishRecommendation.fromString(
        json['recommendation'] as String? ?? 'caution',
      ),
      reason: json['reason'] as String? ?? '',
      healthTips: json['healthTips'] as String?,
    );
  }
}

/// Health recommendation for a dish
enum DishRecommendation {
  best,
  caution,
  avoid;

  static DishRecommendation fromString(String value) {
    switch (value.toLowerCase()) {
      case 'best':
        return DishRecommendation.best;
      case 'avoid':
        return DishRecommendation.avoid;
      default:
        return DishRecommendation.caution;
    }
  }

  String get displayName {
    switch (this) {
      case DishRecommendation.best:
        return 'Best Choice';
      case DishRecommendation.caution:
        return 'Use Caution';
      case DishRecommendation.avoid:
        return 'Avoid';
    }
  }

  String get emoji {
    switch (this) {
      case DishRecommendation.best:
        return '✅';
      case DishRecommendation.caution:
        return '⚠️';
      case DishRecommendation.avoid:
        return '❌';
    }
  }
}

/// Result of analyzing a food product image
class FoodProductAnalysis {
  final String productName;
  final String? brand;
  final String servingSize;
  final int estimatedCalories;
  final int estimatedProtein;
  final int estimatedCarbs;
  final int estimatedFat;
  final int estimatedSodium;
  final int estimatedFiber;
  final int estimatedSugar;
  final String? ingredients;
  final DishRecommendation recommendation;
  final String reason;
  final String? healthTips;
  final String confidence; // high, medium, low

  FoodProductAnalysis({
    required this.productName,
    this.brand,
    required this.servingSize,
    required this.estimatedCalories,
    required this.estimatedProtein,
    required this.estimatedCarbs,
    required this.estimatedFat,
    required this.estimatedSodium,
    this.estimatedFiber = 0,
    this.estimatedSugar = 0,
    this.ingredients,
    required this.recommendation,
    required this.reason,
    this.healthTips,
    this.confidence = 'medium',
  });

  factory FoodProductAnalysis.fromJson(Map<String, dynamic> json) {
    return FoodProductAnalysis(
      productName: json['productName'] as String? ?? 'Unknown Product',
      brand: json['brand'] as String?,
      servingSize: json['servingSize'] as String? ?? '1 serving',
      estimatedCalories: (json['estimatedCalories'] as num?)?.toInt() ?? 0,
      estimatedProtein: (json['estimatedProtein'] as num?)?.toInt() ?? 0,
      estimatedCarbs: (json['estimatedCarbs'] as num?)?.toInt() ?? 0,
      estimatedFat: (json['estimatedFat'] as num?)?.toInt() ?? 0,
      estimatedSodium: (json['estimatedSodium'] as num?)?.toInt() ?? 0,
      estimatedFiber: (json['estimatedFiber'] as num?)?.toInt() ?? 0,
      estimatedSugar: (json['estimatedSugar'] as num?)?.toInt() ?? 0,
      ingredients: json['ingredients'] as String?,
      recommendation: DishRecommendation.fromString(
        json['recommendation'] as String? ?? 'caution',
      ),
      reason: json['reason'] as String? ?? '',
      healthTips: json['healthTips'] as String?,
      confidence: json['confidence'] as String? ?? 'medium',
    );
  }
}
