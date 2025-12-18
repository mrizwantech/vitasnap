import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dietary_preferences_service.dart';

/// Service to manage cloud sync with Firebase Firestore
class CloudSyncService extends ChangeNotifier {
  static const _kCloudSyncEnabled = 'cloud_sync_enabled';
  static const _kLastSyncTime = 'last_sync_time';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SharedPreferences _prefs;
  
  bool _isEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _userId;

  CloudSyncService(this._prefs) {
    _loadSettings();
  }

  bool get isEnabled => _isEnabled;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  void setUserId(String? userId) {
    _userId = userId;
    _loadSettings();
  }

  String get _syncEnabledKey => _userId != null 
      ? '${_kCloudSyncEnabled}_$_userId' 
      : _kCloudSyncEnabled;

  String get _lastSyncKey => _userId != null 
      ? '${_kLastSyncTime}_$_userId' 
      : _kLastSyncTime;

  void _loadSettings() {
    _isEnabled = _prefs.getBool(_syncEnabledKey) ?? false;
    final lastSyncMs = _prefs.getInt(_lastSyncKey);
    _lastSyncTime = lastSyncMs != null 
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs) 
        : null;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _prefs.setBool(_syncEnabledKey, enabled);
    notifyListeners();
    
    // If enabling, do an initial sync
    if (enabled && _userId != null) {
      await syncToCloud();
    }
  }

  /// Get the Firestore document reference for the current user
  DocumentReference? get _userDoc {
    if (_userId == null) return null;
    return _firestore.collection('users').doc(_userId);
  }

  /// Sync scan history to cloud
  Future<void> syncScanHistory(List<Map<String, dynamic>> scanHistory) async {
    if (!_isEnabled || _userId == null) return;
    
    try {
      await _userDoc?.set({
        'scanHistory': scanHistory,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing scan history: $e');
    }
  }

  /// Sync dietary preferences to cloud
  Future<void> syncDietaryPreferences(Set<DietaryRestriction> restrictions) async {
    if (!_isEnabled || _userId == null) return;
    
    try {
      await _userDoc?.set({
        'dietaryPreferences': restrictions.map((r) => r.name).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error syncing dietary preferences: $e');
    }
  }

  /// Sync all data to cloud
  Future<void> syncToCloud({
    List<Map<String, dynamic>>? scanHistory,
    Set<DietaryRestriction>? dietaryPreferences,
  }) async {
    if (!_isEnabled || _userId == null) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (scanHistory != null) {
        data['scanHistory'] = scanHistory;
      }

      if (dietaryPreferences != null) {
        data['dietaryPreferences'] = dietaryPreferences.map((r) => r.name).toList();
      }

      if (data.length > 1) {
        await _userDoc?.set(data, SetOptions(merge: true));
      }

      _lastSyncTime = DateTime.now();
      await _prefs.setInt(_lastSyncKey, _lastSyncTime!.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error syncing to cloud: $e');
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Fetch data from cloud
  Future<Map<String, dynamic>?> fetchFromCloud() async {
    if (!_isEnabled || _userId == null) return null;
    
    _isSyncing = true;
    notifyListeners();

    try {
      final doc = await _userDoc?.get();
      if (doc != null && doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching from cloud: $e');
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Delete all cloud data for current user
  Future<void> deleteCloudData() async {
    if (_userId == null) return;
    
    try {
      await _userDoc?.delete();
      _lastSyncTime = null;
      await _prefs.remove(_lastSyncKey);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting cloud data: $e');
    }
  }

  /// Format last sync time for display
  String get lastSyncDisplay {
    if (_lastSyncTime == null) return 'Never';
    
    final now = DateTime.now();
    final diff = now.difference(_lastSyncTime!);
    
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    
    return '${_lastSyncTime!.month}/${_lastSyncTime!.day}/${_lastSyncTime!.year}';
  }
}
