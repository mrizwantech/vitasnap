import 'package:flutter/material.dart';

import '../../../domain/entities/recipe.dart';

/// Horizontal tabs for selecting meal type (Breakfast, Lunch, Dinner, Snack)
class MealTypeTabs extends StatelessWidget {
  final MealType selectedType;
  final ValueChanged<MealType> onTypeSelected;

  const MealTypeTabs({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: MealType.values.length,
        itemBuilder: (context, index) {
          final type = MealType.values[index];
          final isSelected = type == selectedType;

          return Padding(
            padding: EdgeInsets.only(
              right: index < MealType.values.length - 1 ? 12 : 0,
            ),
            child: GestureDetector(
              onTap: () => onTypeSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? _getTypeColor(type) : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected ? _getTypeColor(type) : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getTypeEmoji(type),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getTypeColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return const Color(0xFFFF9500);
      case MealType.lunch:
        return const Color(0xFF34C759);
      case MealType.dinner:
        return const Color(0xFF5856D6);
      case MealType.snack:
        return const Color(0xFFFF2D55);
    }
  }

  String _getTypeEmoji(MealType type) {
    switch (type) {
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
}
