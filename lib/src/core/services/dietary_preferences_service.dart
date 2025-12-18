import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_service.dart';

/// Dietary restriction/preference types
enum DietaryRestriction {
  vegan,
  vegetarian,
  halal,
  kosher,
  glutenFree,
  dairyFree,
  nutFree,
  soyFree,
  eggFree,
  shellfishFree,
  lowSodium,
  lowSugar,
}

/// Extension for display names and icons
extension DietaryRestrictionX on DietaryRestriction {
  String get displayName {
    switch (this) {
      case DietaryRestriction.vegan:
        return 'Vegan';
      case DietaryRestriction.vegetarian:
        return 'Vegetarian';
      case DietaryRestriction.halal:
        return 'Halal';
      case DietaryRestriction.kosher:
        return 'Kosher';
      case DietaryRestriction.glutenFree:
        return 'Gluten-Free';
      case DietaryRestriction.dairyFree:
        return 'Dairy-Free';
      case DietaryRestriction.nutFree:
        return 'Nut-Free';
      case DietaryRestriction.soyFree:
        return 'Soy-Free';
      case DietaryRestriction.eggFree:
        return 'Egg-Free';
      case DietaryRestriction.shellfishFree:
        return 'Shellfish-Free';
      case DietaryRestriction.lowSodium:
        return 'Low Sodium';
      case DietaryRestriction.lowSugar:
        return 'Low Sugar';
    }
  }

  IconData get icon {
    switch (this) {
      case DietaryRestriction.vegan:
        return Icons.eco;
      case DietaryRestriction.vegetarian:
        return Icons.grass;
      case DietaryRestriction.halal:
        return Icons.verified;
      case DietaryRestriction.kosher:
        return Icons.star_outline;
      case DietaryRestriction.glutenFree:
        return Icons.no_food;
      case DietaryRestriction.dairyFree:
        return Icons.water_drop_outlined;
      case DietaryRestriction.nutFree:
        return Icons.dangerous_outlined;
      case DietaryRestriction.soyFree:
        return Icons.block;
      case DietaryRestriction.eggFree:
        return Icons.egg_outlined;
      case DietaryRestriction.shellfishFree:
        return Icons.set_meal_outlined;
      case DietaryRestriction.lowSodium:
        return Icons.opacity;
      case DietaryRestriction.lowSugar:
        return Icons.icecream_outlined;
    }
  }

  String get category {
    switch (this) {
      case DietaryRestriction.vegan:
      case DietaryRestriction.vegetarian:
      case DietaryRestriction.halal:
      case DietaryRestriction.kosher:
        return 'Diet Type';
      case DietaryRestriction.glutenFree:
      case DietaryRestriction.dairyFree:
      case DietaryRestriction.nutFree:
      case DietaryRestriction.soyFree:
      case DietaryRestriction.eggFree:
      case DietaryRestriction.shellfishFree:
        return 'Allergies & Intolerances';
      case DietaryRestriction.lowSodium:
      case DietaryRestriction.lowSugar:
        return 'Health Goals';
    }
  }
}

/// Service to manage dietary preferences
class DietaryPreferencesService extends ChangeNotifier {
  static const _kPreferencesPrefix = 'dietary_preferences_';
  final SharedPreferences _prefs;
  String? _userId;
  CloudSyncService? _cloudSyncService;

  Set<DietaryRestriction> _selectedRestrictions = {};

  DietaryPreferencesService(this._prefs);

  /// Set the cloud sync service for auto-syncing preferences
  void setCloudSyncService(CloudSyncService service) {
    _cloudSyncService = service;
  }

  String get _storageKey => _userId != null ? '$_kPreferencesPrefix$_userId' : '${_kPreferencesPrefix}anonymous';

  /// Set the current user ID and reload preferences for that user
  void setUserId(String? userId) {
    _userId = userId;
    _loadPreferences();
  }

  Set<DietaryRestriction> get selectedRestrictions =>
      Set.unmodifiable(_selectedRestrictions);

  bool isSelected(DietaryRestriction restriction) =>
      _selectedRestrictions.contains(restriction);

