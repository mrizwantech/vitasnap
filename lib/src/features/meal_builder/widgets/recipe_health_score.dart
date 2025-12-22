import 'package:flutter/material.dart';

import '../../../domain/entities/recipe.dart';

/// Widget displaying the health score with visual feedback
class RecipeHealthScore extends StatelessWidget {
  final int score;
  final HealthScoreRating rating;
  final String message;
  final Map<String, double> nutrition;
  final bool isDark;
  final VoidCallback? onLogMeal;

  const RecipeHealthScore({
    super.key,
    required this.score,
    required this.rating,
    required this.message,
    required this.nutrition,
    required this.isDark,
    this.onLogMeal,
  });

  @override
  Widget build(BuildContext context) {
    final ratingColor = _getRatingColor(rating);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ratingColor,
            ratingColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ratingColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Score Circle
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'SCORE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Message and Nutrition
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRatingEmoji(rating),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Nutrition row
                Row(
                  children: [
                    _buildNutritionBadge(
                      nutrition['calories']?.round().toString() ?? '0',
                      'Cal',
                    ),
                    const SizedBox(width: 8),
                    _buildNutritionBadge(
                      '${nutrition['protein']?.round() ?? 0}g',
                      'Protein',
                    ),
                    const SizedBox(width: 8),
                    _buildNutritionBadge(
                      '${nutrition['carbs']?.round() ?? 0}g',
                      'Carbs',
                    ),
                    const SizedBox(width: 8),
                    _buildNutritionBadge(
                      '${nutrition['fat']?.round() ?? 0}g',
                      'Fat',
                    ),
                  ],
                ),
                // Log Meal button
                if (onLogMeal != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onLogMeal,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Log This Meal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _getRatingColor(rating),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionBadge(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRatingColor(HealthScoreRating rating) {
    switch (rating) {
      case HealthScoreRating.excellent:
        return const Color(0xFF34C759);
      case HealthScoreRating.good:
        return const Color(0xFF30D158);
      case HealthScoreRating.fair:
        return const Color(0xFFFF9500);
      case HealthScoreRating.poor:
        return const Color(0xFFFF3B30);
    }
  }

  String _getRatingEmoji(HealthScoreRating rating) {
    switch (rating) {
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
