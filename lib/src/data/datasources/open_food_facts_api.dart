/// Remote data source for Open Food Facts API.
///
/// Minimal implementation: fetch product by barcode using
/// `https://world.openfoodfacts.org/api/v0/product/<barcode>.json`.
library;
import 'dart:async';
import 'dart:developer' as developer;

import '../../core/network/network_service.dart';

class OpenFoodFactsApi {
	final NetworkService _network;
	OpenFoodFactsApi(this._network);

	Future<Map<String, dynamic>> fetchProductByBarcode(String barcode) async {
		final uri = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
		developer.log('[OpenFoodFactsApi] fetching $uri', name: 'OpenFoodFactsApi');
		final json = await _network.getJson(uri);
		developer.log('[OpenFoodFactsApi] received keys: ${json.keys.toList()}', name: 'OpenFoodFactsApi');
		return json;
	}
}
