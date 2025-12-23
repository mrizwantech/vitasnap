import 'package:flutter/material.dart';

import '../../../domain/entities/recipe.dart';

/// Card displaying the current recipe being built with its ingredients
class CurrentRecipeCard extends StatelessWidget {
  final MealType mealType;
  final List<RecipeIngredient> ingredients;
  final ValueChanged<String> onRemoveIngredient;
  final VoidCallback onClearAll;
  final Color cardColor;
  final bool isDark;

  const CurrentRecipeCard({
    super.key,
    required this.mealType,
    required this.ingredients,
    required this.onRemoveIngredient,
    required this.onClearAll,
    required this.cardColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'My ${mealType.displayName}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (ingredients.isNotEmpty)
                TextButton(
                  onPressed: () => _showClearConfirmation(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(60, 30),
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Ingredient list (or nothing if empty)
          if (ingredients.isNotEmpty)
            _buildIngredientList(),
        ],
      ),
    );
  }

  Widget _buildIngredientList() {
    return Column(
      children: ingredients.map((ingredient) {
        final scoreValue = (ingredient.scoreValue * ingredient.quantity * 0.5).round();
        final scoreColor = scoreValue >= 0 ? Colors.green : Colors.red;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Emoji
                Text(
                  ingredient.iconEmoji ?? '🍽️',
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                // Name and quantity
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '${ingredient.quantity.toStringAsFixed(ingredient.quantity == ingredient.quantity.roundToDouble() ? 0 : 1)} ${ingredient.unit.displayName.toLowerCase()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${scoreValue >= 0 ? '+' : ''}$scoreValue',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Remove button
                GestureDetector(
                  onTap: () => onRemoveIngredient(ingredient.id),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All'),
        content: const Text('Remove all ingredients from this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClearAll();
            },
            child: Text(
              'Clear',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
