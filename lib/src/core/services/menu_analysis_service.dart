import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Service for analyzing restaurant menus using Firebase AI (Gemini)
class MenuAnalysisService {
  late final GenerativeModel _model;
  
  MenuAnalysisService() {
    // Initialize the Gemini model via Firebase AI
    // Using gemini-2.5-flash as recommended by Firebase docs
    _model = FirebaseAI.googleAI().generativeModel(
      model: 'gemini-2.5-flash',
    );
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
      
      final response = await _model.generateContent([
        Content.text(prompt),
      ]);

      final text = response.text;
      if (text == null || text.isEmpty) {
        throw Exception('No response from AI model');
      }

      return _parseResponse(text);
    } catch (e) {
      debugPrint('Dish analysis error: $e');
      rethrow;
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
You are a nutritionist AI assistant. Analyze this restaurant menu image and extract all dish names you can identify.

For each dish, provide:
1. The dish name as written on the menu
2. Estimated nutritional information (calories, protein, carbs, fat, sodium)
3. A health recommendation based on the user's profile

User's Health Conditions: $conditions
User's Dietary Preferences: $preferences

Respond ONLY with a valid JSON object in this exact format:
{
  "dishes": [
    {
      "name": "Dish Name",
      "description": "Brief description of the dish",
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

Be conservative with estimates. If you can't identify a dish clearly, skip it.
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
      final jsonMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(responseText);
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

  MenuAnalysisResult({
    required this.dishes,
    required this.summary,
  });

  factory MenuAnalysisResult.fromJson(Map<String, dynamic> json) {
    return MenuAnalysisResult(
      dishes: (json['dishes'] as List<dynamic>?)
          ?.map((d) => DishAnalysis.fromJson(d as Map<String, dynamic>))
          .toList() ?? [],
      summary: json['summary'] as String? ?? '',
    );
  }

  List<DishAnalysis> get bestChoices => 
      dishes.where((d) => d.recommendation == DishRecommendation.best).toList();
  
  List<DishAnalysis> get cautionChoices => 
      dishes.where((d) => d.recommendation == DishRecommendation.caution).toList();
  
  List<DishAnalysis> get avoidChoices => 
      dishes.where((d) => d.recommendation == DishRecommendation.avoid).toList();
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
