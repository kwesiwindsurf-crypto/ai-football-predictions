import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favourites'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, size: 80, color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No favourites yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryOf(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the star icon on any match or league\nto save it here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
