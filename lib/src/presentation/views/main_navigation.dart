import 'package:flutter/material.dart';

import 'home_dashboard.dart';
import 'favorites_page.dart';
import 'add_food_page.dart';
import '../../features/profile/profile_page.dart';

/// Main navigation wrapper with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// Navigate to home tab from anywhere in the widget tree
  static void navigateToHome(BuildContext context) {
    final state = context.findAncestorStateOfType<MainNavigationState>();
    state?.navigateToTab(0);
  }

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboard(),
    AddFoodPage(),
    FavoritesPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // Reset index to 0 when the widget is created (e.g., after login)
    _currentIndex = 0;
  }

  /// Get safe current index (ensure it's within bounds)
  int get _safeIndex => _currentIndex.clamp(0, _pages.length - 1);

  /// Navigate to a specific tab by index
  void navigateToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  /// Navigate to home tab (index 0)
  void navigateToHome() => navigateToTab(0);

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1B8A4E);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIdx = _safeIndex;

    return Scaffold(
      body: IndexedStack(
        index: currentIdx,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: currentIdx,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: isDark ? Theme.of(context).cardColor : Colors.white,
          indicatorColor: primaryColor.withValues(alpha: 0.15),
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.home_outlined,
                color: currentIdx == 0 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.home, color: primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.add_circle_outline,
                color: currentIdx == 1 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.add_circle, color: primaryColor),
              label: 'Add Meal',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.favorite_border,
                color: currentIdx == 2 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.favorite, color: primaryColor),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: currentIdx == 3 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.person, color: primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
