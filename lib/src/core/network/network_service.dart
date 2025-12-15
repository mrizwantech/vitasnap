/// Responsible for making HTTP requests and handling common network concerns.
///
/// Provides a tiny wrapper around the `http` package exposing `getJson`.
/// Keep this small so it can be replaced or extended for tests.
library;
import 'dart:convert';

import 'package:http/http.dart' as http;

class NetworkService {
	final http.Client _client;
	NetworkService({http.Client? client}) : _client = client ?? http.Client();

	Future<Map<String, dynamic>> getJson(Uri uri) async {
		final resp = await _client.get(uri).timeout(const Duration(seconds: 15));
		if (resp.statusCode >= 200 && resp.statusCode < 300) {
			return json.decode(resp.body) as Map<String, dynamic>;
		}
		throw Exception('Network request failed (${resp.statusCode})');
	}
}
