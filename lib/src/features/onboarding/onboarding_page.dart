import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/health_conditions_service.dart';
import '../../core/services/dietary_preferences_service.dart';
import '../../core/services/theme_service.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onComplete;
  final String userId;
  
  const OnboardingPage({super.key, required this.onComplete, required this.userId});

  static const _kOnboardingCompletePrefix = 'onboarding_complete_';

  /// Check if onboarding has been completed for a specific user
  static Future<bool> isCompleteForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kOnboardingCompletePrefix$userId') ?? false;
  }

  /// Mark onboarding as complete for a specific user
  static Future<void> markCompleteForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_kOnboardingCompletePrefix$userId', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Total pages: 4 intro slides + theme + dietary + health + walkthrough
  static const int _totalPages = 8;
  static const int _themeSlideIndex = 4;
  static const int _dietarySlideIndex = 5;
  static const int _healthSlideIndex = 6;

  final List<OnboardingItem> _introItems = [
    OnboardingItem(
      icon: Icons.qr_code_scanner,
      title: 'Scan Any Product',
      description: 'Simply point your camera at any food barcode to instantly get detailed nutritional information.',
      color: const Color(0xFF1B8A4E),
    ),
    OnboardingItem(
      icon: Icons.health_and_safety,
      title: 'Health Score',
      description: 'Get an instant health score based on nutritional values, helping you make healthier choices.',
      color: const Color(0xFF2196F3),
    ),
    OnboardingItem(
      icon: Icons.restaurant_menu,
      title: 'Dietary Preferences',
      description: 'Set your dietary restrictions and get alerts when products contain ingredients you avoid.',
      color: const Color(0xFFFF9800),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingPage.markCompleteForUser(widget.userId);
    widget.onComplete();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  Color _getCurrentColor() {
    if (_currentPage < _introItems.length) {
      return _introItems[_currentPage].color;
    } else if (_currentPage == _themeSlideIndex) {
      return const Color(0xFF607D8B); // Blue Grey for theme
    } else if (_currentPage == _dietarySlideIndex) {
      return const Color(0xFFFF9800); // Orange for dietary
    } else if (_currentPage == _healthSlideIndex) {
      return const Color(0xFFE53935); // Red for health
    }
    return const Color(0xFF1B8A4E); // Green for walkthrough
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentColor = _getCurrentColor();
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  if (index < _introItems.length) {
                    return _OnboardingSlide(item: _introItems[index]);
                  } else if (index == _themeSlideIndex) {
                    return const _ThemeSelectionSlide();
                  } else if (index == _dietarySlideIndex) {
                    return const _DietaryPreferencesSlide();
                  } else if (index == _healthSlideIndex) {
                    return const _HealthQuestionnaireSlide();
                  } else {
                    return const _WalkthroughSlide();
                  }
                },
              ),
            ),
            
            // Page indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (index) {
                    Color color;
                    if (index < _introItems.length) {
                      color = _introItems[index].color;
                    } else if (index == _themeSlideIndex) {
                      color = const Color(0xFF607D8B);
                    } else if (index == _dietarySlideIndex) {
                      color = const Color(0xFFFF9800);
                    } else if (index == _healthSlideIndex) {
                      color = const Color(0xFFE53935);
                    } else {
                      color = const Color(0xFF1B8A4E); // Walkthrough
                    }
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? color
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _currentPage == _totalPages - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _OnboardingSlide extends StatelessWidget {
  final OnboardingItem item;

  const _OnboardingSlide({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with background
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 80,
              color: item.color,
            ),
          ),
          const SizedBox(height: 48),
          
          // Title
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Description
          Text(
            item.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Theme selection slide for onboarding
class _ThemeSelectionSlide extends StatelessWidget {
  const _ThemeSelectionSlide();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF607D8B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.palette,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Your Theme',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select how you want VitaSnap to look.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Theme options
          Consumer<ThemeService>(
            builder: (context, themeService, _) {
              return Column(
                children: AppThemeMode.values.map((mode) {
                  final isSelected = themeService.themeMode == mode;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ThemeOptionCard(
                      mode: mode,
                      isSelected: isSelected,
                      onTap: () => themeService.setThemeMode(mode),
                      isDark: isDark,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can change this anytime in Settings.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final AppThemeMode mode;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _ThemeOptionCard({
    required this.mode,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  IconData get _icon {
    switch (mode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  String get _title {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light Mode';
      case AppThemeMode.dark:
        return 'Dark Mode';
      case AppThemeMode.system:
        return 'System Default';
    }
  }

  String get _description {
    switch (mode) {
      case AppThemeMode.light:
        return 'Bright and clean appearance';
      case AppThemeMode.dark:
        return 'Easy on the eyes, saves battery';
      case AppThemeMode.system:
        return 'Follows your device settings';
    }
  }

  Color get _accentColor => const Color(0xFF607D8B);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor.withValues(alpha: 0.1)
                : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? _accentColor
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accentColor.withValues(alpha: 0.15)
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icon,
                  color: isSelected
                      ? _accentColor
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? _accentColor
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? _accentColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? _accentColor
                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dietary preferences slide for onboarding
class _DietaryPreferencesSlide extends StatelessWidget {
  const _DietaryPreferencesSlide();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFFF9800);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dietary Preferences',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select any dietary restrictions or allergies to get personalized alerts.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'We\'ll warn you when scanned products contain ingredients you want to avoid.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Dietary restrictions list
          Expanded(
            child: Consumer<DietaryPreferencesService>(
              builder: (context, service, _) {
                return ListView(
                  children: DietaryRestriction.values.map((restriction) {
                    final isSelected = service.isSelected(restriction);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DietaryRestrictionChip(
                        restriction: restriction,
                        isSelected: isSelected,
                        onTap: () => service.toggleRestriction(restriction),
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DietaryRestrictionChip extends StatelessWidget {
  final DietaryRestriction restriction;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _DietaryRestrictionChip({
    required this.restriction,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  static const Color _accentColor = Color(0xFFFF9800);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? _accentColor.withValues(alpha: 0.1)
                : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? _accentColor
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _accentColor.withValues(alpha: 0.15)
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  restriction.icon,
                  color: isSelected
                      ? _accentColor
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restriction.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? _accentColor
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Text(
                      restriction.category,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? _accentColor : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? _accentColor
                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 12,
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Health questionnaire slide for onboarding
class _HealthQuestionnaireSlide extends StatelessWidget {
  const _HealthQuestionnaireSlide();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.favorite,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Health Matters',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tell us about your health conditions so we can give you personalized food recommendations.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Info message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'This helps us warn you about foods that may affect your health. You can change this anytime in Settings.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Health conditions list
          Expanded(
            child: Consumer<HealthConditionsService>(
              builder: (context, service, _) {
                return ListView(
                  children: HealthCondition.values.map((condition) {
                    final isSelected = service.isSelected(condition);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HealthConditionChip(
                        condition: condition,
                        isSelected: isSelected,
                        onTap: () => service.toggleCondition(condition),
                        isDark: isDark,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthConditionChip extends StatelessWidget {
  final HealthCondition condition;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _HealthConditionChip({
    required this.condition,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? condition.color.withValues(alpha: 0.1)
                : (isDark ? Colors.grey.shade800 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? condition.color
                  : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? condition.color.withValues(alpha: 0.15)
                      : (isDark ? Colors.grey.shade700 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  condition.icon,
                  color: isSelected
                      ? condition.color
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      condition.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? condition.color
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    Text(
                      condition.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected ? condition.color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? condition.color
                        : (isDark ? Colors.grey.shade600 : Colors.grey.shade300),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.check,
                  size: 14,
                  color: isSelected ? Colors.white : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// App walkthrough slide showing how to use the app
class _WalkthroughSlide extends StatelessWidget {
  const _WalkthroughSlide();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF1B8A4E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.rocket_launch,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You\'re All Set!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Here\'s a quick guide to get you started with VitaSnap.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey.shade400 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Walkthrough steps
          Expanded(
            child: ListView(
              children: const [
                _WalkthroughStep(
                  step: 1,
                  icon: Icons.qr_code_scanner,
                  title: 'Scan a Product',
                  description: 'Tap the scan button on the home screen and point your camera at any food barcode.',
                  color: Color(0xFF1B8A4E),
                ),
                _WalkthroughStep(
                  step: 2,
                  icon: Icons.restaurant_menu,
                  title: 'Restaurant Menu Scanner',
                  description: 'Take a photo of any restaurant menu to get AI-powered nutritional analysis and health recommendations.',
                  color: Color(0xFFE65100),
                ),
                _WalkthroughStep(
                  step: 3,
                  icon: Icons.lunch_dining,
                  title: 'Build Your Meal',
                  description: 'Combine ingredients to build custom meals and see the total nutritional breakdown and health score.',
                  color: Color(0xFF00897B),
                ),
                _WalkthroughStep(
                  step: 4,
                  icon: Icons.favorite_border,
                  title: 'Save Favorites',
                  description: 'Tap the heart icon to save products you love for quick access later.',
                  color: Color(0xFFE91E63),
                ),
                _WalkthroughStep(
                  step: 5,
                  icon: Icons.history,
                  title: 'Track History',
                  description: 'All your scanned products and meals are saved automatically. Review them anytime from your history.',
                  color: Color(0xFFFF9800),
                ),
                _WalkthroughStep(
                  step: 6,
                  icon: Icons.settings,
                  title: 'Customize Settings',
                  description: 'Update your dietary preferences, health conditions, or theme anytime in the Profile tab.',
                  color: Color(0xFF9C27B0),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Ready message
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.1),
                  primaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap "Get Started" to begin your healthy eating journey!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WalkthroughStep extends StatelessWidget {
  final int step;
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _WalkthroughStep({
    required this.step,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number with connector
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              if (step < 5)
                Container(
                  width: 2,
                  height: 40,
                  color: color.withValues(alpha: 0.3),
                ),
            ],
          ),
          const SizedBox(width: 12),
          
          // Content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
