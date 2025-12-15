/// ViewModel for scanning flows (MVVM).
///
library;
import 'package:flutter/foundation.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_product_by_barcode.dart';

class ScanViewModel extends ChangeNotifier {
	final GetProductByBarcode _getProduct;
	ScanViewModel(this._getProduct);

	bool _loading = false;
	bool get loading => _loading;

	Product? _product;
	Product? get product => _product;

	String? _error;
	String? get error => _error;

	Future<void> fetchByBarcode(String barcode) async {
		_loading = true;
		_error = null;
		notifyListeners();
		try {
			final p = await _getProduct(barcode);
			_product = p;
		} catch (e) {
			_error = e.toString();
			_product = null;
		} finally {
			_loading = false;
			notifyListeners();
		}
	}
}
