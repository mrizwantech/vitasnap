import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/restaurant.dart';

/// Service for managing community restaurant database
/// Falls back to local hardcoded data when Firestore is unavailable
class RestaurantDatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _collection = 'restaurants';

  /// Cached local restaurants for offline fallback
  List<Restaurant>? _cachedLocalRestaurants;

  /// Get all restaurants (popular first, then by usage)
  /// Falls back to local data if Firestore fails
  Future<List<Restaurant>> getRestaurants({
    String? category,
    String? searchQuery,
    int limit = 50,
  }) async {
    try {
      // Simple query without compound index requirement
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collection)
          .limit(limit);

      if (category != null && category.isNotEmpty) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();

      var restaurants = snapshot.docs
          .map((doc) => Restaurant.fromJson(doc.data()))
          .toList();

      // If Firestore returned no results, use local fallback
      if (restaurants.isEmpty) {
        debugPrint(
          'DEBUG: Firestore returned no restaurants, using local fallback',
        );
        restaurants = _getLocalRestaurants();
      }

      // Sort locally: verified first, then by usage count
      restaurants.sort((a, b) {
        if (a.isVerified != b.isVerified) {
          return a.isVerified ? -1 : 1;
        }
        return b.usageCount.compareTo(a.usageCount);
      });

      // Filter by search query locally (Firestore doesn't support LIKE)
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        restaurants = restaurants
            .where((r) => r.name.toLowerCase().contains(lowerQuery))
            .toList();
      }

      return restaurants;
    } catch (e) {
      debugPrint('DEBUG: Firestore error, using local fallback: $e');
      return _getLocalRestaurantsFiltered(
        category: category,
        searchQuery: searchQuery,
      );
    }
  }

  /// Search restaurants by name
  /// Falls back to local data if Firestore fails
  Future<List<Restaurant>> searchRestaurants(String query) async {
    if (query.isEmpty) return getRestaurants();

    try {
      // Get all restaurants and filter (Firestore limitation)
      final snapshot = await _firestore
          .collection(_collection)
          .limit(100)
          .get();

      var restaurants = snapshot.docs
          .map((doc) => Restaurant.fromJson(doc.data()))
          .toList();

      // If Firestore returned no results, use local fallback
      if (restaurants.isEmpty) {
        restaurants = _getLocalRestaurants();
      }

      final lowerQuery = query.toLowerCase();
      return restaurants
          .where((r) => r.name.toLowerCase().contains(lowerQuery))
          .toList();
    } catch (e) {
      debugPrint('DEBUG: Firestore search error, using local fallback: $e');
      return _getLocalRestaurantsFiltered(searchQuery: query);
    }
  }

  /// Get local restaurants filtered by criteria
  List<Restaurant> _getLocalRestaurantsFiltered({
    String? category,
    String? searchQuery,
  }) {
    var restaurants = _getLocalRestaurants();

    if (category != null && category.isNotEmpty) {
      restaurants = restaurants
          .where((r) => r.category.toLowerCase() == category.toLowerCase())
          .toList();
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      restaurants = restaurants
          .where((r) => r.name.toLowerCase().contains(lowerQuery))
          .toList();
    }

    return restaurants;
  }

  /// Get local restaurants (cached after first call)
  List<Restaurant> _getLocalRestaurants() {
    _cachedLocalRestaurants ??= _getPopularRestaurants();
    return _cachedLocalRestaurants!;
  }

  /// Get a single restaurant by ID
  /// Falls back to local data if Firestore fails
  Future<Restaurant?> getRestaurant(String id) async {
    try {
      final doc = await _firestore.collection(_collection).doc(id).get();
      if (!doc.exists) {
        // Try local fallback
        final local = _getLocalRestaurants();
        return local.where((r) => r.id == id).firstOrNull;
      }
      return Restaurant.fromJson(doc.data()!);
    } catch (e) {
      debugPrint(
        'DEBUG: Firestore getRestaurant error, using local fallback: $e',
      );
      final local = _getLocalRestaurants();
      return local.where((r) => r.id == id).firstOrNull;
    }
  }

  /// Add a new restaurant (user contribution)
  Future<String> addRestaurant(Restaurant restaurant) async {
    try {
      final docRef = _firestore.collection(_collection).doc(restaurant.id);
      await docRef.set(restaurant.toJson());
      return restaurant.id;
    } catch (e) {
      debugPrint('DEBUG: Failed to add restaurant to Firestore: $e');
      // Return the ID anyway - the restaurant won't persist but the app won't crash
      return restaurant.id;
    }
  }

  /// Add menu items to an existing restaurant
  Future<void> addMenuItems(String restaurantId, List<MenuItem> items) async {
    try {
      final doc = await _firestore
          .collection(_collection)
          .doc(restaurantId)
          .get();
      if (!doc.exists) return;

      final restaurant = Restaurant.fromJson(doc.data()!);
      final updatedItems = [...restaurant.menuItems, ...items];

      await _firestore.collection(_collection).doc(restaurantId).update({
        'menuItems': updatedItems.map((m) => m.toJson()).toList(),
      });
    } catch (e) {
      debugPrint('DEBUG: Failed to add menu items to Firestore: $e');
    }
  }

  /// Increment usage count when user selects a dish
  Future<void> incrementUsage(String restaurantId) async {
    try {
      await _firestore.collection(_collection).doc(restaurantId).update({
        'usageCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('DEBUG: Failed to increment usage in Firestore: $e');
    }
  }

  /// Seed popular restaurants (call once to initialize)
  /// Silently fails if Firestore is unavailable - local data will be used as fallback
  Future<void> seedPopularRestaurants() async {
    try {
      debugPrint('DEBUG: Checking if restaurants already seeded...');
      final existing = await _firestore.collection(_collection).limit(1).get();
      if (existing.docs.isNotEmpty) {
        debugPrint('DEBUG: Restaurants already seeded, skipping');
        return;
      }

      debugPrint('DEBUG: No restaurants found, seeding now...');
      final restaurants = _getPopularRestaurants();
      final batch = _firestore.batch();

      for (final restaurant in restaurants) {
        final docRef = _firestore.collection(_collection).doc(restaurant.id);
        batch.set(docRef, restaurant.toJson());
      }

      await batch.commit();
      debugPrint('DEBUG: Seeded ${restaurants.length} restaurants');
    } catch (e) {
      debugPrint(
        'DEBUG: Failed to seed restaurants to Firestore (using local fallback): $e',
      );
      // Local fallback will be used via getRestaurants() - no action needed
    }
  }

  /// Pre-loaded popular restaurant chains with menu items
  List<Restaurant> _getPopularRestaurants() {
    return [
      Restaurant(
        id: 'mcdonalds',
        name: "McDonald's",
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'mcd_1',
            name: 'Big Mac',
            category: 'Burgers',
            calories: 550,
            protein: 25,
            carbs: 45,
            fat: 30,
            sodium: 1010,
          ),
          MenuItem(
            id: 'mcd_2',
            name: 'Quarter Pounder with Cheese',
            category: 'Burgers',
            calories: 520,
            protein: 30,
            carbs: 42,
            fat: 26,
            sodium: 1140,
          ),
          MenuItem(
            id: 'mcd_3',
            name: 'McChicken',
            category: 'Chicken',
            calories: 400,
            protein: 14,
            carbs: 40,
            fat: 21,
            sodium: 560,
          ),
          MenuItem(
            id: 'mcd_4',
            name: 'Filet-O-Fish',
            category: 'Fish',
            calories: 390,
            protein: 16,
            carbs: 39,
            fat: 19,
            sodium: 580,
          ),
          MenuItem(
            id: 'mcd_5',
            name: 'Chicken McNuggets (10pc)',
            category: 'Chicken',
            calories: 420,
            protein: 22,
            carbs: 26,
            fat: 25,
            sodium: 900,
          ),
          MenuItem(
            id: 'mcd_6',
            name: 'Medium Fries',
            category: 'Sides',
            calories: 320,
            protein: 5,
            carbs: 43,
            fat: 15,
            sodium: 260,
          ),
          MenuItem(
            id: 'mcd_7',
            name: 'McFlurry with Oreo',
            category: 'Desserts',
            calories: 510,
            protein: 12,
            carbs: 80,
            fat: 17,
            sodium: 280,
          ),
          MenuItem(
            id: 'mcd_8',
            name: 'Egg McMuffin',
            category: 'Breakfast',
            calories: 310,
            protein: 17,
            carbs: 30,
            fat: 13,
            sodium: 770,
          ),
          MenuItem(
            id: 'mcd_9',
            name: 'Southwest Salad with Grilled Chicken',
            category: 'Salads',
            calories: 350,
            protein: 37,
            carbs: 27,
            fat: 11,
            sodium: 1070,
          ),
        ],
      ),
      Restaurant(
        id: 'subway',
        name: 'Subway',
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'sub_1',
            name: 'Turkey Breast 6"',
            category: 'Subs',
            calories: 280,
            protein: 18,
            carbs: 46,
            fat: 3,
            sodium: 810,
          ),
          MenuItem(
            id: 'sub_2',
            name: 'Italian B.M.T. 6"',
            category: 'Subs',
            calories: 410,
            protein: 20,
            carbs: 47,
            fat: 16,
            sodium: 1280,
          ),
          MenuItem(
            id: 'sub_3',
            name: 'Chicken Teriyaki 6"',
            category: 'Subs',
            calories: 340,
            protein: 26,
            carbs: 51,
            fat: 5,
            sodium: 880,
          ),
          MenuItem(
            id: 'sub_4',
            name: 'Veggie Delite 6"',
            category: 'Subs',
            calories: 200,
            protein: 8,
            carbs: 44,
            fat: 1,
            sodium: 280,
          ),
          MenuItem(
            id: 'sub_5',
            name: 'Tuna 6"',
            category: 'Subs',
            calories: 480,
            protein: 20,
            carbs: 46,
            fat: 24,
            sodium: 640,
          ),
          MenuItem(
            id: 'sub_6',
            name: 'Meatball Marinara 6"',
            category: 'Subs',
            calories: 480,
            protein: 22,
            carbs: 53,
            fat: 20,
            sodium: 960,
          ),
          MenuItem(
            id: 'sub_7',
            name: 'Rotisserie Chicken 6"',
            category: 'Subs',
            calories: 350,
            protein: 29,
            carbs: 45,
            fat: 6,
            sodium: 750,
          ),
        ],
      ),
      Restaurant(
        id: 'chipotle',
        name: 'Chipotle',
        category: RestaurantCategory.mexican,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'chip_1',
            name: 'Chicken Burrito',
            category: 'Burritos',
            calories: 1005,
            protein: 54,
            carbs: 105,
            fat: 40,
            sodium: 2150,
          ),
          MenuItem(
            id: 'chip_2',
            name: 'Steak Burrito Bowl',
            category: 'Bowls',
            calories: 625,
            protein: 40,
            carbs: 42,
            fat: 31,
            sodium: 1570,
          ),
          MenuItem(
            id: 'chip_3',
            name: 'Chicken Tacos (3)',
            category: 'Tacos',
            calories: 555,
            protein: 36,
            carbs: 42,
            fat: 24,
            sodium: 1170,
          ),
          MenuItem(
            id: 'chip_4',
            name: 'Veggie Bowl',
            category: 'Bowls',
            calories: 535,
            protein: 15,
            carbs: 72,
            fat: 22,
            sodium: 1130,
          ),
          MenuItem(
            id: 'chip_5',
            name: 'Carnitas Burrito',
            category: 'Burritos',
            calories: 1055,
            protein: 47,
            carbs: 105,
            fat: 46,
            sodium: 2070,
          ),
          MenuItem(
            id: 'chip_6',
            name: 'Chips & Guacamole',
            category: 'Sides',
            calories: 770,
            protein: 10,
            carbs: 81,
            fat: 47,
            sodium: 600,
          ),
          MenuItem(
            id: 'chip_7',
            name: 'Sofritas Bowl',
            category: 'Bowls',
            calories: 545,
            protein: 17,
            carbs: 55,
            fat: 28,
            sodium: 1340,
          ),
        ],
      ),
      Restaurant(
        id: 'chickfila',
        name: 'Chick-fil-A',
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'cfa_1',
            name: 'Chick-fil-A Chicken Sandwich',
            category: 'Sandwiches',
            calories: 440,
            protein: 28,
            carbs: 40,
            fat: 19,
            sodium: 1350,
          ),
          MenuItem(
            id: 'cfa_2',
            name: 'Spicy Chicken Sandwich',
            category: 'Sandwiches',
            calories: 450,
            protein: 28,
            carbs: 41,
            fat: 19,
            sodium: 1620,
          ),
          MenuItem(
            id: 'cfa_3',
            name: 'Grilled Chicken Sandwich',
            category: 'Sandwiches',
            calories: 320,
            protein: 28,
            carbs: 41,
            fat: 6,
            sodium: 800,
          ),
          MenuItem(
            id: 'cfa_4',
            name: 'Chicken Nuggets (8pc)',
            category: 'Nuggets',
            calories: 250,
            protein: 27,
            carbs: 11,
            fat: 11,
            sodium: 1090,
          ),
          MenuItem(
            id: 'cfa_5',
            name: 'Waffle Fries (Medium)',
            category: 'Sides',
            calories: 420,
            protein: 5,
            carbs: 45,
            fat: 24,
            sodium: 240,
          ),
          MenuItem(
            id: 'cfa_6',
            name: 'Cobb Salad',
            category: 'Salads',
            calories: 510,
            protein: 42,
            carbs: 28,
            fat: 27,
            sodium: 1310,
          ),
          MenuItem(
            id: 'cfa_7',
            name: 'Grilled Nuggets (8pc)',
            category: 'Nuggets',
            calories: 130,
            protein: 25,
            carbs: 1,
            fat: 3,
            sodium: 440,
          ),
        ],
      ),
      Restaurant(
        id: 'wendys',
        name: "Wendy's",
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'wen_1',
            name: 'Dave\'s Single',
            category: 'Burgers',
            calories: 570,
            protein: 30,
            carbs: 39,
            fat: 34,
            sodium: 1130,
          ),
          MenuItem(
            id: 'wen_2',
            name: 'Baconator',
            category: 'Burgers',
            calories: 950,
            protein: 57,
            carbs: 38,
            fat: 66,
            sodium: 1750,
          ),
          MenuItem(
            id: 'wen_3',
            name: 'Spicy Chicken Sandwich',
            category: 'Chicken',
            calories: 500,
            protein: 27,
            carbs: 48,
            fat: 22,
            sodium: 1080,
          ),
          MenuItem(
            id: 'wen_4',
            name: 'Grilled Chicken Sandwich',
            category: 'Chicken',
            calories: 370,
            protein: 34,
            carbs: 36,
            fat: 10,
            sodium: 820,
          ),
          MenuItem(
            id: 'wen_5',
            name: 'Medium Fries',
            category: 'Sides',
            calories: 350,
            protein: 4,
            carbs: 47,
            fat: 16,
            sodium: 320,
          ),
          MenuItem(
            id: 'wen_6',
            name: 'Apple Pecan Salad',
            category: 'Salads',
            calories: 560,
            protein: 38,
            carbs: 35,
            fat: 30,
            sodium: 1010,
          ),
          MenuItem(
            id: 'wen_7',
            name: 'Frosty (Medium)',
            category: 'Desserts',
            calories: 460,
            protein: 11,
            carbs: 75,
            fat: 12,
            sodium: 230,
          ),
        ],
      ),
      Restaurant(
        id: 'tacobell',
        name: 'Taco Bell',
        category: RestaurantCategory.mexican,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'tb_1',
            name: 'Crunchy Taco',
            category: 'Tacos',
            calories: 170,
            protein: 8,
            carbs: 13,
            fat: 10,
            sodium: 310,
          ),
          MenuItem(
            id: 'tb_2',
            name: 'Burrito Supreme - Beef',
            category: 'Burritos',
            calories: 400,
            protein: 16,
            carbs: 52,
            fat: 14,
            sodium: 1090,
          ),
          MenuItem(
            id: 'tb_3',
            name: 'Crunchwrap Supreme',
            category: 'Specialties',
            calories: 530,
            protein: 16,
            carbs: 71,
            fat: 21,
            sodium: 1200,
          ),
          MenuItem(
            id: 'tb_4',
            name: 'Quesadilla - Chicken',
            category: 'Quesadillas',
            calories: 500,
            protein: 27,
            carbs: 38,
            fat: 27,
            sodium: 1180,
          ),
          MenuItem(
            id: 'tb_5',
            name: 'Nachos BellGrande',
            category: 'Specialties',
            calories: 740,
            protein: 16,
            carbs: 82,
            fat: 38,
            sodium: 1050,
          ),
          MenuItem(
            id: 'tb_6',
            name: 'Bean Burrito',
            category: 'Burritos',
            calories: 380,
            protein: 14,
            carbs: 55,
            fat: 11,
            sodium: 1060,
          ),
          MenuItem(
            id: 'tb_7',
            name: 'Power Menu Bowl - Veggie',
            category: 'Bowls',
            calories: 430,
            protein: 12,
            carbs: 57,
            fat: 18,
            sodium: 960,
          ),
        ],
      ),
      Restaurant(
        id: 'starbucks',
        name: 'Starbucks',
        category: RestaurantCategory.cafe,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'sbux_1',
            name: 'Caffè Latte (Grande)',
            category: 'Drinks',
            calories: 190,
            protein: 13,
            carbs: 19,
            fat: 7,
            sodium: 170,
          ),
          MenuItem(
            id: 'sbux_2',
            name: 'Caramel Macchiato (Grande)',
            category: 'Drinks',
            calories: 250,
            protein: 10,
            carbs: 35,
            fat: 7,
            sodium: 150,
          ),
          MenuItem(
            id: 'sbux_3',
            name: 'Iced Coffee (Grande)',
            category: 'Drinks',
            calories: 80,
            protein: 1,
            carbs: 20,
            fat: 0,
            sodium: 15,
          ),
          MenuItem(
            id: 'sbux_4',
            name: 'Bacon & Gouda Sandwich',
            category: 'Food',
            calories: 370,
            protein: 18,
            carbs: 34,
            fat: 18,
            sodium: 770,
          ),
          MenuItem(
            id: 'sbux_5',
            name: 'Spinach & Feta Wrap',
            category: 'Food',
            calories: 290,
            protein: 19,
            carbs: 34,
            fat: 10,
            sodium: 840,
          ),
          MenuItem(
            id: 'sbux_6',
            name: 'Chocolate Croissant',
            category: 'Bakery',
            calories: 340,
            protein: 6,
            carbs: 38,
            fat: 18,
            sodium: 260,
          ),
          MenuItem(
            id: 'sbux_7',
            name: 'Protein Box - Eggs & Cheese',
            category: 'Food',
            calories: 470,
            protein: 25,
            carbs: 40,
            fat: 24,
            sodium: 810,
          ),
        ],
      ),
      Restaurant(
        id: 'panerabread',
        name: 'Panera Bread',
        category: RestaurantCategory.casual,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'pan_1',
            name: 'Broccoli Cheddar Soup (Bowl)',
            category: 'Soups',
            calories: 360,
            protein: 14,
            carbs: 29,
            fat: 21,
            sodium: 1220,
          ),
          MenuItem(
            id: 'pan_2',
            name: 'Caesar Salad with Chicken',
            category: 'Salads',
            calories: 470,
            protein: 35,
            carbs: 23,
            fat: 27,
            sodium: 830,
          ),
          MenuItem(
            id: 'pan_3',
            name: 'Turkey & Avocado BLT',
            category: 'Sandwiches',
            calories: 620,
            protein: 32,
            carbs: 56,
            fat: 30,
            sodium: 1610,
          ),
          MenuItem(
            id: 'pan_4',
            name: 'Mediterranean Veggie Sandwich',
            category: 'Sandwiches',
            calories: 520,
            protein: 16,
            carbs: 58,
            fat: 25,
            sodium: 1210,
          ),
          MenuItem(
            id: 'pan_5',
            name: 'Mac & Cheese (Bowl)',
            category: 'Pasta',
            calories: 990,
            protein: 34,
            carbs: 97,
            fat: 50,
            sodium: 1940,
          ),
          MenuItem(
            id: 'pan_6',
            name: 'Greek Salad',
            category: 'Salads',
            calories: 390,
            protein: 6,
            carbs: 15,
            fat: 35,
            sodium: 1000,
          ),
          MenuItem(
            id: 'pan_7',
            name: 'Chicken Noodle Soup (Bowl)',
            category: 'Soups',
            calories: 160,
            protein: 14,
            carbs: 16,
            fat: 5,
            sodium: 1200,
          ),
        ],
      ),
      Restaurant(
        id: 'dominos',
        name: "Domino's Pizza",
        category: RestaurantCategory.pizza,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'dom_1',
            name: 'Pepperoni Pizza (Medium, 2 slices)',
            category: 'Pizza',
            calories: 440,
            protein: 18,
            carbs: 50,
            fat: 18,
            sodium: 1040,
          ),
          MenuItem(
            id: 'dom_2',
            name: 'Cheese Pizza (Medium, 2 slices)',
            category: 'Pizza',
            calories: 380,
            protein: 14,
            carbs: 50,
            fat: 12,
            sodium: 800,
          ),
          MenuItem(
            id: 'dom_3',
            name: 'Buffalo Chicken Pizza (Medium, 2 slices)',
            category: 'Pizza',
            calories: 420,
            protein: 18,
            carbs: 48,
            fat: 16,
            sodium: 1180,
          ),
          MenuItem(
            id: 'dom_4',
            name: 'Breadsticks (8pc)',
            category: 'Sides',
            calories: 580,
            protein: 16,
            carbs: 92,
            fat: 16,
            sodium: 1020,
          ),
          MenuItem(
            id: 'dom_5',
            name: 'Chicken Wings (8pc)',
            category: 'Sides',
            calories: 720,
            protein: 48,
            carbs: 4,
            fat: 56,
            sodium: 2640,
          ),
          MenuItem(
            id: 'dom_6',
            name: 'Garden Salad',
            category: 'Salads',
            calories: 70,
            protein: 4,
            carbs: 8,
            fat: 3,
            sodium: 180,
          ),
        ],
      ),
      Restaurant(
        id: 'culvers',
        name: "Culver's",
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'cul_1',
            name: 'ButterBurger (Single)',
            category: 'Burgers',
            calories: 390,
            protein: 22,
            carbs: 36,
            fat: 17,
            sodium: 670,
          ),
          MenuItem(
            id: 'cul_2',
            name: 'ButterBurger Deluxe (Double)',
            category: 'Burgers',
            calories: 680,
            protein: 40,
            carbs: 40,
            fat: 41,
            sodium: 1140,
          ),
          MenuItem(
            id: 'cul_3',
            name: 'Wisconsin Swiss Melt',
            category: 'Burgers',
            calories: 580,
            protein: 34,
            carbs: 37,
            fat: 33,
            sodium: 1020,
          ),
          MenuItem(
            id: 'cul_4',
            name: 'Chicken Tenders (4pc)',
            category: 'Chicken',
            calories: 470,
            protein: 36,
            carbs: 24,
            fat: 26,
            sodium: 1130,
          ),
          MenuItem(
            id: 'cul_5',
            name: 'Crinkle Cut Fries (Regular)',
            category: 'Sides',
            calories: 320,
            protein: 4,
            carbs: 45,
            fat: 14,
            sodium: 550,
          ),
          MenuItem(
            id: 'cul_6',
            name: 'Concrete Mixer with Oreo',
            category: 'Custard',
            calories: 880,
            protein: 18,
            carbs: 122,
            fat: 38,
            sodium: 560,
          ),
          MenuItem(
            id: 'cul_7',
            name: 'Grilled Chicken Sandwich',
            category: 'Chicken',
            calories: 440,
            protein: 40,
            carbs: 38,
            fat: 15,
            sodium: 850,
          ),
          MenuItem(
            id: 'cul_8',
            name: 'North Atlantic Cod Filet',
            category: 'Fish',
            calories: 600,
            protein: 23,
            carbs: 55,
            fat: 31,
            sodium: 1250,
          ),
        ],
      ),
      Restaurant(
        id: 'innout',
        name: 'In-N-Out Burger',
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'ino_1',
            name: 'Hamburger',
            category: 'Burgers',
            calories: 390,
            protein: 16,
            carbs: 39,
            fat: 19,
            sodium: 650,
          ),
          MenuItem(
            id: 'ino_2',
            name: 'Cheeseburger',
            category: 'Burgers',
            calories: 480,
            protein: 22,
            carbs: 39,
            fat: 27,
            sodium: 1000,
          ),
          MenuItem(
            id: 'ino_3',
            name: 'Double-Double',
            category: 'Burgers',
            calories: 670,
            protein: 37,
            carbs: 39,
            fat: 41,
            sodium: 1440,
          ),
          MenuItem(
            id: 'ino_4',
            name: 'French Fries',
            category: 'Sides',
            calories: 395,
            protein: 7,
            carbs: 54,
            fat: 18,
            sodium: 245,
          ),
          MenuItem(
            id: 'ino_5',
            name: 'Protein Style Burger (Lettuce Wrap)',
            category: 'Burgers',
            calories: 240,
            protein: 13,
            carbs: 11,
            fat: 17,
            sodium: 370,
          ),
          MenuItem(
            id: 'ino_6',
            name: 'Grilled Cheese',
            category: 'Other',
            calories: 380,
            protein: 16,
            carbs: 39,
            fat: 18,
            sodium: 720,
          ),
        ],
      ),
      Restaurant(
        id: 'popeyes',
        name: 'Popeyes',
        category: RestaurantCategory.fastFood,
        isVerified: true,
        menuItems: [
          MenuItem(
            id: 'pop_1',
            name: 'Chicken Sandwich',
            category: 'Sandwiches',
            calories: 700,
            protein: 28,
            carbs: 50,
            fat: 42,
            sodium: 1440,
          ),
          MenuItem(
            id: 'pop_2',
            name: 'Spicy Chicken Sandwich',
            category: 'Sandwiches',
            calories: 700,
            protein: 28,
            carbs: 50,
            fat: 42,
            sodium: 1640,
          ),
          MenuItem(
            id: 'pop_3',
            name: 'Chicken Tenders (3pc)',
            category: 'Chicken',
            calories: 340,
            protein: 27,
            carbs: 14,
            fat: 20,
            sodium: 1200,
          ),
          MenuItem(
            id: 'pop_4',
            name: 'Spicy Chicken Leg',
            category: 'Chicken',
            calories: 160,
            protein: 13,
            carbs: 4,
            fat: 10,
            sodium: 410,
          ),
          MenuItem(
            id: 'pop_5',
            name: 'Cajun Fries (Regular)',
            category: 'Sides',
            calories: 260,
            protein: 3,
            carbs: 34,
            fat: 13,
            sodium: 570,
          ),
          MenuItem(
            id: 'pop_6',
            name: 'Red Beans & Rice',
            category: 'Sides',
            calories: 230,
            protein: 9,
            carbs: 24,
            fat: 11,
            sodium: 680,
          ),
          MenuItem(
            id: 'pop_7',
            name: 'Mashed Potatoes with Gravy',
            category: 'Sides',
            calories: 110,
            protein: 2,
            carbs: 14,
            fat: 5,
            sodium: 580,
          ),
        ],
      ),
    ];
  }
}
