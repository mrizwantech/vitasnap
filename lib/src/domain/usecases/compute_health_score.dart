import '../entities/product.dart';

class ComputeHealthScore {
  /// Compute health score using Nutri-Score if available,
  /// otherwise fall back to a heuristic based on nutriments.
  /// 
  /// Nutri-Score mapping: A=100, B=75, C=50, D=25, E=0
  int call(Product p) {
    // Prefer official Nutri-Score from OpenFoodFacts
    if (p.nutriscoreGrade != null && p.nutriscoreGrade!.isNotEmpty) {
      return p.nutriScoreValue;
    }
    
    // Fallback: compute heuristic score from nutriments
    return _computeFromNutriments(p.nutriments);
  }

  /// Fallback heuristic: 0-100 score based on sugar, saturated fat, salt
  int _computeFromNutriments(Map<String, dynamic> n) {
    if (n.isEmpty) {
      return 50; // Neutral score if no data
    }
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
