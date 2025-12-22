import 'package:flutter/material.dart';

import '../../../domain/entities/recipe.dart';

/// Grid display of available ingredients to add to recipe
class IngredientGrid extends StatelessWidget {
  final List<RecipeIngredient> ingredients;
  final ValueChanged<RecipeIngredient> onIngredientTap;
  final Color cardColor;
  final bool isDark;

  const IngredientGrid({
    super.key,
    required this.ingredients,
    required this.onIngredientTap,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: isDark ? Colors.white38 : Colors.black26,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ingredients found',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final ingredient = ingredients[index];
          return _IngredientCard(
            ingredient: ingredient,
            onTap: () => onIngredientTap(ingredient),
            cardColor: cardColor,
            isDark: isDark,
          );
        },
        childCount: ingredients.length,
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final RecipeIngredient ingredient;
  final VoidCallback onTap;
  final Color cardColor;
  final bool isDark;

  const _IngredientCard({
    required this.ingredient,
    required this.onTap,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emoji Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(ingredient.category).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      ingredient.iconEmoji ?? '🍽️',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    ingredient.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            // Nutri-Score badge
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getNutriScoreColor(ingredient.nutriScore),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ingredient.nutriScore.displayName,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getNutriScoreColor(NutriScoreGrade grade) {
    switch (grade) {
      case NutriScoreGrade.a:
        return const Color(0xFF038141); // Dark green
      case NutriScoreGrade.b:
        return const Color(0xFF85BB2F); // Light green
      case NutriScoreGrade.c:
        return const Color(0xFFFECB02); // Yellow
      case NutriScoreGrade.d:
        return const Color(0xFFEE8100); // Orange
      case NutriScoreGrade.e:
        return const Color(0xFFE63E11); // Red
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'protein':
        return const Color(0xFFE53935);
      case 'veggies':
        return const Color(0xFF43A047);
      case 'fruits':
        return const Color(0xFFFF9800);
      case 'grains':
        return const Color(0xFFFFC107);
      case 'dairy':
        return const Color(0xFF1E88E5);
      default:
        return const Color(0xFF757575);
    }
  }
}
