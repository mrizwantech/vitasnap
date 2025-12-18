import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Health condition types with their analysis rules
enum HealthCondition {
  diabetes,
  highBloodPressure,
  heartDisease,
  highCholesterol,
  kidneyDisease,
  obesity,
  gout,
}

/// Extension to provide display info for health conditions
extension HealthConditionInfo on HealthCondition {
  String get displayName {
    switch (this) {
      case HealthCondition.diabetes:
        return 'Diabetes';
      case HealthCondition.highBloodPressure:
        return 'High Blood Pressure';
      case HealthCondition.heartDisease:
        return 'Heart Disease';
      case HealthCondition.highCholesterol:
        return 'High Cholesterol';
      case HealthCondition.kidneyDisease:
        return 'Kidney Disease';
      case HealthCondition.obesity:
        return 'Obesity / Weight Management';
      case HealthCondition.gout:
        return 'Gout';
    }
  }

  String get description {
    switch (this) {
      case HealthCondition.diabetes:
        return 'Monitors sugar, carbs, and glycemic impact';
      case HealthCondition.highBloodPressure:
        return 'Monitors sodium and salt content';
      case HealthCondition.heartDisease:
        return 'Monitors fats, sodium, and cholesterol';
      case HealthCondition.highCholesterol:
        return 'Monitors saturated fats and cholesterol';
      case HealthCondition.kidneyDisease:
        return 'Monitors sodium, potassium, and phosphorus';
      case HealthCondition.obesity:
        return 'Monitors calories, fats, and sugars';
      case HealthCondition.gout:
        return 'Monitors purines and certain proteins';
    }
  }

  IconData get icon {
    switch (this) {
      case HealthCondition.diabetes:
        return Icons.bloodtype;
      case HealthCondition.highBloodPressure:
        return Icons.favorite;
      case HealthCondition.heartDisease:
        return Icons.monitor_heart;
      case HealthCondition.highCholesterol:
        return Icons.water_drop;
      case HealthCondition.kidneyDisease:
        return Icons.healing;
      case HealthCondition.obesity:
        return Icons.monitor_weight;
      case HealthCondition.gout:
        return Icons.accessibility_new;
    }
  }

  Color get color {
    switch (this) {
      case HealthCondition.diabetes:
        return const Color(0xFF9C27B0);
      case HealthCondition.highBloodPressure:
        return const Color(0xFFE53935);
      case HealthCondition.heartDisease:
        return const Color(0xFFD32F2F);
      case HealthCondition.highCholesterol:
        return const Color(0xFFFF9800);
      case HealthCondition.kidneyDisease:
        return const Color(0xFF795548);
      case HealthCondition.obesity:
        return const Color(0xFF2196F3);
      case HealthCondition.gout:
        return const Color(0xFF607D8B);
    }
  }
}

/// Severity level for health warnings
enum WarningSeverity {
  safe,      // Green - OK to consume
  caution,   // Yellow - Consume in moderation
  warning,   // Orange - Limit consumption
  danger,    // Red - Avoid or strictly limit
}

extension WarningSeverityInfo on WarningSeverity {
  String get label {
    switch (this) {
      case WarningSeverity.safe:
        return 'Safe';
      case WarningSeverity.caution:
        return 'Caution';
      case WarningSeverity.warning:
        return 'Warning';
      case WarningSeverity.danger:
        return 'Avoid';
    }
  }

  Color get color {
    switch (this) {
      case WarningSeverity.safe:
        return const Color(0xFF4CAF50);
      case WarningSeverity.caution:
        return const Color(0xFFFFC107);
      case WarningSeverity.warning:
        return const Color(0xFFFF9800);
      case WarningSeverity.danger:
        return const Color(0xFFF44336);
    }
  }

  IconData get icon {
    switch (this) {
      case WarningSeverity.safe:
        return Icons.check_circle;
      case WarningSeverity.caution:
        return Icons.info;
      case WarningSeverity.warning:
        return Icons.warning_amber;
      case WarningSeverity.danger:
        return Icons.dangerous;
    }
  }
}

/// A single health warning/advice for a product
class HealthWarning {
  final HealthCondition condition;
  final WarningSeverity severity;
  final String title;
  final String explanation;
  final String? nutrientValue; // e.g., "15g sugar per 100g"

