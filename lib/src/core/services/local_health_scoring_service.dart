import '../../domain/entities/restaurant.dart';
import 'health_conditions_service.dart';
import 'dietary_preferences_service.dart';
import 'menu_analysis_service.dart';

/// Health rating grade (A-E)
/// NOT the trademarked Nutri-Score - this is VitaSnap's own rating system
enum HealthRating { a, b, c, d, e }

/// Local health scoring service that analyzes menu items
/// using ONLY verified nutrition data from official restaurant sources.
/// 
/// IMPORTANT LEGAL NOTES:
/// - This is for INFORMATIONAL purposes only, NOT medical advice
/// - Users should consult healthcare providers for dietary guidance
/// - Nutrition data comes from official restaurant nutrition guides
/// - We only use data we actually have - NO estimations
/// 
/// Based on general dietary guidelines from:
/// - WHO (World Health Organization) - sodium recommendations
/// - Dietary Guidelines for Americans - general nutrition
class LocalHealthScoringService {
  
  // General daily reference values (not medical recommendations)
  // These are standard reference values used on nutrition labels
  static const double _dailyCalorieReference = 2000;  // kcal
  static const double _dailySodiumReference = 2300;   // mg (FDA reference)
  // Note: Carbs, protein, fat reference values removed as not currently used
  
  /// Legal disclaimer that MUST be shown to users
  static const String disclaimer = '''
IMPORTANT DISCLAIMER

This information is for general reference only and is NOT medical advice.

• Nutrition data is sourced from official restaurant nutrition guides
• Values may vary by location, preparation, and serving size
• Always verify with the restaurant for the most current information
• Consult a healthcare provider or registered dietitian for personalized dietary advice
• Do not use this app to make medical decisions

By using this feature, you acknowledge that VitaSnap is not responsible for dietary decisions made based on this information.
''';

  /// Short disclaimer for display in results
  static const String shortDisclaimer = 
    'For informational purposes only. Not medical advice. '
    'Verify nutrition info with restaurant.';
  
  /// Analyze menu items using ONLY verified nutrition data
  MenuAnalysisResult analyzeMenuItems({
    required List<MenuItem> items,
    required Set<HealthCondition> healthConditions,
    required Set<DietaryRestriction> dietaryRestrictions,
    String? dataSource,
  }) {
    final dishes = <DishAnalysis>[];
    
    for (final item in items) {
      final analysis = _analyzeItem(
        item, 
        healthConditions, 
        dietaryRestrictions,
        dataSource,
      );
      dishes.add(analysis);
    }
    
    // Sort by recommendation (best first, then caution, then avoid)
    dishes.sort((a, b) {
      final order = {
        DishRecommendation.best: 0,
        DishRecommendation.caution: 1,
        DishRecommendation.avoid: 2,
      };
      return order[a.recommendation]!.compareTo(order[b.recommendation]!);
    });
    
    // Generate summary
    final bestCount = dishes.where((d) => d.recommendation == DishRecommendation.best).length;
    final cautionCount = dishes.where((d) => d.recommendation == DishRecommendation.caution).length;
    final avoidCount = dishes.where((d) => d.recommendation == DishRecommendation.avoid).length;
    
    String summary;
    if (avoidCount > 0) {
      summary = 'Based on your preferences, $avoidCount item(s) may not align with your goals. ';
    } else if (cautionCount > 0) {
      summary = '$cautionCount item(s) have higher values in some nutrients. ';
    } else {
      summary = 'These items generally align with your selected preferences. ';
    }
    
    if (bestCount > 0) {
      summary += '$bestCount item(s) are lower in nutrients you\'re watching.';
    }
    
    // Add disclaimer reminder
    summary += '\n\n$shortDisclaimer';
    
    return MenuAnalysisResult(
      dishes: dishes,
      summary: summary,
    );
  }
  
  /// Calculate health rating based ONLY on data we have
  /// Returns null if insufficient data
  HealthRating? _calculateHealthRating({
    required int? calories,
    required int? sodium,
    required int? protein,
    required int? carbs,
    required int? fat,
  }) {
    // If we don't have basic data, don't rate
    if (calories == null) return null;
    
    int score = 0;
    int factorsConsidered = 0;
    
    // Calories (per meal, assuming ~3 meals/day)
    // Reference: ~600-700 cal per meal is moderate
    if (calories <= 400) {
      score += 2;
    } else if (calories <= 600) {
      score += 1;
    } else if (calories <= 800) {
      score += 0;
    } else if (calories <= 1000) {
      score -= 1;
    } else {
      score -= 2;
    }
    factorsConsidered++;
    
    // Sodium (if available)
    // Reference: FDA recommends <2300mg/day, so ~750mg/meal is moderate
    if (sodium != null) {
      if (sodium <= 400) {
        score += 2;
      } else if (sodium <= 700) {
        score += 1;
      } else if (sodium <= 1000) {
        score += 0;
      } else if (sodium <= 1500) {
        score -= 1;
      } else {
        score -= 2;
      }
      factorsConsidered++;
    }
    
    // Protein (if available) - generally positive
    if (protein != null) {
      if (protein >= 25) {
        score += 1;
      } else if (protein >= 15) {
        score += 0;
      }
      factorsConsidered++;
    }
    
    // Calculate average and convert to grade
    if (factorsConsidered == 0) return null;
    
    final avgScore = score / factorsConsidered;
    
    if (avgScore >= 1.5) return HealthRating.a;
    if (avgScore >= 0.5) return HealthRating.b;
    if (avgScore >= -0.5) return HealthRating.c;
    if (avgScore >= -1.5) return HealthRating.d;
    return HealthRating.e;
  }
  
