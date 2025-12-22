import 'package:flutter/material.dart';
import '../../domain/entities/scan_result.dart';
import '../../domain/usecases/compute_weekly_stats.dart';
import '../widgets/vitasnap_logo.dart';

/// Weekly Overview page showing detailed nutritional insights.
class WeeklyOverviewPage extends StatelessWidget {
  final List<ScanResult> scans;
  final WeeklyStats stats;

  const WeeklyOverviewPage({
    super.key,
    required this.scans,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to this week's scans
    final now = DateTime.now();
    final weekday = now.weekday;
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));

    final weeklyScans = scans.where((s) {
      return s.timestamp.isAfter(startOfWeek) ||
          s.timestamp.isAtSameMomentAs(startOfWeek);
    }).toList();

    // Sort by score for best/worst
    final sortedByScore = List<ScanResult>.from(weeklyScans)
      ..sort((a, b) => b.score.compareTo(a.score));

    final bestProducts = sortedByScore.take(3).toList();
    final worstProducts = sortedByScore.reversed.take(3).toList();

    // Daily breakdown
    final dailyStats = _computeDailyStats(weeklyScans, startOfWeek);

    // Nutritional insights
    final nutritionInsights = _computeNutritionInsights(weeklyScans);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with grade and score
            _buildScoreHeader(),
            const SizedBox(height: 24),

            // Daily Activity Chart
            _buildSectionTitle('Daily Activity'),
            const SizedBox(height: 12),
            _buildDailyChart(dailyStats),
            const SizedBox(height: 24),

            // Score Distribution
            _buildSectionTitle('Score Distribution'),
            const SizedBox(height: 12),
            _buildScoreDistribution(weeklyScans),
            const SizedBox(height: 24),

            // Best Products
            if (bestProducts.isNotEmpty) ...[
              _buildSectionTitle('🌟 Top Performers'),
              const SizedBox(height: 12),
              ...bestProducts.map((s) => _buildProductCard(s, isGood: true)),
              const SizedBox(height: 24),
            ],

            // Products to Improve
            if (worstProducts.isNotEmpty &&
                worstProducts.any((s) => s.score < 50)) ...[
              _buildSectionTitle('⚠️ Products to Reconsider'),
              const SizedBox(height: 12),
              ...worstProducts
                  .where((s) => s.score < 50)
                  .map((s) => _buildProductCard(s, isGood: false)),
              const SizedBox(height: 24),
            ],

            // Nutritional Insights
            if (nutritionInsights.isNotEmpty) ...[
              _buildSectionTitle('🥗 Nutritional Insights'),
              const SizedBox(height: 12),
              _buildNutritionInsights(nutritionInsights),
              const SizedBox(height: 24),
            ],

