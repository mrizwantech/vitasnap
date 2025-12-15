/// Use case: fetch a product by barcode.
///
library;
import '../repositories/product_repository.dart';
import '../entities/product.dart';

class GetProductByBarcode {
	final ProductRepository repository;
	GetProductByBarcode(this.repository);

	Future<Product> call(String barcode) async {
		return repository.getProductByBarcode(barcode);
	}
}
