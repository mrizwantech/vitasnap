import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Meal types for reminders
enum MealReminderType {
  breakfast,
  lunch,
  dinner;

  String get displayName {
    switch (this) {
      case MealReminderType.breakfast:
        return 'Breakfast';
      case MealReminderType.lunch:
        return 'Lunch';
      case MealReminderType.dinner:
        return 'Dinner';
    }
  }

  String get emoji {
    switch (this) {
      case MealReminderType.breakfast:
        return '🍳';
      case MealReminderType.lunch:
        return '🥗';
      case MealReminderType.dinner:
        return '🍽️';
    }
  }

  int get notificationId {
    switch (this) {
      case MealReminderType.breakfast:
        return 1;
      case MealReminderType.lunch:
        return 2;
      case MealReminderType.dinner:
        return 3;
    }
  }
}

/// Service to manage meal reminder notifications
/// Schedules one notification at a time - after each notification fires,
/// schedules the next one
class MealReminderService extends ChangeNotifier {
  static const String _enabledKey = 'meal_reminders_enabled';
  static const String _breakfastHourKey = 'breakfast_reminder_hour';
  static const String _breakfastMinuteKey = 'breakfast_reminder_minute';
  static const String _lunchHourKey = 'lunch_reminder_hour';
  static const String _lunchMinuteKey = 'lunch_reminder_minute';
  static const String _dinnerHourKey = 'dinner_reminder_hour';
  static const String _dinnerMinuteKey = 'dinner_reminder_minute';
  static const String _lastScheduledMealKey = 'last_scheduled_meal';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isEnabled = false;
  bool _isInitialized = false;
  
  // Callback for when notification is tapped - set by the app to navigate
  static void Function()? onNotificationTapped;

  // Default times
  int _breakfastHour = 7;
  int _breakfastMinute = 0;
  int _lunchHour = 12;
  int _lunchMinute = 0;
  int _dinnerHour = 19;
  int _dinnerMinute = 0;

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isInitialized => _isInitialized;

  int get breakfastHour => _breakfastHour;
  int get breakfastMinute => _breakfastMinute;
  int get lunchHour => _lunchHour;
  int get lunchMinute => _lunchMinute;
  int get dinnerHour => _dinnerHour;
  int get dinnerMinute => _dinnerMinute;

  String get breakfastTimeDisplay =>
      _formatTime(_breakfastHour, _breakfastMinute);
  String get lunchTimeDisplay => _formatTime(_lunchHour, _lunchMinute);
  String get dinnerTimeDisplay => _formatTime(_dinnerHour, _dinnerMinute);

