import '../entities/recipe.dart';
import '../repositories/recipe_repository.dart';

/// Use case for retrieving recipes
class GetRecipes {
  final RecipeRepository _repository;

  GetRecipes(this._repository);

  /// Get all recipes
  Future<List<Recipe>> call() {
    return _repository.getRecipes();
  }

  /// Get recipes by meal type
  Future<List<Recipe>> byMealType(MealType mealType) {
    return _repository.getRecipesByMealType(mealType);
  }

  /// Get a single recipe by ID
  Future<Recipe?> byId(String id) {
    return _repository.getRecipeById(id);
  }
}
