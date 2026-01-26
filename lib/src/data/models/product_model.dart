/// Data transfer and persistence model for a Product.
///
/// Maps JSON from Open Food Facts into a model and provides conversion
/// to the domain `Product` entity.
library;
import 'dart:developer' as developer;
import '../../domain/entities/product.dart';

class ProductModel {
	final String barcode;
	final String name;
	final String brand;
	final String? imageUrl;
	final String? ingredients;
	final Map<String, dynamic>? nutriments;
	final List<String> labels;
	final String? nutriscoreGrade; // Nutri-Score grade: a, b, c, d, e
	final String? servingSize;
	final double? servingQuantityGrams;
	final int? novaGroup; // NOVA classification: 1-4

	ProductModel({
		required this.barcode,
		required this.name,
		required this.brand,
		this.imageUrl,
		this.ingredients,
		this.nutriments,
		this.labels = const [],
		this.nutriscoreGrade,
		this.servingSize,
		this.servingQuantityGrams,
		this.novaGroup,
	});

	factory ProductModel.fromJson(Map<String, dynamic> json) {
		final product = json['product'] as Map<String, dynamic>? ?? {};
		// Extract labels_tags which contains dietary info like vegetarian, halal, etc.
		final labelsTags = (product['labels_tags'] as List<dynamic>?)
			?.map((e) => e.toString())
			.toList() ?? [];
		developer.log('[ProductModel] labels_tags: $labelsTags', name: 'ProductModel');
		// Also try 'labels' field as fallback
		if (labelsTags.isEmpty) {
			final labelsStr = product['labels'] as String?;
			if (labelsStr != null && labelsStr.isNotEmpty) {
				developer.log('[ProductModel] labels string: $labelsStr', name: 'ProductModel');
			}
		}
		// Extract Nutri-Score grade (a, b, c, d, e)
		final nutriscoreGrade = product['nutriscore_grade']?.toString().toLowerCase();
		developer.log('[ProductModel] nutriscore_grade: $nutriscoreGrade', name: 'ProductModel');
		
		// Extract NOVA group (1-4) for ultra-processing classification
		final novaGroup = _parseNovaGroup(product['nova_group']);
		developer.log('[ProductModel] nova_group: $novaGroup', name: 'ProductModel');
		
		// Extract serving size info
		final servingSize = product['serving_size']?.toString();
		final servingQuantityGrams = _parseServingQuantity(
			product['serving_quantity'],
			servingSize,
		);
		developer.log('[ProductModel] serving_size: $servingSize, quantity: $servingQuantityGrams g', name: 'ProductModel');
		
		return ProductModel(
			barcode: product['code']?.toString() ?? '',
			name: product['product_name'] ?? product['generic_name'] ?? 'Unknown',
			brand: product['brands'] ?? '',
			imageUrl: product['image_front_small_url'],
			ingredients: product['ingredients_text'],
			nutriments: product['nutriments'] as Map<String, dynamic>?,
			labels: labelsTags,
			nutriscoreGrade: nutriscoreGrade,
			servingSize: servingSize,
			servingQuantityGrams: servingQuantityGrams,
			novaGroup: novaGroup,
		);
	}

	/// Parse NOVA group from API data (1-4)
	static int? _parseNovaGroup(dynamic value) {
		if (value == null) return null;
		if (value is int) return value.clamp(1, 4);
		final parsed = int.tryParse(value.toString());
		if (parsed != null && parsed >= 1 && parsed <= 4) return parsed;
		return null;
	}

	/// Parse serving quantity in grams from API data
	static double? _parseServingQuantity(dynamic quantity, String? servingSize) {
		// Try direct quantity field first
		if (quantity != null) {
			if (quantity is num) return quantity.toDouble();
			final parsed = double.tryParse(quantity.toString());
			if (parsed != null) return parsed;
		}
		
		// Try to extract grams from serving_size string like "150g" or "1 cup (150g)"
		if (servingSize != null) {
			// Match patterns like "150g", "150 g", "(150g)", "150gr"
			final regex = RegExp(r'(\d+(?:\.\d+)?)\s*(?:g|gr|grams?)(?:\b|$)', caseSensitive: false);
			final match = regex.firstMatch(servingSize);
			if (match != null) {
				return double.tryParse(match.group(1)!);
			}
			
			// Match ml for liquids (approximate 1ml = 1g for water-based)
			final mlRegex = RegExp(r'(\d+(?:\.\d+)?)\s*ml', caseSensitive: false);
			final mlMatch = mlRegex.firstMatch(servingSize);
			if (mlMatch != null) {
				return double.tryParse(mlMatch.group(1)!);
			}
		}
		
		return null;
	}

	Product toEntity() {
		return Product(
			barcode: barcode,
			name: name,
			brand: brand,
			imageUrl: imageUrl,
			ingredients: ingredients,
			nutriments: nutriments ?? {},
			labels: labels,
			nutriscoreGrade: nutriscoreGrade,
			servingSize: servingSize,
			servingQuantityGrams: servingQuantityGrams,
			novaGroup: novaGroup,
		);
	}
}