  DishAnalysis _analyzeItem(
    MenuItem item,
    Set<HealthCondition> conditions,
    Set<DietaryRestriction> restrictions,
    String? dataSource,
  ) {
    final notes = <String>[];      // Neutral observations
    final concerns = <String>[];   // Things to be aware of
    
    final calories = item.calories;
    final protein = item.protein;
    final carbs = item.carbs;
    final fat = item.fat;
    final sodium = item.sodium;
    
    // Calculate health rating (only if we have data)
    final healthRating = _calculateHealthRating(
      calories: calories,
      sodium: sodium,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );
    
    // Start with base score from rating
    int score = _healthRatingToBaseScore(healthRating);
    
    // === FACTUAL OBSERVATIONS BASED ON USER'S SELECTED CONDITIONS ===
    // Using neutral language - stating facts, not giving medical advice
    
    if (conditions.contains(HealthCondition.diabetes)) {
      if (carbs != null) {
        if (carbs > 60) {
          concerns.add('Higher carbohydrate content (${carbs}g)');
          score -= 15;
        } else if (carbs > 45) {
          notes.add('Contains ${carbs}g carbohydrates');
          score -= 5;
        } else if (carbs < 30) {
          notes.add('Lower carbohydrate option (${carbs}g)');
          score += 5;
        }
      }
    }
    
    if (conditions.contains(HealthCondition.highBloodPressure)) {
      if (sodium != null) {
        final percentDaily = ((sodium / _dailySodiumReference) * 100).round();
        if (sodium > 1000) {
          concerns.add('Higher sodium ($sodium mg, $percentDaily% daily reference)');
          score -= 20;
        } else if (sodium > 700) {
          notes.add('Contains $sodium mg sodium ($percentDaily% daily reference)');
          score -= 10;
        } else if (sodium < 400) {
          notes.add('Lower sodium option ($sodium mg)');
          score += 5;
        }
      }
    }
    
    if (conditions.contains(HealthCondition.heartDisease)) {
      if (sodium != null && sodium > 800) {
        concerns.add('Higher sodium content ($sodium mg)');
        score -= 10;
      }
      if (fat != null && fat > 30) {
        concerns.add('Higher fat content (${fat}g)');
        score -= 10;
      }
    }
    
    if (conditions.contains(HealthCondition.highCholesterol)) {
      if (fat != null && fat > 25) {
        concerns.add('Higher fat content (${fat}g)');
        score -= 15;
      }
    }
    
    if (conditions.contains(HealthCondition.kidneyDisease)) {
      if (sodium != null && sodium > 600) {
        concerns.add('Higher sodium ($sodium mg)');
        score -= 10;
      }
      if (protein != null && protein > 30) {
        notes.add('Higher protein content (${protein}g)');
        score -= 5;
      }
    }
    
    if (conditions.contains(HealthCondition.obesity)) {
      if (calories != null) {
        final percentDaily = ((calories / _dailyCalorieReference) * 100).round();
        if (calories > 800) {
          concerns.add('Higher calorie content ($calories kcal, $percentDaily% daily reference)');
          score -= 20;
        } else if (calories > 600) {
          notes.add('Contains $calories kcal ($percentDaily% daily reference)');
          score -= 10;
        } else if (calories < 400 && protein != null && protein > 15) {
          notes.add('Lower calorie option with protein ($calories kcal)');
          score += 10;
        }
      }
    }
    
    if (conditions.contains(HealthCondition.gout)) {
      final lowerName = item.name.toLowerCase();
      if (_containsRedMeat(lowerName)) {
        notes.add('Contains red meat');
        score -= 10;
      }
    }
    
    // === DIETARY RESTRICTION CHECKS ===
    
    if (restrictions.contains(DietaryRestriction.glutenFree)) {
      final lowerName = item.name.toLowerCase();
      if (_likelyContainsGluten(lowerName)) {
        concerns.add('May contain gluten - verify with restaurant');
        score -= 25;
      }
    }

    if (restrictions.contains(DietaryRestriction.vegetarian) ||
        restrictions.contains(DietaryRestriction.vegan)) {
      final lowerName = item.name.toLowerCase();
      if (_likelyContainsMeat(lowerName)) {
        concerns.add('Appears to contain meat - verify with restaurant');
        score -= 30;
      }
      if (restrictions.contains(DietaryRestriction.vegan) && _likelyContainsDairy(lowerName)) {
        concerns.add('May contain dairy - verify with restaurant');
        score -= 25;
      }
    }
    
    if (restrictions.contains(DietaryRestriction.dairyFree)) {
      final lowerName = item.name.toLowerCase();
      if (_likelyContainsDairy(lowerName)) {
        concerns.add('May contain dairy - verify with restaurant');
        score -= 20;
      }
    }
    
    if (restrictions.contains(DietaryRestriction.lowSodium)) {
      if (sodium != null && sodium > 600) {
        concerns.add('Higher sodium content ($sodium mg)');
        score -= 15;
      }
    }
    
    // === POSITIVE ATTRIBUTES (factual) ===
    
    if (protein != null && protein > 25 && concerns.isEmpty) {
      notes.add('Good protein source (${protein}g)');
    }
    
    // Clamp score
    score = score.clamp(0, 100);
    
    // Determine recommendation
    DishRecommendation recommendation;
    if (score >= 60) {
      recommendation = DishRecommendation.best;
    } else if (score >= 35) {
      recommendation = DishRecommendation.caution;
    } else {
      recommendation = DishRecommendation.avoid;
    }
    
    // Build reason (factual, not prescriptive)
    final ratingStr = healthRating != null ? 'Rating: ${healthRating.name.toUpperCase()}' : 'Rating: N/A (insufficient data)';
    String reason;
    if (concerns.isEmpty && notes.isNotEmpty) {
      reason = '$ratingStr. ${notes.take(2).join(". ")}';
    } else if (concerns.isNotEmpty) {
      reason = '$ratingStr. ${concerns.take(2).join(". ")}';
    } else if (calories != null) {
      reason = '$ratingStr. $calories kcal${protein != null ? ", ${protein}g protein" : ""}.';
    } else {
      reason = 'Limited nutrition data available. Verify with restaurant.';
    }
    
    // Build tips (informational, not medical)
    String? healthTips;
    if (concerns.isNotEmpty && notes.isNotEmpty) {
      healthTips = notes.first;
    } else if (recommendation == DishRecommendation.caution) {
      healthTips = 'Consider checking portion size or pairing with lower-calorie sides.';
    } else if (recommendation == DishRecommendation.avoid && concerns.isNotEmpty) {
      healthTips = 'You may want to explore other options on the menu.';
    }
    
    // Add data source to description
    String description = item.description ?? '';
    if (dataSource != null) {
      description = '$description\n[Source: $dataSource]'.trim();
    }
    
    return DishAnalysis(
      name: item.name,
      description: description,
      recommendation: recommendation,
      reason: reason,
      estimatedCalories: calories ?? 0,
      estimatedProtein: protein ?? 0,
      estimatedCarbs: carbs ?? 0,
      estimatedFat: fat ?? 0,
      estimatedSodium: sodium ?? 0,
      healthTips: healthTips,
    );
  }
  
