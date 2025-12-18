import 'package:flutter/material.dart';

/// Dietary label info for display
class DietaryLabelInfo {
  final String displayName;
  final IconData icon;
  final Color color;
  final bool isPresent; // true = has label, false = doesn't have label

  const DietaryLabelInfo({
    required this.displayName,
    required this.icon,
    required this.color,
    this.isPresent = true,
  });
}

/// Known dietary labels map
const _dietaryLabelMap = {
  // Religious certifications
  'en:halal': ('Halal', Icons.verified, Color(0xFF009688)),
  'en:kosher': ('Kosher', Icons.star, Color(0xFF3F51B5)),
  // Dietary preferences
  'en:vegan': ('Vegan', Icons.eco, Color(0xFF4CAF50)),
  'en:vegetarian': ('Vegetarian', Icons.grass, Color(0xFF8BC34A)),
  // Allergen-free
  'en:gluten-free': ('Gluten Free', Icons.no_food, Color(0xFFFF9800)),
  'en:no-gluten': ('Gluten Free', Icons.no_food, Color(0xFFFF9800)),
  'en:lactose-free': ('Lactose Free', Icons.no_drinks, Color(0xFF2196F3)),
  'en:no-lactose': ('Lactose Free', Icons.no_drinks, Color(0xFF2196F3)),
  // Organic
  'en:organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  'en:eu-organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  'en:usda-organic': ('Organic', Icons.spa, Color(0xFF66BB6A)),
  // Other
  'en:fair-trade': ('Fair Trade', Icons.handshake, Color(0xFF607D8B)),
  'en:palm-oil-free': ('Palm Oil Free', Icons.nature, Color(0xFF795548)),
  'en:no-palm-oil': ('Palm Oil Free', Icons.nature, Color(0xFF795548)),
};

/// Parse dietary labels - shows only labels that ARE present
List<DietaryLabelInfo> parseDietaryLabels(List<String> labels) {
  final List<DietaryLabelInfo> result = [];
  final addedTypes =
      <String>{}; // Avoid duplicates (e.g., multiple organic labels)

  for (final tag in labels) {
    final normalized = tag.toLowerCase();
    if (_dietaryLabelMap.containsKey(normalized)) {
      final (name, icon, color) = _dietaryLabelMap[normalized]!;
      // Avoid duplicate types
      if (!addedTypes.contains(name)) {
        result.add(
          DietaryLabelInfo(
            displayName: name,
            icon: icon,
            color: color,
            isPresent: true,
          ),
        );
        addedTypes.add(name);
      }
    }
  }

  return result;
}

class ProductTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int score;
  final DateTime? timestamp;
  final VoidCallback? onTap;
  final List<String> labels;
  const ProductTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.score,
    this.timestamp,
    this.onTap,
    this.labels = const [],
  });

  String get _grade {
    if (score >= 85) return 'A';
    if (score >= 70) return 'B';
    if (score >= 55) return 'C';
    if (score >= 40) return 'D';
    return 'E';
  }

  Color get _gradeColor {
    switch (_grade) {
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

  Color get _gradeBgColor {
    switch (_grade) {
      case 'A':
        return const Color(0xFFE8F5EE);
      case 'B':
        return const Color(0xFFF0F9E8);
      case 'C':
        return const Color(0xFFFFFBEB);
      case 'D':
        return const Color(0xFFFFF4E6);
      case 'E':
        return const Color(0xFFFEE9E9);
      default:
        return Colors.grey.shade100;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      // Format as date
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dietaryLabels = parseDietaryLabels(labels);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : _gradeBgColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: _gradeColor.withValues(alpha: isDark ? 0.25 : 0.15),
                ),
                alignment: Alignment.center,
                child: Text(
                  _grade,
                  style: TextStyle(
                    color: _gradeColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timestamp != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(timestamp!),
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show dietary info - only if labels exist from API
                    const SizedBox(height: 4),
                    if (labels.isEmpty)
                      Text(
                        'No dietary info',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: dietaryLabels
                            .take(4)
                            .map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: label.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      label.isPresent
                                          ? Icons.check
                                          : Icons.close,
                                      size: 10,
                                      color: label.color,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      label.displayName,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: label.color,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _gradeColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  score.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
