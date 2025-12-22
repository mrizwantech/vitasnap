import '../entities/recipe.dart';
import '../repositories/recipe_repository.dart';

/// Use case for getting preset ingredients
class GetPresetIngredients {
  final RecipeRepository _repository;

  GetPresetIngredients(this._repository);

  Future<List<RecipeIngredient>> call() {
    return _repository.getPresetIngredients();
  }
}
