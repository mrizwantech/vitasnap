import '../entities/recipe.dart';

/// Use case for computing the health score of a recipe based on Nutri-Score grades
/// 
/// The scoring logic is based on:
/// - Individual ingredient Nutri-Score grades (A=20, B=10, C=0, D=-10, E=-20)
/// - Quantity multipliers (scaled by 0.5)
/// 
/// Score Ratings:
/// - 20+ = Excellent 🌟
/// - 5-19 = Good 🔥
/// - -5 to 4 = Fair ⚠️
/// - <-5 = Poor 🔴
class ComputeRecipeScore {
  /// Compute the total health score for a recipe
  int call(Recipe recipe) {
    if (recipe.ingredients.isEmpty) return 0;
    
    int totalScore = 0;
    for (final ingredient in recipe.ingredients) {
      // Score is Nutri-Score value × quantity × 0.5 scaling factor
      totalScore += (ingredient.scoreValue * ingredient.quantity * 0.5).round();
    }
    
    return totalScore;
  }

  /// Compute score for a single ingredient with given quantity
  int computeIngredientScore(RecipeIngredient ingredient, double quantity) {
    return (ingredient.scoreValue * quantity * 0.5).round();
  }

  /// Get the rating category for a score
  HealthScoreRating getRating(int score) {
    if (score >= 20) return HealthScoreRating.excellent;
    if (score >= 5) return HealthScoreRating.good;
    if (score >= -5) return HealthScoreRating.fair;
    return HealthScoreRating.poor;
  }

  /// Generate a descriptive message based on score and meal type
  String getScoreMessage(int score, MealType mealType) {
    final rating = getRating(score);
    switch (rating) {
      case HealthScoreRating.excellent:
        return 'Excellent ${mealType.displayName}!';
      case HealthScoreRating.good:
        return 'Good ${mealType.displayName}!';
      case HealthScoreRating.fair:
        return 'Fair ${mealType.displayName}';
      case HealthScoreRating.poor:
        return 'Could be healthier';
    }
  }
}
