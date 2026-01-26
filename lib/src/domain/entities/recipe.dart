/// Nutri-Score grades from A (best) to E (worst)
/// Mapped to numeric values for recipe score calculation
enum NutriScoreGrade {
  a, // Best
  b,
  c, // Neutral
  d,
  e; // Worst

  /// Numeric value for recipe score calculation
  /// A=20, B=10, C=0, D=-10, E=-20
  int get numericValue {
    switch (this) {
      case NutriScoreGrade.a:
        return 20;
      case NutriScoreGrade.b:
        return 10;
      case NutriScoreGrade.c:
        return 0;
      case NutriScoreGrade.d:
        return -10;
      case NutriScoreGrade.e:
        return -20;
    }
  }

  /// Display name for UI
  String get displayName {
    return name.toUpperCase();
  }

  /// Get grade from string (e.g., from API)
  static NutriScoreGrade fromString(String? grade) {
    if (grade == null || grade.isEmpty) return NutriScoreGrade.c;
    switch (grade.toLowerCase()) {
      case 'a':
        return NutriScoreGrade.a;
      case 'b':
        return NutriScoreGrade.b;
      case 'c':
        return NutriScoreGrade.c;
      case 'd':
        return NutriScoreGrade.d;
      case 'e':
        return NutriScoreGrade.e;
      default:
        return NutriScoreGrade.c;
    }
  }
}

/// Domain entity representing an ingredient in a recipe
class RecipeIngredient {
  final String id;
  final String name;
  final String? iconEmoji;
  final double quantity;
  final IngredientUnit unit;
  final Map<String, dynamic> nutriments;
  final NutriScoreGrade nutriScore; // Nutri-Score grade (A-E)
  final String category; // protein, veggies, fruits, grains, dairy, other

  const RecipeIngredient({
    required this.id,
    required this.name,
    this.iconEmoji,
    required this.quantity,
    required this.unit,
    this.nutriments = const {},
    this.nutriScore = NutriScoreGrade.c,
    this.category = 'other',
  });

  /// Get the numeric score value from Nutri-Score grade
  int get scoreValue => nutriScore.numericValue;

  /// Calculate nutrition values adjusted for quantity
  Map<String, double> get adjustedNutriments {
    final factor = _getQuantityFactor();
    return {
      'calories': (_getDouble(nutriments['energy-kcal_100g']) * factor),
      'protein': (_getDouble(nutriments['proteins_100g']) * factor),
      'carbs': (_getDouble(nutriments['carbohydrates_100g']) * factor),
      'fat': (_getDouble(nutriments['fat_100g']) * factor),
      'fiber': (_getDouble(nutriments['fiber_100g']) * factor),
      'sugar': (_getDouble(nutriments['sugars_100g']) * factor),
      'sodium': (_getDouble(nutriments['sodium_100g']) * factor),
    };
  }

  double _getQuantityFactor() {
    // Convert quantity to 100g equivalent factor
    switch (unit) {
      case IngredientUnit.whole:
        // Assume average whole item ~50g (egg), adjust per ingredient
        return quantity * 0.5;
      case IngredientUnit.gram:
        return quantity / 100;
      case IngredientUnit.cup:
        // ~240g per cup
        return quantity * 2.4;
      case IngredientUnit.tbsp:
        // ~15g per tablespoon
        return quantity * 0.15;
      case IngredientUnit.tsp:
        // ~5g per teaspoon
        return quantity * 0.05;
      case IngredientUnit.slice:
        // ~30g per slice
        return quantity * 0.3;
      case IngredientUnit.piece:
        // ~25g per piece
        return quantity * 0.25;
    }
  }

  double _getDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  RecipeIngredient copyWith({
    String? id,
    String? name,
    String? iconEmoji,
    double? quantity,
    IngredientUnit? unit,
    Map<String, dynamic>? nutriments,
    NutriScoreGrade? nutriScore,
    String? category,
  }) {
    return RecipeIngredient(
      id: id ?? this.id,
      name: name ?? this.name,
      iconEmoji: iconEmoji ?? this.iconEmoji,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      nutriments: nutriments ?? this.nutriments,
      nutriScore: nutriScore ?? this.nutriScore,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'iconEmoji': iconEmoji,
      'quantity': quantity,
      'unit': unit.name,
      'nutriments': nutriments,
      'nutriScore': nutriScore.name,
      'category': category,
    };
  }

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      id: json['id'] as String,
      name: json['name'] as String,
      iconEmoji: json['iconEmoji'] as String?,
      quantity: (json['quantity'] as num).toDouble(),
      unit: IngredientUnit.values.firstWhere(
        (e) => e.name == json['unit'],
        orElse: () => IngredientUnit.whole,
      ),
      nutriments: Map<String, dynamic>.from(json['nutriments'] ?? {}),
      nutriScore: NutriScoreGrade.values.firstWhere(
        (e) => e.name == json['nutriScore'],
        orElse: () => NutriScoreGrade.c,
      ),
      category: json['category'] as String? ?? 'other',
    );
  }
}

