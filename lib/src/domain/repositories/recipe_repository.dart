import '../entities/recipe.dart';

/// Repository interface for managing recipes
abstract class RecipeRepository {
  /// Get all saved recipes
  Future<List<Recipe>> getRecipes();

  /// Get recipes filtered by meal type
  Future<List<Recipe>> getRecipesByMealType(MealType mealType);

  /// Get a single recipe by ID
  Future<Recipe?> getRecipeById(String id);

  /// Save a new recipe or update existing
  Future<void> saveRecipe(Recipe recipe);

  /// Delete a recipe
  Future<void> deleteRecipe(String id);

  /// Get default/preset ingredients for the ingredient picker
  Future<List<RecipeIngredient>> getPresetIngredients();

  /// Search for ingredients from OpenFoodFacts by name
  /// Returns ingredients with real nutrition data from the API
  Future<List<RecipeIngredient>> searchIngredients(String query);
}
