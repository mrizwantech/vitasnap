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

/// Data quality/confidence indicator for health scores
/// Reflects how much nutrition data was available for scoring
class DataConfidence {
  final int confidence; // 0-100, where 100 = all data available
  final List<String> missingFields;
  final String label; // "high", "medium", "low"
  
  const DataConfidence({
    required this.confidence,
    required this.missingFields,
    required this.label,
  });
  
  /// Get a user-friendly description
  String get description {
    if (confidence >= 80) return 'High confidence - comprehensive nutrition data';
    if (confidence >= 50) return 'Medium confidence - some data missing: ${missingFields.join(", ")}';
    return 'Low confidence - limited data: ${missingFields.join(", ")}';
  }
}

/// Result of health score computation with breakdown
class HealthScoreResult {
  final int score;
  final String? nutriscoreGrade;
  final List<ScoreFactor> factors;
  /// Data quality/confidence indicator (null if using official Nutri-Score)
  final DataConfidence? dataConfidence;
  /// Whether this score is from official Nutri-Score (true) or computed fallback (false)
  final bool isOfficialNutriScore;

  const HealthScoreResult({
    required this.score,
    this.nutriscoreGrade,
    required this.factors,
    this.dataConfidence,
    this.isOfficialNutriScore = false,
  });
  
  /// Get display label for the score source
  String get sourceLabel => isOfficialNutriScore 
    ? 'Official Nutri-Score' 
    : 'VitaSnap Health Score';
}

class ComputeHealthScore {
  // ============================================================
  // NUTRI-SCORE-LIKE ALGORITHM CONSTANTS
  // Based on official Nutri-Score thresholds (general foods category)
  // ============================================================
  
  // Sugar thresholds (g/100g) → points 0-10
  static const List<double> _sugarThresholds = [4.5, 9, 13.5, 18, 22.5, 27, 31, 36, 40, 45];
  
  // Saturated fat thresholds (g/100g) → points 0-10
  static const List<double> _satFatThresholds = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
  
  // Salt thresholds (g/100g) → points 0-10  
  // Note: salt = sodium × 2.5
  static const List<double> _saltThresholds = [0.225, 0.45, 0.675, 0.9, 1.125, 1.35, 1.575, 1.8, 2.025, 2.25];
  
  // Energy thresholds (kcal/100g) → points 0-10
  static const List<double> _energyThresholds = [80, 160, 240, 320, 400, 480, 560, 640, 720, 800];
  
  // Fiber thresholds (g/100g) → points 0-5
  static const List<double> _fiberThresholds = [0.9, 1.9, 2.8, 3.7, 4.7];
  
  // Protein thresholds (g/100g) → points 0-5
  static const List<double> _proteinThresholds = [1.6, 3.2, 4.8, 6.4, 8.0];

  /// Compute health score using Nutri-Score if available,
  /// otherwise fall back to a Nutri-Score-like algorithm.
  /// 
  /// Returns 0-100 score:
  /// - Official Nutri-Score: A=100, B=75, C=50, D=25, E=0
  /// - Computed fallback: Uses Nutri-Score algorithm mapped to 0-100
  int call(Product p) {
    // Prefer official Nutri-Score from OpenFoodFacts
    if (p.nutriscoreGrade != null && p.nutriscoreGrade!.isNotEmpty) {
      return p.nutriScoreValue;
    }
    
    // Fallback: compute Nutri-Score-like score from nutriments
    return _computeFromNutriments(p.nutriments, p.novaGroup).score;
  }

  /// Compute health score with detailed breakdown of factors
  HealthScoreResult computeWithBreakdown(Product p) {
    // Prefer official Nutri-Score from OpenFoodFacts
    if (p.nutriscoreGrade != null && p.nutriscoreGrade!.isNotEmpty) {
      return HealthScoreResult(
        score: p.nutriScoreValue,
        nutriscoreGrade: p.nutriscoreGrade,
        factors: _getNutriScoreFactors(p),
        isOfficialNutriScore: true,
      );
    }
    
    // Fallback: compute Nutri-Score-like score from nutriments
    return _computeFromNutriments(p.nutriments, p.novaGroup);
  }

