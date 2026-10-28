import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../../features/matches/presentation/pages/home_screen.dart';
import '../../features/leagues/presentation/pages/leagues_hub_screen.dart';
import '../../features/tracker/presentation/pages/tracker_screen.dart';
import '../../features/settings/presentation/pages/settings_screen.dart';

/// Root shell that keeps all 4 tabs alive in memory for 0ms instant switching.
class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  static MainNavigationShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<MainNavigationShellState>();

  @override
  State<MainNavigationShell> createState() => MainNavigationShellState();
}

class MainNavigationShellState extends State<MainNavigationShell> {
  late int currentIndex = widget.initialIndex;

  // Keep all 4 tabs alive in memory so switching is 0ms with zero rebuilds
  final List<Widget> _pages = const [
    HomeScreen(),
    LeaguesHubScreen(),
    TrackerScreen(),
    SettingsScreen(),
  ];

  void switchTab(int index) {
    if (index == currentIndex) return;
    setState(() {
      currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AppBottomNavBar(currentIndex: currentIndex),
    );
  }
}

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
  });

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    // 1. If inside MainNavigationShell, switch instantly in 0ms without destroying state!
    final shell = MainNavigationShell.of(context);
    if (shell != null) {
      shell.switchTab(index);
      return;
    }

    // 2. Fallback if navigated from a standalone route: replace with the shell
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => MainNavigationShell(initialIndex: index),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              _buildNavItem(context, 0, Icons.sports_soccer_rounded, 'Matches', primary, textSecondary),
              _buildNavItem(context, 1, Icons.emoji_events_rounded, 'Leagues', primary, textSecondary),
              _buildNavItem(context, 2, Icons.insights_rounded, 'Tracker', primary, textSecondary),
              _buildNavItem(context, 3, Icons.tune_rounded, 'Settings', primary, textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    Color primary,
    Color textSecondary,
  ) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(context, index),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? primary.withValues(alpha: 0.16)
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
