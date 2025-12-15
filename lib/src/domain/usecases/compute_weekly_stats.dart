import '../entities/scan_result.dart';

/// Weekly statistics computed from scan history.
class WeeklyStats {
  /// Average score of all scans this week (0-100)
  final double averageScore;
  
  /// Number of products scanned this week
  final int scanCount;
  
  /// Grade based on Nutri-Score style (A-E)
  final String grade;
  
  /// Description of the grade
  final String gradeDescription;

  const WeeklyStats({
    required this.averageScore,
    required this.scanCount,
    required this.grade,
    required this.gradeDescription,
  });

  /// Empty stats when no scans are available
  static const empty = WeeklyStats(
    averageScore: 0,
    scanCount: 0,
    grade: '-',
    gradeDescription: 'No scans yet',
  );
}

/// Use case to compute weekly statistics from scan history.
class ComputeWeeklyStats {
  /// Computes weekly stats using the simple average method.
  /// 
  /// Filters scans to only include those from the current week (Monday-Sunday),
  /// then calculates the average score and assigns a Nutri-Score style grade.
  WeeklyStats call(List<ScanResult> scans) {
    if (scans.isEmpty) return WeeklyStats.empty;

    // Get start of current week (Monday)
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: weekday - 1));
    
    // Filter scans from this week
    final weeklyScans = scans.where((s) {
      return s.timestamp.isAfter(startOfWeek) || 
             s.timestamp.isAtSameMomentAs(startOfWeek);
    }).toList();

    if (weeklyScans.isEmpty) return WeeklyStats.empty;

    // Calculate simple average
    final totalScore = weeklyScans.fold<int>(0, (sum, s) => sum + s.score);
    final averageScore = totalScore / weeklyScans.length;

    // Determine grade based on Nutri-Score style
    final (grade, description) = _getGrade(averageScore);

    return WeeklyStats(
      averageScore: averageScore,
      scanCount: weeklyScans.length,
      grade: grade,
      gradeDescription: description,
    );
  }

  /// Returns grade and description based on score.
  /// A: 85-100 (Excellent)
  /// B: 70-84 (Good)
  /// C: 55-69 (Moderate)
  /// D: 40-54 (Poor)
  /// E: 0-39 (Avoid)
  (String, String) _getGrade(double score) {
    if (score >= 85) return ('A', 'Excellent');
    if (score >= 70) return ('B', 'Good');
    if (score >= 55) return ('C', 'Moderate');
    if (score >= 40) return ('D', 'Poor');
    return ('E', 'Avoid');
  }
}
