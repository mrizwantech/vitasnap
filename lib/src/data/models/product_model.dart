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

	ProductModel({
		required this.barcode,
		required this.name,
		required this.brand,
		this.imageUrl,
		this.ingredients,
		this.nutriments,
		this.labels = const [],
		this.nutriscoreGrade,
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
		
		return ProductModel(
			barcode: product['code']?.toString() ?? '',
			name: product['product_name'] ?? product['generic_name'] ?? 'Unknown',
			brand: product['brands'] ?? '',
			imageUrl: product['image_front_small_url'],
			ingredients: product['ingredients_text'],
			nutriments: product['nutriments'] as Map<String, dynamic>?,
			labels: labelsTags,
			nutriscoreGrade: nutriscoreGrade,
		);
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
		);
	}
}
