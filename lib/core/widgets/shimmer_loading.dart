import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

class MatchCardShimmer extends StatelessWidget {
  const MatchCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surface,
      highlightColor: AppTheme.surface.withValues(alpha: 0.5),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(width: 100, height: 12, color: Colors.white),
                  Container(width: 40, height: 12, color: Colors.white),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTeamShimmer(),
                  Container(width: 40, height: 30, color: Colors.white),
                  _buildTeamShimmer(),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white),
              const SizedBox(height: 8),
              Container(width: 150, height: 16, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeamShimmer() {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Container(width: 60, height: 12, color: Colors.white),
        ],
      ),
    );
  }
}

class MatchListShimmer extends StatelessWidget {
  const MatchListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index % 2 == 0) ...[
              Shimmer.fromColors(
                baseColor: AppTheme.surface,
                highlightColor: AppTheme.surface.withValues(alpha: 0.5),
                child: Container(
                  width: 150,
                  height: 24,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
            const MatchCardShimmer(),
          ],
        );
      },
    );
  }
}

class StandingsTableShimmer extends StatelessWidget {
  const StandingsTableShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Shimmer.fromColors(
        baseColor: AppTheme.surface,
        highlightColor: AppTheme.surface.withValues(alpha: 0.5),
        child: Column(
          children: [
            Container(
              height: 48,
              color: Colors.white,
            ),
            Expanded(
              child: ListView.separated(
                itemCount: 10,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(width: 20, height: 14, color: Colors.white),
                        const SizedBox(width: 10),
                        Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Container(height: 14, color: Colors.white)),
                        const SizedBox(width: 20),
                        Container(width: 20, height: 14, color: Colors.white),
                        const SizedBox(width: 20),
                        Container(width: 20, height: 14, color: Colors.white),
                        const SizedBox(width: 20),
                        Container(width: 20, height: 14, color: Colors.white),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LeaguePillsShimmer extends StatelessWidget {
  const LeaguePillsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 5,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          return Shimmer.fromColors(
            baseColor: AppTheme.surface,
            highlightColor: AppTheme.surface.withValues(alpha: 0.5),
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }
}
