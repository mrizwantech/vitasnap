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
	/// Labels/certifications like vegetarian, vegan, halal, kosher, etc.
	final List<String> labels;
	/// Nutri-Score grade from OpenFoodFacts: a, b, c, d, e (or null if not available)
	final String? nutriscoreGrade;
	/// Serving size text (e.g., "1 cup (150g)", "30g")
	final String? servingSize;
	/// Serving quantity in grams (parsed from servingSize)
	final double? servingQuantityGrams;

	Product({
		required this.barcode,
		required this.name,
		required this.brand,
		this.imageUrl,
		this.ingredients,
		this.nutriments = const {},
		this.labels = const [],
		this.nutriscoreGrade,
		this.servingSize,
		this.servingQuantityGrams,
	});

	/// Get numeric health score from Nutri-Score grade
	/// A=100, B=75, C=50, D=25, E=0
	/// Returns 50 if grade is unknown
	int get nutriScoreValue {
		switch (nutriscoreGrade?.toLowerCase()) {
			case 'a':
				return 100;
			case 'b':
				return 75;
			case 'c':
				return 50;
			case 'd':
				return 25;
			case 'e':
				return 0;
			default:
				return 50; // Unknown/not available
		}
	}
}
