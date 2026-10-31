import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/match_model.dart' as model;
import '../../../match_details/presentation/pages/match_details_screen.dart';

class FeaturedAiBanner extends StatelessWidget {
  final model.Match? featuredMatch;
  final VoidCallback? onView;

  const FeaturedAiBanner({
    super.key,
    this.featuredMatch,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    if (featuredMatch == null) return const SizedBox.shrink();

    final match = featuredMatch!;
    final primary = AppTheme.primaryOf(context);
    final isHomeFav = match.prediction.homeWinProbability >= match.prediction.awayWinProbability;
    final favTeam = isHomeFav ? match.homeTeam : match.awayTeam;
    final winProb = (isHomeFav ? match.prediction.homeWinProbability : match.prediction.awayWinProbability).round();
    final recommendation = match.prediction.recommendation;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF064E3B).withValues(alpha: 0.35),
            AppTheme.surfaceOf(context),
            const Color(0xFF4C1D95).withValues(alpha: 0.25),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: primary.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Magic Wand Icon Container
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Recommendation
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI Model Consensus: $winProb% Value Win',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$favTeam • $recommendation',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // "View" Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              elevation: 0,
            ),
            onPressed: () {
              if (onView != null) {
                onView!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MatchDetailsScreen(match: match),
                  ),
                );
              }
            },
            child: const Text(
              'View',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
