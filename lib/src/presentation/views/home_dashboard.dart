import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/product_tile.dart';
import 'scan_page.dart';
import '../../domain/usecases/get_recent_scans.dart';
import '../../domain/repositories/user_repository.dart';
import '../../domain/entities/scan_result.dart';
import '../viewmodels/scan_viewmodel.dart';

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  Future<List<ScanResult>> _scansFuture = Future.value([]);
  String _userName = 'there';

  @override
  void initState() {
    super.initState();
    // Access providers after first frame to avoid using BuildContext across async gaps
    final getScans = context.read<GetRecentScans>();
    final userRepo = context.read<UserRepository>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scansFuture = getScans(limit: 10);
      userRepo.getUserName().then((name) {
        if (!mounted) return;
        setState(() {
          _userName = name ?? 'there';
        });
      });
    });
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _userName == 'there' ? '' : _userName);
    final newName = await showDialog<String?>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Your name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      );
    });
    if (newName != null && newName.isNotEmpty) {
      await context.read<UserRepository>().setUserName(newName);
      setState(() => _userName = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanVm = context.watch<ScanViewModel?>();
    final latestScore = scanVm?.lastScan?.score ?? null;
    final latestProductName = scanVm?.lastScan?.product.name;

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Good morning', style: TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Text(_userName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    GestureDetector(onTap: _editName, child: const Icon(Icons.edit, size: 18, color: Colors.grey)),
                  ]),
                  const Text('👋', style: TextStyle(fontSize: 28)),
                ],
              ),
              const SizedBox(height: 18),
              // Score card - show latest scan score if present
              Container(
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
                    Text('Latest Scan Score', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(latestScore != null ? latestScore.toString() : '-', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        if (latestProductName != null) Expanded(child: Text(latestProductName, style: const TextStyle(color: Colors.white70))),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Icon(Icons.info_outline, color: Colors.white70, size: 16),
                        SizedBox(width: 6),
                        Text('Scores are heuristics based on nutrition facts', style: TextStyle(color: Colors.white70)),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Recent Scans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
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
                          return const Center(child: Text('No scans yet. Tap the button to scan a product.'));
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 120),
                          itemCount: items.length,
                          itemBuilder: (ctx, idx) {
                            final s = items[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10.0),
                              child: ProductTile(title: s.product.name, subtitle: s.product.brand, badgeText: s.score.toString()),
                            );
                          },
                        );
                      },
                    ),
                    // Center scan button floating above list
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanPage()));
                            // Refresh scans after returning
                            setState(() => _scansFuture = context.read<GetRecentScans>().call(limit: 10));
                          },
                          child: Container(
                            height: 72,
                            width: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(colors: [Color(0xFF00C17B), Color(0xFF0EA76B)]),
                              boxShadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.12), blurRadius: 8, offset: const Offset(0,4))],
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 34),
                          ),
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
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home, label: 'Home', active: true),
              _NavItem(icon: Icons.bar_chart, label: 'Stats'),
              const SizedBox(width: 64), // space for FAB
              _NavItem(icon: Icons.dynamic_feed, label: 'Feed'),
              _NavItem(icon: Icons.person, label: 'Profile'),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanPage()));
          setState(() => _scansFuture = context.read<GetRecentScans>().call(limit: 10));
        },
        backgroundColor: const Color(0xFF00C17B),
        child: const Icon(Icons.qr_code_scanner, size: 28),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  const _NavItem({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF00C17B) : Colors.grey.shade600;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [Icon(icon, color: color), const SizedBox(height: 4), Text(label, style: TextStyle(color: color, fontSize: 12))],
    );
  }
}
