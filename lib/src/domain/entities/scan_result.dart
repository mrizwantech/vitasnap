import 'dart:convert';

import 'product.dart';
import 'recipe.dart'; // For MealType

class ScanResult {
  final Product product;
  final int score; // 0-100
  final DateTime timestamp;
  final MealType? mealType; // breakfast, lunch, dinner, snack

  ScanResult({
    required this.product,
    required this.score,
    DateTime? timestamp,
    this.mealType,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'product': {
          'barcode': product.barcode,
          'name': product.name,
          'brand': product.brand,
          'imageUrl': product.imageUrl,
          'ingredients': product.ingredients,
          'nutriments': product.nutriments,
          'labels': product.labels,
        },
        'score': score,
        'timestamp': timestamp.toIso8601String(),
        'mealType': mealType?.name,
      };

  static ScanResult fromJson(Map<String, dynamic> json) {
    final p = json['product'] as Map<String, dynamic>;
    final product = Product(
      barcode: p['barcode'] as String,
      name: p['name'] as String,
      brand: p['brand'] as String,
      imageUrl: p['imageUrl'] as String?,
      ingredients: p['ingredients'] as String?,
      nutriments: Map<String, dynamic>.from(p['nutriments'] ?? {}),
      labels: (p['labels'] as List<dynamic>?)?.cast<String>() ?? [],
    );
    
    MealType? mealType;
    if (json['mealType'] != null) {
      mealType = MealType.values.firstWhere(
        (e) => e.name == json['mealType'],
        orElse: () => MealType.snack,
      );
    }
    
    return ScanResult(
      product: product,
      score: (json['score'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      mealType: mealType,
    );
  }

  static String encodeList(List<ScanResult> items) => jsonEncode(items.map((e) => e.toJson()).toList());

  static List<ScanResult> decodeList(String encoded) {
    final arr = jsonDecode(encoded) as List<dynamic>;
    return arr.map((e) => ScanResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
