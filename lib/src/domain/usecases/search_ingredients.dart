import '../entities/recipe.dart';
import '../repositories/recipe_repository.dart';

/// Use case for searching ingredients from OpenFoodFacts
/// Returns ingredients with real nutrition data from the API
class SearchIngredients {
  final RecipeRepository _repository;

  SearchIngredients(this._repository);

  /// Search for ingredients by name
  /// Returns a list of RecipeIngredients with real nutrition data
  Future<List<RecipeIngredient>> call(String query) async {
    return _repository.searchIngredients(query);
  }
}
