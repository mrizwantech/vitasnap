import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/favorites_service.dart';
import '../../domain/entities/scan_result.dart';
import '../widgets/product_tile.dart';
import '../widgets/vitasnap_logo.dart';
import 'product_details_page.dart';

/// Page displaying user's favorite products
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF1B8A4E);

    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF8),
      appBar: AppBar(
        title: const VitaSnapLogo(fontSize: 20, showTagline: true),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Colors.red.shade400,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Favorites',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Your saved products',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Favorites list
            Expanded(
              child: Consumer<FavoritesService>(
                builder: (context, favoritesService, _) {
                  final favorites = favoritesService.favorites;
                  
                  if (favorites.isEmpty) {
                    return _buildEmptyState(primaryColor);
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final scanResult = favorites[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: Key(scanResult.product.barcode),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: Colors.red.shade700,
                            ),
                          ),
                          onDismissed: (_) {
                            favoritesService.removeFavorite(scanResult.product.barcode);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${scanResult.product.name} removed from favorites'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () {
                                    favoritesService.addFavorite(scanResult);
                                  },
                                ),
                              ),
                            );
                          },
                          child: ProductTile(
                            title: scanResult.product.name,
                            subtitle: scanResult.product.brand,
                            score: scanResult.score,
                            labels: scanResult.product.labels,
                            onTap: () => _openProductDetails(context, scanResult),
                          ),
                        ),
                      );
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

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.red.shade300,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No favorites yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Tap the heart icon on any product to save it here for quick access',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openProductDetails(BuildContext context, ScanResult scanResult) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsPage(scanResult: scanResult),
      ),
    );
  }
}
