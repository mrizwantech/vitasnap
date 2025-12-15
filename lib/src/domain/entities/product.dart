/// Domain entity representing a Product.
///
/// Holds only core business data needed by the app and no framework concerns.
class Product {
	final String barcode;
	final String name;
	final String brand;
	final String? imageUrl;
	final String? ingredients;
	final Map<String, dynamic> nutriments;

	Product({
		required this.barcode,
		required this.name,
		required this.brand,
		this.imageUrl,
		this.ingredients,
		this.nutriments = const {},
	});
}
