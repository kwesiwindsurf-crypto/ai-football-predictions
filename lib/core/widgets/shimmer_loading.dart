import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

/// Theme-aware skeleton loaders: dark greys on the dark theme, soft blue-greys
/// on the light theme, so placeholders never render as dark slabs on white.
class MatchCardShimmer extends StatelessWidget {
  const MatchCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A2230) : const Color(0xFFE2E8F0),
      highlightColor: isDark ? const Color(0xFF28354A) : const Color(0xFFF6F9FC),
      child: Card(
        color: AppTheme.surfaceOf(context),
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.cardBorderOf(context), width: 1),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ShimmerBox(width: 120, height: 12, radius: 4),
                  _ShimmerBox(width: 48, height: 12, radius: 4),
                ],
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: _TeamShimmer()),
                  _ShimmerBox(width: 40, height: 24, radius: 6),
                  Expanded(child: _TeamShimmer()),
                ],
              ),
              SizedBox(height: 14),
              Divider(height: 1, color: Colors.white12),
              SizedBox(height: 10),
              _ShimmerBox(width: 180, height: 14, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

/// A single shimmer-masking rectangle (colored, then tinted by the shader).
class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _TeamShimmer extends StatelessWidget {
  const _TeamShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 70,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class MatchListShimmer extends StatelessWidget {
  const MatchListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    final syncGreen = isDark ? const Color(0xFF00D06C) : const Color(0xFF00A855);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active pulsing status indicator
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isDark ? const Color(0xFF10141D) : const Color(0xFFE9F7F1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: syncGreen.withValues(alpha: isDark ? 0.3 : 0.45),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: syncGreen,
                  ),
                ),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Syncing live match scores & predictions...',
                    style: TextStyle(
                      color: syncGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Direct placeholder cards (safe inside scrollable slivers with unbounded height)
          ...List.generate(4, (index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index % 2 == 0) ...[
                  Shimmer.fromColors(
                    baseColor: isDark
                        ? const Color(0xFF1A2230)
                        : const Color(0xFFE2E8F0),
                    highlightColor: isDark
                        ? const Color(0xFF28354A)
                        : const Color(0xFFF6F9FC),
                    child: Container(
                      width: 140,
                      height: 22,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
                const MatchCardShimmer(),
              ],
            );
          }),
        ],
      ),
    );
  }
}
