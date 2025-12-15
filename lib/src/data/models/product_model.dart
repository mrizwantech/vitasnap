/// Data transfer and persistence model for a Product.
///
/// Maps JSON from Open Food Facts into a model and provides conversion
/// to the domain `Product` entity.
library;
import '../../domain/entities/product.dart';

class ProductModel {
	final String barcode;
	final String name;
	final String brand;
	final String? imageUrl;
	final String? ingredients;
	final Map<String, dynamic>? nutriments;

	ProductModel({
		required this.barcode,
		required this.name,
		required this.brand,
		this.imageUrl,
		this.ingredients,
		this.nutriments,
	});

	factory ProductModel.fromJson(Map<String, dynamic> json) {
		final product = json['product'] as Map<String, dynamic>? ?? {};
		return ProductModel(
			barcode: product['code']?.toString() ?? '',
			name: product['product_name'] ?? product['generic_name'] ?? 'Unknown',
			brand: product['brands'] ?? '',
			imageUrl: product['image_front_small_url'],
			ingredients: product['ingredients_text'],
			nutriments: product['nutriments'] as Map<String, dynamic>?,
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
		);
	}
}
