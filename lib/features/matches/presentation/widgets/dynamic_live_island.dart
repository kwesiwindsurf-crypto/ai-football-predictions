import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/match_model.dart' as model;
import '../../../match_details/presentation/pages/match_details_screen.dart';

class DynamicLiveIsland extends StatefulWidget {
  final List<model.Match>? liveMatches;

  const DynamicLiveIsland({
    super.key,
    this.liveMatches,
  });

  @override
  State<DynamicLiveIsland> createState() => _DynamicLiveIslandState();
}

class _DynamicLiveIslandState extends State<DynamicLiveIsland>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _currentIndex = 0;
  Timer? _rotationTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If multiple live matches exist, rotate the preview pill every 5 seconds
    _startTimerIfNeeded(widget.liveMatches ?? ApiService.liveMatchesNotifier.value);
  }

  void _startTimerIfNeeded(List<model.Match> matches) {
    _rotationTimer?.cancel();
    if (matches.length > 1) {
      _rotationTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          final currentList = widget.liveMatches ?? ApiService.liveMatchesNotifier.value;
          if (currentList.isNotEmpty) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % currentList.length;
            });
          }
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant DynamicLiveIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final matches = widget.liveMatches ?? ApiService.liveMatchesNotifier.value;
    if (_currentIndex >= matches.length) {
      _currentIndex = 0;
    }
    _startTimerIfNeeded(matches);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveMatches != null) {
      return _buildIsland(context, widget.liveMatches!);
    }

    return ValueListenableBuilder<List<model.Match>>(
      valueListenable: ApiService.liveMatchesNotifier,
      builder: (context, liveList, _) {
        return _buildIsland(context, liveList);
      },
    );
  }

  Widget _buildIsland(BuildContext context, List<model.Match> matches) {
    if (matches.isEmpty) return const SizedBox.shrink();

    final match = matches[_currentIndex.clamp(0, matches.length - 1)];
    final homeScore = match.homeScore ?? 0;
    final awayScore = match.awayScore ?? 0;

    // Minute calculation or status short from real match
    String minuteStr = "LIVE";
    if (match.statusShort != null && match.statusShort!.isNotEmpty && match.statusShort != 'LIVE') {
      minuteStr = match.statusShort!;
    } else {
      final elapsed = DateTime.now().difference(match.date.toLocal()).inMinutes;
      if (elapsed > 0 && elapsed <= 120) {
        minuteStr = "$elapsed'";
      }
    }

    return Center(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MatchDetailsScreen(match: match),
            ),
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(
              color: const Color(0xFF1F2937),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.15),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing live green dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: _pulseAnimation.value),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: _pulseAnimation.value * 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 7),

              // Match Minute + Score
              Text(
                "$minuteStr  $homeScore - $awayScore",
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(width: 8),

              // Mini circle with soccer ball icon
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 11,
                  color: AppTheme.primary,
                ),
              ),

              if (matches.length > 1) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${matches.length - 1}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
