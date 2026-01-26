import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../widgets/vitasnap_logo.dart';
import '../../features/meal_builder/meal_builder_page.dart';
import '../../features/menu_scanner/menu_scanner_page.dart';

/// Possible views within the Add Food page
enum _AddFoodView {
  selection,  // Initial view with Build My Meal / Restaurant options
  mealBuilder,
  restaurantMenu,
}

/// Landing page for adding food - choose between personal meal or restaurant
class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  _AddFoodView _currentView = _AddFoodView.selection;

  void _showMealBuilder() {
    setState(() {
      _currentView = _AddFoodView.mealBuilder;
    });
  }

  void _showRestaurantMenu() {
    setState(() {
      _currentView = _AddFoodView.restaurantMenu;
    });
  }

  void _showSelection() {
    setState(() {
      _currentView = _AddFoodView.selection;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentView) {
      case _AddFoodView.mealBuilder:
        return MealBuilderPage(
          embedded: true,
          onBack: _showSelection,
        );
      case _AddFoodView.restaurantMenu:
        return _RestaurantMenuEmbedded(onBack: _showSelection);
      case _AddFoodView.selection:
        return _buildSelectionView(context);
    }
  }

  Widget _buildSelectionView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? const Color(0xFF1A1A2E)
        : AppColors.backgroundLight;
    final ScrollController scrollController = ScrollController();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black87,
      ),
      body: SafeArea(
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      kToolbarHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: AppColors.primaryGreen,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What did you eat?',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Track your meals for better health insights',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      _buildOptionCard(
                        context: context,
                        icon: Icons.kitchen,
                        emoji: '🍳',
                        title: 'Build My Meal',
                        subtitle: 'Search ingredients and track homemade meals',
                        description:
                            'Perfect for home cooking, snacks, and custom meals',
                        color: AppColors.primaryGreen,
                        isDark: isDark,
                        onTap: _showMealBuilder,
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      _buildOptionCard(
                        context: context,
                        icon: Icons.restaurant,
                        emoji: '🍔',
                        title: 'Restaurant Menu',
                        subtitle:
                            'Scan a menu or pick from popular restaurants',
                        description:
                            'AI analyzes menus and suggests healthier choices',
                        color: const Color(0xFFFF6B35),
                        isDark: isDark,
                        onTap: _showRestaurantMenu,
                      ),

                      const SizedBox(height: 24),

                      // Push tip toward bottom when content is short
                      const Spacer(),

                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.primaryGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.primaryGreen.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 20,
                              color: isDark
                                  ? Colors.amber
                                  : AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Tip: You can also scan product barcodes from the Home screen!',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required BuildContext context,
    required IconData icon,
    required String emoji,
    required String title,
    required String subtitle,
    required String description,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252542) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon/Emoji container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(Icons.arrow_forward_ios, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// Embedded Restaurant Menu view with back button
class _RestaurantMenuEmbedded extends StatelessWidget {
  final VoidCallback onBack;

  const _RestaurantMenuEmbedded({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: AppColors.backgroundLight,
      child: SafeArea(
        child: Column(
          children: [
            // Back button header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  const Spacer(),
                ],
              ),
            ),
            // Menu Scanner content
            const Expanded(
              child: MenuScannerPage(embedded: true),
            ),
          ],
        ),
      ),
    );
  }
}
