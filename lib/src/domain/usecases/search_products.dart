/// Use case: search products by query or barcode prefix.
///
/// Responsibilities:
/// - Accept query parameters and return a list of domain `Product`
import '../entities/product.dart';
import '../repositories/product_repository.dart';

class SearchProducts {
  final ProductRepository _repo;
  SearchProducts(this._repo);

  Future<List<Product>> call(String query) => _repo.searchProducts(query);
}
