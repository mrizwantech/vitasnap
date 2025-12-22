import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/health_conditions_service.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/recipe.dart';
import '../../../domain/entities/scan_result.dart';
import '../../../domain/usecases/add_scan_result.dart';
import '../../../presentation/viewmodels/meal_builder_viewmodel.dart';

/// Modal bottom sheet for adding an ingredient with quantity selection
class AddIngredientModal extends StatefulWidget {
  final RecipeIngredient ingredient;
  final VoidCallback? onAdded;

  const AddIngredientModal({
    super.key,
    required this.ingredient,
    this.onAdded,
  });

  @override
  State<AddIngredientModal> createState() => _AddIngredientModalState();
}

class _AddIngredientModalState extends State<AddIngredientModal> {
  double _quantity = 1;
  late IngredientUnit _selectedUnit;
  bool _addToTracker = false;
  MealType _selectedMealType = MealType.snack;

  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.ingredient.unit;
  }

  int get _calculatedScore {
    return (widget.ingredient.scoreValue * _quantity * 0.5).round();
  }

  Map<String, double> get _calculatedNutrition {
    // Create a temporary ingredient with current quantity
    final tempIngredient = widget.ingredient.copyWith(
      quantity: _quantity,
      unit: _selectedUnit,
    );
    return tempIngredient.adjustedNutriments;
  }

  /// Get nutritional highlights - what's good and bad about this ingredient
  Map<String, List<Map<String, dynamic>>> get _nutritionHighlights {
    final nutrition = _calculatedNutrition;
    final List<Map<String, dynamic>> good = [];
    final List<Map<String, dynamic>> bad = [];

    // Protein - high is good (> 5g per serving)
    final protein = nutrition['protein'] ?? 0;
    if (protein >= 10) {
      good.add({'label': 'High in Protein', 'value': '${protein.round()}g', 'icon': '💪'});
    } else if (protein >= 5) {
      good.add({'label': 'Good Protein', 'value': '${protein.round()}g', 'icon': '💪'});
    }

    // Fiber - high is good (> 3g per serving)
    final fiber = nutrition['fiber'] ?? 0;
    if (fiber >= 5) {
      good.add({'label': 'High in Fiber', 'value': '${fiber.round()}g', 'icon': '🌾'});
    } else if (fiber >= 3) {
      good.add({'label': 'Good Fiber', 'value': '${fiber.round()}g', 'icon': '🌾'});
    }

    // Low calories is good (< 100 per serving)
    final calories = nutrition['calories'] ?? 0;
    if (calories <= 50) {
      good.add({'label': 'Low Calorie', 'value': '${calories.round()} cal', 'icon': '✨'});
    } else if (calories > 300) {
      bad.add({'label': 'High Calorie', 'value': '${calories.round()} cal', 'icon': '🔥'});
    }

    // Fat - high is concerning (> 15g per serving)
    final fat = nutrition['fat'] ?? 0;
    if (fat > 20) {
      bad.add({'label': 'High in Fat', 'value': '${fat.round()}g', 'icon': '🍳'});
    } else if (fat > 10) {
      bad.add({'label': 'Moderate Fat', 'value': '${fat.round()}g', 'icon': '🍳'});
    } else if (fat <= 3 && fat >= 0) {
      good.add({'label': 'Low Fat', 'value': '${fat.round()}g', 'icon': '💚'});
    }

    // Sugar - high is bad (> 10g per serving)
    final sugar = nutrition['sugar'] ?? 0;
    if (sugar > 15) {
      bad.add({'label': 'High in Sugar', 'value': '${sugar.round()}g', 'icon': '🍬'});
    } else if (sugar > 8) {
      bad.add({'label': 'Moderate Sugar', 'value': '${sugar.round()}g', 'icon': '🍬'});
    } else if (sugar <= 2) {
      good.add({'label': 'Low Sugar', 'value': '${sugar.round()}g', 'icon': '👍'});
    }

    // Sodium - high is bad (> 400mg per serving)
    final sodium = (nutrition['sodium'] ?? 0) * 1000; // Convert to mg
    if (sodium > 600) {
      bad.add({'label': 'High Sodium', 'value': '${sodium.round()}mg', 'icon': '🧂'});
    } else if (sodium > 300) {
      bad.add({'label': 'Moderate Sodium', 'value': '${sodium.round()}mg', 'icon': '🧂'});
    } else if (sodium <= 100) {
      good.add({'label': 'Low Sodium', 'value': '${sodium.round()}mg', 'icon': '💙'});
    }

    // Carbs - context dependent, but very high is notable
    final carbs = nutrition['carbs'] ?? 0;
    if (carbs > 40) {
      bad.add({'label': 'High in Carbs', 'value': '${carbs.round()}g', 'icon': '🍞'});
    } else if (carbs <= 5) {
      good.add({'label': 'Low Carb', 'value': '${carbs.round()}g', 'icon': '🥗'});
    }

    // Check cholesterol from raw nutriments (not in adjusted)
    final cholesterol = _getDouble(widget.ingredient.nutriments['cholesterol_100g']) * _getQuantityFactor() * 1000; // mg
    if (cholesterol > 150) {
      bad.add({'label': 'High Cholesterol', 'value': '${cholesterol.round()}mg', 'icon': '⚠️'});
    } else if (cholesterol > 60) {
      bad.add({'label': 'Contains Cholesterol', 'value': '${cholesterol.round()}mg', 'icon': '🥚'});
    }

    // Saturated fat
    final saturatedFat = _getDouble(widget.ingredient.nutriments['saturated-fat_100g']) * _getQuantityFactor();
    if (saturatedFat > 5) {
      bad.add({'label': 'High Saturated Fat', 'value': '${saturatedFat.round()}g', 'icon': '🔴'});
    } else if (saturatedFat > 2) {
      bad.add({'label': 'Saturated Fat', 'value': '${saturatedFat.toStringAsFixed(1)}g', 'icon': '🟠'});
    }

    return {'good': good, 'bad': bad};
  }

  double _getDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  double _getQuantityFactor() {
    switch (_selectedUnit) {
      case IngredientUnit.whole:
        return _quantity * 0.5;
      case IngredientUnit.gram:
        return _quantity / 100;
      case IngredientUnit.cup:
        return _quantity * 2.4;
      case IngredientUnit.tbsp:
        return _quantity * 0.15;
      case IngredientUnit.tsp:
        return _quantity * 0.05;
      case IngredientUnit.slice:
        return _quantity * 0.3;
      case IngredientUnit.piece:
        return _quantity * 0.25;
    }
  }

  /// Get personalized health warnings based on user's health conditions
  HealthAnalysisResult? _getHealthWarnings(HealthConditionsService healthService) {
    if (!healthService.hasConditions) return null;
    
    // Analyze the food's inherent nutritional quality (per 100g basis)
    // The thresholds in analyzeProduct are designed for per-100g values
    // so we pass the raw nutriments without scaling
    return healthService.analyzeProduct(nutriments: widget.ingredient.nutriments);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF252542) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // FIXED HEADER: Ingredient info
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(widget.ingredient.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      widget.ingredient.iconEmoji ?? '🍽️',
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.ingredient.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.ingredient.category,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // SCROLLABLE MIDDLE: Nutrition details
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                // Combined Nutrition Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'NUTRITION FOR ${_quantity == _quantity.roundToDouble() ? _quantity.toInt() : _quantity.toStringAsFixed(1)} ${_selectedUnit.displayName.toUpperCase()}${_quantity > 1 && _selectedUnit != IngredientUnit.gram ? 'S' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtextColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNutritionItem(
                            '${_calculatedNutrition['calories']?.round() ?? 0}',
                            'Cal',
                            textColor,
                            subtextColor,
                          ),
                          _buildNutritionItem(
                            '${_calculatedNutrition['protein']?.round() ?? 0}g',
                            'Protein',
                            textColor,
                            subtextColor,
                          ),
                          _buildNutritionItem(
                            '${_calculatedNutrition['carbs']?.round() ?? 0}g',
                            'Carbs',
                            textColor,
                            subtextColor,
                          ),
                          _buildNutritionItem(
                            '${_calculatedNutrition['fat']?.round() ?? 0}g',
                            'Fat',
                            textColor,
                            subtextColor,
                          ),
                        ],
                      ),
                      // Inline highlights (good/bad) if any
                      _buildInlineHighlights(isDark),
                    ],
                  ),
                ),

                // Personalized Health Warnings based on user's conditions
                Builder(
                  builder: (context) {
                    final healthService = context.watch<HealthConditionsService>();
                    final healthResult = _getHealthWarnings(healthService);
                    
                    // Show debug card for troubleshooting
                    if (!healthService.hasConditions) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Set health conditions in Profile to see personalized warnings',
                                  style: TextStyle(
                                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (healthResult == null || !healthResult.hasWarnings) {
                      // Show "all clear" message when user has conditions but no warnings
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No health concerns for your conditions',
                                  style: TextStyle(
                                    color: isDark ? Colors.green.shade200 : Colors.green.shade700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _buildHealthWarnings(healthResult, isDark, textColor, subtextColor),
                    );
                  },
                ),

                // Log to Tracker option
                const SizedBox(height: 16),
                _buildTrackerOption(isDark, textColor, subtextColor),

                const SizedBox(height: 16),
              ],
            ),
          ),
          ),

          // FIXED FOOTER: Unified action bar with quantity + unit + Add
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 20),
            decoration: BoxDecoration(
              color: backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Quantity controls
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onPressed: _quantity > 0.5
                            ? () => setState(() => _quantity -= 0.5)
                            : null,
                        isDark: isDark,
                      ),
                      Container(
                        width: 36,
                        child: Text(
                          _quantity == _quantity.roundToDouble()
                              ? _quantity.toInt().toString()
                              : _quantity.toStringAsFixed(1),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
                        onPressed: () => setState(() => _quantity += 0.5),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Unit dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<IngredientUnit>(
                      value: _selectedUnit,
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: subtextColor,
                        size: 20,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                      dropdownColor: backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      items: _getAvailableUnits().map((unit) {
                        return DropdownMenuItem(
                          value: unit,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(unit.displayName),
                          ),
                        );
                      }).toList(),
                      onChanged: (unit) {
                        if (unit != null) setState(() => _selectedUnit = unit);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Add button
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addIngredient,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 20),
                        const SizedBox(width: 4),
                        const Text(
                          'Add',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_calculatedScore >= 0 ? '+' : ''}$_calculatedScore',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 20,
            color: onPressed != null
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white24 : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionItem(
    String value,
    String label,
    Color textColor,
    Color subtextColor,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: subtextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInlineHighlights(bool isDark) {
    final highlights = _nutritionHighlights;
    final good = highlights['good'] ?? [];
    final bad = highlights['bad'] ?? [];

    if (good.isEmpty && bad.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(
          color: isDark ? Colors.white12 : Colors.black12,
          height: 1,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            ...good.map((item) => _buildMiniChip(
              icon: item['icon'] as String,
              label: item['label'] as String,
              isGood: true,
              isDark: isDark,
            )),
            ...bad.map((item) => _buildMiniChip(
              icon: item['icon'] as String,
              label: item['label'] as String,
              isGood: false,
              isDark: isDark,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniChip({
    required String icon,
    required String label,
    required bool isGood,
    required bool isDark,
  }) {
    final bgColor = isGood
        ? (isDark ? const Color(0xFF1B5E20).withValues(alpha: 0.3) : const Color(0xFFE8F5E9))
        : (isDark ? const Color(0xFFB71C1C).withValues(alpha: 0.3) : const Color(0xFFFFEBEE));
    final textColor = isGood
        ? (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32))
        : (isDark ? const Color(0xFFEF9A9A) : const Color(0xFFC62828));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthWarnings(
    HealthAnalysisResult result,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.overallSeverity.color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: result.overallSeverity.color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with overall severity
          Row(
            children: [
              Icon(
                result.overallSeverity.icon,
                color: result.overallSeverity.color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'HEALTH ALERT FOR YOUR CONDITIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: result.overallSeverity.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Warning items
          ...result.warnings.take(3).map((warning) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildWarningItem(warning, isDark),
          )),
          // Show more indicator if there are more warnings
          if (result.warnings.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+ ${result.warnings.length - 3} more alerts...',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: subtextColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWarningItem(HealthWarning warning, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: warning.severity.color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            warning.condition.icon,
            color: warning.severity.color,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: warning.severity.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      warning.severity.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: warning.severity.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      warning.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                warning.explanation,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (warning.nutrientValue != null) ...[
                const SizedBox(height: 4),
                Text(
                  warning.nutrientValue!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: warning.severity.color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<IngredientUnit> _getAvailableUnits() {
    // Return relevant units based on ingredient category
    switch (widget.ingredient.category) {
      case 'protein':
        return [
          IngredientUnit.whole,
          IngredientUnit.piece,
          IngredientUnit.slice,
          IngredientUnit.gram,
        ];
      case 'veggies':
      case 'fruits':
        return [
          IngredientUnit.whole,
          IngredientUnit.cup,
          IngredientUnit.gram,
        ];
      case 'grains':
        return [
          IngredientUnit.cup,
          IngredientUnit.slice,
          IngredientUnit.gram,
        ];
      case 'dairy':
        return [
          IngredientUnit.cup,
          IngredientUnit.slice,
          IngredientUnit.tbsp,
          IngredientUnit.gram,
        ];
      default:
        return [
          IngredientUnit.tbsp,
          IngredientUnit.tsp,
          IngredientUnit.cup,
          IngredientUnit.gram,
        ];
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

  Widget _buildTrackerOption(bool isDark, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _addToTracker 
              ? Theme.of(context).primaryColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Checkbox row
          GestureDetector(
            onTap: () => setState(() => _addToTracker = !_addToTracker),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _addToTracker,
                    onChanged: (v) => setState(() => _addToTracker = v ?? false),
                    activeColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Log to Today\'s Tracker',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.history,
                  size: 18,
                  color: subtextColor,
                ),
              ],
            ),
          ),
          // Meal type selector (shown when checked)
          if (_addToTracker) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: MealType.values.map((meal) {
                  final isSelected = meal == _selectedMealType;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMealType = meal),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : (isDark ? Colors.white10 : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : (isDark ? Colors.white24 : Colors.grey.shade300),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(meal.emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              meal.displayName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark ? Colors.white70 : Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _addIngredient() async {
    final viewModel = context.read<MealBuilderViewModel>();
    viewModel.addIngredient(widget.ingredient, _quantity, _selectedUnit);
    viewModel.clearSearchResults();
    
    // If user wants to log to tracker, create a ScanResult and add to history
    if (_addToTracker) {
      final addScanResult = context.read<AddScanResult>();
      
      // Create Product from ingredient
      final product = Product(
        barcode: 'ingredient_${widget.ingredient.id}',
        name: widget.ingredient.name,
        brand: widget.ingredient.category,
        nutriments: _calculatedNutrition.map((k, v) => MapEntry(k, v)),
      );
      
      // Create ScanResult with meal type
      final scanResult = ScanResult(
        product: product,
        score: widget.ingredient.scoreValue,
        mealType: _selectedMealType,
      );
      
      await addScanResult(scanResult);
    }
    
    widget.onAdded?.call();
    Navigator.pop(context, {'added': true, 'loggedToTracker': _addToTracker});
  }
}
