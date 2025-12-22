/// Domain entity representing a restaurant
class Restaurant {
  final String id;
  final String name;
  final String? logoUrl;
  final String category; // fast-food, casual, fine-dining, etc.
  final List<MenuItem> menuItems;
  final bool isVerified; // Pre-loaded = true, user-contributed = false
  final String? contributedBy; // User ID who added it
  final DateTime createdAt;
  final int usageCount; // How many times users selected dishes from this

  Restaurant({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.category,
    required this.menuItems,
    this.isVerified = false,
    this.contributedBy,
    DateTime? createdAt,
    this.usageCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logoUrl': logoUrl,
    'category': category,
    'menuItems': menuItems.map((m) => m.toJson()).toList(),
    'isVerified': isVerified,
    'contributedBy': contributedBy,
    'createdAt': createdAt.toIso8601String(),
    'usageCount': usageCount,
  };

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String?,
      category: json['category'] as String? ?? 'other',
      menuItems: (json['menuItems'] as List<dynamic>?)
          ?.map((m) => MenuItem.fromJson(m as Map<String, dynamic>))
          .toList() ?? [],
      isVerified: json['isVerified'] as bool? ?? false,
      contributedBy: json['contributedBy'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      usageCount: json['usageCount'] as int? ?? 0,
    );
  }

  Restaurant copyWith({
    String? id,
    String? name,
    String? logoUrl,
    String? category,
    List<MenuItem>? menuItems,
    bool? isVerified,
    String? contributedBy,
    DateTime? createdAt,
    int? usageCount,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      logoUrl: logoUrl ?? this.logoUrl,
      category: category ?? this.category,
      menuItems: menuItems ?? this.menuItems,
      isVerified: isVerified ?? this.isVerified,
      contributedBy: contributedBy ?? this.contributedBy,
      createdAt: createdAt ?? this.createdAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

/// A single menu item at a restaurant
class MenuItem {
  final String id;
  final String name;
  final String? description;
  final String? category; // burgers, salads, drinks, etc.
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final int? sodium;
  final double? price;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    this.category,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.sodium,
    this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sodium': sodium,
    'price': price,
  };

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      calories: json['calories'] as int?,
      protein: json['protein'] as int?,
      carbs: json['carbs'] as int?,
      fat: json['fat'] as int?,
      sodium: json['sodium'] as int?,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

/// Restaurant categories
class RestaurantCategory {
  static const String fastFood = 'fast-food';
  static const String casual = 'casual';
  static const String fineDining = 'fine-dining';
  static const String cafe = 'cafe';
  static const String pizza = 'pizza';
  static const String mexican = 'mexican';
  static const String asian = 'asian';
  static const String other = 'other';

  static String getDisplayName(String category) {
    switch (category) {
      case fastFood: return 'Fast Food';
      case casual: return 'Casual Dining';
      case fineDining: return 'Fine Dining';
      case cafe: return 'Cafe & Coffee';
      case pizza: return 'Pizza';
      case mexican: return 'Mexican';
      case asian: return 'Asian';
      default: return 'Other';
    }
  }

  static String getEmoji(String category) {
    switch (category) {
      case fastFood: return '🍔';
      case casual: return '🍽️';
      case fineDining: return '🥂';
      case cafe: return '☕';
      case pizza: return '🍕';
      case mexican: return '🌮';
      case asian: return '🍜';
      default: return '🍴';
    }
  }

  static List<String> all = [
    fastFood, casual, fineDining, cafe, pizza, mexican, asian, other
  ];
}