            // Tips based on grade
            _buildSectionTitle('💡 Recommendations'),
            const SizedBox(height: 12),
            _buildTipsCard(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildScoreHeader() {
    final gradeColor = _getGradeColor(stats.grade);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [gradeColor, gradeColor.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Your Weekly Score',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Grade badge
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  stats.grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Column(
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
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        '/100',
                        style: TextStyle(color: Colors.white70, fontSize: 20),
                      ),
                    ],
                  ),
                  Text(
                    stats.gradeDescription,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${stats.scanCount} product${stats.scanCount == 1 ? '' : 's'} scanned this week',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Map<int, _DailyData> _computeDailyStats(
      List<ScanResult> scans, DateTime startOfWeek) {
    final Map<int, _DailyData> daily = {};

    // Initialize all days
    for (int i = 0; i < 7; i++) {
      daily[i] = _DailyData(count: 0, totalScore: 0);
    }

    // Populate with scan data
    for (final scan in scans) {
      final dayIndex = scan.timestamp.difference(startOfWeek).inDays;
      if (dayIndex >= 0 && dayIndex < 7) {
        daily[dayIndex] = _DailyData(
          count: daily[dayIndex]!.count + 1,
          totalScore: daily[dayIndex]!.totalScore + scan.score,
        );
      }
    }

    return daily;
  }

  Widget _buildDailyChart(Map<int, _DailyData> dailyStats) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxCount =
        dailyStats.values.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final today = DateTime.now().weekday - 1; // 0 = Monday

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final data = dailyStats[index]!;
              final isToday = index == today;
              final avgScore =
                  data.count > 0 ? (data.totalScore / data.count).round() : 0;

              return Expanded(
                child: Column(
                  children: [
                    // Bar
                    Container(
                      height: 100,
                      alignment: Alignment.bottomCenter,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: maxCount > 0
                            ? (data.count / maxCount) * 80 + 20
                            : 20,
                        width: 32,
                        decoration: BoxDecoration(
                          color: isToday
                              ? const Color(0xFF00C17B)
                              : data.count > 0
                                  ? const Color(0xFF00C17B).withValues(alpha: 0.5)
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: data.count > 0
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${data.count}',
                                    style: TextStyle(
                                      color:
                                          isToday ? Colors.white : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (avgScore > 0)
                                    Text(
                                      '$avgScore',
                                      style: TextStyle(
                                        color: isToday
                                            ? Colors.white70
                                            : Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Day label
                    Text(
                      days[index],
                      style: TextStyle(
                        color: isToday ? const Color(0xFF00C17B) : Colors.grey,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C17B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text('Scans', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 16),
              const Text('(avg score)', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDistribution(List<ScanResult> scans) {
    // Count products in each grade range
    int gradeA = 0, gradeB = 0, gradeC = 0, gradeD = 0, gradeE = 0;
    for (final scan in scans) {
      if (scan.score >= 85) {
        gradeA++;
      } else if (scan.score >= 70) {
        gradeB++;
      } else if (scan.score >= 55) {
        gradeC++;
      } else if (scan.score >= 40) {
        gradeD++;
      } else {
        gradeE++;
      }
    }

    final total = scans.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildGradeBar('A', 'Excellent', gradeA, total, const Color(0xFF1B8A4E)),
          _buildGradeBar('B', 'Good', gradeB, total, const Color(0xFF7AC547)),
          _buildGradeBar('C', 'Moderate', gradeC, total, const Color(0xFFF9C74F)),
          _buildGradeBar('D', 'Poor', gradeD, total, const Color(0xFFED8936)),
          _buildGradeBar('E', 'Avoid', gradeE, total, const Color(0xFFE53E3E)),
        ],
      ),
    );
  }

  Widget _buildGradeBar(
      String grade, String label, int count, int total, Color color) {
    final percentage = total > 0 ? count / total : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Text(
              grade,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style:
                            const TextStyle(fontSize: 13, color: Colors.black87)),
                    Text('$count',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ScanResult scan, {required bool isGood}) {
    final color = isGood ? const Color(0xFF00C17B) : const Color(0xFFE53E3E);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product image or placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: scan.product.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      scan.product.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, e, s) =>
                          Icon(Icons.fastfood, color: Colors.grey.shade400),
                    ),
                  )
                : Icon(Icons.fastfood, color: Colors.grey.shade400),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan.product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  scan.product.brand,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Score badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${scan.score}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, _NutritionData> _computeNutritionInsights(List<ScanResult> scans) {
    final Map<String, _NutritionData> insights = {};

    // Aggregate nutrition data
    for (final scan in scans) {
      final nutriments = scan.product.nutriments;

      // Process key nutrients
      _addNutrient(insights, 'sugar', 'Sugars', nutriments['sugars_100g'], 'g');
      _addNutrient(insights, 'salt', 'Salt', nutriments['salt_100g'], 'g');
      _addNutrient(insights, 'fat', 'Fat', nutriments['fat_100g'], 'g');
      _addNutrient(insights, 'saturated', 'Saturated Fat',
          nutriments['saturated-fat_100g'], 'g');
      _addNutrient(
          insights, 'fiber', 'Fiber', nutriments['fiber_100g'], 'g');
      _addNutrient(
          insights, 'protein', 'Protein', nutriments['proteins_100g'], 'g');
      _addNutrient(
          insights, 'sodium', 'Sodium', nutriments['sodium_100g'], 'mg');
    }

    return insights;
  }

  void _addNutrient(Map<String, _NutritionData> insights, String key,
      String label, dynamic value, String unit) {
    if (value == null) return;
    final numValue = (value is num) ? value.toDouble() : double.tryParse(value.toString());
    if (numValue == null) return;

    if (insights.containsKey(key)) {
      insights[key] = _NutritionData(
        label: label,
        totalValue: insights[key]!.totalValue + numValue,
        count: insights[key]!.count + 1,
        unit: unit,
      );
    } else {
      insights[key] = _NutritionData(
        label: label,
        totalValue: numValue,
        count: 1,
        unit: unit,
      );
    }
  }

  Widget _buildNutritionInsights(Map<String, _NutritionData> insights) {
    // Define which nutrients are "bad" (should be low) vs "good" (should be high)
    const badNutrients = ['sugar', 'salt', 'fat', 'saturated', 'sodium'];
    const goodNutrients = ['fiber', 'protein'];

    final sortedKeys = insights.keys.toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: sortedKeys.map((key) {
          final data = insights[key]!;
          final avgValue = data.totalValue / data.count;
          final isGood = goodNutrients.contains(key);
          final isBad = badNutrients.contains(key);

          Color barColor;
          String status;

          if (isGood) {
            // For good nutrients, higher is better
            barColor = avgValue > 3 ? const Color(0xFF00C17B) : Colors.orange;
            status = avgValue > 3 ? '✓ Good' : 'Could be higher';
          } else if (isBad) {
            // For bad nutrients, lower is better
            if (key == 'sugar') {
              barColor = avgValue < 5 ? const Color(0xFF00C17B) : avgValue < 12 ? Colors.orange : const Color(0xFFE53E3E);
              status = avgValue < 5 ? '✓ Low' : avgValue < 12 ? 'Moderate' : '⚠ High';
            } else if (key == 'salt' || key == 'sodium') {
              barColor = avgValue < 0.3 ? const Color(0xFF00C17B) : avgValue < 1.5 ? Colors.orange : const Color(0xFFE53E3E);
              status = avgValue < 0.3 ? '✓ Low' : avgValue < 1.5 ? 'Moderate' : '⚠ High';
            } else {
              barColor = avgValue < 3 ? const Color(0xFF00C17B) : avgValue < 10 ? Colors.orange : const Color(0xFFE53E3E);
              status = avgValue < 3 ? '✓ Low' : avgValue < 10 ? 'Moderate' : '⚠ High';
            }
          } else {
            barColor = Colors.grey;
            status = '';
          }

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    data.label,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${avgValue.toStringAsFixed(1)}${data.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: barColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(avg)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 11,
                      color: barColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTipsCard() {
    final tips = _getTipsForGrade(stats.grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tips.map((tip) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C17B),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  List<String> _getTipsForGrade(String grade) {
    switch (grade) {
      case 'A':
        return [
          'Excellent choices! Keep up the great work.',
          'You\'re making smart nutritional decisions.',
          'Share your healthy picks with friends and family!',
        ];
      case 'B':
        return [
          'Good job! You\'re on the right track.',
          'Try replacing one "C" or "D" grade product with an "A" grade alternative.',
          'Check the sugar content on packaged foods.',
        ];
      case 'C':
        return [
          'There\'s room for improvement.',
          'Focus on reducing processed foods in your diet.',
          'Look for products with less added sugar and salt.',
          'Choose whole grain options when available.',
        ];
      case 'D':
        return [
          'Consider making some healthier swaps.',
          'Try fresh fruits instead of sugary snacks.',
          'Read nutrition labels before purchasing.',
          'Opt for products with shorter ingredient lists.',
        ];
      case 'E':
        return [
          'Time to rethink your food choices.',
          'Start by replacing one unhealthy item per week.',
          'Prioritize whole, unprocessed foods.',
          'Consider meal planning to make healthier choices easier.',
        ];
      default:
        return [
          'Start scanning products to get personalized recommendations!',
          'Scan items before adding them to your cart.',
          'Compare similar products to find healthier options.',
        ];
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
        return const Color(0xFF1B8A4E);
      case 'B':
        return const Color(0xFF7AC547);
      case 'C':
        return const Color(0xFFF9C74F);
      case 'D':
        return const Color(0xFFED8936);
      case 'E':
        return const Color(0xFFE53E3E);
      default:
        return Colors.grey;
    }
  }
}

class _DailyData {
  final int count;
  final int totalScore;

  _DailyData({required this.count, required this.totalScore});
}

class _NutritionData {
  final String label;
  final double totalValue;
  final int count;
  final String unit;

  _NutritionData({
    required this.label,
    required this.totalValue,
    required this.count,
    required this.unit,
  });
}
