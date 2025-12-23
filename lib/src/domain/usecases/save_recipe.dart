import '../entities/recipe.dart';
import '../repositories/recipe_repository.dart';

/// Use case for saving a recipe
class SaveRecipe {
  final RecipeRepository _repository;

  SaveRecipe(this._repository);

  Future<void> call(Recipe recipe) {
    return _repository.saveRecipe(recipe);
  }
}
