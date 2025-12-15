import '../entities/product.dart';

class ComputeHealthScore {
  // Compute a simple heuristic 0-100 score from nutriments map.
  // Lower sugar, saturated fat, and salt produce higher scores.
  int call(Product p) {
    final n = p.nutriments;
    double sugar = _toDouble(n['sugars_100g']);
    double satFat = _toDouble(n['saturated-fat_100g']);
    double salt = _toDouble(n['salt_100g']);
    // Basic heuristic weights
    double score = 100;
    score -= sugar * 2.0; // sugars penalized moderately
    score -= satFat * 4.0; // saturated fat penalized more
    score -= salt * 6.0; // salt is heavily penalized (g per 100g)
    // apply clamp
    if (score < 0) score = 0;
    if (score > 100) score = 100;
    return score.round();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    try {
      return double.parse(v.toString());
    } catch (_) {
      return 0.0;
    }
  }
}
