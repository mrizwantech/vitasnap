import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../core/services/health_conditions_service.dart';
import '../../core/strings.dart';
import '../../domain/repositories/scan_history_repository.dart';
import '../settings/dietary_preferences_page.dart';
import '../settings/privacy_policy_page.dart';
import '../../presentation/views/health_conditions_page.dart';
import '../../presentation/widgets/vitasnap_logo.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final themeService = context.watch<ThemeService>();
    final user = authService.user;
    final primaryColor = const Color(0xFF1B8A4E);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            _getInitials(
                              user?.displayName ?? user?.email ?? '?',
                            ),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    user?.displayName ?? AppStrings.user,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Email or phone
                  Text(
                    user?.email ?? user?.phoneNumber ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // App Settings section
            _SectionTitle(title: AppStrings.settings, isDark: isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              children: [
                  _ThemeTile(
                    themeService: themeService,
                    primaryColor: primaryColor,
                  ),
                  _divider(),
                  _SettingsTile(
                    icon: Icons.food_bank_outlined,
                    title: AppStrings.dietaryPreferences,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DietaryPreferencesPage(),
                        ),
                      );
                    },
                  ),
                  _divider(),
                  _HealthConditionsTile(primaryColor: primaryColor),
                  _divider(),
                  _SettingsTile(
                    icon: Icons.notifications_outlined,
                    title: AppStrings.notifications,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.comingSoon)),
                      );
                    },
                  ),
                ],
            ),
            const SizedBox(height: 24),

            // Data & Privacy section
            _SectionTitle(title: AppStrings.dataAndPrivacy, isDark: isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              children: [
                  _CloudSyncTile(primaryColor: primaryColor),
                  _divider(),
                  _ClearHistoryTile(primaryColor: primaryColor),
                  _divider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: AppStrings.privacyPolicy,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                  ),
                ],
            ),
            const SizedBox(height: 24),

            // Support section
            _SectionTitle(title: AppStrings.about, isDark: isDark),
            const SizedBox(height: 12),
            _SettingsCard(
              isDark: isDark,
              children: [
                  _SettingsTile(
                    icon: Icons.help_outline,
                    title: AppStrings.helpAndSupport,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.comingSoon)),
                      );
                    },
                  ),
                ],
            ),
            const SizedBox(height: 24),

            // Sign out button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text(AppStrings.signOutConfirmTitle),
                      content: const Text(AppStrings.signOutConfirmMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text(AppStrings.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            AppStrings.signOut,
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await authService.signOut();
                    // Pop all routes and go back to root (AuthWrapper will show login)
                    if (context.mounted) {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    }
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  AppStrings.signOut,
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // App version
            Text(
              '${AppStrings.appName} v1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: Colors.grey.shade200,
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle({required this.title, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _SettingsCard({required this.children, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final ThemeService themeService;
  final Color primaryColor;

  const _ThemeTile({
    required this.themeService,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        themeService.getThemeModeIcon(themeService.themeMode),
        color: Colors.grey.shade700,
      ),
      title: const Text(AppStrings.theme),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          themeService.getThemeModeName(themeService.themeMode),
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 14,
          ),
        ),
      ),
      onTap: () => _showThemeDialog(context),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            final isSelected = themeService.themeMode == mode;
            return ListTile(
              leading: Icon(
                themeService.getThemeModeIcon(mode),
                color: isSelected ? primaryColor : Colors.grey.shade600,
              ),
              title: Text(
                themeService.getThemeModeName(mode),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? primaryColor : null,
                ),
              ),
              trailing: isSelected
                  ? Icon(Icons.check, color: primaryColor)
                  : null,
              onTap: () {
                themeService.setThemeMode(mode);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ClearHistoryTile extends StatelessWidget {
  final Color primaryColor;

  const _ClearHistoryTile({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.delete_outline, color: Colors.grey.shade700),
      title: const Text(AppStrings.clearHistory),
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: () => _showClearHistoryDialog(context),
    );
  }

  Future<void> _showClearHistoryDialog(BuildContext context) async {
    final historyRepo = context.read<ScanHistoryRepository>();
    final scanCount = await historyRepo.getScanCount();

    if (scanCount == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.noHistoryToClear)),
        );
      }
      return;
    }

    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.delete_forever,
            color: Colors.red.shade600,
            size: 32,
          ),
        ),
        title: const Text(AppStrings.clearHistoryConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.clearHistoryConfirmMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, color: Colors.grey.shade600, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$scanCount ${scanCount == 1 ? 'scan' : 'scans'} will be deleted',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await historyRepo.clearHistory();
      // Also clear from Firebase if cloud sync is enabled
      final cloudSync = context.read<CloudSyncService>();
      if (cloudSync.isEnabled) {
        await cloudSync.deleteCloudData();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.historyCleared)),
        );
      }
    }
  }
}

class _HealthConditionsTile extends StatelessWidget {
  final Color primaryColor;
  const _HealthConditionsTile({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final healthService = context.watch<HealthConditionsService>();
    final conditionCount = healthService.selectedConditions.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.health_and_safety,
          color: Colors.red.shade400,
          size: 20,
        ),
      ),
      title: const Text(
        'Health Conditions',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        conditionCount == 0
            ? 'Set your health conditions'
            : '$conditionCount condition${conditionCount == 1 ? '' : 's'} selected',
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const HealthConditionsPage(),
          ),
        );
      },
    );
  }
}

class _CloudSyncTile extends StatelessWidget {
  final Color primaryColor;
  const _CloudSyncTile({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final cloudSync = context.watch<CloudSyncService>();
    // Always show switch as enabled by default if local storage is cleared
    final cloudEnabled = cloudSync.isEnabled == true;
    
    return ListTile(
      leading: Icon(
        cloudSync.isEnabled ? Icons.cloud_done : Icons.cloud_outlined,
        color: cloudSync.isEnabled ? primaryColor : Colors.grey.shade700,
      ),
      title: const Text('Cloud Backup'),
      subtitle: cloudSync.isEnabled
          ? Text(
              cloudSync.isSyncing 
                  ? 'Syncing...' 
                  : 'Last sync: ${cloudSync.lastSyncDisplay}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            )
          : null,
      trailing: Switch(
        value: cloudEnabled,
        activeThumbColor: primaryColor,
        onChanged: (value) => _toggleCloudSync(context, value),
      ),
    );
  }

  Future<void> _toggleCloudSync(BuildContext context, bool enable) async {
    final cloudSync = context.read<CloudSyncService>();
    
    if (enable) {
      await cloudSync.setEnabled(true);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud backup enabled!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await cloudSync.setEnabled(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cloud backup disabled')),
        );
      }
    }
  }
}
