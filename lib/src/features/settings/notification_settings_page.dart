import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/meal_reminder_service.dart';
import '../../presentation/widgets/vitasnap_logo.dart';

/// Page to configure meal reminder notification times
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  @override
  void initState() {
    super.initState();
    // Initialize the service when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MealReminderService>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF1B8A4E);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: false),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: Consumer<MealReminderService>(
        builder: (context, reminderService, child) {
          // Show loading while initializing
          if (!reminderService.isInitialized) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        color: primaryColor,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Meal Reminders',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get reminded to log your meals',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Enable/Disable toggle
                _SettingsCard(
                  isDark: isDark,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Enable Meal Reminders',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      reminderService.isEnabled
                          ? 'You\'ll receive reminders for each meal'
                          : 'Turn on to get meal reminders',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    value: reminderService.isEnabled,
                    activeThumbColor: primaryColor,
                    onChanged: (value) async {
                      await reminderService.setEnabled(value);
                      if (value && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Meal reminders enabled! 🔔'),
                            backgroundColor: primaryColor,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Meal times section
                Text(
                  'Reminder Times',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to adjust when you\'d like to be reminded',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 16),

                // Breakfast time
                _MealTimeCard(
                  isDark: isDark,
                  emoji: '🍳',
                  mealName: 'Breakfast',
                  currentTime: reminderService.breakfastTimeDisplay,
                  isEnabled: reminderService.isEnabled,
                  onTap: () => _showTimePicker(
                    context,
                    reminderService,
                    MealReminderType.breakfast,
                    reminderService.breakfastHour,
                    reminderService.breakfastMinute,
                  ),
                ),
                const SizedBox(height: 12),

                // Lunch time
                _MealTimeCard(
                  isDark: isDark,
                  emoji: '🥗',
                  mealName: 'Lunch',
                  currentTime: reminderService.lunchTimeDisplay,
                  isEnabled: reminderService.isEnabled,
                  onTap: () => _showTimePicker(
                    context,
                    reminderService,
                    MealReminderType.lunch,
                    reminderService.lunchHour,
                    reminderService.lunchMinute,
                  ),
                ),
                const SizedBox(height: 12),

                // Dinner time
                _MealTimeCard(
                  isDark: isDark,
                  emoji: '🍽️',
                  mealName: 'Dinner',
                  currentTime: reminderService.dinnerTimeDisplay,
                  isEnabled: reminderService.isEnabled,
                  onTap: () => _showTimePicker(
                    context,
                    reminderService,
                    MealReminderType.dinner,
                    reminderService.dinnerHour,
                    reminderService.dinnerMinute,
                  ),
                ),

                const SizedBox(height: 32),

                // Info note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reminders are scheduled one at a time. After each meal reminder, the next one will be automatically scheduled.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (reminderService.isEnabled) ...[
                  const SizedBox(height: 16),
                  _NextReminderInfo(reminderService: reminderService),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTimePicker(
    BuildContext context,
    MealReminderService service,
    MealReminderType mealType,
    int currentHour,
    int currentMinute,
  ) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: const Color(0xFF1B8A4E)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      switch (mealType) {
        case MealReminderType.breakfast:
          await service.setBreakfastTime(picked.hour, picked.minute);
          break;
        case MealReminderType.lunch:
          await service.setLunchTime(picked.hour, picked.minute);
          break;
        case MealReminderType.dinner:
          await service.setDinnerTime(picked.hour, picked.minute);
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${mealType.displayName} reminder updated! ${mealType.emoji}',
            ),
            backgroundColor: const Color(0xFF1B8A4E),
          ),
        );
      }
    }
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _SettingsCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _MealTimeCard extends StatelessWidget {
  final bool isDark;
  final String emoji;
  final String mealName;
  final String currentTime;
  final bool isEnabled;
  final VoidCallback onTap;

  const _MealTimeCard({
    required this.isDark,
    required this.emoji,
    required this.mealName,
    required this.currentTime,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.5,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isEnabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Reminder at $currentTime',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B8A4E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentTime,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B8A4E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NextReminderInfo extends StatelessWidget {
  final MealReminderService reminderService;

  const _NextReminderInfo({required this.reminderService});

  @override
  Widget build(BuildContext context) {
    final nextMeal = reminderService.getNextMealType();
    if (nextMeal == null) return const SizedBox.shrink();

    final nextTime = reminderService.getNextReminderTime(nextMeal);
    final now = DateTime.now();
    final difference = nextTime.difference(now);

    String timeUntil;
    if (difference.inDays > 0) {
      timeUntil = 'Tomorrow at ${reminderService.breakfastTimeDisplay}';
    } else if (difference.inHours > 0) {
      timeUntil =
          'In ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      timeUntil =
          'In ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      timeUntil = 'Any moment now';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B8A4E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1B8A4E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A4E).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.schedule,
              color: Color(0xFF1B8A4E),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Reminder: ${nextMeal.emoji} ${nextMeal.displayName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeUntil,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