  const HealthWarning({
    required this.condition,
    required this.severity,
    required this.title,
    required this.explanation,
    this.nutrientValue,
  });
}

/// Overall health analysis result for a product
class HealthAnalysisResult {
  final List<HealthWarning> warnings;
  final WarningSeverity overallSeverity;
  final String summary;

  const HealthAnalysisResult({
    required this.warnings,
    required this.overallSeverity,
    required this.summary,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasDangers => warnings.any((w) => w.severity == WarningSeverity.danger);
}

/// Service to manage health conditions and analyze products
class HealthConditionsService extends ChangeNotifier {
  static const _kHealthConditionsKey = 'health_conditions';
  
  final SharedPreferences _prefs;
  Set<HealthCondition> _selectedConditions = {};

  HealthConditionsService(this._prefs) {
    _loadConditions();
  }

  Set<HealthCondition> get selectedConditions => Set.unmodifiable(_selectedConditions);
  bool get hasConditions => _selectedConditions.isNotEmpty;

  bool isSelected(HealthCondition condition) => _selectedConditions.contains(condition);

  Future<void> toggleCondition(HealthCondition condition) async {
    if (_selectedConditions.contains(condition)) {
      _selectedConditions.remove(condition);
    } else {
      _selectedConditions.add(condition);
    }
    await _saveConditions();
    notifyListeners();
  }

  Future<void> setConditions(Set<HealthCondition> conditions) async {
    _selectedConditions = Set.from(conditions);
    await _saveConditions();
    notifyListeners();
  }

  void _loadConditions() {
    final encoded = _prefs.getString(_kHealthConditionsKey);
    if (encoded != null) {
      try {
        final List<dynamic> list = jsonDecode(encoded);
        _selectedConditions = list
            .map((e) => HealthCondition.values.firstWhere(
                  (c) => c.name == e,
                  orElse: () => HealthCondition.diabetes,
                ))
            .toSet();
      } catch (e) {
        debugPrint('Error loading health conditions: $e');
      }
    }
  }

  Future<void> _saveConditions() async {
    final encoded = jsonEncode(_selectedConditions.map((c) => c.name).toList());
    await _prefs.setString(_kHealthConditionsKey, encoded);
  }

  /// Analyze a product for the user's health conditions
  /// nutriments: Map of nutrient values (per 100g typically)
  /// ingredients: Raw ingredients string
  HealthAnalysisResult analyzeProduct({
    required Map<String, dynamic> nutriments,
    String? ingredients,
  }) {
    if (_selectedConditions.isEmpty) {
      return const HealthAnalysisResult(
        warnings: [],
        overallSeverity: WarningSeverity.safe,
        summary: 'No health conditions configured',
      );
    }

    final List<HealthWarning> warnings = [];

    for (final condition in _selectedConditions) {
      warnings.addAll(_analyzeForCondition(condition, nutriments, ingredients));
    }

    // Sort by severity (most severe first)
    warnings.sort((a, b) => b.severity.index.compareTo(a.severity.index));

    // Determine overall severity
    WarningSeverity overallSeverity = WarningSeverity.safe;
    if (warnings.any((w) => w.severity == WarningSeverity.danger)) {
      overallSeverity = WarningSeverity.danger;
    } else if (warnings.any((w) => w.severity == WarningSeverity.warning)) {
      overallSeverity = WarningSeverity.warning;
    } else if (warnings.any((w) => w.severity == WarningSeverity.caution)) {
      overallSeverity = WarningSeverity.caution;
    }

    // Generate summary
    String summary;
    if (warnings.isEmpty) {
      summary = 'This product appears safe for your health conditions.';
    } else if (overallSeverity == WarningSeverity.danger) {
      summary = 'This product may significantly impact your health. Review the warnings below.';
    } else if (overallSeverity == WarningSeverity.warning) {
      summary = 'This product has some concerns for your health conditions. Consume with caution.';
    } else {
      summary = 'This product is generally okay but has some points to consider.';
    }

    return HealthAnalysisResult(
      warnings: warnings,
      overallSeverity: overallSeverity,
      summary: summary,
    );
  }

  List<HealthWarning> _analyzeForCondition(
    HealthCondition condition,
    Map<String, dynamic> nutriments,
    String? ingredients,
  ) {
    switch (condition) {
      case HealthCondition.diabetes:
        return _analyzeForDiabetes(nutriments, ingredients);
      case HealthCondition.highBloodPressure:
        return _analyzeForHighBloodPressure(nutriments, ingredients);
      case HealthCondition.heartDisease:
        return _analyzeForHeartDisease(nutriments, ingredients);
      case HealthCondition.highCholesterol:
        return _analyzeForHighCholesterol(nutriments, ingredients);
      case HealthCondition.kidneyDisease:
        return _analyzeForKidneyDisease(nutriments, ingredients);
      case HealthCondition.obesity:
        return _analyzeForObesity(nutriments, ingredients);
      case HealthCondition.gout:
        return _analyzeForGout(nutriments, ingredients);
    }
  }

  /// Diabetes analysis - focuses on sugars, carbs
  List<HealthWarning> _analyzeForDiabetes(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Check sugars (per 100g)
    final sugars = _getNumericValue(nutriments, ['sugars_100g', 'sugars']);
    if (sugars != null) {
      if (sugars > 22.5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.diabetes,
          severity: WarningSeverity.danger,
          title: 'Very High Sugar Content',
          explanation: 'This product is very high in sugar which can cause rapid blood sugar spikes. '
              'For diabetics, this can be dangerous and make blood sugar control very difficult.',
          nutrientValue: '${sugars.toStringAsFixed(1)}g sugar per 100g',
        ));
      } else if (sugars > 12.5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.diabetes,
          severity: WarningSeverity.warning,
          title: 'High Sugar Content',
          explanation: 'This product has high sugar levels that may affect your blood glucose. '
              'Monitor your portions carefully and consider your total daily carb intake.',
          nutrientValue: '${sugars.toStringAsFixed(1)}g sugar per 100g',
        ));
      } else if (sugars > 5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.diabetes,
          severity: WarningSeverity.caution,
          title: 'Moderate Sugar Content',
          explanation: 'This product contains moderate sugar. It may be acceptable in small portions '
              'as part of a balanced diabetic diet, but monitor your blood sugar response.',
          nutrientValue: '${sugars.toStringAsFixed(1)}g sugar per 100g',
        ));
      }
    }

    // Check carbohydrates
    final carbs = _getNumericValue(nutriments, ['carbohydrates_100g', 'carbohydrates']);
    if (carbs != null && carbs > 50) {
      warnings.add(HealthWarning(
        condition: HealthCondition.diabetes,
        severity: WarningSeverity.warning,
        title: 'High Carbohydrate Content',
        explanation: 'High carbohydrate foods can significantly impact blood sugar levels. '
            'Consider portion size and pair with protein or fiber to slow absorption.',
        nutrientValue: '${carbs.toStringAsFixed(1)}g carbs per 100g',
      ));
    }

    // Check for problematic ingredients
    if (ingredients != null) {
      final lowerIngredients = ingredients.toLowerCase();
      if (lowerIngredients.contains('high fructose corn syrup') || 
          lowerIngredients.contains('glucose syrup') ||
          lowerIngredients.contains('corn syrup')) {
        warnings.add(HealthWarning(
          condition: HealthCondition.diabetes,
          severity: WarningSeverity.warning,
          title: 'Contains Added Syrups',
          explanation: 'This product contains added syrups (like corn syrup or glucose syrup) '
              'which are quickly absorbed and can cause rapid blood sugar spikes.',
        ));
      }
    }

    return warnings;
  }

  /// High Blood Pressure analysis - focuses on sodium
  List<HealthWarning> _analyzeForHighBloodPressure(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Check sodium (per 100g) - values in mg or g
    var sodium = _getNumericValue(nutriments, ['sodium_100g', 'sodium']);
    // If value seems to be in grams (< 10), convert to mg
    if (sodium != null && sodium < 10) {
      sodium = sodium * 1000;
    }
    
    // Also check salt (salt = sodium × 2.5)
    var salt = _getNumericValue(nutriments, ['salt_100g', 'salt']);
    if (salt != null && sodium == null) {
      sodium = salt * 400; // Convert salt g to sodium mg
    }

    if (sodium != null) {
      if (sodium > 1500) {
        warnings.add(HealthWarning(
          condition: HealthCondition.highBloodPressure,
          severity: WarningSeverity.danger,
          title: 'Very High Sodium Content',
          explanation: 'This product is extremely high in sodium which can raise blood pressure '
              'significantly. The recommended daily limit for hypertension is 1500mg total. '
              'This product alone could exceed that limit.',
          nutrientValue: '${sodium.toStringAsFixed(0)}mg sodium per 100g',
        ));
      } else if (sodium > 600) {
        warnings.add(HealthWarning(
          condition: HealthCondition.highBloodPressure,
          severity: WarningSeverity.warning,
          title: 'High Sodium Content',
          explanation: 'High sodium intake is linked to increased blood pressure. '
              'Try to balance this with low-sodium foods throughout the day.',
          nutrientValue: '${sodium.toStringAsFixed(0)}mg sodium per 100g',
        ));
      } else if (sodium > 300) {
        warnings.add(HealthWarning(
          condition: HealthCondition.highBloodPressure,
          severity: WarningSeverity.caution,
          title: 'Moderate Sodium Content',
          explanation: 'This product has moderate sodium. Keep track of your total daily intake '
              'to stay within recommended limits (less than 1500mg/day for hypertension).',
          nutrientValue: '${sodium.toStringAsFixed(0)}mg sodium per 100g',
        ));
      }
    }

    return warnings;
  }

  /// Heart Disease analysis - sodium, saturated fat, trans fat
  List<HealthWarning> _analyzeForHeartDisease(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Check saturated fat
    final satFat = _getNumericValue(nutriments, ['saturated-fat_100g', 'saturated_fat_100g', 'saturated-fat']);
    if (satFat != null) {
      if (satFat > 5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.heartDisease,
          severity: WarningSeverity.danger,
          title: 'High Saturated Fat',
          explanation: 'Saturated fat can raise LDL ("bad") cholesterol levels, increasing '
              'the risk of heart disease and stroke. Limit intake to less than 13g per day.',
          nutrientValue: '${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        ));
      } else if (satFat > 1.5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.heartDisease,
          severity: WarningSeverity.caution,
          title: 'Moderate Saturated Fat',
          explanation: 'Contains some saturated fat. Monitor your total daily intake '
              'and balance with unsaturated fats like olive oil and nuts.',
          nutrientValue: '${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        ));
      }
    }

    // Check sodium (reuse blood pressure logic)
    var sodium = _getNumericValue(nutriments, ['sodium_100g', 'sodium']);
    if (sodium != null && sodium < 10) sodium = sodium * 1000;
    if (sodium != null && sodium > 600) {
      warnings.add(HealthWarning(
        condition: HealthCondition.heartDisease,
        severity: WarningSeverity.warning,
        title: 'High Sodium',
        explanation: 'High sodium intake can strain the heart and contribute to high blood pressure, '
            'a major risk factor for heart disease.',
        nutrientValue: '${sodium.toStringAsFixed(0)}mg sodium per 100g',
      ));
    }

    // Check for trans fat in ingredients
    if (ingredients != null) {
      final lower = ingredients.toLowerCase();
      if (lower.contains('hydrogenated') || lower.contains('trans fat')) {
        warnings.add(HealthWarning(
          condition: HealthCondition.heartDisease,
          severity: WarningSeverity.danger,
          title: 'May Contain Trans Fats',
          explanation: 'Trans fats (often from hydrogenated oils) are the worst type of fat for heart health. '
              'They raise bad cholesterol, lower good cholesterol, and increase heart disease risk.',
        ));
      }
    }

    return warnings;
  }

  /// High Cholesterol analysis
  List<HealthWarning> _analyzeForHighCholesterol(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Saturated fat is the main dietary driver of high cholesterol
    final satFat = _getNumericValue(nutriments, ['saturated-fat_100g', 'saturated_fat_100g', 'saturated-fat']);
    if (satFat != null) {
      if (satFat > 5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.highCholesterol,
          severity: WarningSeverity.danger,
          title: 'High Saturated Fat',
          explanation: 'Saturated fat is the primary dietary cause of high LDL cholesterol. '
              'Reducing saturated fat intake is one of the most effective ways to lower cholesterol.',
          nutrientValue: '${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        ));
      } else if (satFat > 1.5) {
        warnings.add(HealthWarning(
          condition: HealthCondition.highCholesterol,
          severity: WarningSeverity.caution,
          title: 'Moderate Saturated Fat',
          explanation: 'Contains saturated fat which can contribute to elevated cholesterol levels. '
              'Keep your total daily saturated fat under 13g.',
          nutrientValue: '${satFat.toStringAsFixed(1)}g saturated fat per 100g',
        ));
      }
    }

    // Check cholesterol if available
    final cholesterol = _getNumericValue(nutriments, ['cholesterol_100g', 'cholesterol']);
    if (cholesterol != null && cholesterol > 50) {
      warnings.add(HealthWarning(
        condition: HealthCondition.highCholesterol,
        severity: WarningSeverity.warning,
        title: 'Contains Dietary Cholesterol',
        explanation: 'While dietary cholesterol has less impact than saturated fat, '
            'limiting intake can still be beneficial for those with high cholesterol.',
        nutrientValue: '${cholesterol.toStringAsFixed(0)}mg cholesterol per 100g',
      ));
    }

    return warnings;
  }

  /// Kidney Disease analysis - sodium, potassium, phosphorus, protein
  List<HealthWarning> _analyzeForKidneyDisease(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Sodium check
    var sodium = _getNumericValue(nutriments, ['sodium_100g', 'sodium']);
    if (sodium != null && sodium < 10) sodium = sodium * 1000;
    if (sodium != null && sodium > 400) {
      warnings.add(HealthWarning(
        condition: HealthCondition.kidneyDisease,
        severity: sodium > 800 ? WarningSeverity.danger : WarningSeverity.warning,
        title: 'High Sodium Content',
        explanation: 'Damaged kidneys cannot effectively remove excess sodium. '
            'High sodium can lead to fluid retention and increased blood pressure.',
        nutrientValue: '${sodium.toStringAsFixed(0)}mg sodium per 100g',
      ));
    }

    // Potassium check (if available)
    final potassium = _getNumericValue(nutriments, ['potassium_100g', 'potassium']);
    if (potassium != null && potassium > 300) {
      warnings.add(HealthWarning(
        condition: HealthCondition.kidneyDisease,
        severity: potassium > 500 ? WarningSeverity.danger : WarningSeverity.warning,
        title: 'High Potassium Content',
        explanation: 'Kidneys with reduced function may not be able to remove excess potassium. '
            'High potassium levels can cause dangerous heart rhythm problems.',
        nutrientValue: '${potassium.toStringAsFixed(0)}mg potassium per 100g',
      ));
    }

    // Phosphorus check (if available)
    final phosphorus = _getNumericValue(nutriments, ['phosphorus_100g', 'phosphorus']);
    if (phosphorus != null && phosphorus > 200) {
      warnings.add(HealthWarning(
        condition: HealthCondition.kidneyDisease,
        severity: WarningSeverity.warning,
        title: 'High Phosphorus Content',
        explanation: 'Excess phosphorus can weaken bones and cause calcium deposits in blood vessels. '
            'Damaged kidneys cannot remove phosphorus effectively.',
        nutrientValue: '${phosphorus.toStringAsFixed(0)}mg phosphorus per 100g',
      ));
    }

    // Check for phosphate additives
    if (ingredients != null && ingredients.toLowerCase().contains('phosphate')) {
      warnings.add(HealthWarning(
        condition: HealthCondition.kidneyDisease,
        severity: WarningSeverity.warning,
        title: 'Contains Phosphate Additives',
        explanation: 'Phosphate additives are more readily absorbed than natural phosphorus. '
            'These can significantly increase phosphorus levels in the body.',
      ));
    }

    return warnings;
  }

  /// Obesity/Weight Management analysis
  List<HealthWarning> _analyzeForObesity(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Check calories/energy
    final energy = _getNumericValue(nutriments, ['energy-kcal_100g', 'energy_100g', 'energy-kcal']);
    if (energy != null) {
      if (energy > 400) {
        warnings.add(HealthWarning(
          condition: HealthCondition.obesity,
          severity: WarningSeverity.warning,
          title: 'Very High Calorie Content',
          explanation: 'This is a calorie-dense food. For weight management, be mindful of portion sizes. '
              'Consider if this fits within your daily calorie goals.',
          nutrientValue: '${energy.toStringAsFixed(0)} kcal per 100g',
        ));
      } else if (energy > 250) {
        warnings.add(HealthWarning(
          condition: HealthCondition.obesity,
          severity: WarningSeverity.caution,
          title: 'Moderate-High Calories',
          explanation: 'This product has moderate to high calories. Track your portions '
              'and balance with lower-calorie foods.',
          nutrientValue: '${energy.toStringAsFixed(0)} kcal per 100g',
        ));
      }
    }

    // Check total fat
    final fat = _getNumericValue(nutriments, ['fat_100g', 'fat']);
    if (fat != null && fat > 17.5) {
      warnings.add(HealthWarning(
        condition: HealthCondition.obesity,
        severity: WarningSeverity.warning,
        title: 'High Fat Content',
        explanation: 'Fat is calorie-dense (9 calories per gram). High-fat foods can '
            'contribute to weight gain if consumed in excess.',
        nutrientValue: '${fat.toStringAsFixed(1)}g fat per 100g',
      ));
    }

    // Check sugars
    final sugars = _getNumericValue(nutriments, ['sugars_100g', 'sugars']);
    if (sugars != null && sugars > 15) {
      warnings.add(HealthWarning(
        condition: HealthCondition.obesity,
        severity: WarningSeverity.warning,
        title: 'High Sugar Content',
        explanation: 'Sugary foods provide calories without much nutritional value. '
            'They can also trigger cravings and make weight management harder.',
        nutrientValue: '${sugars.toStringAsFixed(1)}g sugar per 100g',
      ));
    }

    return warnings;
  }

  /// Gout analysis - focuses on purines
  List<HealthWarning> _analyzeForGout(Map<String, dynamic> nutriments, String? ingredients) {
    final warnings = <HealthWarning>[];
    
    // Check for high-purine ingredients
    if (ingredients != null) {
      final lower = ingredients.toLowerCase();
      
      // High purine foods
      final highPurineIndicators = [
        'organ meat', 'liver', 'kidney', 'heart', 'brain',
        'anchovy', 'anchovies', 'sardine', 'sardines', 'herring',
        'mackerel', 'scallop', 'scallops', 'mussel', 'mussels',
        'game meat', 'venison',
      ];
      
      final moderatePurineIndicators = [
        'beef', 'pork', 'lamb', 'duck',
        'shellfish', 'crab', 'lobster', 'shrimp',
        'asparagus', 'spinach', 'mushroom',
      ];

      for (final indicator in highPurineIndicators) {
        if (lower.contains(indicator)) {
          warnings.add(HealthWarning(
            condition: HealthCondition.gout,
            severity: WarningSeverity.danger,
            title: 'High Purine Content',
            explanation: 'This product contains high-purine ingredients which can significantly '
                'increase uric acid levels and trigger gout attacks. Best to avoid.',
            nutrientValue: 'Contains: $indicator',
          ));
          break;
        }
      }

      // Only check moderate if no high-purine warning
      if (warnings.isEmpty) {
        for (final indicator in moderatePurineIndicators) {
          if (lower.contains(indicator)) {
            warnings.add(HealthWarning(
              condition: HealthCondition.gout,
              severity: WarningSeverity.caution,
              title: 'Moderate Purine Content',
              explanation: 'This product contains ingredients with moderate purine levels. '
                  'Consume in moderation and monitor your uric acid levels.',
              nutrientValue: 'Contains: $indicator',
            ));
            break;
          }
        }
      }

      // Check for high fructose which can also affect gout
      if (lower.contains('high fructose') || lower.contains('fructose syrup')) {
        warnings.add(HealthWarning(
          condition: HealthCondition.gout,
          severity: WarningSeverity.warning,
          title: 'Contains High Fructose',
          explanation: 'Fructose can increase uric acid production in the body. '
              'High fructose corn syrup has been linked to increased gout risk.',
        ));
      }
    }

    // Check protein content (very high protein can be an issue)
    final protein = _getNumericValue(nutriments, ['proteins_100g', 'proteins', 'protein_100g']);
    if (protein != null && protein > 25) {
      warnings.add(HealthWarning(
        condition: HealthCondition.gout,
        severity: WarningSeverity.caution,
        title: 'High Protein Content',
        explanation: 'Very high protein intake may contribute to elevated uric acid levels. '
            'Balance with plenty of water and low-purine foods.',
        nutrientValue: '${protein.toStringAsFixed(1)}g protein per 100g',
      ));
    }

    return warnings;
  }

  /// Helper to extract numeric values from nutriments map
  double? _getNumericValue(Map<String, dynamic> nutriments, List<String> keys) {
    for (final key in keys) {
      final value = nutriments[key];
      if (value != null) {
        if (value is num) {
          return value.toDouble();
        }
        if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }
    return null;
  }
}
