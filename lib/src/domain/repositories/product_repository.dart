/// Abstract repository for product-related domain operations.
library;
import '../entities/product.dart';

abstract class ProductRepository {
	Future<Product> getProductByBarcode(String barcode);
	
	/// Search products by name/text query.
	Future<List<Product>> searchProducts(String query);
}