  /// Get factors that explain the official Nutri-Score grade
  List<ScoreFactor> _getNutriScoreFactors(Product p) {
    final factors = <ScoreFactor>[];
    final n = p.nutriments;
    
    // Analyze negative factors using sliding scale
    final sugar = _toDouble(n['sugars_100g']);
    final sugarPoints = _getPoints(sugar, _sugarThresholds);
    if (sugarPoints > 0) {
      factors.add(ScoreFactor(
        name: sugarPoints >= 7 ? 'High Sugar' : sugarPoints >= 4 ? 'Moderate Sugar' : 'Some Sugar',
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g',
        isPositive: false,
        impact: -sugarPoints.toDouble() * 2,
      ));
    }

    final satFat = _toDouble(n['saturated-fat_100g']);
    final satFatPoints = _getPoints(satFat, _satFatThresholds);
    if (satFatPoints > 0) {
      factors.add(ScoreFactor(
        name: satFatPoints >= 7 ? 'High Saturated Fat' : satFatPoints >= 4 ? 'Moderate Saturated Fat' : 'Some Saturated Fat',
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -satFatPoints.toDouble() * 2,
      ));
    }

    // Handle salt vs sodium consistently: prefer salt_100g, fallback to sodium_100g * 2.5
    final salt = _getSaltValue(n);
    final saltPoints = _getPoints(salt, _saltThresholds);
    if (saltPoints > 0) {
      factors.add(ScoreFactor(
        name: saltPoints >= 7 ? 'High Sodium' : saltPoints >= 4 ? 'Moderate Sodium' : 'Some Sodium',
        description: 'Contains ${(salt / 2.5 * 1000).round()}mg sodium per 100g',
        isPositive: false,
        impact: -saltPoints.toDouble() * 2,
      ));
    }

    final calories = _toDouble(n['energy-kcal_100g']);
    final energyPoints = _getPoints(calories, _energyThresholds);
    if (energyPoints > 0) {
      factors.add(ScoreFactor(
        name: energyPoints >= 7 ? 'High Calories' : energyPoints >= 4 ? 'Moderate Calories' : 'Some Calories',
        description: 'Contains ${calories.round()} kcal per 100g',
        isPositive: false,
        impact: -energyPoints.toDouble() * 1.5,
      ));
    }

    // Analyze positive factors
    final fiber = _toDouble(n['fiber_100g']);
    final fiberPoints = _getPoints(fiber, _fiberThresholds);
    if (fiberPoints > 0) {
      factors.add(ScoreFactor(
        name: fiberPoints >= 4 ? 'High Fiber' : fiberPoints >= 2 ? 'Good Fiber' : 'Some Fiber',
        description: 'Contains ${fiber.toStringAsFixed(1)}g fiber per 100g',
        isPositive: true,
        impact: fiberPoints.toDouble() * 2,
      ));
    }

    final protein = _toDouble(n['proteins_100g']);
    final proteinPoints = _getPoints(protein, _proteinThresholds);
    if (proteinPoints > 0) {
      factors.add(ScoreFactor(
        name: proteinPoints >= 4 ? 'High Protein' : proteinPoints >= 2 ? 'Good Protein' : 'Some Protein',
        description: 'Contains ${protein.toStringAsFixed(1)}g protein per 100g',
        isPositive: true,
        impact: proteinPoints.toDouble() * 2,
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

  /// Compute Nutri-Score-like score from nutriments using sliding scales
  /// This approximates the official Nutri-Score algorithm when grade is missing
  HealthScoreResult _computeFromNutriments(Map<String, dynamic> n, int? novaGroup) {
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
        dataConfidence: DataConfidence(
          confidence: 0,
          missingFields: ['All nutrient data'],
          label: 'low',
        ),
      );
    }
    
    final factors = <ScoreFactor>[];
    final missingFields = <String>[];
    int confidenceScore = 100;
    
    // ============================================================
    // NEGATIVE POINTS (0-40 possible)
    // Using piecewise linear interpolation for smooth transitions
    // ============================================================
    
    double negativePoints = 0;
    
    // Sugar (0-10 points)
    final sugarValue = n['sugars_100g'];
    final sugar = _toDouble(sugarValue);
    if (sugarValue == null) {
      missingFields.add('sugar');
      confidenceScore -= 10;
    }
    final sugarPoints = _getPointsInterpolated(sugar, _sugarThresholds);
    negativePoints += sugarPoints;
    if (sugarPoints > 0) {
      factors.add(ScoreFactor(
        name: _getSeverityLabel(sugarPoints, 10, 'Sugar'),
        description: 'Contains ${sugar.toStringAsFixed(1)}g sugar per 100g',
        isPositive: false,
        impact: -sugarPoints,
      ));
    }
    
    // Saturated fat (0-10 points)
    final satFatValue = n['saturated-fat_100g'];
    final satFat = _toDouble(satFatValue);
    if (satFatValue == null) {
      missingFields.add('saturated fat');
      confidenceScore -= 10;
    }
    final satFatPoints = _getPointsInterpolated(satFat, _satFatThresholds);
    negativePoints += satFatPoints;
    if (satFatPoints > 0) {
      factors.add(ScoreFactor(
        name: _getSeverityLabel(satFatPoints, 10, 'Saturated Fat'),
        description: 'Contains ${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        isPositive: false,
        impact: -satFatPoints,
      ));
    }
    
    // Salt/Sodium (0-10 points) - handle both consistently
    final salt = _getSaltValue(n);
    final hasSaltData = n['salt_100g'] != null || n['sodium_100g'] != null;
    if (!hasSaltData) {
      missingFields.add('salt/sodium');
      confidenceScore -= 10;
    }
    final saltPoints = _getPointsInterpolated(salt, _saltThresholds);
    negativePoints += saltPoints;
    if (saltPoints > 0) {
      final sodiumMg = (salt / 2.5 * 1000).round();
      factors.add(ScoreFactor(
        name: _getSeverityLabel(saltPoints, 10, 'Sodium'),
        description: 'Contains ${sodiumMg}mg sodium per 100g (salt: ${salt.toStringAsFixed(2)}g)',
        isPositive: false,
        impact: -saltPoints,
      ));
    }
    
    // Energy/Calories (0-10 points)
    final energyValue = n['energy-kcal_100g'];
    final energy = _toDouble(energyValue);
    if (energyValue == null) {
      missingFields.add('calories');
      confidenceScore -= 10;
    }
    final energyPoints = _getPointsInterpolated(energy, _energyThresholds);
    negativePoints += energyPoints;
    if (energyPoints > 0) {
      factors.add(ScoreFactor(
        name: _getSeverityLabel(energyPoints, 10, 'Calories'),
        description: 'Contains ${energy.round()} kcal per 100g',
        isPositive: false,
        impact: -energyPoints,
      ));
    }
    
    // ============================================================
    // POSITIVE POINTS (0-15 possible)
    // ============================================================
    
    double positivePoints = 0;
    
    // Fiber (0-5 points)
    final fiberValue = n['fiber_100g'];
    final fiber = _toDouble(fiberValue);
    if (fiberValue == null) {
      missingFields.add('fiber');
      confidenceScore -= 5;
    }
    final fiberPoints = _getPointsInterpolated(fiber, _fiberThresholds);
    positivePoints += fiberPoints;
    if (fiberPoints > 0) {
      factors.add(ScoreFactor(
        name: fiberPoints >= 4 ? 'High Fiber' : fiberPoints >= 2 ? 'Good Fiber' : 'Some Fiber',
        description: 'Contains ${fiber.toStringAsFixed(1)}g fiber per 100g',
        isPositive: true,
        impact: fiberPoints,
      ));
    }
    
    // Protein (0-5 points)
    final proteinValue = n['proteins_100g'];
    final protein = _toDouble(proteinValue);
    if (proteinValue == null) {
      missingFields.add('protein');
      confidenceScore -= 5;
    }
    final proteinPoints = _getPointsInterpolated(protein, _proteinThresholds);
    positivePoints += proteinPoints;
    if (proteinPoints > 0) {
      factors.add(ScoreFactor(
        name: proteinPoints >= 4 ? 'High Protein' : proteinPoints >= 2 ? 'Good Protein' : 'Some Protein',
        description: 'Contains ${protein.toStringAsFixed(1)}g protein per 100g',
        isPositive: true,
        impact: proteinPoints,
      ));
    }
    
    // Fruits/vegetables/legumes/nuts bonus (simplified - up to 5 points)
    // In the real Nutri-Score, this is based on % content
    // We approximate based on fiber+protein combo as a proxy for whole foods
    if (fiber > 3 && energy < 200 && satFat < 2 && sugar < 10) {
      positivePoints += 3; // Likely a whole food/fruit/vegetable
      factors.add(const ScoreFactor(
        name: 'Whole Food Indicators',
        description: 'Nutritional profile suggests minimally processed whole food',
        isPositive: true,
        impact: 3,
      ));
    }
    
    // ============================================================
    // NOVA GROUP ADJUSTMENT (optional but valuable)
    // Ultra-processed foods (NOVA 4) get a small penalty
    // ============================================================
    
    double novaAdjustment = 0;
    if (novaGroup != null) {
      if (novaGroup == 4) {
        novaAdjustment = 5; // Adds to negative points
        factors.add(const ScoreFactor(
          name: 'Ultra-Processed',
          description: 'NOVA Group 4: Ultra-processed food product',
          isPositive: false,
          impact: -5,
        ));
      } else if (novaGroup == 1) {
        // Small bonus for unprocessed/minimally processed
        positivePoints += 2;
        factors.add(const ScoreFactor(
          name: 'Minimally Processed',
          description: 'NOVA Group 1: Unprocessed or minimally processed food',
          isPositive: true,
          impact: 2,
        ));
      }
    }
    
    // ============================================================
    // CALCULATE RAW NUTRI-SCORE-LIKE VALUE
    // Range: roughly -15 (best) to +40 (worst)
    // ============================================================
    
    final rawScore = negativePoints - positivePoints + novaAdjustment;
    
    // ============================================================
    // MAP TO 0-100 SCALE (higher = better)
    // Using Nutri-Score grade boundaries:
    // A: rawScore <= -1  → 90-100
    // B: rawScore 0-2    → 70-89
    // C: rawScore 3-10   → 45-69
    // D: rawScore 11-18  → 20-44
    // E: rawScore >= 19  → 0-19
    // ============================================================
    
    int uiScore;
    String inferredGrade;
    
    if (rawScore <= -1) {
      // Grade A: 90-100
      // Map -15 to -1 → 100 to 90
      uiScore = (100 - ((rawScore + 15) / 14 * 10).clamp(0, 10)).round();
      uiScore = uiScore.clamp(90, 100);
      inferredGrade = 'A';
    } else if (rawScore <= 2) {
      // Grade B: 70-89
      // Map -1 to 2 → 89 to 70
      uiScore = (89 - (rawScore + 1) / 3 * 19).round();
      uiScore = uiScore.clamp(70, 89);
      inferredGrade = 'B';
    } else if (rawScore <= 10) {
      // Grade C: 45-69
      // Map 3 to 10 → 69 to 45
      uiScore = (69 - (rawScore - 3) / 7 * 24).round();
      uiScore = uiScore.clamp(45, 69);
      inferredGrade = 'C';
    } else if (rawScore <= 18) {
      // Grade D: 20-44
      // Map 11 to 18 → 44 to 20
      uiScore = (44 - (rawScore - 11) / 7 * 24).round();
      uiScore = uiScore.clamp(20, 44);
      inferredGrade = 'D';
    } else {
      // Grade E: 0-19
      // Map 19 to 40 → 19 to 0
      uiScore = (19 - (rawScore - 19) / 21 * 19).round();
      uiScore = uiScore.clamp(0, 19);
      inferredGrade = 'E';
    }
    
    // ============================================================
    // APPLY CONFIDENCE PENALTY
    // If significant data is missing, reduce score slightly
    // ============================================================
    
    confidenceScore = confidenceScore.clamp(0, 100);
    final confidenceLabel = confidenceScore >= 80 ? 'high' 
        : confidenceScore >= 50 ? 'medium' 
        : 'low';
    
    // Apply a gentle penalty for low confidence
    if (confidenceScore < 50) {
      // Reduce score toward 50 (neutral) based on how much data is missing
      final penalty = ((50 - confidenceScore) / 100 * (uiScore - 50)).round();
      uiScore = (uiScore - penalty).clamp(0, 100);
    }
    
    // If no factors found, add a general assessment
    if (factors.isEmpty) {
      factors.add(ScoreFactor(
        name: 'Balanced Profile',
        description: 'Nutrient levels are within acceptable ranges (Grade $inferredGrade)',
        isPositive: uiScore >= 50,
        impact: 0,
      ));
    }
    
    return HealthScoreResult(
      score: uiScore,
      nutriscoreGrade: inferredGrade.toLowerCase(),
      factors: factors,
      dataConfidence: DataConfidence(
        confidence: confidenceScore,
        missingFields: missingFields,
        label: confidenceLabel,
      ),
      isOfficialNutriScore: false,
    );
  }
  
  // ============================================================
  // HELPER METHODS
  // ============================================================
  
  /// Get salt value consistently from either salt_100g or sodium_100g
  /// Converts sodium to salt using: salt = sodium × 2.5
  double _getSaltValue(Map<String, dynamic> n) {
    // Prefer salt_100g if available
    final saltValue = n['salt_100g'];
    if (saltValue != null) {
      return _toDouble(saltValue);
    }
    // Fall back to sodium_100g and convert
    final sodiumValue = n['sodium_100g'];
    if (sodiumValue != null) {
      return _toDouble(sodiumValue) * 2.5;
    }
    return 0.0;
  }
  
  /// Get discrete points based on thresholds (0 to threshold.length)
  int _getPoints(double value, List<double> thresholds) {
    for (int i = 0; i < thresholds.length; i++) {
      if (value <= thresholds[i]) return i;
    }
    return thresholds.length;
  }
  
  /// Get interpolated points for smooth transitions (piecewise linear)
  /// Returns a value between 0 and thresholds.length
  double _getPointsInterpolated(double value, List<double> thresholds) {
    if (value <= 0) return 0;
    if (value >= thresholds.last) return thresholds.length.toDouble();
    
    // Find which segment we're in
    double prevThreshold = 0;
    for (int i = 0; i < thresholds.length; i++) {
      if (value <= thresholds[i]) {
        // Interpolate within this segment
        final range = thresholds[i] - prevThreshold;
        final position = value - prevThreshold;
        return i + (position / range);
      }
      prevThreshold = thresholds[i];
    }
    return thresholds.length.toDouble();
  }
  
  /// Get severity label based on points
  String _getSeverityLabel(double points, int maxPoints, String nutrient) {
    final ratio = points / maxPoints;
    if (ratio >= 0.7) return 'High $nutrient';
    if (ratio >= 0.4) return 'Moderate $nutrient';
    return 'Some $nutrient';
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
