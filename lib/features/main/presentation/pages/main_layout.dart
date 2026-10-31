import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../matches/presentation/pages/home_screen.dart';
import '../../../leagues/presentation/pages/leagues_hub_screen.dart';
import '../../../tracker/presentation/pages/tracker_screen.dart';
import '../../../settings/presentation/pages/settings_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LeaguesHubScreen(),
    const TrackerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    debugPrint('🔥🔥🔥 MainLayout build called! _currentIndex=$_currentIndex');
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surface.withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: borderColor, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          bottom: true,
          child: SizedBox(
            height: 60,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
              children: [
                _buildNavItem(0, Icons.sports_soccer_rounded, 'Matches', primary),
                _buildNavItem(
                  1,
                  Icons.emoji_events_rounded,
                  'Leagues',
                  primary,
                ),
                _buildNavItem(2, Icons.insights_rounded, 'Tracker', primary),
                _buildNavItem(3, Icons.tune_rounded, 'Settings', primary),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildNavItem(int index, IconData icon, String label, Color primary) {
    final isSelected = _currentIndex == index;
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentIndex = index;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected ? primary : textSecondary,
                  size: 22,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? primary : textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
