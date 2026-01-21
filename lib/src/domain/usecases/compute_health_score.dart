import '../entities/product.dart';

/// Represents a factor that affected the health score
class ScoreFactor {
  final String name;
  final String description;
  final bool isPositive;
  final double impact; // Positive = contributed positively, negative = penalized

  const ScoreFactor({
    required this.name,
    required this.description,
    required this.isPositive,
    required this.impact,
  });
}

/// Result of health score computation with breakdown
class HealthScoreResult {
  final int score;
  final String? nutriscoreGrade;
  final List<ScoreFactor> factors;

  const HealthScoreResult({
    required this.score,
    this.nutriscoreGrade,
    required this.factors,
  });
}

class ComputeHealthScore {
  /// Compute health score using Nutri-Score if available,
  /// otherwise fall back to a heuristic based on nutriments.
  /// 
  /// Nutri-Score mapping: A=100, B=75, C=50, D=25, E=0
  int call(Product p) {
    // Prefer official Nutri-Score from OpenFoodFacts
    if (p.nutriscoreGrade != null && p.nutriscoreGrade!.isNotEmpty) {
      return p.nutriScoreValue;
    }
    
    // Fallback: compute heuristic score from nutriments
    return _computeFromNutriments(p.nutriments).score;
  }

  /// Compute health score with detailed breakdown of factors
  HealthScoreResult computeWithBreakdown(Product p) {
    // Prefer official Nutri-Score from OpenFoodFacts
    if (p.nutriscoreGrade != null && p.nutriscoreGrade!.isNotEmpty) {
      return HealthScoreResult(
        score: p.nutriScoreValue,
        nutriscoreGrade: p.nutriscoreGrade,
        factors: _getNutriScoreFactors(p),
      );
    }
    
    // Fallback: compute heuristic score from nutriments
    return _computeFromNutriments(p.nutriments);
  }

  /// Get factors that explain the Nutri-Score grade
  List<ScoreFactor> _getNutriScoreFactors(Product p) {
    final factors = <ScoreFactor>[];
    final n = p.nutriments;
    
    // Analyze negative factors (things that lower the score)
    final sugar = _toDouble(n['sugars_100g']);
    if (sugar > 22.5) {
      factors.add(ScoreFactor(
        name: 'High Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g (very high)',
        isPositive: false,
        impact: -20,
      ));
    } else if (sugar > 12.5) {
      factors.add(ScoreFactor(
        name: 'Moderate Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g',
        isPositive: false,
        impact: -10,
      ));
    }

    final satFat = _toDouble(n['saturated-fat_100g']);
    if (satFat > 5) {
      factors.add(ScoreFactor(
        name: 'High Saturated Fat',
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -15,
      ));
    } else if (satFat > 2) {
      factors.add(ScoreFactor(
        name: 'Moderate Saturated Fat',
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -8,
      ));
    }

    final salt = _toDouble(n['salt_100g']);
    if (salt > 1.5) {
      factors.add(ScoreFactor(
        name: 'High Sodium',
        description: 'Contains ${(salt * 1000 / 2.5).round()}mg sodium per 100g',
        isPositive: false,
        impact: -15,
      ));
    } else if (salt > 0.6) {
      factors.add(ScoreFactor(
        name: 'Moderate Sodium',
        description: 'Contains ${(salt * 1000 / 2.5).round()}mg sodium per 100g',
        isPositive: false,
        impact: -8,
      ));
    }

    final calories = _toDouble(n['energy-kcal_100g']);
    if (calories > 400) {
      factors.add(ScoreFactor(
        name: 'High Calories',
        description: 'Contains ${calories.round()} kcal per 100g',
        isPositive: false,
        impact: -10,
      ));
    }

    // Analyze positive factors
    final fiber = _toDouble(n['fiber_100g']);
    if (fiber > 6) {
      factors.add(ScoreFactor(
        name: 'High Fiber',
        description: 'Contains ${fiber.toStringAsFixed(1)}g fiber per 100g',
        isPositive: true,
        impact: 10,
      ));
    } else if (fiber > 3) {
      factors.add(ScoreFactor(
        name: 'Good Fiber',
        description: 'Contains ${fiber.toStringAsFixed(1)}g fiber per 100g',
        isPositive: true,
        impact: 5,
      ));
    }

    final protein = _toDouble(n['proteins_100g']);
    if (protein > 8) {
      factors.add(ScoreFactor(
        name: 'High Protein',
        description: 'Contains ${protein.toStringAsFixed(1)}g protein per 100g',
        isPositive: true,
        impact: 8,
      ));
    }

    // If no specific factors found, add a general note
    if (factors.isEmpty) {
      final grade = p.nutriscoreGrade!.toUpperCase();
      if (grade == 'A' || grade == 'B') {
        factors.add(const ScoreFactor(
          name: 'Balanced Nutrition',
          description: 'This product has a good nutritional balance',
          isPositive: true,
          impact: 0,
        ));
      } else {
        factors.add(const ScoreFactor(
          name: 'Nutritional Profile',
          description: 'Consider checking the detailed nutrient values',
          isPositive: false,
          impact: 0,
        ));
      }
    }

    return factors;
  }

