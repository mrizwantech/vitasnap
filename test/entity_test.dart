// Unit tests for VitaSnap core entities
//
// Note: Full widget tests require Firebase mocking which is complex.
// These are simple unit tests for core domain entities.

import 'package:flutter_test/flutter_test.dart';
import 'package:vitasnap/src/domain/entities/product.dart';
import 'package:vitasnap/src/domain/entities/scan_result.dart';
import 'package:vitasnap/src/domain/entities/recipe.dart';

void main() {
  group('Product Entity', () {
    test('creates product with required fields', () {
      final product = Product(
        barcode: '123456789',
        name: 'Test Product',
        brand: 'Test Brand',
        nutriments: {'energy-kcal_100g': 100.0},
      );

      expect(product.barcode, '123456789');
      expect(product.name, 'Test Product');
      expect(product.brand, 'Test Brand');
      expect(product.nutriments['energy-kcal_100g'], 100.0);
    });

    test('nutriScoreValue returns correct values', () {
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}, nutriscoreGrade: 'a').nutriScoreValue,
        100,
      );
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}, nutriscoreGrade: 'b').nutriScoreValue,
        75,
      );
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}, nutriscoreGrade: 'c').nutriScoreValue,
        50,
      );
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}, nutriscoreGrade: 'd').nutriScoreValue,
        25,
      );
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}, nutriscoreGrade: 'e').nutriScoreValue,
        0,
      );
      expect(
        Product(barcode: '1', name: 'A', brand: 'B', nutriments: {}).nutriScoreValue,
        50, // Default when null
      );
    });
  });

  group('ScanResult Entity', () {
    test('creates scan result with product and score', () {
      final product = Product(
        barcode: '123',
        name: 'Test',
        brand: 'Brand',
        nutriments: {},
      );
      final scan = ScanResult(
        product: product,
        score: 75,
        mealType: MealType.lunch,
      );

      expect(scan.product.name, 'Test');
      expect(scan.score, 75);
      expect(scan.mealType, MealType.lunch);
      expect(scan.timestamp, isNotNull);
    });

    test('encodeList and decodeList work correctly', () {
      final product = Product(
        barcode: '123',
        name: 'Test',
        brand: 'Brand',
        nutriments: {},
      );
      final scans = [
        ScanResult(product: product, score: 80, timestamp: DateTime(2024, 1, 1)),
        ScanResult(product: product, score: 60, timestamp: DateTime(2024, 1, 2)),
      ];

      final encoded = ScanResult.encodeList(scans);
      final decoded = ScanResult.decodeList(encoded);

      expect(decoded.length, 2);
      expect(decoded[0].score, 80);
      expect(decoded[1].score, 60);
    });
  });

  group('MealType', () {
    test('has correct display names', () {
      expect(MealType.breakfast.displayName, 'Breakfast');
      expect(MealType.lunch.displayName, 'Lunch');
      expect(MealType.dinner.displayName, 'Dinner');
      expect(MealType.snack.displayName, 'Snack');
    });

    test('has emojis', () {
      expect(MealType.breakfast.emoji, isNotEmpty);
      expect(MealType.lunch.emoji, isNotEmpty);
      expect(MealType.dinner.emoji, isNotEmpty);
      expect(MealType.snack.emoji, isNotEmpty);
    });
  });

  group('Recipe Entity', () {
    test('creates recipe with ingredients', () {
      final ingredients = [
        RecipeIngredient(
          id: '1',
          name: 'Egg',
          iconEmoji: '🥚',
          quantity: 2,
          unit: IngredientUnit.piece,
          category: 'protein',
          nutriments: {
            'energy-kcal_100g': 155.0,
            'proteins_100g': 13.0,
            'fat_100g': 11.0,
            'carbohydrates_100g': 1.0,
          },
        ),
      ];

      final recipe = Recipe(
        id: 'test',
        name: 'Test Recipe',
        ingredients: ingredients,
        mealType: MealType.breakfast,
        createdAt: DateTime.now(),
      );

      expect(recipe.ingredients.length, 1);
      expect(recipe.ingredients.first.name, 'Egg');
      expect(recipe.mealType, MealType.breakfast);
    });
  });
}
