import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/product_tile.dart';
import '../widgets/vitasnap_logo.dart';
import 'product_details_page.dart';
import 'weekly_overview_page.dart';
import '../../domain/usecases/get_recent_scans.dart';
import '../../domain/usecases/compute_weekly_stats.dart';
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
  late Future<List<ScanResult>> _weeklyStatsFuture; // All scans for weekly stats
  String _userName = AppStrings.defaultUserName;


  @override
  void dispose() {
    // Remove callback to avoid memory leaks
    final scanViewModel = context.read<ScanViewModel>();
    scanViewModel.onScanHistoryRestored = null;
    scanViewModel.removeListener(_onScanViewModelChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refreshScans() {
    setState(() {
      _scansFuture = context.read<GetRecentScans>().call(limit: 10);
      // Fetch all scans (up to 50) for weekly stats to ensure accurate calculation
      _weeklyStatsFuture = context.read<GetRecentScans>().call(limit: 50);
    });
  }


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize with empty future, then load after first frame
    _scansFuture = Future.value([]);
    _weeklyStatsFuture = Future.value([]);

    // Listen for scan history restored event
    final scanViewModel = context.read<ScanViewModel>();
    scanViewModel.onScanHistoryRestored = _refreshScans;
    
    // Listen for changes to scan history (e.g., when meal is logged from meal builder)
    scanViewModel.addListener(_onScanViewModelChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScans();
      _loadUserName();
    });
  }
  
  void _onScanViewModelChanged() {
    // Refresh scans when ScanViewModel notifies (e.g., new item added)
    _refreshScans();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshScans();
    }
  }

  void _loadUserName() {

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
      if (!mounted) return;
      await context.read<UserRepository>().setUserName(newName);
      setState(() => _userName = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF6FBF8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            if (isWide) {
              // Tablet/large screen: two-column layout
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column: greeting, stats, actions
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 24, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              const Center(
                                child: VitaSnapLogo(fontSize: 28, showTagline: true),
                              ),
                              Positioned(
                                right: 0,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () {},
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
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 28,
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
                                child: Icon(Icons.edit, size: 20, color: isDark ? Colors.grey.shade400 : Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          FutureBuilder<List<ScanResult>>(
                            future: _weeklyStatsFuture, // Use all scans for accurate weekly stats
                            builder: (context, snap) {
                              final scans = snap.data ?? [];
                              final stats = ComputeWeeklyStats()(scans);
                              return _WeeklyStatsCard(
                                stats: stats,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => WeeklyOverviewPage(scans: scans, stats: stats),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Right column: recent scans
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 24, 32, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                AppStrings.recentScans,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: Stack(
                              children: [
                                FutureBuilder<List<ScanResult>>(
                                  future: _scansFuture,
                                  builder: (context, snap) {
                                    final items = snap.data ?? [];
                                    if (snap.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (items.isEmpty) {
                                      return const Center(child: Text(AppStrings.noScansYet));
                                    }
                                    return ListView.builder(
                                      padding: const EdgeInsets.only(bottom: 180),
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
                                            mealType: s.mealType,
                                            onTap: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => ProductDetailsPage(scanResult: s, showAddToList: false),
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
                ],
              );
            } else {
              // Phone/small screen: single column
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const Center(
                          child: VitaSnapLogo(fontSize: 22, showTagline: true),
                        ),
                        Positioned(
                          right: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {},
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
                    FutureBuilder<List<ScanResult>>(
                      future: _weeklyStatsFuture, // Use all scans for accurate weekly stats
                      builder: (context, snap) {
                        final scans = snap.data ?? [];
                        final stats = ComputeWeeklyStats()(scans);
                        return _WeeklyStatsCard(
                          stats: stats,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => WeeklyOverviewPage(scans: scans, stats: stats),
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
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (items.isEmpty) {
                                return const Center(child: Text(AppStrings.noScansYet));
                              }
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 180),
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
                                      mealType: s.mealType,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ProductDetailsPage(scanResult: s, showAddToList: false),
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
              );
            }
          },
        ),
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
                        color: gradeColor.withValues(alpha: 0.4),
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
