/// Abstract repository for product-related domain operations.
library;
import '../entities/product.dart';

abstract class ProductRepository {
	Future<Product> getProductByBarcode(String barcode);
}