  void _loadPreferences() {
    final stored = _prefs.getString(_storageKey);
    if (stored != null) {
      try {
        final List<dynamic> decoded = jsonDecode(stored);
        _selectedRestrictions = decoded
            .map((name) => DietaryRestriction.values.firstWhere(
                  (e) => e.name == name,
                ))
            .toSet();
      } catch (_) {
        _selectedRestrictions = {};
      }
    } else {
      _selectedRestrictions = {};
    }
    notifyListeners();
  }

  Future<void> _savePreferences() async {
    final encoded = jsonEncode(
      _selectedRestrictions.map((e) => e.name).toList(),
    );
    await _prefs.setString(_storageKey, encoded);
    // Auto-sync to cloud if enabled
    _syncToCloudIfEnabled();
  }

  Future<void> _syncToCloudIfEnabled() async {
    if (_cloudSyncService == null || !_cloudSyncService!.isEnabled) return;
    await _cloudSyncService!.syncDietaryPreferences(_selectedRestrictions);
  }

  Future<void> toggleRestriction(DietaryRestriction restriction) async {
    if (_selectedRestrictions.contains(restriction)) {
      _selectedRestrictions.remove(restriction);
    } else {
      _selectedRestrictions.add(restriction);
    }
    await _savePreferences();
    notifyListeners();
  }

  Future<void> setRestrictions(Set<DietaryRestriction> restrictions) async {
    _selectedRestrictions = Set.from(restrictions);
    await _savePreferences();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _selectedRestrictions.clear();
    await _savePreferences();
    notifyListeners();
  }

  /// Check if a product matches user's dietary preferences
  /// Returns a record with matches and violations
  ({List<DietaryRestriction> matches, List<DietaryRestriction> violations}) checkProduct({
    required List<String> productLabels,
    required List<String>? allergens,
    required String? ingredients,
  }) {
    final matches = <DietaryRestriction>[];
    final violations = <DietaryRestriction>[];
    final labelsLower = productLabels.map((l) => l.toLowerCase()).toList();
    final allergensLower =
        allergens?.map((a) => a.toLowerCase()).toList() ?? [];
    final ingredientsLower = ingredients?.toLowerCase() ?? '';

    for (final restriction in _selectedRestrictions) {
      bool violated = false;

      switch (restriction) {
        case DietaryRestriction.vegan:
          violated = !labelsLower.any((l) => l.contains('vegan'));
          break;
        case DietaryRestriction.vegetarian:
          violated = !labelsLower.any((l) => l.contains('vegetarian'));
          break;
        case DietaryRestriction.halal:
          violated = !labelsLower.any((l) => l.contains('halal'));
          break;
        case DietaryRestriction.kosher:
          violated = !labelsLower.any((l) => l.contains('kosher'));
          break;
        case DietaryRestriction.glutenFree:
          violated = allergensLower.any((a) =>
                  a.contains('gluten') || a.contains('wheat')) ||
              ingredientsLower.contains('wheat') ||
              ingredientsLower.contains('gluten');
          break;
        case DietaryRestriction.dairyFree:
          violated = allergensLower.any((a) =>
                  a.contains('milk') || a.contains('dairy')) ||
              ingredientsLower.contains('milk') ||
              ingredientsLower.contains('dairy') ||
              ingredientsLower.contains('lactose');
          break;
        case DietaryRestriction.nutFree:
          violated = allergensLower.any((a) =>
                  a.contains('nut') || a.contains('peanut')) ||
              ingredientsLower.contains('nut') ||
              ingredientsLower.contains('almond') ||
              ingredientsLower.contains('peanut');
          break;
        case DietaryRestriction.soyFree:
          violated =
              allergensLower.any((a) => a.contains('soy')) ||
                  ingredientsLower.contains('soy');
          break;
        case DietaryRestriction.eggFree:
          violated =
              allergensLower.any((a) => a.contains('egg')) ||
                  ingredientsLower.contains('egg');
          break;
        case DietaryRestriction.shellfishFree:
          violated = allergensLower.any((a) =>
                  a.contains('shellfish') || a.contains('crustacean')) ||
              ingredientsLower.contains('shrimp') ||
              ingredientsLower.contains('crab') ||
              ingredientsLower.contains('lobster');
          break;
        case DietaryRestriction.lowSodium:
        case DietaryRestriction.lowSugar:
          // These need nutritional data, skip for now
          break;
      }

      if (violated) {
        violations.add(restriction);
      } else {
        matches.add(restriction);
      }
    }

    return (matches: matches, violations: violations);
  }
}
