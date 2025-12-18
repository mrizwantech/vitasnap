import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/dietary_preferences_service.dart';
import '../../core/strings.dart';

class DietaryPreferencesPage extends StatelessWidget {
  const DietaryPreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<DietaryPreferencesService>();
    final primaryColor = const Color(0xFF1B8A4E);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group restrictions by category
    final grouped = <String, List<DietaryRestriction>>{};
    for (final restriction in DietaryRestriction.values) {
      final category = restriction.category;
      grouped.putIfAbsent(category, () => []).add(restriction);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(AppStrings.dietaryPreferences),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0,
        actions: [
          if (service.selectedRestrictions.isNotEmpty)
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All'),
                    content: const Text(
                      'Are you sure you want to clear all dietary preferences?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(AppStrings.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Clear',
                          style: TextStyle(color: Colors.red.shade600),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await service.clearAll();
                }
              },
              child: Text(
                'Clear All',
                style: TextStyle(color: Colors.red.shade600),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select your dietary restrictions and preferences. '
                    'Products that don\'t match will be highlighted.',
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          ...grouped.entries.map((entry) => _buildCategory(
                context,
                entry.key,
                entry.value,
                service,
                primaryColor,
                isDark,
              )),
        ],
      ),
    );
  }

  Widget _buildCategory(
    BuildContext context,
    String title,
    List<DietaryRestriction> restrictions,
    DietaryPreferencesService service,
    Color primaryColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            ),
          ),
        ),
        Container(
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
            children: restrictions.asMap().entries.map((entry) {
              final index = entry.key;
              final restriction = entry.value;
              final isSelected = service.isSelected(restriction);

              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primaryColor.withValues(alpha: 0.1)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        restriction.icon,
                        color: isSelected ? primaryColor : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      restriction.displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: Switch(
                      value: isSelected,
                      onChanged: (_) => service.toggleRestriction(restriction),
                      activeColor: primaryColor,
                    ),
                    onTap: () => service.toggleRestriction(restriction),
                  ),
                  if (index < restrictions.length - 1)
                    Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: Colors.grey.shade200,
                    ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
