import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/scan_result.dart';
import '../widgets/vitasnap_logo.dart';

/// Product details page showing nutritional info with option to add or share.
class ProductDetailsPage extends StatelessWidget {
  final ScanResult scanResult;

  const ProductDetailsPage({super.key, required this.scanResult});

  @override
  Widget build(BuildContext context) {
    final product = scanResult.product;
    final score = scanResult.score;
    final grade = _getGrade(score);
    final gradeColor = _getGradeColor(grade);
    final gradeMessage = _getGradeMessage(grade);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20),
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
              // Add to list button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, {'added': true}),
                  icon: const Icon(Icons.add),
                  label: const Text('Add to List'),
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
          ),
        ),
      ),
    );
  }

  void _shareProduct(BuildContext context) {
    final product = scanResult.product;
    final grade = _getGrade(scanResult.score);
    final text =
        '''
Check out this product on VitaSnap!

${product.name}
Brand: ${product.brand.isNotEmpty ? product.brand : 'Unknown'}
Health Score: ${scanResult.score}/100 (Grade $grade)

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
