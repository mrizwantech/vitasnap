import 'dart:convert';

import 'product.dart';
import 'recipe.dart'; // For MealType

/// Represents an individual item in a meal (for multi-item meals)
class MealItem {
  final String name;
  final String category;
  final double quantity;
  final String unit;
  final int score; // 0-100 scale
  final Map<String, double> nutrition;

  const MealItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.score,
    required this.nutrition,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'score': score,
    'nutrition': nutrition,
  };

  static MealItem fromJson(Map<String, dynamic> json) => MealItem(
    name: json['name'] as String,
    category: json['category'] as String? ?? '',
    quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
    unit: json['unit'] as String? ?? 'serving',
    score: (json['score'] as num?)?.toInt() ?? 50,
    nutrition: Map<String, double>.from(
      (json['nutrition'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
    ),
  );
}

class ScanResult {
  final Product product;
  final int score; // 0-100
  final DateTime timestamp;
  final MealType? mealType; // breakfast, lunch, dinner, snack
  final List<MealItem>? mealItems; // Individual items for multi-item meals

  ScanResult({
    required this.product,
    required this.score,
    DateTime? timestamp,
    this.mealType,
    this.mealItems,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether this is a multi-item meal
  bool get isMultiItemMeal => mealItems != null && mealItems!.length > 1;

  /// Create a copy with updated fields
  ScanResult copyWith({
    Product? product,
    int? score,
    DateTime? timestamp,
    MealType? mealType,
    List<MealItem>? mealItems,
  }) {
    return ScanResult(
      product: product ?? this.product,
      score: score ?? this.score,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      mealItems: mealItems ?? this.mealItems,
    );
  }

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
        'mealItems': mealItems?.map((e) => e.toJson()).toList(),
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

    // Parse meal items if present
    List<MealItem>? mealItems;
    if (json['mealItems'] != null) {
      mealItems = (json['mealItems'] as List<dynamic>)
          .map((e) => MealItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    
    return ScanResult(
      product: product,
      score: (json['score'] as num).toInt(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      mealType: mealType,
      mealItems: mealItems,
    );
  }

  static String encodeList(List<ScanResult> items) => jsonEncode(items.map((e) => e.toJson()).toList());

  static List<ScanResult> decodeList(String encoded) {
    final arr = jsonDecode(encoded) as List<dynamic>;
    return arr.map((e) => ScanResult.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
