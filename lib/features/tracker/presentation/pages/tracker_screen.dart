import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/betting_tracker_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/matches_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/match_model.dart' as model;
import '../../../matches/presentation/widgets/dynamic_live_island.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ApiService _apiService = ApiService();
  final BettingTrackerService _tracker = BettingTrackerService.instance;

  String _selectedTimeframe = 'all'; // 'all', 'today'
  String _selectedStatusFilter = 'all'; // 'all', 'won', 'lost', 'live'
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('TrackerScreen');
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    try {
      final matches = await _apiService.fetchMatches();
      await _tracker.syncMatches(matches);
    } catch (_) {
      // API error handled gracefully, local tracker history is always available
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(104),
        child: Container(
          color: AppTheme.surfaceOf(context),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered Dynamic Live Island (Matching FotMob / iOS Island)
                Selector<MatchesProvider, List<model.Match>>(
                  selector: (_, p) => p.liveMatches,
                  shouldRebuild: (prev, next) => prev.length != next.length,
                  builder: (context, liveMatches, _) {
                    if (liveMatches.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Center(
                        child: DynamicLiveIsland(liveMatches: liveMatches),
                      ),
                    );
                  },
                ),
                        // Title Row: BETTING & AI TRACKER + Subtitle on left, Circular refresh button on right
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'BETTING & AI TRACKER',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Continuous 1-unit flat simulation',
                                style: TextStyle(
                                  color: Color(0xFF8B949E),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _isRefreshing ? null : _refreshData,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF161B22),
                                border: Border.all(
                                  color: const Color(0xFF272F3D),
                                  width: 1,
                                ),
                              ),
                              child: _isRefreshing
                                  ? const Padding(
                                      padding: EdgeInsets.all(9),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppTheme.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: Colors.white70,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: RefreshIndicator(
            color: primary,
            onRefresh: _refreshData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // 1. User Start Date Timeline Banner
              Selector<BettingTrackerService, ({DateTime startDate, int daysActive})>(
                selector: (_, tracker) => (
                  startDate: tracker.userStartDate,
                  daysActive: tracker.daysActive,
                ),
                builder: (context, data, _) {
                  final formattedStartDate = DateFormat('MMM d, yyyy').format(data.startDate);
                  return _buildUserTimelineBanner(
                    formattedStartDate: formattedStartDate,
                    daysActive: data.daysActive,
                    primary: primary,
                    surface: surface,
                    borderColor: borderColor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                  );
                },
              ),
              const SizedBox(height: 14),

              // 2. Timeframe Selector Pills
              _buildTimeframeSelector(primary, surface, borderColor, textPrimary, textSecondary),
              const SizedBox(height: 16),

              // 3. Main Hero Analytics Card (Win Rate, Units Profit, ROI)
              Selector<BettingTrackerService, TrackerStats>(
                selector: (_, tracker) => tracker.getCachedStats(timeframe: _selectedTimeframe),
                builder: (context, stats, _) {
                  return _buildHeroPerformanceCard(stats, primary, surface, borderColor, isDark);
                },
              ),
              const SizedBox(height: 16),

              // 4. Cumulative Units & Win Rate Trend Chart (Vintage Points)
              Selector<BettingTrackerService, List<CumulativePoint>>(
                selector: (_, tracker) => tracker.getCachedStats(timeframe: _selectedTimeframe).progression,
                shouldRebuild: (prev, next) {
                  if (prev.length != next.length) return true;
                  if (prev.isEmpty) return false;
                  return prev.last.cumulativeUnits != next.last.cumulativeUnits;
                },
                builder: (context, points, _) {
                  return _buildTrendProgressionCard(points, primary, surface, borderColor, textPrimary, textSecondary);
                },
              ),
              const SizedBox(height: 20),

              // 5. Recent Form Row
              Selector<BettingTrackerService, List<String>>(
                selector: (_, tracker) => tracker.cachedStats.recentForm,
                shouldRebuild: (prev, next) => !listEquals(prev, next),
                builder: (context, recentForm, _) {
                  if (recentForm.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildFormGuideRow(recentForm, surface, borderColor, textPrimary, textSecondary),
                  );
                },
              ),

              // 6. Outcome Filter Header & Chips (Tabs)
              Selector<BettingTrackerService, ({int total, int won, int lost, int live, int pending})>(
                selector: (_, tracker) {
                  final s = tracker.getCachedStats(timeframe: _selectedTimeframe);
                  return (
                    total: s.totalBets,
                    won: s.wins,
                    lost: s.losses,
                    live: s.live,
                    pending: s.pending,
                  );
                },
                builder: (context, counts, _) {
                  return _buildOutcomeFilterBar(counts, primary, surface, borderColor, textPrimary, textSecondary);
                },
              ),
              const SizedBox(height: 12),

              // 7. Tracked Bets List (Tier 1 Structural Selector)
              Selector<BettingTrackerService, List<String>>(
                selector: (_, tracker) => tracker.getBetIdsForFilter(
                  timeframe: _selectedTimeframe,
                  statusFilter: _selectedStatusFilter,
                ),
                shouldRebuild: (prev, next) => !listEquals(prev, next),
                builder: (context, betIds, _) {
                  if (betIds.isEmpty) {
                    return _buildEmptyState(surface, borderColor, textSecondary);
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: betIds.length,
                    itemBuilder: (context, index) {
                      return TrackedBetCardTile(
                        key: ValueKey(betIds[index]),
                        betId: betIds[index],
                        surface: surface,
                        borderColor: borderColor,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        primary: primary,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTimelineBanner({
    required String formattedStartDate,
    required int daysActive,
    required Color primary,
    required Color surface,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history_toggle_off_rounded, color: primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ACTIVE TRACKING',
                      style: TextStyle(
                        color: primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'DAY $daysActive',
                        style: TextStyle(
                          color: primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Started on $formattedStartDate',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Every match and prediction is verified & logged continuously.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector(
    Color primary,
    Color surface,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final timeframes = [
      {'id': 'all', 'label': 'All Time'},
      {'id': 'today', 'label': 'Today'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: timeframes.map((tf) {
          final isSelected = _selectedTimeframe == tf['id'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTimeframe = tf['id']!;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: primary.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  tf['label']!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildHeroPerformanceCard(
    TrackerStats stats,
    Color primary,
    Color surface,
    Color borderColor,
    bool isDark,
  ) {
    final profitPositive = stats.netProfit >= 0;
    final profitColor = profitPositive ? AppTheme.success : AppTheme.secondary;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  surface,
                  primary.withValues(alpha: 0.12),
                ]
              : [
                  Colors.white,
                  primary.withValues(alpha: 0.08),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Win Rate Display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WIN RATE OVER TIME',
                    style: TextStyle(
                      color: primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        stats.winRate.toStringAsFixed(1),
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        '%',
                        style: TextStyle(
                          color: primary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${stats.wins} Won • ${stats.losses} Lost',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              // Net Profit & ROI Unit Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: profitColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: profitColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NET PROFIT',
                      style: TextStyle(
                        color: profitColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${profitPositive ? '+' : ''}${stats.netProfit.toStringAsFixed(2)}u',
                      style: TextStyle(
                        color: profitColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'ROI: ${profitPositive ? '+' : ''}${stats.roi.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: profitColor.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 16),

          // 4 Grid metrics - responsive Wrap for clean centered layout on small screens
          Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 12,
            spacing: 12,
            children: [
              _buildMiniMetric(
                'Total Bets',
                stats.totalBets.toString(),
                isDark ? Colors.white : Colors.black87,
                Icons.analytics_outlined,
              ),
              _buildMiniMetric(
                'Avg Odds',
                stats.averageOdds > 0 ? '@${stats.averageOdds.toStringAsFixed(2)}' : '-',
                primary,
                Icons.trending_up_rounded,
              ),
              _buildMiniMetric(
                'Streak',
                stats.currentStreak > 0
                    ? '🔥 ${stats.currentStreak}W'
                    : (stats.currentStreak < 0 ? '❄️ ${stats.currentStreak.abs()}L' : '-'),
                stats.currentStreak > 0 ? AppTheme.success : AppTheme.secondary,
                Icons.bolt_rounded,
              ),
              _buildMiniMetric(
                'Pending',
                stats.live.toString(),
                Colors.orange,
                Icons.timelapse_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color, IconData icon) {
    final textSecondary = AppTheme.textSecondaryOf(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 65),
      child: Column(
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.8)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendProgressionCard(
    List<CumulativePoint> points,
    Color primary,
    Color surface,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cumulative Profit Trajectory (Units)',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Over Time',
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Visual progress of 1-unit flat staking strategy from your first day:',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 16),
          if (points.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timeline_rounded, color: primary.withValues(alpha: 0.5), size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Awaiting First Settled Match',
                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Your profit & win rate trajectory curve starts logging upon full-time results.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _ProgressionChartPainter(
                  points: points,
                  lineColor: primary,
                  fillColor: primary.withValues(alpha: 0.18),
                  baselineColor: borderColor,
                  textColor: textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormGuideRow(
    List<String> form,
    Color surface,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(
            'Recent Form:',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: form.map((res) {
                  final isWin = res == 'W';
                  return Container(
                    margin: const EdgeInsets.only(right: 6),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isWin ? AppTheme.success : AppTheme.secondary,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: (isWin ? AppTheme.success : AppTheme.secondary).withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        res,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Last ${form.length} picks',
            style: TextStyle(color: textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildOutcomeFilterBar(
    ({int total, int won, int lost, int live, int pending}) counts,
    Color primary,
    Color surface,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final filters = [
      {'id': 'all', 'label': 'All (${counts.total})'},
      {'id': 'won', 'label': 'Won (${counts.won})'},
      {'id': 'lost', 'label': 'Lost (${counts.lost})'},
      if (counts.live > 0) {'id': 'live', 'label': 'Live (${counts.live})'},
      if (counts.pending > 0) {'id': 'pending', 'label': 'Upcoming (${counts.pending})'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tracked Picks',
          style: TextStyle(
            color: textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((f) {
              final isSelected = _selectedStatusFilter == f['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedStatusFilter = f['id']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected ? primary.withValues(alpha: 0.18) : surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? primary : borderColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      f['label']!,
                      style: TextStyle(
                        color: isSelected ? primary : textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color surface, Color borderColor, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 40, color: textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No predictions match the selected filter.',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

}

/// 🎯 Tier 2 Leaf Selector Widget:
/// Observes only this individual bet ID. Rebuilds ONLY when its score, status, or profit changes!
class TrackedBetCardTile extends StatelessWidget {
  final String betId;
  final Color surface;
  final Color borderColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color primary;

  const TrackedBetCardTile({
    super.key,
    required this.betId,
    required this.surface,
    required this.borderColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<BettingTrackerService, TrackedBet?>(
      selector: (_, tracker) => tracker.getBetById(betId),
      shouldRebuild: (prev, next) {
        if (prev == null || next == null) return true;
        return prev.status != next.status ||
               prev.homeScore != next.homeScore ||
               prev.awayScore != next.awayScore ||
               prev.profit != next.profit;
      },
      builder: (context, bet, _) {
        if (bet == null) return const SizedBox.shrink();

        final isWon = bet.status == 'won';
        final isLost = bet.status == 'lost';
        final isLive = bet.status == 'live';
        final isPending = bet.status == 'pending';

        Color badgeColor;
        String badgeText;
        IconData badgeIcon;

        if (isLive) {
          badgeColor = Colors.orange;
          badgeText = 'LIVE';
          badgeIcon = Icons.sensors_rounded;
        } else if (isWon) {
          badgeColor = AppTheme.success;
          badgeText = 'WON +${bet.profit.toStringAsFixed(2)}u';
          badgeIcon = Icons.check_circle_rounded;
        } else if (isLost) {
          badgeColor = AppTheme.secondary;
          badgeText = 'LOST -1.00u';
          badgeIcon = Icons.cancel_rounded;
        } else if (isPending) {
          badgeColor = primary;
          badgeText = 'UPCOMING';
          badgeIcon = Icons.schedule_rounded;
        } else {
          badgeColor = Colors.grey;
          badgeText = 'VOID';
          badgeIcon = Icons.remove_circle_outline_rounded;
        }

        final matchDate = DateFormat('MMM d • HH:mm').format(bet.date);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLive ? Colors.orange.withValues(alpha: 0.4) : borderColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League & Date Row
              Row(
                children: [
                  Flexible(
                    child: Text(
                      bet.league.toUpperCase(),
                      style: TextStyle(
                        color: primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    matchDate,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Match Teams Text
              Text(
                '${bet.homeTeam} vs ${bet.awayTeam}',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (bet.homeScore != null && bet.awayScore != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.orange.withValues(alpha: 0.15)
                          : (textPrimary.withValues(alpha: 0.08)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLive ? Colors.orange.withValues(alpha: 0.4) : borderColor,
                      ),
                    ),
                    child: Text(
                      'Score: ${bet.homeScore} - ${bet.awayScore}',
                      style: TextStyle(
                        color: isLive ? Colors.orange : textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // AI Pick & Outcome Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  // AI Pick Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 14, color: primary),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 170),
                          child: Text(
                            'Pick: ${bet.pick}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '@${bet.odds.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Outcome Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 13, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Custom painter for rendering a smooth cumulative units trajectory chart
class _ProgressionChartPainter extends CustomPainter {
  final List<CumulativePoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color baselineColor;
  final Color textColor;

  _ProgressionChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.baselineColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    double minVal = 0.0;
    double maxVal = 0.0;
    for (final p in points) {
      if (p.cumulativeUnits < minVal) minVal = p.cumulativeUnits;
      if (p.cumulativeUnits > maxVal) maxVal = p.cumulativeUnits;
    }

    // Give some vertical breathing space
    final span = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);
    final rangeMin = minVal - (span * 0.15);
    final rangeMax = maxVal + (span * 0.15);
    final rangeTotal = rangeMax - rangeMin;

    double getY(double val) {
      final norm = (val - rangeMin) / rangeTotal;
      return size.height - (norm * size.height);
    }

    double getX(int index) {
      if (points.length <= 1) return size.width / 2;
      return (index / (points.length - 1)) * size.width;
    }

    // 1. Draw Zero baseline
    final zeroY = getY(0.0);
    final dashPaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, zeroY), Offset(size.width, zeroY), dashPaint);

    // Text: 0.0u indicator
    final tpZero = TextPainter(
      text: TextSpan(
        text: '0.0u',
        style: TextStyle(color: textColor, fontSize: 9),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tpZero.paint(canvas, Offset(4, zeroY - 12));

    // 2. Build line and fill paths
    final linePath = Path();
    final fillPath = Path();

    linePath.moveTo(getX(0), getY(points.first.cumulativeUnits));
    fillPath.moveTo(getX(0), zeroY);
    fillPath.lineTo(getX(0), getY(points.first.cumulativeUnits));

    for (int i = 1; i < points.length; i++) {
      final prevX = getX(i - 1);
      final prevY = getY(points[i - 1].cumulativeUnits);
      final curX = getX(i);
      final curY = getY(points[i].cumulativeUnits);

      // Smooth cubic bezier
      final cpX1 = prevX + (curX - prevX) / 2;
      final cpY1 = prevY;
      final cpX2 = prevX + (curX - prevX) / 2;
      final cpY2 = curY;

      linePath.cubicTo(cpX1, cpY1, cpX2, cpY2, curX, curY);
      fillPath.cubicTo(cpX1, cpY1, cpX2, cpY2, curX, curY);
    }

    fillPath.lineTo(getX(points.length - 1), zeroY);
    fillPath.close();

    // Fill under curve
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          fillColor,
          fillColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, strokePaint);

    // 3. Draw dots on milestone points
    for (int i = 0; i < points.length; i++) {
      final px = getX(i);
      final py = getY(points[i].cumulativeUnits);

      // Draw small dot
      canvas.drawCircle(
        Offset(px, py),
        3.0,
        Paint()..color = lineColor,
      );

      // Last point glowing aura
      if (i == points.length - 1) {
        canvas.drawCircle(
          Offset(px, py),
          6.0,
          Paint()..color = lineColor.withValues(alpha: 0.3),
        );
        canvas.drawCircle(
          Offset(px, py),
          4.0,
          Paint()..color = Colors.white,
        );

        // Value text at the end
        final val = points[i].cumulativeUnits;
        final tpLast = TextPainter(
          text: TextSpan(
            text: '${val >= 0 ? '+' : ''}${val.toStringAsFixed(2)}u',
            style: TextStyle(
              color: lineColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tpLast.paint(canvas, Offset(size.width - tpLast.width - 2, py - 18));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressionChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.lineColor != lineColor;
  }
}