  String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz_data.initializeTimeZones();

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings(
        '@drawable/ic_notification',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Check if app was launched from notification
      final launchDetails = await _notifications.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        // App was launched from notification - trigger callback after a delay
        // to allow the app to fully initialize
        Future.delayed(const Duration(milliseconds: 500), () {
          if (onNotificationTapped != null) {
            onNotificationTapped!();
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }

    // Load saved preferences
    await _loadPreferences();
    _isInitialized = true;

    // If enabled, schedule the next reminder
    if (_isEnabled) {
      try {
        await scheduleNextReminder();
      } catch (e) {
        debugPrint('Error scheduling reminder: $e');
      }
    }

    notifyListeners();
  }

  /// Called when a notification is tapped
  void _onNotificationTapped(NotificationResponse response) {
    // Schedule the next reminder when notification is interacted with
    scheduleNextReminder();
    
    // Call the navigation callback if set
    if (onNotificationTapped != null) {
      onNotificationTapped!();
    }
  }

  /// Load preferences from storage
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    _isEnabled = prefs.getBool(_enabledKey) ?? false;
    _breakfastHour = prefs.getInt(_breakfastHourKey) ?? 7;
    _breakfastMinute = prefs.getInt(_breakfastMinuteKey) ?? 0;
    _lunchHour = prefs.getInt(_lunchHourKey) ?? 12;
    _lunchMinute = prefs.getInt(_lunchMinuteKey) ?? 0;
    _dinnerHour = prefs.getInt(_dinnerHourKey) ?? 19;
    _dinnerMinute = prefs.getInt(_dinnerMinuteKey) ?? 0;
  }

  /// Save preferences to storage
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, _isEnabled);
    await prefs.setInt(_breakfastHourKey, _breakfastHour);
    await prefs.setInt(_breakfastMinuteKey, _breakfastMinute);
    await prefs.setInt(_lunchHourKey, _lunchHour);
    await prefs.setInt(_lunchMinuteKey, _lunchMinute);
    await prefs.setInt(_dinnerHourKey, _dinnerHour);
    await prefs.setInt(_dinnerMinuteKey, _dinnerMinute);
  }

  /// Enable or disable reminders
  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;

    _isEnabled = enabled;
    await _savePreferences();

    if (enabled) {
      // Request permission on Android 13+
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        await androidPlugin?.requestNotificationsPermission();
      }
      await scheduleNextReminder();
    } else {
      await cancelAllReminders();
    }

    notifyListeners();
  }

  /// Update breakfast time
  Future<void> setBreakfastTime(int hour, int minute) async {
    _breakfastHour = hour;
    _breakfastMinute = minute;
    await _savePreferences();

    if (_isEnabled) {
      await scheduleNextReminder();
    }

    notifyListeners();
  }

  /// Update lunch time
  Future<void> setLunchTime(int hour, int minute) async {
    _lunchHour = hour;
    _lunchMinute = minute;
    await _savePreferences();

    if (_isEnabled) {
      await scheduleNextReminder();
    }

    notifyListeners();
  }

  /// Update dinner time
  Future<void> setDinnerTime(int hour, int minute) async {
    _dinnerHour = hour;
    _dinnerMinute = minute;
    await _savePreferences();

    if (_isEnabled) {
      await scheduleNextReminder();
    }

    notifyListeners();
  }

  /// Get the next meal reminder to schedule
  MealReminderType? getNextMealType() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final breakfastMinutes = _breakfastHour * 60 + _breakfastMinute;
    final lunchMinutes = _lunchHour * 60 + _lunchMinute;
    final dinnerMinutes = _dinnerHour * 60 + _dinnerMinute;

    // Find the next meal that hasn't passed yet today
    if (currentMinutes < breakfastMinutes) {
      return MealReminderType.breakfast;
    } else if (currentMinutes < lunchMinutes) {
      return MealReminderType.lunch;
    } else if (currentMinutes < dinnerMinutes) {
      return MealReminderType.dinner;
    } else {
      // All meals passed today, schedule breakfast for tomorrow
      return MealReminderType.breakfast;
    }
  }

  /// Get the DateTime for the next reminder
  DateTime getNextReminderTime(MealReminderType mealType) {
    final now = DateTime.now();
    int hour, minute;

    switch (mealType) {
      case MealReminderType.breakfast:
        hour = _breakfastHour;
        minute = _breakfastMinute;
        break;
      case MealReminderType.lunch:
        hour = _lunchHour;
        minute = _lunchMinute;
        break;
      case MealReminderType.dinner:
        hour = _dinnerHour;
        minute = _dinnerMinute;
        break;
    }

    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Schedule the next meal reminder
  Future<void> scheduleNextReminder() async {
    if (!_isEnabled) return;

    // Cancel any existing notifications first
    await cancelAllReminders();

    final nextMeal = getNextMealType();
    if (nextMeal == null) return;

    final scheduledTime = getNextReminderTime(nextMeal);
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

    // Create notification details with VitaSnap branding
    const androidDetails = AndroidNotificationDetails(
      'meal_reminders',
      'Meal Reminders',
      channelDescription: 'Reminders to log your meals in VitaSnap',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      ticker: 'VitaSnap Meal Reminder',
      subText: 'VitaSnap',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      subtitle: 'VitaSnap',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule the notification
    await _notifications.zonedSchedule(
      nextMeal.notificationId,
      'VitaSnap ${nextMeal.emoji} ${nextMeal.displayName} Reminder',
      'Time to log your ${nextMeal.displayName.toLowerCase()}! Stay on track with your nutrition goals.',
      tzScheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // Save which meal we scheduled
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastScheduledMealKey, nextMeal.name);

    debugPrint('Scheduled ${nextMeal.displayName} reminder for $scheduledTime');
  }

  /// Cancel all pending reminders
  Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
  }

  /// Send a test notification immediately
  Future<bool> sendTestNotification() async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'meal_reminders',
        'Meal Reminders',
        channelDescription: 'Reminders to log your meals in VitaSnap',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_notification',
        ticker: 'VitaSnap Notification',
        subText: 'VitaSnap',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: 'VitaSnap',
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        999, // Test notification ID
        'VitaSnap 🔔 Test Notification',
        'Notifications are working! You\'ll receive meal reminders to help track your nutrition.',
        details,
      );
      return true;
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      return false;
    }
  }

  /// Called when the app comes to foreground to reschedule if needed
  Future<void> onAppResumed() async {
    if (_isEnabled) {
      await scheduleNextReminder();
    }
  }
}