  /// Convert health rating to base score
  int _healthRatingToBaseScore(HealthRating? rating) {
    if (rating == null) return 50; // Neutral if no data
    switch (rating) {
      case HealthRating.a: return 80;
      case HealthRating.b: return 65;
      case HealthRating.c: return 50;
      case HealthRating.d: return 35;
      case HealthRating.e: return 20;
    }
  }
  
  // Helper methods use "likely" to indicate uncertainty
  bool _likelyContainsGluten(String name) {
    final glutenKeywords = [
      'bread', 'bun', 'wrap', 'tortilla', 'pasta', 'noodle',
      'breaded', 'crispy', 'fried', 'sandwich', 'burger',
      'pizza', 'pancake', 'waffle', 'muffin', 'cookie',
      'cake', 'pastry', 'croissant', 'bagel', 'roll',
    ];
    return glutenKeywords.any((k) => name.contains(k));
  }
  
  bool _likelyContainsMeat(String name) {
    final meatKeywords = [
      'chicken', 'beef', 'pork', 'bacon', 'ham', 'turkey',
      'steak', 'sausage', 'fish', 'shrimp', 'salmon',
      'tuna', 'cod', 'nugget', 'wing', 'rib', 'brisket',
      'meatball', 'pepperoni', 'chorizo', 'lamb', 'duck',
      'crab', 'lobster', 'prawn', 'anchovy',
    ];
    return meatKeywords.any((k) => name.contains(k));
  }
  
  bool _likelyContainsDairy(String name) {
    final dairyKeywords = [
      'cheese', 'cream', 'milk', 'butter', 'yogurt',
      'latte', 'cappuccino', 'mocha', 'frappuccino',
      'ice cream', 'milkshake',
    ];
    return dairyKeywords.any((k) => name.contains(k));
  }
  
  bool _containsRedMeat(String name) {
    final redMeatKeywords = [
      'beef', 'steak', 'brisket', 'rib',
      'pork', 'bacon', 'ham', 'sausage', 'lamb',
    ];
    return redMeatKeywords.any((k) => name.contains(k));
  }
}
