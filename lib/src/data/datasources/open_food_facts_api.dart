/// Remote data source for Open Food Facts API.
///
/// Minimal implementation: fetch product by barcode using
/// `https://world.openfoodfacts.org/api/v0/product/<barcode>.json`.
library;
import 'dart:async';

import '../../core/network/network_service.dart';

class OpenFoodFactsApi {
	final NetworkService _network;
	OpenFoodFactsApi(this._network);

	Future<Map<String, dynamic>> fetchProductByBarcode(String barcode) async {
		final uri = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
		final json = await _network.getJson(uri);
		return json;
	}
}
