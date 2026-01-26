import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/services/dietary_preferences_service.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/health_conditions_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/recipe.dart'; // For MealType
import '../../domain/entities/scan_result.dart';
import '../../domain/usecases/compute_health_score.dart';
import '../widgets/vitasnap_logo.dart';

/// Product details page showing nutritional info with option to add or share.
class ProductDetailsPage extends StatefulWidget {
  final ScanResult scanResult;
  final bool showDietaryAlert;
  final bool showAddToList;

  const ProductDetailsPage({
    super.key,
    required this.scanResult,
    this.showDietaryAlert = false,
    this.showAddToList = true,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  bool _alertShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_alertShown && widget.showDietaryAlert) {
      _alertShown = true;
      // Check dietary preferences after the widget is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkDietaryPreferences();
      });
    }
  }

  void _checkDietaryPreferences() {
    final dietaryService = context.read<DietaryPreferencesService>();
    if (dietaryService.selectedRestrictions.isEmpty) return;

    final product = widget.scanResult.product;
    final result = dietaryService.checkProduct(
      productLabels: product.labels,
      allergens: null, // We don't have allergens from API yet
      ingredients: product.ingredients,
    );

    if ((result.violations.isNotEmpty || result.matches.isNotEmpty) &&
        mounted) {
      _showDietaryAlert(matches: result.matches, violations: result.violations);
    }
  }

  void _showDietaryAlert({
    required List<DietaryRestriction> matches,
    required List<DietaryRestriction> violations,
  }) {
    final primaryColor = const Color(0xFF1B8A4E);
    final hasViolations = violations.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasViolations
                ? Colors.orange.shade100
                : Colors.green.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasViolations
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline,
            color: hasViolations
                ? Colors.orange.shade700
                : Colors.green.shade700,
            size: 32,
          ),
        ),
        title: Text(hasViolations ? 'Dietary Alert' : 'Dietary Match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Show matches first (green)
            if (matches.isNotEmpty) ...[
              Text(
                'Matches your preferences:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...matches.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          v.icon,
                          color: Colors.green.shade600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        v.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            // Show violations (red)
            if (violations.isNotEmpty) ...[
              if (matches.isNotEmpty) const SizedBox(height: 12),
              Text(
                'May not match:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.red.shade700,
                ),
              ),
              const SizedBox(height: 8),
              ...violations.map(
                (v) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          v.icon,
                          color: Colors.red.shade600,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        v.displayName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.cancel, color: Colors.red.shade600, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Got it', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.scanResult.product;
    final score = widget.scanResult.score;
    final grade = _getGrade(score);
    final gradeColor = _getGradeColor(grade);
    final gradeMessage = _getGradeMessage(grade);

    // Get score breakdown with factors
    final computeHealthScore = context.read<ComputeHealthScore>();
    final scoreResult = computeHealthScore.computeWithBreakdown(product);

    // Check for dietary matches and violations
    final dietaryService = context.watch<DietaryPreferencesService>();
    final dietaryResult = dietaryService.selectedRestrictions.isNotEmpty
        ? dietaryService.checkProduct(
            productLabels: product.labels,
            allergens: null,
            ingredients: product.ingredients,
          )
        : (matches: <DietaryRestriction>[], violations: <DietaryRestriction>[]);

    // Check health conditions
    final healthService = context.watch<HealthConditionsService>();
    final healthResult = healthService.hasConditions
        ? healthService.analyzeProduct(
            nutriments: product.nutriments,
            ingredients: product.ingredients,
          )
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Dietary info banner (shows matches and violations)
              if (dietaryResult.matches.isNotEmpty ||
                  dietaryResult.violations.isNotEmpty) ...[
                _DietaryInfoBanner(
                  matches: dietaryResult.matches,
                  violations: dietaryResult.violations,
                ),
                const SizedBox(height: 16),
              ],
              // Health conditions analysis (shows for all products when user has conditions)
              if (healthResult != null) ...[
                _HealthWarningsBanner(result: healthResult),
                const SizedBox(height: 16),
              ],
              // Product card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF9E6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: product.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    product.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, e, s) => const Icon(
                                      Icons.fastfood,
                                      size: 40,
                                      color: Color(0xFF00C17B),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.fastfood,
                                  size: 40,
                                  color: Color(0xFF00C17B),
                                ),
                        ),
                        const SizedBox(width: 16),
                        // Product info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.brand.isNotEmpty
                                    ? product.brand
                                    : 'Unknown brand',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Grade badge
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: gradeColor,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            grade,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Grade message
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            grade == 'A' || grade == 'B'
                                ? Icons.check_circle
                                : Icons.info,
                            color: gradeColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            gradeMessage,
                            style: TextStyle(
                              color: gradeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score source indicator
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: scoreResult.nutriscoreGrade != null
                            ? Colors.blue.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scoreResult.nutriscoreGrade != null
                              ? Colors.blue.shade200
                              : Colors.purple.shade200,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            scoreResult.nutriscoreGrade != null
                                ? Icons.verified
                                : Icons.calculate,
                            size: 14,
                            color: scoreResult.nutriscoreGrade != null
                                ? Colors.blue.shade700
                                : Colors.purple.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            scoreResult.nutriscoreGrade != null
                                ? 'Nutri-Score ${scoreResult.nutriscoreGrade!.toUpperCase()}'
                                : 'VitaSnap Analysis',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scoreResult.nutriscoreGrade != null
                                  ? Colors.blue.shade700
                                  : Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Serving size info and calorie calculation
                    const SizedBox(height: 12),
                    _ServingSizeInfo(product: product),
                    // Score explanation section
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Why this rating?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Methodology explanation
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scoreResult.nutriscoreGrade != null
                            ? Colors.blue.shade50
                            : Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            scoreResult.nutriscoreGrade != null
                                ? Icons.verified
                                : Icons.calculate,
                            size: 16,
                            color: scoreResult.nutriscoreGrade != null
                                ? Colors.blue.shade700
                                : Colors.purple.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scoreResult.nutriscoreGrade != null
                                  ? 'This rating uses the official Nutri-Score (${scoreResult.nutriscoreGrade!.toUpperCase()}) from the European food rating system. Nutri-Score grades products A (best) to E (worst) based on nutritional quality per 100g.'
                                  : 'This rating is calculated by VitaSnap based on the nutritional profile per 100g. We analyze sugar, sodium, saturated fat, fiber, and protein content to estimate a health score.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scoreResult.nutriscoreGrade != null
                                    ? Colors.blue.shade700
                                    : Colors.purple.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Score factors breakdown
                    if (scoreResult.factors.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...scoreResult.factors.map(
                        (factor) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                factor.isPositive
                                    ? Icons.add_circle
                                    : Icons.remove_circle,
                                color: factor.isPositive
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      factor.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: factor.isPositive
                                            ? const Color(0xFF22C55E)
                                            : const Color(0xFFEF4444),
                                      ),
                                    ),
                                    Text(
                                      factor.description,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Dietary labels (vegetarian, halal, kosher, etc.)
              if (_getDietaryLabels(product.labels).isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dietary Info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (product.labels.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No dietary certification info available for this product',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _getDietaryLabels(product.labels)
                              .map((label) => _DietaryBadge(label: label))
                              .toList(),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              // Meal Items breakdown (for multi-item meals)
              if (widget.scanResult.isMultiItemMeal) ...[
                _MealItemsSection(
                  mealItems: widget.scanResult.mealItems!,
                  overallScore: widget.scanResult.score,
                ),
                const SizedBox(height: 20),
              ],
              // Nutritional breakdown
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nutritional Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NutrientRow(
                      label: 'Sugar',
                      value: _getNutrientValue(
                        product.nutriments,
                        'sugars_100g',
                      ),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 50, // Reference: 50g is high
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Sodium',
                      value:
                          _getNutrientValue(product.nutriments, 'sodium_100g') *
                          1000, // Convert to mg
                      unit: 'mg',
                      color: const Color(0xFF00C17B),
                      maxValue: 2300, // Daily reference
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Fiber',
                      value: _getNutrientValue(
                        product.nutriments,
                        'fiber_100g',
                      ),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 25, // Daily reference
                      isPositive: true,
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Protein',
                      value: _getNutrientValue(
                        product.nutriments,
                        'proteins_100g',
                      ),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 50,
                      isPositive: true,
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Sat. Fat',
                      value: _getNutrientValue(
                        product.nutriments,
                        'saturated-fat_100g',
                      ),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 20, // Daily reference
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Score display
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      'Health Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: gradeColor,
                      ),
                    ),
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100), // Space for bottom buttons
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              // Share button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _shareProduct(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00C17B),
                    side: const BorderSide(color: Color(0xFF00C17B)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Favorite button
              Expanded(
                flex: 1,
                child: Consumer<FavoritesService>(
                  builder: (context, favoritesService, _) {
                    final isFavorite = favoritesService.isFavorite(
                      product.barcode,
                    );
                    return ElevatedButton(
                      onPressed: () {
                        favoritesService.toggleFavorite(widget.scanResult);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFavorite
                                  ? 'Removed from favorites'
                                  : 'Added to favorites',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFavorite
                            ? Colors.red
                            : Colors.grey.shade200,
                        foregroundColor: isFavorite
                            ? Colors.white
                            : Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                      ),
                    );
                  },
                ),
              ),
              if (widget.showAddToList) ...[
                const SizedBox(width: 12),
                // Add to list button - shows meal type picker
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _showMealTypePicker(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Log Meal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C17B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showMealTypePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isToday = true; // When logging from scan, it's always for today
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF252542) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Log as...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current time: ${_formatTime(now)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...MealType.values.map((meal) {
                    final isFuture = isToday && meal.isFutureForToday;
                    return ListTile(
                      leading: Text(
                        meal.emoji,
                        style: TextStyle(
                          fontSize: 24,
                          color: isFuture ? Colors.grey.shade400 : null,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            meal.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isFuture
                                  ? Colors.grey.shade400
                                  : isDark
                                      ? Colors.white
                                      : Colors.black87,
                            ),
                          ),
                          if (isFuture) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Future',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: isFuture
                          ? Text(
                              'Available after ${meal.typicalStartHour}:00',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : null,
                      onTap: isFuture
                          ? () {
                              // Show snackbar explaining why it's disabled
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Can't log ${meal.displayName} yet - it's still ${MealType.getCurrentMealType().displayName} time",
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          : () {
                              Navigator.pop(ctx); // Close bottom sheet
                              Navigator.pop(context, {
                                'added': true,
                                'mealType': meal,
                              });
                            },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isFuture
                          ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                          : (isDark ? Colors.white10 : Colors.grey.shade50),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  void _shareProduct(BuildContext context) {
    final product = widget.scanResult.product;
    final grade = _getGrade(widget.scanResult.score);
    final text =
        '''
Check out this product on VitaSnap!

${product.name}
Brand: ${product.brand.isNotEmpty ? product.brand : 'Unknown'}
Health Score: ${widget.scanResult.score}/100 (Grade $grade)

Scan your food with VitaSnap to make healthier choices!
''';
    Share.share(text);
  }

  double _getNutrientValue(Map<String, dynamic> nutriments, String key) {
    final value = nutriments[key];
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return 0;
    }
  }

  String _getGrade(int score) {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    if (score >= 40) return 'D';
    return 'E';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF1B8A4E);
      case 'B':
        return const Color(0xFF7AC547);
      case 'C':
        return const Color(0xFFF9C74F);
      case 'D':
        return const Color(0xFFED8936);
      case 'E':
        return const Color(0xFFE53E3E);
      default:
        return Colors.grey;
    }
  }

  String _getGradeMessage(String grade) {
    switch (grade) {
      case 'A':
        return 'Excellent Choice';
      case 'B':
        return 'Good Choice';
      case 'C':
        return 'Moderate Choice';
      case 'D':
        return 'Poor Choice';
      case 'E':
        return 'Avoid if Possible';
      default:
        return 'Unknown';
    }
  }
}

class _NutrientRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final double maxValue;
  final bool isPositive;

  const _NutrientRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.maxValue,
    this.isPositive = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (value / maxValue).clamp(0.0, 1.0);
    final displayValue = unit == 'mg'
        ? value.round()
        : value.toStringAsFixed(1);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
        ),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text(
            '$displayValue$unit',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

/// Dietary label badge widget
class _DietaryBadge extends StatelessWidget {
  final _DietaryLabelInfo label;

  const _DietaryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: label.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: label.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            label.isPresent ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: label.color,
          ),
          const SizedBox(width: 6),
          Text(
            label.displayName,
            style: TextStyle(
              color: label.color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dietary label info holder
class _DietaryLabelInfo {
  final String displayName;
  final IconData icon;
  final Color color;
  final bool isPresent;

  const _DietaryLabelInfo({
    required this.displayName,
    required this.icon,
    required this.color,
    this.isPresent = true,
  });
}

/// Known dietary labels map
const _dietaryLabelMap = {
  // Religious certifications
  'en:halal': ('Halal', Icons.verified, Color(0xFF009688)),
  'en:kosher': ('Kosher', Icons.star, Color(0xFF3F51B5)),
  // Dietary preferences
  'en:vegan': ('Vegan', Icons.eco, Color(0xFF4CAF50)),
  'en:vegetarian': ('Vegetarian', Icons.grass, Color(0xFF8BC34A)),
  // Allergen-free
  'en:gluten-free': ('Gluten Free', Icons.no_food, Color(0xFFFF9800)),
  'en:no-gluten': ('Gluten Free', Icons.no_food, Color(0xFFFF9800)),
  'en:lactose-free': ('Lactose Free', Icons.no_drinks, Color(0xFF2196F3)),
  'en:no-lactose': ('Lactose Free', Icons.no_drinks, Color(0xFF2196F3)),
  // Organic
  'en:organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  'en:eu-organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  'en:usda-organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  // Other
  'en:fair-trade': ('Fair Trade', Icons.handshake, Color(0xFF607D8B)),
  'en:palm-oil-free': ('Palm Oil Free', Icons.nature, Color(0xFF795548)),
  'en:no-palm-oil': ('Palm Oil Free', Icons.nature, Color(0xFF795548)),
};

/// Parse dietary labels - shows only labels that ARE present
List<_DietaryLabelInfo> _getDietaryLabels(List<String> labels) {
  final List<_DietaryLabelInfo> result = [];
  final addedTypes = <String>{}; // Avoid duplicates

  for (final tag in labels) {
    final normalized = tag.toLowerCase();
    if (_dietaryLabelMap.containsKey(normalized)) {
      final (name, icon, color) = _dietaryLabelMap[normalized]!;
      // Avoid duplicate types
      if (!addedTypes.contains(name)) {
        result.add(
          _DietaryLabelInfo(
            displayName: name,
            icon: icon,
            color: color,
            isPresent: true,
          ),
        );
        addedTypes.add(name);
      }
    }
  }

  return result;
}

/// Info banner for dietary preference matches and violations
class _DietaryInfoBanner extends StatelessWidget {
  final List<DietaryRestriction> matches;
  final List<DietaryRestriction> violations;

  const _DietaryInfoBanner({required this.matches, required this.violations});

  @override
  Widget build(BuildContext context) {
    final hasViolations = violations.isNotEmpty;
    final hasMatches = matches.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasViolations ? Colors.orange.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasViolations ? Colors.orange.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasViolations
                      ? Colors.orange.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasViolations
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: hasViolations
                      ? Colors.orange.shade700
                      : Colors.green.shade700,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Dietary Check',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: hasViolations
                      ? Colors.orange.shade800
                      : Colors.green.shade800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Matches (green)
          if (hasMatches) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: matches
                  .map(
                    (v) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(v.icon, size: 16, color: Colors.green.shade700),
                          const SizedBox(width: 6),
                          Text(
                            v.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          // Violations (red)
          if (hasViolations) ...[
            if (hasMatches) const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: violations
                  .map(
                    (v) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(v.icon, size: 16, color: Colors.red.shade700),
                          const SizedBox(width: 6),
                          Text(
                            v.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.red.shade700,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Banner showing health condition warnings for the product
class _HealthWarningsBanner extends StatelessWidget {
  final HealthAnalysisResult result;

  const _HealthWarningsBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasWarnings = result.hasWarnings;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.overallSeverity.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: result.overallSeverity.color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: result.overallSeverity.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  result.overallSeverity.icon,
                  color: result.overallSeverity.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Analysis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: result.overallSeverity.color,
                      ),
                    ),
                    Text(
                      result.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Show safe message or warnings
          if (!hasWarnings) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    color: Colors.green.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Based on your health conditions, this product appears to be a good choice for you.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),

            // Warning cards
            ...result.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _WarningCard(warning: warning),
              ),
            ),

            // Tap to see more
            Center(
              child: TextButton.icon(
                onPressed: () => _showDetailedAnalysis(context),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('View Full Analysis'),
                style: TextButton.styleFrom(
                  foregroundColor: result.overallSeverity.color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailedAnalysis(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.health_and_safety,
                      color: result.overallSeverity.color,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Health Analysis Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: result.overallSeverity.color.withValues(
                          alpha: 0.15,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        result.overallSeverity.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: result.overallSeverity.color,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: result.warnings.length,
                  itemBuilder: (context, index) {
                    final warning = result.warnings[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _DetailedWarningCard(warning: warning),
                    );
                  },
                ),
              ),
              // Disclaimer
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'This is general guidance only. Consult your healthcare provider for personalized advice.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final HealthWarning warning;

  const _WarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warning.severity.color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: warning.condition.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              warning.condition.icon,
              color: warning.condition.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        warning.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: warning.severity.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        warning.severity.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: warning.severity.color,
                        ),
                      ),
                    ),
                  ],
                ),
                if (warning.nutrientValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    warning.nutrientValue!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailedWarningCard extends StatelessWidget {
  final HealthWarning warning;

  const _DetailedWarningCard({required this.warning});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warning.severity.color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning.severity.color.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: warning.condition.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  warning.condition.icon,
                  color: warning.condition.color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      warning.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      warning.condition.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: warning.condition.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: warning.severity.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  warning.severity.icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          if (warning.nutrientValue != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                warning.nutrientValue!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            warning.explanation,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade800,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section to display individual meal items in a multi-item meal
class _MealItemsSection extends StatelessWidget {
  final List<MealItem> mealItems;
  final int overallScore;

  const _MealItemsSection({
    required this.mealItems,
    required this.overallScore,
  });

  String _getGrade(int score) {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    if (score >= 40) return 'D';
    return 'E';
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF22C55E); // Green
      case 'B':
        return const Color(0xFF84CC16); // Lime
      case 'C':
        return const Color(0xFFEAB308); // Yellow
      case 'D':
        return const Color(0xFFF97316); // Orange
      case 'E':
        return const Color(0xFFEF4444); // Red
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 20,
                color: Color(0xFF1B8A4E),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Meal Items',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              // Overall score badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getGradeColor(
                    _getGrade(overallScore),
                  ).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Overall: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _getGradeColor(_getGrade(overallScore)),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _getGrade(overallScore),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Individual meal items
          ...mealItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final grade = _getGrade(item.score);
            final gradeColor = _getGradeColor(grade);
            final isLast = index == mealItems.length - 1;

            return Column(
              children: [
                _MealItemRow(item: item, grade: grade, gradeColor: gradeColor),
                if (!isLast) ...[
                  const SizedBox(height: 8),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 8),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

/// Individual meal item row widget with favorite button and tap to view details
class _MealItemRow extends StatelessWidget {
  final MealItem item;
  final String grade;
  final Color gradeColor;

  const _MealItemRow({
    required this.item,
    required this.grade,
    required this.gradeColor,
  });

  /// Creates a Product from MealItem for favorites/details
  Product _toProduct() {
    return Product(
      barcode: 'meal_item_${item.name.hashCode}',
      name: item.name,
      brand: item.category,
      nutriments: {
        'energy-kcal_100g': item.nutrition['calories'] ?? 0,
        'proteins_100g': item.nutrition['protein'] ?? 0,
        'carbohydrates_100g': item.nutrition['carbs'] ?? 0,
        'fat_100g': item.nutrition['fat'] ?? 0,
        'sodium_100g': (item.nutrition['sodium'] ?? 0) / 1000,
      },
    );
  }

  /// Creates a ScanResult from MealItem for viewing details
  ScanResult _toScanResult() {
    return ScanResult(
      product: _toProduct(),
      score: item.score,
    );
  }

  void _showMealItemDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          scanResult: _toScanResult(),
          showAddToList: false, // Already part of a meal
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favoritesService = context.watch<FavoritesService>();
    final product = _toProduct();
    final isFavorite = favoritesService.isFavorite(product.barcode);

    // Extract key nutrition info
    final calories =
        item.nutrition['calories'] ?? item.nutrition['energy-kcal_100g'] ?? 0;
    final protein =
        item.nutrition['protein'] ?? item.nutrition['proteins_100g'] ?? 0;
    final carbs =
        item.nutrition['carbs'] ?? item.nutrition['carbohydrates_100g'] ?? 0;
    final fat = item.nutrition['fat'] ?? item.nutrition['fat_100g'] ?? 0;

    return InkWell(
      onTap: () => _showMealItemDetails(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grade badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: gradeColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                grade,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Favorite button
                      GestureDetector(
                        onTap: () {
                          if (isFavorite) {
                            favoritesService.removeFavorite(product.barcode);
                          } else {
                            favoritesService.addFavorite(
                              ScanResult(product: product, score: item.score),
                            );
                          }
                        },
                        child: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 20,
                          color: isFavorite ? Colors.red : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} ${item.unit}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (item.category.isNotEmpty) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Nutrition mini-summary
                  if (calories > 0 || protein > 0) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (calories > 0)
                          _NutritionChip(
                            label: '${calories.toStringAsFixed(0)} kcal',
                            color: Colors.orange.shade100,
                            textColor: Colors.orange.shade800,
                          ),
                        if (protein > 0)
                          _NutritionChip(
                            label: '${protein.toStringAsFixed(1)}g protein',
                            color: Colors.blue.shade100,
                            textColor: Colors.blue.shade800,
                          ),
                        if (carbs > 0)
                          _NutritionChip(
                            label: '${carbs.toStringAsFixed(1)}g carbs',
                            color: Colors.green.shade100,
                            textColor: Colors.green.shade800,
                          ),
                        if (fat > 0)
                          _NutritionChip(
                            label: '${fat.toStringAsFixed(1)}g fat',
                            color: Colors.purple.shade100,
                            textColor: Colors.purple.shade800,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small nutrition chip for meal item display
class _NutritionChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _NutritionChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

/// Widget to display serving size info and calculated per-serving nutrition
class _ServingSizeInfo extends StatelessWidget {
  final Product product;

  const _ServingSizeInfo({required this.product});

  @override
  Widget build(BuildContext context) {
    final servingSize = product.servingSize;
    final servingGrams = product.servingQuantityGrams;
    final caloriesPer100g = _getCaloriesPer100g();
    
    // Calculate per-serving calories if we have serving size
    final perServingCalories = servingGrams != null && caloriesPer100g > 0
        ? (caloriesPer100g * servingGrams / 100).round()
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Nutrition Info',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Always show per 100g info
          Row(
            children: [
              Icon(
                Icons.scale,
                size: 14,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                'Database values: per 100g',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              if (caloriesPer100g > 0) ...[
                Text(
                  ' (${caloriesPer100g.round()} kcal)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ],
          ),
          // Show serving size if available
          if (servingSize != null && servingSize.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.restaurant,
                  size: 14,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Serving size: $servingSize',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            if (perServingCalories != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calculate,
                      size: 14,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Per serving: ~$perServingCalories kcal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 14,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Serving size not available - check product label',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  double _getCaloriesPer100g() {
    final nutriments = product.nutriments;
    final value = nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'];
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
