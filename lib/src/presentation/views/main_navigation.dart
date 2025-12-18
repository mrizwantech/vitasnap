import 'package:flutter/material.dart';

import 'home_dashboard.dart';
import 'favorites_page.dart';
import '../../features/profile/profile_page.dart';

/// Main navigation wrapper with bottom navigation bar
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboard(),
    FavoritesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1B8A4E);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
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
          selectedIndex: _currentIndex,
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
                color: _currentIndex == 0 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.home, color: primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.favorite_border,
                color: _currentIndex == 1 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              selectedIcon: Icon(Icons.favorite, color: primaryColor),
              label: 'Favorites',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.person_outline,
                color: _currentIndex == 2 ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
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
