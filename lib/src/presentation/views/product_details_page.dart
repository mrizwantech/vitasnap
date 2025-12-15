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
                                product.brand.isNotEmpty ? product.brand : 'Unknown brand',
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            grade == 'A' || grade == 'B' ? Icons.check_circle : Icons.info,
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
                      value: _getNutrientValue(product.nutriments, 'sugars_100g'),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 50, // Reference: 50g is high
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Sodium',
                      value: _getNutrientValue(product.nutriments, 'sodium_100g') * 1000, // Convert to mg
                      unit: 'mg',
                      color: const Color(0xFF00C17B),
                      maxValue: 2300, // Daily reference
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Fiber',
                      value: _getNutrientValue(product.nutriments, 'fiber_100g'),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 25, // Daily reference
                      isPositive: true,
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Protein',
                      value: _getNutrientValue(product.nutriments, 'proteins_100g'),
                      unit: 'g',
                      color: const Color(0xFF00C17B),
                      maxValue: 50,
                      isPositive: true,
                    ),
                    const SizedBox(height: 12),
                    _NutrientRow(
                      label: 'Sat. Fat',
                      value: _getNutrientValue(product.nutriments, 'saturated-fat_100g'),
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
    final text = '''
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
    final displayValue = unit == 'mg' ? value.round() : value.toStringAsFixed(1);

    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
