import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/scan_result.dart';

/// Service to manage favorite products
class FavoritesService extends ChangeNotifier {
  static const _kFavoritesKey = 'favorites';
  
  final SharedPreferences _prefs;
  List<ScanResult> _favorites = [];

  FavoritesService(this._prefs) {
    _loadFavorites();
  }

  List<ScanResult> get favorites => List.unmodifiable(_favorites);

  /// Check if a product is favorited by barcode
  bool isFavorite(String barcode) {
    return _favorites.any((f) => f.product.barcode == barcode);
  }

  /// Toggle favorite status for a scan result
  Future<void> toggleFavorite(ScanResult scanResult) async {
    final barcode = scanResult.product.barcode;
    
    if (isFavorite(barcode)) {
      _favorites.removeWhere((f) => f.product.barcode == barcode);
    } else {
      _favorites.insert(0, scanResult);
    }
    
    await _saveFavorites();
    notifyListeners();
  }

  /// Add to favorites if not already there
  Future<void> addFavorite(ScanResult scanResult) async {
    if (!isFavorite(scanResult.product.barcode)) {
      _favorites.insert(0, scanResult);
      await _saveFavorites();
      notifyListeners();
    }
  }

  /// Remove from favorites
  Future<void> removeFavorite(String barcode) async {
    _favorites.removeWhere((f) => f.product.barcode == barcode);
    await _saveFavorites();
    notifyListeners();
  }

  /// Clear all favorites
  Future<void> clearFavorites() async {
    _favorites.clear();
    await _saveFavorites();
    notifyListeners();
  }

  void _loadFavorites() {
    final encoded = _prefs.getString(_kFavoritesKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        _favorites = ScanResult.decodeList(encoded);
      } catch (e) {
        debugPrint('Error loading favorites: $e');
        _favorites = [];
      }
    }
  }

  Future<void> _saveFavorites() async {
    final encoded = ScanResult.encodeList(_favorites);
    await _prefs.setString(_kFavoritesKey, encoded);
  }
}
