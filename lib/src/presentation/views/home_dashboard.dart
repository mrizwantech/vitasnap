import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/product_tile.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/vitasnap_logo.dart';
import 'product_not_found_page.dart';
import 'product_details_page.dart';
import 'search_results_page.dart';
import 'weekly_overview_page.dart';
import '../../domain/usecases/get_recent_scans.dart';
import '../../domain/usecases/compute_weekly_stats.dart';
import '../../domain/usecases/search_products.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/scan_result.dart';
import '../../features/profile/profile_page.dart';
import '../../core/services/auth_service.dart';
import '../../core/strings.dart';
import '../viewmodels/scan_viewmodel.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> with WidgetsBindingObserver {
  late Future<List<ScanResult>> _scansFuture;
  String _userName = AppStrings.defaultUserName;
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshScans() {
    setState(() {
      _scansFuture = context.read<GetRecentScans>().call(limit: 10);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize with empty future, then load after first frame
    _scansFuture = Future.value([]);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScans();
      _loadUserName();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshScans();
    }
  }

  void _loadUserName() {
    // First check if user is authenticated with Firebase
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated && authService.user?.displayName != null) {
      final displayName = authService.user!.displayName!;
      if (displayName.isNotEmpty) {
        setState(() {
          _userName = displayName.split(' ').first; // Use first name
        });
        return;
      }
    }
    
    // Fall back to local storage
    context.read<UserRepository>().getUserName().then((name) {
      if (!mounted) return;
      setState(() {
        _userName = name ?? AppStrings.defaultUserName;
      });
    });
  }

  String _getGreeting() => AppStrings.hello;

  Future<void> _editName() async {
    final controller = TextEditingController(
      text: _userName == AppStrings.defaultUserName ? '' : _userName,
    );
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(AppStrings.editName),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: AppStrings.yourName),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(AppStrings.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text(AppStrings.save),
            ),
          ],
        );
      },
    );
    if (newName != null && newName.isNotEmpty) {
      await context.read<UserRepository>().setUserName(newName);
      setState(() => _userName = newName);
    }
  }

  /// Check if the input looks like a barcode (only digits, 8-14 characters)
  bool _looksLikeBarcode(String input) {
    final digitsOnly = RegExp(r'^\d+$');
    return digitsOnly.hasMatch(input) &&
        input.length >= 8 &&
        input.length <= 14;
  }

  Future<void> _doSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _showSearch = false;
      _searchController.clear();
    });

    // If it looks like a barcode, do barcode lookup
    if (_looksLikeBarcode(query)) {
      final vm = context.read<ScanViewModel>();
      final scanResult = await vm.fetchByBarcode(query);

      if (scanResult == null) {
        // Navigate to Product Not Found page
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductNotFoundPage(barcode: query),
          ),
        );
        return;
      }

      // Navigate to product details page
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => ProductDetailsPage(scanResult: scanResult),
        ),
      );

      // If user added the product, save it and refresh list
      if (result != null && result['added'] == true) {
        await vm.addToHistory(scanResult);
        _refreshScans();
      }
    } else {
      // Text search - search by product name
      final searchProducts = context.read<SearchProducts>();

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final results = await searchProducts(query);
        if (mounted) Navigator.of(context).pop(); // Close loading dialog

        if (results.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(AppStrings.noProductsFoundFor(query))),
            );
          }
          return;
        }

        // Navigate to search results page
        final result = await Navigator.of(context).push<Map<String, dynamic>>(
          MaterialPageRoute(
            builder: (_) => SearchResultsPage(query: query, results: results),
          ),
        );

        // If user added a product from search results, refresh list
        if (result != null && result['added'] == true) {
          _refreshScans();
        }
      } catch (e) {
        if (mounted) Navigator.of(context).pop(); // Close loading dialog
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(AppStrings.searchError(e.toString()))));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF6FBF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Stack(
                alignment: Alignment.center,
                children: [
                  // Centered logo with tagline
                  const Center(
                    child: VitaSnapLogo(fontSize: 22, showTagline: true),
                  ),
                  // Icons positioned on the right
                  Positioned(
                    right: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () {
                            // TODO: Notifications
                          },
                          icon: const Icon(Icons.notifications_outlined),
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                        IconButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ProfilePage(),
                              ),
                            );
                            // Refresh scans when coming back from profile/settings
                            _refreshScans();
                          },
                          icon: const Icon(Icons.settings_outlined),
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        children: [
                          TextSpan(
                            text: '${_getGreeting()}, ',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                          TextSpan(text: _userName),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _editName,
                    child: Icon(Icons.edit, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Weekly stats card
              FutureBuilder<List<ScanResult>>(
                future: _scansFuture,
                builder: (context, snap) {
                  final scans = snap.data ?? [];
                  final stats = ComputeWeeklyStats()(scans);
                  return _WeeklyStatsCard(
                    stats: stats,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              WeeklyOverviewPage(scans: scans, stats: stats),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 18),
              const Text(
                AppStrings.recentScans,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Stack(
                  children: [
                    FutureBuilder<List<ScanResult>>(
                      future: _scansFuture,
                      builder: (context, snap) {
                        final items = snap.data ?? [];
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        if (items.isEmpty) {
                          return const Center(
                            child: Text(
                              AppStrings.noScansYet,
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: items.length,
                          itemBuilder: (ctx, idx) {
                            final s = items[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: ProductTile(
                                title: s.product.name,
                                subtitle: s.product.brand,
                                score: s.score,
                                timestamp: s.timestamp,
                                labels: s.product.labels,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailsPage(scanResult: s),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _showSearch
          ? // Search mode: show search field + search button, hide scan
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.1),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: AppStrings.searchByNameOrBarcode,
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _doSearch(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FloatingActionButton(
                    heroTag: 'search_go_fab',
                    onPressed: _doSearch,
                    backgroundColor: const Color(0xFF00C17B),
                    child: const Icon(Icons.arrow_forward, size: 24),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    heroTag: 'search_close_fab',
                    mini: true,
                    onPressed: () => setState(() {
                      _showSearch = false;
                      _searchController.clear();
                    }),
                    backgroundColor: Colors.grey.shade400,
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            )
          : // Normal mode: show search + scan buttons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search FAB
                FloatingActionButton(
                  heroTag: 'search_fab',
                  onPressed: () => setState(() => _showSearch = true),
                  backgroundColor: const Color(0xFF00C17B),
                  elevation: 4,
                  child: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                // Scan FAB
                FloatingActionButton.extended(
                  heroTag: 'scan_fab',
                  onPressed: () async {
                    final res = await Navigator.of(context)
                        .push<Map<String, dynamic>>(
                          MaterialPageRoute(
                            builder: (_) => const BarcodeScannerWidget(),
                          ),
                        );
                    // Refresh list if product was added
                    if (res != null && res['added'] == true) {
                      _refreshScans();
                    }
                  },
                  backgroundColor: const Color(0xFF00C17B),
                  icon: const Icon(Icons.qr_code_scanner, size: 24),
                  label: const Text(AppStrings.scanIt),
                ),
              ],
            ),
    );
  }
}

/// Weekly stats card widget showing grade and average score.
class _WeeklyStatsCard extends StatelessWidget {
  final WeeklyStats stats;
  final VoidCallback? onTap;
  const _WeeklyStatsCard({required this.stats, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Determine grade color
    final gradeColor = _getGradeColor(stats.grade);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF00C17B), Color(0xFF0EA76B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      AppStrings.weeklyStats,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppStrings.scansCount(stats.scanCount),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Grade badge
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: gradeColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: gradeColor.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    stats.grade,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Score and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            stats.scanCount > 0
                                ? stats.averageScore.round().toString()
                                : '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '/100',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        stats.gradeDescription,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                SizedBox(width: 6),
                Text(
                  AppStrings.averageScoreThisWeek,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF1B8A4E); // Dark green
      case 'B':
        return const Color(0xFF7AC547); // Light green
      case 'C':
        return const Color(0xFFF9C74F); // Yellow
      case 'D':
        return const Color(0xFFED8936); // Orange
      case 'E':
        return const Color(0xFFE53E3E); // Red
      default:
        return Colors.grey;
    }
  }
}