enum IngredientUnit {
  whole,
  gram,
  cup,
  tbsp,
  tsp,
  slice,
  piece;

  String get displayName {
    switch (this) {
      case IngredientUnit.whole:
        return 'Whole';
      case IngredientUnit.gram:
        return 'g';
      case IngredientUnit.cup:
        return 'Cup';
      case IngredientUnit.tbsp:
        return 'Tbsp';
      case IngredientUnit.tsp:
        return 'Tsp';
      case IngredientUnit.slice:
        return 'Slice';
      case IngredientUnit.piece:
        return 'Piece';
    }
  }
}

/// Domain entity representing a recipe/meal
class Recipe {
  final String id;
  final String name;
  final MealType mealType;
  final List<RecipeIngredient> ingredients;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Recipe({
    required this.id,
    required this.name,
    required this.mealType,
    this.ingredients = const [],
    required this.createdAt,
    this.updatedAt,
  });

  /// Calculate total nutrition from all ingredients
  Map<String, double> get totalNutrition {
    final totals = <String, double>{
      'calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'fiber': 0,
      'sugar': 0,
      'sodium': 0,
    };

    for (final ingredient in ingredients) {
      final adjusted = ingredient.adjustedNutriments;
      totals['calories'] = totals['calories']! + adjusted['calories']!;
      totals['protein'] = totals['protein']! + adjusted['protein']!;
      totals['carbs'] = totals['carbs']! + adjusted['carbs']!;
      totals['fat'] = totals['fat']! + adjusted['fat']!;
      totals['fiber'] = totals['fiber']! + adjusted['fiber']!;
      totals['sugar'] = totals['sugar']! + adjusted['sugar']!;
      totals['sodium'] = totals['sodium']! + adjusted['sodium']!;
    }

    return totals;
  }

  /// Calculate total health score based on Nutri-Score grades
  /// Returns a value where positive = healthy, negative = unhealthy
  int get totalHealthScore {
    if (ingredients.isEmpty) return 0;
    int total = 0;
    for (final ingredient in ingredients) {
      // Weight the score by quantity (scaled down)
      total += (ingredient.scoreValue * ingredient.quantity * 0.5).round();
    }
    return total;
  }

  /// Get health score rating based on total score
  HealthScoreRating get scoreRating {
    final score = totalHealthScore;
    if (score >= 20) return HealthScoreRating.excellent;
    if (score >= 5) return HealthScoreRating.good;
    if (score >= -5) return HealthScoreRating.fair;
    return HealthScoreRating.poor;
  }

  Recipe copyWith({
    String? id,
    String? name,
    MealType? mealType,
    List<RecipeIngredient>? ingredients,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      mealType: mealType ?? this.mealType,
      ingredients: ingredients ?? this.ingredients,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType.name,
      'ingredients': ingredients.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      mealType: MealType.values.firstWhere(
        (e) => e.name == json['mealType'],
        orElse: () => MealType.breakfast,
      ),
      ingredients: (json['ingredients'] as List?)
              ?.map((e) => RecipeIngredient.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return 'Breakfast';
      case MealType.lunch:
        return 'Lunch';
      case MealType.dinner:
        return 'Dinner';
      case MealType.snack:
        return 'Snack';
    }
  }

  String get emoji {
    switch (this) {
      case MealType.breakfast:
        return '🍳';
      case MealType.lunch:
        return '🥗';
      case MealType.dinner:
        return '🍽️';
      case MealType.snack:
        return '🍎';
    }
  }

  /// Get the typical start hour for this meal type
  int get typicalStartHour {
    switch (this) {
      case MealType.breakfast:
        return 5;  // 5 AM
      case MealType.lunch:
        return 11; // 11 AM
      case MealType.dinner:
        return 17; // 5 PM
      case MealType.snack:
        return 0;  // Anytime
    }
  }

  /// Check if this meal type is in the future for today
  /// Returns true if the current time hasn't reached the typical meal time yet
  bool get isFutureForToday {
    // Snacks can be added anytime
    if (this == MealType.snack) return false;
    
    final now = DateTime.now();
    final currentHour = now.hour;
    
    return currentHour < typicalStartHour;
  }

  /// Get the current appropriate meal type based on time of day
  static MealType getCurrentMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 17) return MealType.lunch;
    return MealType.dinner;
  }
}

enum HealthScoreRating {
  excellent,
  good,
  fair,
  poor;

  String get displayName {
    switch (this) {
      case HealthScoreRating.excellent:
        return 'Excellent!';
      case HealthScoreRating.good:
        return 'Good';
      case HealthScoreRating.fair:
        return 'Fair';
      case HealthScoreRating.poor:
        return 'Poor';
    }
  }

  String get emoji {
    switch (this) {
      case HealthScoreRating.excellent:
        return '🌟';
      case HealthScoreRating.good:
        return '🔥';
      case HealthScoreRating.fair:
        return '⚠️';
      case HealthScoreRating.poor:
        return '🔴';
    }
  }
}
