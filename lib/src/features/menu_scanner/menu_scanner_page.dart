import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/services/menu_analysis_service.dart';
import '../../core/services/health_conditions_service.dart';
import '../../core/services/dietary_preferences_service.dart';
import '../../core/services/restaurant_database_service.dart';
import '../../core/services/local_health_scoring_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/scan_result.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/entities/restaurant.dart';
import '../../presentation/viewmodels/scan_viewmodel.dart';
import '../../presentation/views/main_navigation.dart';
import '../../presentation/widgets/vitasnap_logo.dart';

/// Key for storing disclaimer acceptance in shared preferences
const String _disclaimerAcceptedKey = 'menu_scanner_disclaimer_accepted';

/// Page for scanning and analyzing restaurant menus
class MenuScannerPage extends StatefulWidget {
  const MenuScannerPage({super.key});

  @override
  State<MenuScannerPage> createState() => _MenuScannerPageState();
}

class _MenuScannerPageState extends State<MenuScannerPage> {
  final MenuAnalysisService _menuService = MenuAnalysisService();
  final RestaurantDatabaseService _restaurantService = RestaurantDatabaseService();
  final LocalHealthScoringService _localScoringService = LocalHealthScoringService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _manualInputController = TextEditingController();
  final TextEditingController _restaurantSearchController = TextEditingController();
  
  MenuAnalysisResult? _analysisResult;
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'best', 'caution', 'avoid'
  
  // Restaurant browser state
  List<Restaurant> _restaurants = [];
  bool _loadingRestaurants = false;
  
  // Disclaimer state
  bool _hasAcceptedDisclaimer = false;

  @override
  void initState() {
    super.initState();
    _checkDisclaimerStatus();
    _initializeRestaurants();
  }

