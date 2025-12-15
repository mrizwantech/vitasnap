/// Implementation of `ProductRepository` using remote data sources.
///
/// Coordinates network calls, maps DTOs to domain entities.
library;
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/open_food_facts_api.dart';
import '../models/product_model.dart';

class ProductRepositoryImpl implements ProductRepository {
	final OpenFoodFactsApi api;
	ProductRepositoryImpl(this.api);

	@override
	Future<Product> getProductByBarcode(String barcode) async {
		final json = await api.fetchProductByBarcode(barcode);
		final status = json['status'] ?? 0;
		if (status == 0) {
			throw Exception('Product not found');
		}
		final model = ProductModel.fromJson(json);
		return model.toEntity();
	}
}
/// - Implement caching strategies if needed