  /// Fallback heuristic: 0-100 score based on sugar, saturated fat, salt
  HealthScoreResult _computeFromNutriments(Map<String, dynamic> n) {
    if (n.isEmpty) {
      return const HealthScoreResult(
        score: 50,
        factors: [
          ScoreFactor(
            name: 'Limited Data',
            description: 'No nutritional data available for analysis',
            isPositive: false,
            impact: 0,
          ),
        ],
      );
    }
    
    final factors = <ScoreFactor>[];
    double score = 100;
    
    final sugar = _toDouble(n['sugars_100g']);
    final sugarPenalty = sugar * 2.0;
    if (sugar > 22.5) {
      factors.add(ScoreFactor(
        name: 'High Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g (very high)',
        isPositive: false,
        impact: -sugarPenalty,
      ));
    } else if (sugar > 12.5) {
      factors.add(ScoreFactor(
        name: 'Moderate Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g',
        isPositive: false,
        impact: -sugarPenalty,
      ));
    } else if (sugar > 5) {
      factors.add(ScoreFactor(
        name: 'Some Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g',
        isPositive: false,
        impact: -sugarPenalty,
      ));
    }
    score -= sugarPenalty;
    
    final satFat = _toDouble(n['saturated-fat_100g']);
    final satFatPenalty = satFat * 4.0;
    if (satFat > 5) {
      factors.add(ScoreFactor(
        name: 'High Saturated Fat',
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -satFatPenalty,
      ));
    } else if (satFat > 2) {
      factors.add(ScoreFactor(
        name: 'Moderate Saturated Fat',
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -satFatPenalty,
      ));
    }
    score -= satFatPenalty;
    
    final salt = _toDouble(n['salt_100g']);
    final saltPenalty = salt * 6.0;
    if (salt > 1.5) {
      factors.add(ScoreFactor(
        name: 'High Sodium',
        description: 'Contains ${(salt * 1000 / 2.5).round()}mg sodium per 100g',
        isPositive: false,
        impact: -saltPenalty,
      ));
    } else if (salt > 0.6) {
      factors.add(ScoreFactor(
        name: 'Moderate Sodium',
        description: 'Contains ${(salt * 1000 / 2.5).round()}mg sodium per 100g',
        isPositive: false,
        impact: -saltPenalty,
      ));
    }
    score -= saltPenalty;

    // Check for positive factors
    final fiber = _toDouble(n['fiber_100g']);
    if (fiber > 3) {
      final fiberBonus = fiber * 2;
      score += fiberBonus;
      factors.add(ScoreFactor(
        name: fiber > 6 ? 'High Fiber' : 'Good Fiber',
        description: 'Contains ${fiber.toStringAsFixed(1)}g fiber per 100g',
        isPositive: true,
        impact: fiberBonus,
      ));
    }

    final protein = _toDouble(n['proteins_100g']);
    if (protein > 8) {
      final proteinBonus = protein * 0.5;
      score += proteinBonus;
      factors.add(ScoreFactor(
        name: 'High Protein',
        description: 'Contains ${protein.toStringAsFixed(1)}g protein per 100g',
        isPositive: true,
        impact: proteinBonus,
      ));
    }
    
    // Clamp score
    if (score < 0) score = 0;
    if (score > 100) score = 100;

    // If no factors found, add a general assessment
    if (factors.isEmpty) {
      factors.add(const ScoreFactor(
        name: 'Balanced Profile',
        description: 'Nutrient levels are within acceptable ranges',
        isPositive: true,
        impact: 0,
      ));
    }
    
    return HealthScoreResult(
      score: score.round(),
      factors: factors,
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0.0;
    }
  }
}