  Future<void> _checkDisclaimerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasAcceptedDisclaimer = prefs.getBool(_disclaimerAcceptedKey) ?? false;
    });
  }

  /// Show disclaimer dialog and return true if user accepts
  Future<bool> _showDisclaimerIfNeeded() async {
    if (_hasAcceptedDisclaimer) return true;
    
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Important Information',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  LocalHealthScoringService.disclaimer,
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, 
                    color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Nutrition data sourced from official restaurant websites',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle_outline, 
                    color: Colors.green[700], size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Always verify with restaurant for current information',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(_disclaimerAcceptedKey, true);
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('I Understand', 
              style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (accepted == true) {
      setState(() => _hasAcceptedDisclaimer = true);
      return true;
    }
    return false;
  }

  Future<void> _initializeRestaurants() async {
    // Seed popular restaurants on first launch
    debugPrint('DEBUG: Starting restaurant initialization...');
    await _restaurantService.seedPopularRestaurants();
    debugPrint('DEBUG: Seeding complete, now loading restaurants...');
    _loadRestaurants();
  }

  Future<void> _loadRestaurants({String? query}) async {
    setState(() => _loadingRestaurants = true);
    try {
      debugPrint('DEBUG: Loading restaurants with query: $query');
      final restaurants = query != null && query.isNotEmpty
          ? await _restaurantService.searchRestaurants(query)
          : await _restaurantService.getRestaurants();
      debugPrint('DEBUG: Loaded ${restaurants.length} restaurants');
      setState(() {
        _restaurants = restaurants;
        _loadingRestaurants = false;
      });
    } catch (e) {
      debugPrint('DEBUG: Error loading restaurants: $e');
      setState(() => _loadingRestaurants = false);
    }
  }

  @override
  void dispose() {
    _manualInputController.dispose();
    _restaurantSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    // Show info dialog before proceeding
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primaryGreen),
            const SizedBox(width: 12),
            const Text('Image Analysis'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please note:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.timer, 'Analysis may take 30-60 seconds'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.wifi, 'Requires a stable internet connection'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.photo_camera, 'Use clear, well-lit photos for best results'),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.menu_book, 'Focus on the menu text for accurate reading'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: For faster results, type dish names manually instead.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(source == ImageSource.camera ? Icons.camera_alt : Icons.photo_library, size: 18),
            label: Text(source == ImageSource.camera ? 'Open Camera' : 'Open Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();
      setState(() {
        _analysisResult = null;
        _errorMessage = null;
      });

      await _analyzeImage(bytes);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
    }
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _analyzeImage(Uint8List imageBytes) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final healthService = context.read<HealthConditionsService>();
      final dietaryService = context.read<DietaryPreferencesService>();

      final healthConditions = healthService.selectedConditions
          .map((c) => c.displayName)
          .toList();
      final dietaryPreferences = dietaryService.selectedRestrictions
          .map((r) => r.displayName)
          .toList();

      final result = await _menuService.analyzeMenuImage(
        imageBytes: imageBytes,
        healthConditions: healthConditions,
        dietaryPreferences: dietaryPreferences,
      );

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeManualInput() async {
    final text = _manualInputController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter dish names';
      });
      return;
    }

    // Split by newlines or commas
    final dishNames = text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (dishNames.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter at least one dish name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final healthService = context.read<HealthConditionsService>();
      final dietaryService = context.read<DietaryPreferencesService>();

      final healthConditions = healthService.selectedConditions
          .map((c) => c.displayName)
          .toList();
      final dietaryPreferences = dietaryService.selectedRestrictions
          .map((r) => r.displayName)
          .toList();

      final result = await _menuService.analyzeDishNames(
        dishNames: dishNames,
        healthConditions: healthConditions,
        dietaryPreferences: dietaryPreferences,
      );

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });

      // Clear input after successful analysis
      _manualInputController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isLoading = false;
      });
    }
  }

  List<DishAnalysis> get _filteredDishes {
    if (_analysisResult == null) return [];
    
    switch (_selectedFilter) {
      case 'best':
        return _analysisResult!.bestChoices;
      case 'caution':
        return _analysisResult!.cautionChoices;
      case 'avoid':
        return _analysisResult!.avoidChoices;
      default:
        return _analysisResult!.dishes;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primaryGreen;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          if (_analysisResult != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _analysisResult = null;
                  _errorMessage = null;
                });
              },
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView()
          : _analysisResult != null
              ? _buildResultsView(primaryColor, isDark)
              : _buildInputView(primaryColor, isDark),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated loading indicator
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                strokeWidth: 6,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Analyzing menu...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Our AI is reading the menu and evaluating\neach dish based on your health profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'This may take 30-60 seconds',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please don\'t close the app',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputView(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Compact header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: 24,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Menu Scanner',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get health recommendations for any dish',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Camera/Gallery buttons - compact row
          Row(
            children: [
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.camera_alt,
                  label: 'Take Photo',
                  color: primaryColor,
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompactActionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.blue.shade600,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          
          // Divider
          _buildOrDivider(),
          const SizedBox(height: 16),

          // Manual input - compact
          TextField(
            controller: _manualInputController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Type dish names (e.g., Grilled Salmon, Caesar Salad)',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.edit_note, color: Colors.grey.shade400),
              suffixIcon: IconButton(
                icon: Icon(Icons.send, color: primaryColor),
                onPressed: _analyzeManualInput,
                tooltip: 'Analyze',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          const SizedBox(height: 20),
          
          // Divider
          _buildOrDivider(),
          const SizedBox(height: 16),

          // Popular Restaurants Section
          _buildRestaurantBrowserSection(primaryColor, isDark),

          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Compact action button for camera/gallery
  Widget _buildCompactActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// OR divider widget
  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildRestaurantBrowserSection(Color primaryColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with explanation box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.fastfood_outlined, color: primaryColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quick Pick from Restaurants',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap any restaurant to see menu with nutrition info',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showAddRestaurantDialog,
                icon: Icon(Icons.add_circle_outline, color: primaryColor, size: 22),
                tooltip: 'Add restaurant',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Search field - compact
        TextField(
          controller: _restaurantSearchController,
          onChanged: (value) => _loadRestaurants(query: value),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search restaurants...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            suffixIcon: _restaurantSearchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 18),
                    onPressed: () {
                      _restaurantSearchController.clear();
                      _loadRestaurants();
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // Restaurant grid
        if (_loadingRestaurants)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_restaurants.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.store_mall_directory, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No restaurants found',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showAddRestaurantDialog,
                    child: const Text('Add one!'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.9,
            ),
            itemCount: _restaurants.length > 8 ? 8 : _restaurants.length,
            itemBuilder: (context, index) {
              final restaurant = _restaurants[index];
              return _buildRestaurantCard(restaurant, primaryColor);
            },
          ),

        // View all button
        if (_restaurants.length > 8) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _showAllRestaurantsSheet,
              icon: const Icon(Icons.expand_more),
              label: Text('View all ${_restaurants.length} restaurants'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRestaurantCard(Restaurant restaurant, Color primaryColor) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 1,
      child: InkWell(
        onTap: () => _showRestaurantMenu(restaurant),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _getCategoryColor(restaurant.category).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getCategoryIcon(restaurant.category),
                  color: _getCategoryColor(restaurant.category),
                  size: 18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                restaurant.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case RestaurantCategory.fastFood:
        return Colors.orange;
      case RestaurantCategory.casual:
        return Colors.blue;
      case RestaurantCategory.fineDining:
        return Colors.purple;
      case RestaurantCategory.cafe:
        return Colors.brown;
      case RestaurantCategory.pizza:
        return Colors.red;
      case RestaurantCategory.mexican:
        return Colors.green;
      case RestaurantCategory.asian:
        return Colors.pink;
      case RestaurantCategory.other:
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case RestaurantCategory.fastFood:
        return Icons.fastfood;
      case RestaurantCategory.casual:
        return Icons.restaurant;
      case RestaurantCategory.fineDining:
        return Icons.dining;
      case RestaurantCategory.cafe:
        return Icons.local_cafe;
      case RestaurantCategory.pizza:
        return Icons.local_pizza;
      case RestaurantCategory.mexican:
        return Icons.lunch_dining;
      case RestaurantCategory.asian:
        return Icons.ramen_dining;
      case RestaurantCategory.other:
      default:
        return Icons.storefront;
    }
  }

  void _showRestaurantMenu(Restaurant restaurant) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RestaurantMenuSheet(
        restaurant: restaurant,
        onAnalyze: (selectedItems) {
          Navigator.pop(context);
          _analyzeRestaurantItems(restaurant, selectedItems);
        },
      ),
    );
  }

  void _showAllRestaurantsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'All Restaurants',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _restaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = _restaurants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(restaurant.category).withValues(alpha: 0.1),
                      child: Icon(
                        _getCategoryIcon(restaurant.category),
                        color: _getCategoryColor(restaurant.category),
                      ),
                    ),
                    title: Text(restaurant.name),
                    subtitle: Text('${restaurant.menuItems.length} items'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      _showRestaurantMenu(restaurant);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRestaurantDialog() {
    final nameController = TextEditingController();
    String selectedCategory = RestaurantCategory.other;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.add_business, color: Color(0xFF1B8A4E)),
              SizedBox(width: 12),
              Text('Add Restaurant'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Help build our community database!',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Restaurant Name',
                  hintText: 'e.g., Pizza Hut',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: RestaurantCategory.all.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(_getCategoryIcon(cat), size: 20, color: _getCategoryColor(cat)),
                        const SizedBox(width: 8),
                        Text(_categoryName(cat)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedCategory = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a restaurant name')),
                  );
                  return;
                }
                
                try {
                  final newRestaurant = Restaurant(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    category: selectedCategory,
                    menuItems: [],
                    isVerified: false,
                    contributedBy: 'user',
                    usageCount: 0,
                  );
                  await _restaurantService.addRestaurant(newRestaurant);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadRestaurants();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${nameController.text} added! You can now add menu items.'),
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryName(String category) {
    switch (category) {
      case RestaurantCategory.fastFood:
        return 'Fast Food';
      case RestaurantCategory.casual:
        return 'Casual Dining';
      case RestaurantCategory.fineDining:
        return 'Fine Dining';
      case RestaurantCategory.cafe:
        return 'Cafe';
      case RestaurantCategory.pizza:
        return 'Pizza';
      case RestaurantCategory.mexican:
        return 'Mexican';
      case RestaurantCategory.asian:
        return 'Asian';
      case RestaurantCategory.other:
      default:
        return 'Other';
    }
  }

  Future<void> _analyzeRestaurantItems(Restaurant restaurant, List<MenuItem> items) async {
    if (items.isEmpty) return;
    
    // Show disclaimer if not accepted
    final accepted = await _showDisclaimerIfNeeded();
    if (!accepted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get user's health conditions and dietary preferences
      final healthService = context.read<HealthConditionsService>();
      final dietaryService = context.read<DietaryPreferencesService>();
      
      final healthConditions = healthService.selectedConditions;
      final dietaryRestrictions = dietaryService.selectedRestrictions;

      // Check if items have nutrition data (use local scoring) or not (use AI)
      final hasNutritionData = items.every((item) => item.calories != null);
      
      // Data source for attribution
      final dataSource = '${restaurant.name} Official Nutrition Guide';
      
      MenuAnalysisResult result;
      
      if (hasNutritionData) {
        // Use LOCAL scoring - instant, free, works offline!
        debugPrint('DEBUG: Using LOCAL scoring for ${items.length} items with nutrition data');
        result = _localScoringService.analyzeMenuItems(
          items: items,
          healthConditions: healthConditions,
          dietaryRestrictions: dietaryRestrictions,
          dataSource: dataSource,
        );
      } else {
        // Fall back to AI for items without nutrition data
        debugPrint('DEBUG: Using AI scoring for ${items.length} items (missing nutrition data)');
        final dishNames = items.map((item) => item.name).toList();
        result = await _menuService.analyzeDishNames(
          dishNames: dishNames,
          healthConditions: healthConditions.map((c) => c.displayName).toList(),
          dietaryPreferences: dietaryRestrictions.map((r) => r.displayName).toList(),
        );
      }

      // Increment usage count
      await _restaurantService.incrementUsage(restaurant.id);

      setState(() {
        _analysisResult = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to analyze menu items: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildResultsView(Color primaryColor, bool isDark) {
    final result = _analysisResult!;
    final filteredDishes = _filteredDishes;

    return CustomScrollView(
      slivers: [
        // Summary card
        SliverToBoxAdapter(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: primaryColor.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.analytics_outlined, color: primaryColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Analysis Results',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  result.summary,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Filter chips
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${result.dishes.length})', primaryColor),
                const SizedBox(width: 8),
                _buildFilterChip('best', '✅ Best (${result.bestChoices.length})', Colors.green),
                const SizedBox(width: 8),
                _buildFilterChip('caution', '⚠️ Caution (${result.cautionChoices.length})', Colors.orange),
                const SizedBox(width: 8),
                _buildFilterChip('avoid', '❌ Avoid (${result.avoidChoices.length})', Colors.red),
              ],
            ),
          ),
        ),

        // Dishes list
        if (filteredDishes.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.no_food,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dishes in this category',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildDishCard(filteredDishes[index], isDark, primaryColor),
                childCount: filteredDishes.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, Color color) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.1),
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildDishCard(DishAnalysis dish, bool isDark, Color primaryColor) {
    final Color recommendationColor;
    switch (dish.recommendation) {
      case DishRecommendation.best:
        recommendationColor = Colors.green;
        break;
      case DishRecommendation.caution:
        recommendationColor = Colors.orange;
        break;
      case DishRecommendation.avoid:
        recommendationColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: recommendationColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showDishDetails(dish, primaryColor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dish.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (dish.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            dish.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: recommendationColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: recommendationColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          dish.recommendation.emoji,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dish.recommendation.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: recommendationColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Nutrition row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientBadge('Cal', '${dish.estimatedCalories}', Colors.orange),
                  _buildNutrientBadge('Protein', '${dish.estimatedProtein}g', Colors.blue),
                  _buildNutrientBadge('Carbs', '${dish.estimatedCarbs}g', Colors.purple),
                  _buildNutrientBadge('Fat', '${dish.estimatedFat}g', Colors.amber.shade700),
                ],
              ),

              const SizedBox(height: 12),

              // Reason
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: recommendationColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: recommendationColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dish.reason,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Add to Tracker button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAddToTrackerDialog(dish, primaryColor),
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  label: const Text('Add to Tracker'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  /// Show dialog to select meal type and add dish to tracker
  void _showAddToTrackerDialog(DishAnalysis dish, Color primaryColor) {
    MealType selectedMealType = MealType.lunch;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Add "${dish.name}" to Tracker',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select meal type:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Meal type chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MealType.values.map((type) {
                      final isSelected = selectedMealType == type;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(type.emoji),
                            const SizedBox(width: 4),
                            Text(type.displayName),
                          ],
                        ),
                        selectedColor: primaryColor.withValues(alpha: 0.2),
                        backgroundColor: Colors.grey.shade100,
                        labelStyle: TextStyle(
                          color: isSelected ? primaryColor : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (_) {
                          setModalState(() {
                            selectedMealType = type;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Add button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _addDishToTracker(dish, selectedMealType);
                      },
                      icon: const Icon(Icons.add),
                      label: Text('Add to ${selectedMealType.displayName}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Add dish to tracker (scan history)
  Future<void> _addDishToTracker(DishAnalysis dish, MealType mealType) async {
    // Create a Product from dish analysis
    final product = Product(
      barcode: 'menu_${DateTime.now().millisecondsSinceEpoch}',
      name: dish.name,
      brand: 'Restaurant Menu',
      imageUrl: null,
      ingredients: dish.description,
      nutriments: {
        'energy-kcal_100g': dish.estimatedCalories.toDouble(),
        'proteins_100g': dish.estimatedProtein.toDouble(),
        'carbohydrates_100g': dish.estimatedCarbs.toDouble(),
        'fat_100g': dish.estimatedFat.toDouble(),
        'sodium_100g': dish.estimatedSodium.toDouble() / 1000, // Convert mg to g
      },
      labels: ['Menu Scanner', dish.recommendation.displayName],
    );

    // Calculate score based on recommendation
    int score;
    switch (dish.recommendation) {
      case DishRecommendation.best:
        score = 85;
        break;
      case DishRecommendation.caution:
        score = 60;
        break;
      case DishRecommendation.avoid:
        score = 35;
        break;
    }

    final scanResult = ScanResult(
      product: product,
      score: score,
      mealType: mealType,
    );

    // Add to scan history via ScanViewModel
    final scanViewModel = context.read<ScanViewModel>();
    await scanViewModel.addToHistory(scanResult);

    // Clear search results and reset state
    setState(() {
      _analysisResult = null;
      _errorMessage = null;
      _manualInputController.clear();
    });

    // Show success message and navigate to home
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(mealType.emoji),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${dish.name} added to ${mealType.displayName}'),
              ),
            ],
          ),
          backgroundColor: AppColors.primaryGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navigate to home tab
      if (mounted) {
        MainNavigation.navigateToHome(context);
      }
    }
  }

  void _showDishDetails(DishAnalysis dish, Color primaryColor) {
    final Color recommendationColor;
    switch (dish.recommendation) {
      case DishRecommendation.best:
        recommendationColor = Colors.green;
        break;
      case DishRecommendation.caution:
        recommendationColor = Colors.orange;
        break;
      case DishRecommendation.avoid:
        recommendationColor = Colors.red;
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Dish name and recommendation
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        dish.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: recommendationColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: recommendationColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            dish.recommendation.emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dish.recommendation.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: recommendationColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (dish.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    dish.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Nutrition details
                const Text(
                  'Estimated Nutrition',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildNutritionRow('Calories', '${dish.estimatedCalories} kcal', Colors.orange),
                _buildNutritionRow('Protein', '${dish.estimatedProtein}g', Colors.blue),
                _buildNutritionRow('Carbohydrates', '${dish.estimatedCarbs}g', Colors.purple),
                _buildNutritionRow('Fat', '${dish.estimatedFat}g', Colors.amber.shade700),
                _buildNutritionRow('Sodium', '${dish.estimatedSodium}mg', Colors.red.shade400),

                const SizedBox(height: 24),

                // Recommendation reason
                const Text(
                  'Why This Recommendation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: recommendationColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: recommendationColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    dish.reason,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),

                // Health tips
                if (dish.healthTips != null && dish.healthTips!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Health Tips',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dish.healthTips!,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Add to Tracker button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddToTrackerDialog(dish, primaryColor);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add to Tracker'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet widget for displaying restaurant menu items
class _RestaurantMenuSheet extends StatefulWidget {
  final Restaurant restaurant;
  final Function(List<MenuItem>) onAnalyze;

  const _RestaurantMenuSheet({
    required this.restaurant,
    required this.onAnalyze,
  });

  @override
  State<_RestaurantMenuSheet> createState() => _RestaurantMenuSheetState();
}

class _RestaurantMenuSheetState extends State<_RestaurantMenuSheet> {
  final Set<String> _selectedItemIds = {};
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newItemNameController = TextEditingController();
  final TextEditingController _newItemCaloriesController = TextEditingController();

  List<MenuItem> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.restaurant.menuItems;
    return widget.restaurant.menuItems
        .where((item) => item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newItemNameController.dispose();
    _newItemCaloriesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primaryGreen;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.restaurant.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.restaurant.menuItems.length} items • Tap to select',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search menu items...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: primaryColor,
                  tooltip: 'Add menu item',
                  onPressed: _showAddMenuItemDialog,
                ),
              ],
            ),
          ),

          // Selection info
          if (_selectedItemIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: primaryColor.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedItemIds.length} item${_selectedItemIds.length > 1 ? 's' : ''} selected',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: primaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedItemIds.clear()),
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),

          // Menu items list
          Expanded(
            child: _filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No items found',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _showAddMenuItemDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add menu item'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      final isSelected = _selectedItemIds.contains(item.id);
                      return _buildMenuItemTile(item, isSelected);
                    },
                  ),
          ),

          // Analyze button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedItemIds.isEmpty
                      ? null
                      : () {
                          final selectedItems = widget.restaurant.menuItems
                              .where((item) => _selectedItemIds.contains(item.id))
                              .toList();
                          widget.onAnalyze(selectedItems);
                        },
                  icon: const Icon(Icons.analytics),
                  label: Text(
                    _selectedItemIds.isEmpty
                        ? 'Select items to analyze'
                        : 'Analyze ${_selectedItemIds.length} item${_selectedItemIds.length > 1 ? 's' : ''}',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemTile(MenuItem item, bool isSelected) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 2 : 0,
      color: isSelected ? AppColors.primaryGreen.withValues(alpha: 0.05) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? AppColors.primaryGreen : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedItemIds.remove(item.id);
            } else {
              _selectedItemIds.add(item.id);
            }
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection indicator
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? AppColors.primaryGreen : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (item.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Nutrition info
              if (item.calories != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item.calories} cal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddMenuItemDialog() {
    _newItemNameController.clear();
    _newItemCaloriesController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restaurant_menu, color: Color(0xFF1B8A4E)),
            SizedBox(width: 12),
            Text('Add Menu Item'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Help others by adding a missing menu item',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newItemNameController,
              decoration: InputDecoration(
                labelText: 'Item Name *',
                hintText: 'e.g., Big Mac',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newItemCaloriesController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Calories (optional)',
                hintText: 'e.g., 550',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = _newItemNameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter an item name')),
                );
                return;
              }

              final caloriesText = _newItemCaloriesController.text.trim();
              final calories = caloriesText.isNotEmpty ? int.tryParse(caloriesText) : null;

              final newItem = MenuItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: name,
                calories: calories,
              );

              try {
                final restaurantService = RestaurantDatabaseService();
                await restaurantService.addMenuItems(widget.restaurant.id, [newItem]);
                
                // Add to local list
                setState(() {
                  widget.restaurant.menuItems.add(newItem);
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name added to menu!'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
