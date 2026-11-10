import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/api_service.dart';


class MatchDetailsScreen extends StatefulWidget {
  final model.Match match;
  const MatchDetailsScreen({super.key, required this.match});

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AnimationController _headerAnim;
  late final Animation<double> _fadeIn;

  late final AnimationController _pulseAnim;

  /// Live-refreshable match state (updated by the auto-refresh timer)
  late model.Match _liveMatch;
  Timer? _refreshTimer;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _liveMatch = widget.match;
    AnalyticsService.instance.logScreenView('MatchDetailsScreen');
    AnalyticsService.instance.logMatchView(
      matchId: widget.match.id,
      homeTeam: widget.match.homeTeam,
      awayTeam: widget.match.awayTeam,
      league: widget.match.league,
    );
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final isPostponed = widget.match.isPostponed;
    final initialTab = (widget.match.status == model.MatchStatus.live ||
            (widget.match.status == model.MatchStatus.finished && !isPostponed))
        ? 0
        : 1;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialTab);
    _headerAnim =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
    _startAutoRefreshIfNeeded();
  }

  /// Polls the API every 30 s while the match is live or within 3 h of kickoff.
  void _startAutoRefreshIfNeeded() {
    if (_liveMatch.isPostponed) return;
    final isLive = _liveMatch.status == model.MatchStatus.live;
    final now = DateTime.now();
    final minsAfterKickoff = now.difference(_liveMatch.date.toLocal()).inMinutes;
    // Active window: match is live OR kicked off in last 3 hours
    final inActiveWindow = isLive || (minsAfterKickoff >= 0 && minsAfterKickoff < 180);
    if (!inActiveWindow) return;

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshMatchData();
    });
  }

  Future<void> _refreshMatchData() async {
    try {
      final matches = await _apiService.fetchLiveUpdates() ?? await _apiService.getCachedMatches();
      if (matches != null) {
        final updated = matches.where((m) => m.id == _liveMatch.id).firstOrNull;
        if (updated != null && mounted) {
          setState(() {
            _liveMatch = updated;
          });
          // Stop polling once match is finished
          if (updated.status == model.MatchStatus.finished) {
            _refreshTimer?.cancel();
            _refreshTimer = null;
          }
        }
      }
    } catch (_) {
      // Silently ignore refresh errors — stale data is fine
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseAnim.dispose();
    _tabController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = AppTheme.primaryOf(context);
    final surface = AppTheme.surfaceOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.isDark(context)
                  ? const Color(0xFF161B22)
                  : const Color(0xFFEFF3F8),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: AppTheme.textPrimaryOf(context)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _liveMatch.league,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimaryOf(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatDate(_liveMatch.date)} • ${_formatTime(_liveMatch.date)}',
              style: TextStyle(
                fontSize: 10,
                color: textSecondary,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? const Color(0xFF161B22)
                    : const Color(0xFFEFF3F8),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: Icon(Icons.star_border_rounded,
                  size: 19, color: AppTheme.textSecondaryOf(context)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Match added to live pinned activities'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: NestedScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                  child: _buildHeroHeader(),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicatorColor: primary,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(width: 3, color: primary),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                    ),
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(10),
                    labelColor: primary,
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.2),
                    unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
                    tabs: [
                      const Tab(text: 'Timeline'),
                      const Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 13),
                            SizedBox(width: 5),
                            Text('AI Insights & Odds'),
                          ],
                        ),
                      ),
                      const Tab(text: 'Match Stats'),
                    ],
                  ),
                  backgroundColor: surface,
                  borderColor: borderColor,
                ),
              ),
            ];
          },
          body: ScrollConfiguration(
            // Inner tab views share the NestedScrollView's primary scroll
            // controller; platform scrollbars there would see >1 ScrollPosition
            // ("Scrollbar attached to more than one ScrollPosition"). Scrolling
            // itself is unaffected — only the chrome scrollbar is suppressed.
            behavior:
                ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineTab(),
                _buildAIInsightsTab(),
                _buildMatchStatsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO HEADER (Image 3)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final m = _liveMatch;
    final isPostponed = m.isPostponed;
    final isLive = m.status == model.MatchStatus.live;
    final isFinished = m.status == model.MatchStatus.finished && !isPostponed;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    // Scorers lists (extract from original events or provided scorers)
    final homeScorersList = <String>[];
    final awayScorersList = <String>[];

    if (m.homeScorers != null && m.homeScorers!.isNotEmpty) {
      homeScorersList.addAll(m.homeScorers!);
    }
    if (m.awayScorers != null && m.awayScorers!.isNotEmpty) {
      awayScorersList.addAll(m.awayScorers!);
    }

    if (homeScorersList.isEmpty && awayScorersList.isEmpty && m.events != null && m.events!.isNotEmpty) {
      for (final ev in m.events!) {
        final isShootout = ev.type.toLowerCase().contains('shootout') ||
            ev.clock.toUpperCase() == 'SO' ||
            (ev.type.toLowerCase().contains('penalty') && ev.clock.isEmpty);
        if (!isShootout && (ev.scoringPlay || ev.type.toLowerCase().contains('goal'))) {
          final clock = ev.clock.isNotEmpty ? "${ev.clock}'" : '';
          final text = '${ev.player} $clock'.trim();
          if (ev.team == 'home') {
            homeScorersList.add(text);
          } else {
            awayScorersList.add(text);
          }
        }
      }
    }


    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              surface,
              AppTheme.backgroundOf(context),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status bar row: 🔴 80' LIVE · Referee
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isPostponed)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                        width: 0.8,
                      ),
                    ),
                    child: const Text(
                      'POSTPONED',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  )
                else if (isLive)
                  _buildLivePulse(
                    m.statusShort == 'HT'
                        ? 'HT'
                        : (m.elapsed != null ? "${m.elapsed}' LIVE" : (m.statusShort ?? 'LIVE')),
                  )
                else if (isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'FULL TIME',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Text(
                    '${_formatDate(m.date)} ${_formatTime(m.date)}',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                if (m.referee != null && m.referee!.trim().isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: TextStyle(color: textSecondary, fontSize: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Referee: ${m.referee}',
                    style: TextStyle(color: textSecondary, fontSize: 11),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // Teams row
            Row(
              children: [
                // Home Team
                Expanded(
                  child: _buildTeamCard(
                    m.homeTeam,
                    m.homeLogo,
                    true,
                    m.homeForm,
                  ),
                ),

                // Center Scoreboard
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    children: [
                      if (isPostponed) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            'PT',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontSize: 20,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'POSTPONED',
                          style: TextStyle(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.8),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ] else if (m.status == model.MatchStatus.notStarted &&
                          m.homeScore == null &&
                          m.awayScore == null) ...[
                        // Upcoming fixture: show kickoff time — never a fake "0 - 0"
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: textSecondary.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            _formatTime(m.date),
                            style: TextStyle(
                              color: AppTheme.textPrimaryOf(context),
                              fontSize: 20,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'KICKOFF',
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${m.homeScore ?? 0}',
                              style: TextStyle(
                                color: (m.homeScore ?? 0) > (m.awayScore ?? 0)
                                    ? AppTheme.primary
                                    : AppTheme.textPrimaryOf(context),
                                fontSize: 32,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '-',
                              style: TextStyle(
                                color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.5),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${m.awayScore ?? 0}',
                              style: TextStyle(
                                color: (m.awayScore ?? 0) > (m.homeScore ?? 0)
                                    ? AppTheme.primary
                                    : AppTheme.textPrimaryOf(context),
                                fontSize: 32,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (m.statusShort == 'HT') ...[
                          const SizedBox(height: 2),
                          Text(
                            'HALF TIME',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // Away Team
                Expanded(
                  child: _buildTeamCard(
                    m.awayTeam,
                    m.awayLogo,
                    false,
                    m.awayForm,
                  ),
                ),
              ],
            ),

            // Scorers Row (Image 3)
            if (homeScorersList.isNotEmpty || awayScorersList.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.cardBorderOf(context).withValues(alpha: 0.7),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Home Scorers (Left)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: homeScorersList.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_soccer, size: 12, color: AppTheme.textSecondaryOf(context)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  s,
                                  style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 11, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Away Scorers (Right)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: awayScorersList.map((s) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  s,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryOf(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(Icons.sports_soccer, size: 12, color: AppTheme.primary),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // UEFA Aggregate Series Badge
            if (m.seriesSummary != null && m.seriesSummary!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 14, color: Colors.amber),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m.seriesSummary!,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Venue & Attendance Row
            if ((m.venue != null && m.venue!.isNotEmpty) || m.attendance != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (m.venue != null && m.venue!.isNotEmpty) ...[
                    Icon(Icons.stadium_outlined, size: 13, color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        m.venue!,
                        style: TextStyle(color: textSecondary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (m.venue != null && m.venue!.isNotEmpty && m.attendance != null && m.attendance! > 0)
                    Text(' • ', style: TextStyle(color: textSecondary, fontSize: 11)),
                  if (m.attendance != null && m.attendance! > 0) ...[
                    Icon(Icons.people_outline, size: 13, color: AppTheme.textSecondaryOf(context)),
                    const SizedBox(width: 4),
                    Text(
                      '${m.attendance}',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ],

            // Postponed Notice Banner
            if (isPostponed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Match Postponed · Rescheduled by league officials. Pre-match analysis is archived below.',
                        style: TextStyle(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.95),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // 1X2 Odds Buttons Row (3-Columns: 1, X, 2)
            if (m.homeOdds != null || m.drawOdds != null || m.awayOdds != null)
              Row(
                children: [
                  _buildFotMobOddsButton(
                    context,
                    '1 (${_shortTeamName(m.homeTeam)})',
                    m.homeOdds,
                    m.prediction.homeWinProbability >=
                        m.prediction.awayWinProbability,
                  ),
                  const SizedBox(width: 8),
                  _buildFotMobOddsButton(
                    context,
                    'Draw (X)',
                    m.drawOdds,
                    false,
                  ),
                  const SizedBox(width: 8),
                  _buildFotMobOddsButton(
                    context,
                    '2 (${_shortTeamName(m.awayTeam)})',
                    m.awayOdds,
                    m.prediction.homeWinProbability <
                        m.prediction.awayWinProbability,
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 13, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'No market odds published for this fixture',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _shortTeamName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.last : name;
  }

  Widget _buildFotMobOddsButton(
    BuildContext context,
    String label,
    double? odds,
    bool isHighlighted,
  ) {
    final hasOdds = odds != null && odds > 1.0;
    final highlight = hasOdds && isHighlighted;
    return Expanded(
      child: InkWell(
        onTap: hasOdds
            ? () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppTheme.surfaceOf(context),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    content: Text(
                      'Added $label @ ${odds.toStringAsFixed(2)} to slip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                    ),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            : null,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: hasOdds ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: highlight
                  ? AppTheme.primary.withValues(alpha: 0.12)
                  : AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: highlight
                    ? AppTheme.primary.withValues(alpha: 0.7)
                    : AppTheme.cardBorderOf(context),
                width: highlight ? 1.5 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: highlight
                        ? AppTheme.primary
                        : AppTheme.textSecondaryOf(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasOdds ? odds.toStringAsFixed(2) : '—',
                  style: TextStyle(
                    color: highlight
                        ? AppTheme.primary
                        : AppTheme.textPrimaryOf(context),
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamCard(String name, String logo, bool isHome, [String? formStr]) {
    final initials = _teamInitials(name);
    final hasLogo = logo.isNotEmpty && (logo.startsWith('http://') || logo.startsWith('https://'));

    return Column(
      children: [
        // Official Team Crest Box
        Container(
          width: 52,
          height: 52,
          padding: EdgeInsets.all(hasLogo ? 6 : 0),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.cardBorderOf(context),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: hasLogo
              ? CachedNetworkImage(
                  imageUrl: logo,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFFFCD34D),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Color(0xFFFCD34D),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              : Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Color(0xFFFCD34D),
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 4),
        if (formStr != null && formStr.isNotEmpty)
          _buildMiniForm(formStr)
        else
          const SizedBox(height: 14),
      ],
    );
  }

  String _teamInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, min(2, name.length)).toUpperCase();
  }

  Widget _buildTeamLogo(String logo, String name, {double size = 24}) {
    if (logo.isNotEmpty && (logo.startsWith('http://') || logo.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: logo,
        width: size,
        height: size,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildInitialsLogo(name, size: size),
        errorWidget: (context, url, error) => _buildInitialsLogo(name, size: size),
      );
    }
    return _buildInitialsLogo(name, size: size);
  }

  Widget _buildInitialsLogo(String name, {double size = 24}) {
    final fontSize = (size * 0.35).clamp(7.0, 24.0);
    final colors = [
      const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      const [Color(0xFF831843), Color(0xFFEC4899)],
      const [Color(0xFF065F46), Color(0xFF10B981)],
      const [Color(0xFF581C87), Color(0xFF8B5CF6)],
      const [Color(0xFF7C2D12), Color(0xFFF97316)],
      const [Color(0xFF134E4A), Color(0xFF14B8A6)],
      const [Color(0xFF1E293B), Color(0xFF475569)],
      const [Color(0xFF701A75), Color(0xFFD946EF)],
    ];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    final pair = colors[hash % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
        boxShadow: [
          BoxShadow(
            color: pair[0].withValues(alpha: 0.3),
            blurRadius: size > 40 ? 8 : 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: Colors.white24, width: size > 40 ? 2 : 0.8),
      ),
      child: Center(
        child: Text(
          _teamInitials(name),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildMiniForm(String form) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: form.split('').take(5).map((c) {
        Color bg = const Color(0xFFF59E0B); // Amber D
        Color textC = Colors.black;
        if (c == 'W') {
          bg = const Color(0xFF10B981); // Green W
          textC = Colors.black;
        } else if (c == 'L') {
          bg = const Color(0xFFEF4444); // Red L
          textC = Colors.white;
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: Text(
              c,
              style: TextStyle(
                color: textC,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLivePulse(String text) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(_pulseAnim),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TIMELINE / MATCH EVENTS TAB (Image 3)
  // ─────────────────────────────────────────────────────────────
  Widget _buildTimelineTab() {
    final m = _liveMatch;
    final events = m.events ?? [];

    if (events.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(0.0, double.infinity),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.timer_outlined, size: 28, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Match Events Yet',
                      style: TextStyle(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Goals, bookings, and substitutions will stream live here as they happen during the match.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Stack(
      children: [
        // Dotted center spine behind the split timeline
        Positioned.fill(
          child: CustomPaint(
            painter: _TimelineSpinePainter(
              AppTheme.isDark(context)
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.black.withValues(alpha: 0.16),
            ),
          ),
        ),
        ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(14, 12, 14, bottomInset + 32),
          children: [
        Text(
          'LIVE MATCH EVENTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppTheme.textSecondaryOf(context),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(events.length, (index) {
          final ev = events[index];
          final clockStr = ev.clock.replaceAll("'", "").trim();
          final minute = int.tryParse(clockStr) ?? (ev.clock.isNotEmpty ? ev.clock : "-");
          final isGoal = ev.scoringPlay || ev.type.toLowerCase().contains('goal');
          final isRed = ev.redCard || ev.type.toLowerCase().contains('red');
          final isYellow = ev.yellowCard || ev.type.toLowerCase().contains('yellow');
          final isSub = ev.type.toLowerCase().contains('sub') || ev.player.contains('▲');

          Color eventColor = AppTheme.primary;
          IconData eventIcon = Icons.sports_soccer;
          String eventBadge = 'GOAL';

          if (isGoal) {
            eventColor = ev.ownGoal ? const Color(0xFFFF7043) : AppTheme.primary;
            eventIcon = Icons.sports_soccer;
            eventBadge = ev.penalty ? 'PENALTY GOAL' : (ev.ownGoal ? 'OWN GOAL' : 'GOAL');
          } else if (isRed) {
            eventColor = Colors.redAccent;
            eventIcon = Icons.style_rounded;
            eventBadge = 'RED CARD';
          } else if (isYellow) {
            eventColor = Colors.amber;
            eventIcon = Icons.style_rounded;
            eventBadge = 'YELLOW CARD';
          } else if (isSub) {
            eventColor = const Color(0xFF38BDF8); // Cyan
            eventIcon = Icons.swap_horiz_rounded;
            eventBadge = 'SUBSTITUTION';
          } else {
            eventColor = AppTheme.textSecondaryOf(context);
            eventIcon = Icons.event_note_rounded;
            eventBadge = ev.type.toUpperCase();
          }

          final isHomeSide = ev.team == 'home';
          final teamLabel = isHomeSide ? m.homeTeam : m.awayTeam;
          final teamColor = isHomeSide ? AppTheme.primary : AppTheme.secondary;

          // Glassy card, corner-snapped toward the center rail
          final eventCard = Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: AppTheme.isDark(context)
                        ? const [Color(0xFF1C2130), Color(0xFF161B22)]
                        : const [Color(0xFFFFFFFF), Color(0xFFF1F4F8)],
                  ),
                  borderRadius: isHomeSide
                      ? const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        )
                      : const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          topRight: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                  border: Border.all(color: AppTheme.cardBorderOf(context)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: eventColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            eventBadge,
                            style: TextStyle(
                              color: eventColor,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (isHomeSide) ...[
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: teamColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                             Flexible(
                                child: Text(
                                  teamLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryOf(context),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      ev.player,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimaryOf(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Floating minute chip on the top edge
              Positioned(
                top: -8,
                left: isHomeSide ? 10 : null,
                right: isHomeSide ? null : 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundOf(context),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "$minute'",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: teamColor,
                    ),
                  ),
                ),
              ),
            ],
          );

          // Rail node: event icon inside a team-colored ring
          final railNode = Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              shape: BoxShape.circle,
              border: Border.all(color: teamColor, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(eventIcon, size: 12, color: eventColor),
          );

          // Card sits on its own half of the rail, hugging the node
          final cardOnRail = Align(
            alignment: isHomeSide ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 224),
              child: eventCard,
            ),
          );

          // 1st team hangs its card on the left of the rail, opponent on the right;
          // both halves keep the node centered on the dotted spine.
          return Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: isHomeSide ? cardOnRail : const SizedBox.shrink()),
                const SizedBox(width: 6),
                railNode,
                const SizedBox(width: 6),
                Expanded(child: isHomeSide ? const SizedBox.shrink() : cardOnRail),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AI INSIGHTS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildAIInsightsTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14, 14, 14, bottomInset + 32),
      children: [
        _buildModelVerdictCard(),
        const SizedBox(height: 14),
        _buildWhyModelCard(),
        const SizedBox(height: 14),
        _buildBettingTiersCard(),
        if (_liveMatch.h2hSummary != null && _liveMatch.h2hSummary!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildH2HGraphicalCard(),
        ],
        const SizedBox(height: 14),
        _buildRecentFormCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MATCH STATS TAB (Live Dual-Sided Telemetry Bars)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMatchStatsTab() {
    final m = _liveMatch;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final stats = m.stats;

    if (stats == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bar_chart_rounded, size: 26, color: AppTheme.primary),
                ),
                const SizedBox(height: 14),
                Text(
                  'Live Telemetry Starts at Kickoff',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Real-time possession, shot charts, pass accuracy, corners, and fouls will stream live here as official match telemetry updates.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryOf(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(14, 12, 14, bottomInset + 32),
      children: [
        // Teams Header Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Home Team
              Expanded(
                child: Row(
                  children: [
                    _buildTeamLogo(m.homeLogo, m.homeTeam),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        m.homeTeam,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.4),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        m.awayTeam,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTeamLogo(m.awayLogo, m.awayTeam),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1. Possession & Attacking Telemetry Card
        _buildStatsSectionCard(
          title: 'ATTACK & POSSESSION',
          icon: Icons.sports_soccer,
          iconColor: AppTheme.primary,
          children: [
            _buildStatComparisonRow(
              title: 'Possession',
              homeValue: '${stats.possessionHome.toStringAsFixed(1)}%',
              awayValue: '${stats.possessionAway.toStringAsFixed(1)}%',
              homeRatio: (stats.possessionHome / 100.0).clamp(0.05, 0.95),
              highlightHome: stats.possessionHome >= stats.possessionAway,
            ),
            _buildStatComparisonRow(
              title: 'Total Shots',
              homeValue: '${stats.shotsHome}',
              awayValue: '${stats.shotsAway}',
              homeRatio: _calcRatio(stats.shotsHome, stats.shotsAway),
              highlightHome: stats.shotsHome >= stats.shotsAway,
            ),
            _buildStatComparisonRow(
              title: 'Shots On Target',
              homeValue: '${stats.shotsOnTargetHome}',
              awayValue: '${stats.shotsOnTargetAway}',
              homeRatio: _calcRatio(stats.shotsOnTargetHome, stats.shotsOnTargetAway),
              highlightHome: stats.shotsOnTargetHome >= stats.shotsOnTargetAway,
            ),
            _buildStatComparisonRow(
              title: 'Corner Kicks',
              homeValue: '${stats.cornersHome}',
              awayValue: '${stats.cornersAway}',
              homeRatio: _calcRatio(stats.cornersHome, stats.cornersAway),
              highlightHome: stats.cornersHome >= stats.cornersAway,
            ),
            _buildStatComparisonRow(
              title: 'Offsides',
              homeValue: '${stats.offsidesHome}',
              awayValue: '${stats.offsidesAway}',
              homeRatio: _calcRatio(stats.offsidesHome, stats.offsidesAway),
              highlightHome: stats.offsidesHome <= stats.offsidesAway,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 2. Defense & Discipline Telemetry Card
        _buildStatsSectionCard(
          title: 'DEFENSE & DISCIPLINE',
          icon: Icons.shield_outlined,
          iconColor: Colors.blueAccent,
          children: [
            _buildStatComparisonRow(
              title: 'Fouls Committed',
              homeValue: '${stats.foulsHome}',
              awayValue: '${stats.foulsAway}',
              homeRatio: _calcRatio(stats.foulsHome, stats.foulsAway),
              highlightHome: stats.foulsHome <= stats.foulsAway,
            ),
            _buildStatComparisonRow(
              title: 'Yellow Cards',
              homeValue: '${stats.yellowCardsHome}',
              awayValue: '${stats.yellowCardsAway}',
              homeRatio: _calcRatio(stats.yellowCardsHome, stats.yellowCardsAway),
              highlightHome: stats.yellowCardsHome <= stats.yellowCardsAway,
            ),
            _buildStatComparisonRow(
              title: 'Red Cards',
              homeValue: '${stats.redCardsHome}',
              awayValue: '${stats.redCardsAway}',
              homeRatio: _calcRatio(stats.redCardsHome, stats.redCardsAway),
              highlightHome: stats.redCardsHome <= stats.redCardsAway,
            ),
            _buildStatComparisonRow(
              title: 'Goalkeeper Saves',
              homeValue: '${stats.savesHome}',
              awayValue: '${stats.savesAway}',
              homeRatio: _calcRatio(stats.savesHome, stats.savesAway),
              highlightHome: stats.savesHome >= stats.savesAway,
            ),
            _buildStatComparisonRow(
              title: 'Tackles Won',
              homeValue: '${stats.tacklesHome}',
              awayValue: '${stats.tacklesAway}',
              homeRatio: _calcRatio(stats.tacklesHome, stats.tacklesAway),
              highlightHome: stats.tacklesHome >= stats.tacklesAway,
            ),
            _buildStatComparisonRow(
              title: 'Interceptions',
              homeValue: '${stats.interceptionsHome}',
              awayValue: '${stats.interceptionsAway}',
              homeRatio: _calcRatio(stats.interceptionsHome, stats.interceptionsAway),
              highlightHome: stats.interceptionsHome >= stats.interceptionsAway,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3. Passing & Ball Distribution Card
        if (stats.totalPassesHome > 0 || stats.totalPassesAway > 0) ...[
          _buildStatsSectionCard(
            title: 'PASSING & DISTRIBUTION',
            icon: Icons.compare_arrows_rounded,
            iconColor: Colors.cyanAccent,
            children: [
              _buildStatComparisonRow(
                title: 'Accurate Passes',
                homeValue: '${stats.accuratePassesHome}',
                awayValue: '${stats.accuratePassesAway}',
                homeRatio: _calcRatio(stats.accuratePassesHome, stats.accuratePassesAway),
                highlightHome: stats.accuratePassesHome >= stats.accuratePassesAway,
              ),
              _buildStatComparisonRow(
                title: 'Total Passes',
                homeValue: '${stats.totalPassesHome}',
                awayValue: '${stats.totalPassesAway}',
                homeRatio: _calcRatio(stats.totalPassesHome, stats.totalPassesAway),
                highlightHome: stats.totalPassesHome >= stats.totalPassesAway,
              ),
              _buildStatComparisonRow(
                title: 'Pass Accuracy',
                homeValue: '${stats.passAccuracyHome}%',
                awayValue: '${stats.passAccuracyAway}%',
                homeRatio: _calcRatio(stats.passAccuracyHome, stats.passAccuracyAway),
                highlightHome: stats.passAccuracyHome >= stats.passAccuracyAway,
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  double _calcRatio(num home, num away) {
    final total = home + away;
    if (total <= 0) return 0.5;
    return (home / total).clamp(0.08, 0.92);
  }

  Widget _buildStatsSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Container(
      padding: const EdgeInsets.all(16),
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatComparisonRow({
    required String title,
    required String homeValue,
    required String awayValue,
    required double homeRatio,
    required bool highlightHome,
  }) {
    final homeColor = AppTheme.primary;
    const awayColor = Color(0xFF38BDF8); // Light Blue / Sky

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // Stat values + Title Row
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  homeValue,
                  style: TextStyle(
                    color: highlightHome ? homeColor : AppTheme.textSecondaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  awayValue,
                  style: TextStyle(
                    color: !highlightHome ? awayColor : AppTheme.textSecondaryOf(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Dual-sided Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  // Home Bar (Left)
                  Expanded(
                    flex: (homeRatio * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: highlightHome ? homeColor : homeColor.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(4),
                          bottomLeft: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2), // Tiny divider between bars
                  // Away Bar (Right)
                  Expanded(
                    flex: ((1.0 - homeRatio) * 100).round(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !highlightHome ? awayColor : awayColor.withValues(alpha: 0.6),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // ─────────────────────────────────────────────────────────────
  // AI INSIGHTS SUB-CARDS — gauge-stack design
  // ─────────────────────────────────────────────────────────────

  /// Shared unified card header: accent icon chip + title + mono chip.
  Widget _insightCardHeader(IconData icon, Color accent, String title, String chipText,
      Color chipTextColor) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: accent, size: 15),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppTheme.textPrimaryOf(context),
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            chipText,
            style: TextStyle(
              color: chipTextColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelVerdictCard() {
    final m = _liveMatch;
    final p = m.prediction;
    const amber = Color(0xFFF59E0B);
    const indigo = Color(0xFF6366F1);
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    final homeProb = p.homeWinProbability.clamp(1.0, 100.0);
    final drawProb = p.drawProbability.clamp(1.0, 100.0);
    final awayProb = p.awayWinProbability.clamp(1.0, 100.0);

    final isHomeFav = p.homeWinProbability >= p.awayWinProbability;
    final favProb = isHomeFav ? p.homeWinProbability : p.awayWinProbability;
    final favOdds = isHomeFav ? m.homeOdds : m.awayOdds;

    String sub = 'CONF ${p.confidence.round()}%';
    if (favOdds != null && favOdds > 1.01) {
      final edge = favProb - (1.0 / favOdds * 100);
      final b = favOdds - 1.0;
      final kelly = b > 0 ? ((favProb / 100 * favOdds - 1) / b) : 0.0;
      final stake = (kelly * 100).clamp(0.0, 10.0);
      sub = 'CONF ${p.confidence.round()}% · EDGE ${_edgeLabel(edge)} · KELLY ${stake.toStringAsFixed(1)}%';
    }

    final pickName = p.recommendation.trim().isNotEmpty
        ? p.recommendation.trim()
        : _verdictPick(
            p.stakingOptions,
            '${_shortTeamName(isHomeFav ? m.homeTeam : m.awayTeam)} to WIN',
          );

    // Resolve the market price that actually belongs to [pickName].
    final double? pickOdds = _oddsForPick(m, pickName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _insightCardHeader(
            Icons.smart_toy_outlined, AppTheme.success,
            "The Model's Verdict", 'LIVE MODEL v3.4', AppTheme.success,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ModelGauge(
                  percent: homeProb.toDouble(),
                  color: AppTheme.success,
                  track: borderColor,
                  surface: surface,
                  label: m.homeTeam,
                  sub: 'WIN',
                ),
              ),
              Expanded(
                child: _ModelGauge(
                  percent: drawProb.toDouble(),
                  color: amber,
                  track: borderColor,
                  surface: surface,
                  label: 'Draw',
                  sub: 'LEVEL',
                ),
              ),
              Expanded(
                child: _ModelGauge(
                  percent: awayProb.toDouble(),
                  color: indigo,
                  track: borderColor,
                  surface: surface,
                  label: m.awayTeam,
                  sub: 'WIN',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: textSecondary.withValues(alpha: 0.06),
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MODEL PICK · KELLY ADJUSTED',
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        pickName,
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        style: TextStyle(
                          color: textSecondary,
                          fontSize: 9,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: pickOdds == null
                      ? null
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Added $pickName @ ${pickOdds.toStringAsFixed(2)} to slip'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                  child: Opacity(
                    opacity: pickOdds == null ? 0.5 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            pickOdds?.toStringAsFixed(2) ?? '—',
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const Text(
                            'ADD',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _verdictPick(List<String> stakingOptions, String fallback) {
    for (final raw in stakingOptions) {
      final idx = raw.indexOf(':');
      if (idx > 0 && raw.substring(0, idx).trim().toLowerCase() == 'safe') {
        final rest = raw.substring(idx + 1).trim();
        if (rest.isNotEmpty) return _stripOdds(rest);
      }
    }
    return fallback;
  }

  /// Resolves the market price that actually belongs to [pickLabel].
  /// Returns null when the pick is on a market we don't have a price for
  /// (e.g. Over 1.5 goals or Double Chance) — the UI then shows "—" instead of inventing one.
  double? _oddsForPick(model.Match m, String pickLabel) {
    final label = pickLabel.toLowerCase().trim();
    if (label.startsWith('1x') ||
        label.startsWith('x2') ||
        RegExp(r'^12(?![\d.])').hasMatch(label) ||
        label.contains('double chance') ||
        label.contains('over ') ||
        label.contains('under ') ||
        label.contains('btts')) {
      return null;
    }
    if (label == 'draw' || label == 'x' || label.contains('draw (x)')) {
      return m.drawOdds;
    }
    final homeKey = _shortTeamName(m.homeTeam).toLowerCase();
    final awayKey = _shortTeamName(m.awayTeam).toLowerCase();
    if (label.contains('(1)') ||
        label.contains(m.homeTeam.toLowerCase()) ||
        (homeKey.isNotEmpty && label.contains(homeKey))) {
      return m.homeOdds;
    }
    if (label.contains('(2)') ||
        label.contains(m.awayTeam.toLowerCase()) ||
        (awayKey.isNotEmpty && label.contains(awayKey))) {
      return m.awayOdds;
    }
    return null;
  }
  String _stripOdds(String s) {
    return s.replaceAll(RegExp(r'\(\s*\d+(?:\.\d+)?\s*\)'), '').trim();
  }

  String _edgeLabel(double edge) =>
      '${edge >= 0 ? '+' : ''}${edge.toStringAsFixed(1)}%';

  Widget _buildWhyModelCard() {
    final m = _liveMatch;
    final p = m.prediction;
    const amber = Color(0xFFF59E0B);
    const indigo = Color(0xFF6366F1);
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    final homeProb = p.homeWinProbability;
    final awayProb = p.awayWinProbability;
    final homeXg = (homeProb / 100 * 2.5).clamp(0.2, 3.8);
    final awayXg = (awayProb / 100 * 2.5).clamp(0.2, 3.8);
    final totalXg = homeXg + awayXg;

    final isHomeFav = homeProb >= awayProb;
    final favProb = isHomeFav ? homeProb : awayProb;
    final favOdds = isHomeFav ? m.homeOdds : m.awayOdds;
    final edge = (favOdds != null && favOdds > 1.01) ? favProb - (1.0 / favOdds * 100) : null;

    // The analysis payload is "strategy line\nHomeForm: x%, ..." — show the
    // strategy sentence and turn the raw numbers into factor bars.
    String sentence = '';
    if (p.analysis.isNotEmpty) {
      final parts = p.analysis.split('\n');
      for (final part in parts) {
        final t = part.trim();
        if (t.isNotEmpty && !t.toLowerCase().startsWith('homeform')) {
          sentence = t;
          break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _insightCardHeader(
            Icons.insights_rounded, amber,
            'Why the model likes it',
            'xG ${homeXg.toStringAsFixed(2)} · ${awayXg.toStringAsFixed(2)}',
            amber,
          ),
          if (sentence.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Model read: '),
                  TextSpan(
                    text: sentence,
                    style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(
                    text: ' at current market odds.',
                  ),
                ],
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 12,
                  height: 1.65,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _factorBar('Home form', _formWinPercent(m.homeForm), null, AppTheme.success),
          _factorBar('Away form', _formWinPercent(m.awayForm), null, indigo),
          _factorBar('Total xG', (totalXg / 4.0).clamp(0.02, 1.0),
              totalXg.toStringAsFixed(2), amber),

          // Real shots when telemetry exists (live/FT); otherwise a stub bar —
          // never fake-filled from the probability heuristic.
          Builder(
            builder: (_) {
              final statsH = m.stats?.shotsHome;
              final statsA = m.stats?.shotsAway;
              if (statsH != null && statsA != null && (statsH + statsA) > 0) {
                return _factorBar(
                  'Shot quality',
                  statsH / (statsH + statsA),
                  '$statsH v $statsA',
                  amber,
                );
              }
              return _factorBar('Shot quality', null, 'No data yet', amber);
            },
          ),
          if (edge != null)
            _factorBar('Value edge', (edge / 8.0).clamp(0.02, 1.0), _edgeLabel(edge),
                edge >= 0 ? AppTheme.success : indigo),
        ],
      ),
    );
  }

  /// Factor row: [label][track with fill][value]. Null fraction → unfilled stub;
  /// valueText null → formatted share from the fraction.
  Widget _factorBar(String label, double? fraction, String? valueText, Color color) {
    final textSecondary = AppTheme.textSecondaryOf(context);
    final v = valueText ??
        (fraction == null ? '—' : '${(fraction * 100).round()}%');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(
                color: textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: textSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (fraction ?? 0.0).clamp(0.0, 1.0),
                  heightFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: fraction == null ? Colors.transparent : color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 44,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.textPrimaryOf(context),
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// form string like "WWD LW" → share of wins, tracked as 0..1.
  double? _formWinPercent(String? form) {
    if (form == null || form.trim().isEmpty) return null;
    final chars = form.replaceAll(' ', '').toUpperCase().split('').take(5).toList();
    if (chars.isEmpty || chars.every((c) => c != 'W' && c != 'L' && c != 'D')) return null;
    return chars.where((c) => c == 'W').length / chars.length;
  }

  Widget _buildBettingTiersCard() {
    final m = _liveMatch;
    final p = m.prediction;
    const amber = Color(0xFFF59E0B);
    const indigo = Color(0xFF6366F1);
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    // One row per staking tier parsed from the payload:
    // "Safe: 1X (Albion or Draw)" / "Value: fav DNB (1.70)" / "Risky: ... (2.85)"
    final rows = <({String badge, String name, double kellyRef, Color color, double? odds})>[];
    final double confidence = p.confidence / 100.0;

    for (final raw in p.stakingOptions) {
      final idx = raw.indexOf(':');
      if (idx <= 0) continue;
      final key = raw.substring(0, idx).trim().toLowerCase();
      String label = raw.substring(idx + 1).trim();

      double? odds;
      final oddsMatch = RegExp(r'\((\d+(?:\.\d+)?)\)\s*$').firstMatch(label);
      if (oddsMatch != null) odds = double.tryParse(oddsMatch.group(1)!);
      label = _stripOdds(label);

      String badge;
      Color color;
      double kellyRef;
      if (key == 'safe') {
        badge = 'SAFE PICK';
        color = AppTheme.success;
        kellyRef = confidence;
      } else if (key == 'value') {
        badge = 'VALUE EDGE';
        color = amber;
        kellyRef = confidence * 0.75;
      } else if (key == 'goals') {
        badge = 'GOALS MARKET';
        color = amber;
        kellyRef = confidence * 0.6;
      } else if (key == 'risky') {
        badge = 'RISKY PLAY';
        color = indigo;
        kellyRef = confidence * 0.45;
      } else {
        continue; // BTTS / Alternative rows stay off the card
      }
      if (label.isEmpty) continue;
      rows.add((
        badge: badge,
        name: label,
        kellyRef: kellyRef.clamp(0.08, 0.95),
        color: color,
        odds: odds,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _insightCardHeader(
            Icons.savings_rounded, AppTheme.success,
            'Betting Tiers', 'KELLY ADJUSTED', AppTheme.success,
          ),
          const SizedBox(height: 12),
          for (final t in rows) ...[
            _buildTierRow(
              badge: t.badge,
              name: t.name,
              kellyRef: t.kellyRef,
              color: t.color,
              odds: t.odds,
            ),
            const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }

  Widget _buildTierRow({
    required String badge,
    required String name,
    required double kellyRef,
    required Color color,
    required double? odds,
  }) {
    final surface = AppTheme.surfaceOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: textSecondary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: color,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: AppTheme.textPrimaryOf(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 5,
                color: textSecondary.withValues(alpha: 0.12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: kellyRef,
                    heightFactor: 1.0,
                    child: Container(color: color),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: odds == null
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added $name @ ${odds.toStringAsFixed(2)} to slip'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.cardBorderOf(context)),
              ),
              child: Column(
                children: [
                  Text(
                    odds?.toStringAsFixed(2) ?? '—',
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'ODDS',
                    style: TextStyle(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildH2HGraphicalCard() {
    final m = _liveMatch;

    int hWins = 0;
    int aWins = 0;
    int draws = 0;
    int total = 0;

    final rawH2H = m.h2hSummary;
    if (rawH2H != null && rawH2H.isNotEmpty) {
      // Literal club name: a character class drops accents and mis-credits the fragment.
      int winsFor(String team) {
        final hit = RegExp('${RegExp.escape(team)}\\s+won\\s+(\\d+)', caseSensitive: false).firstMatch(rawH2H);
        return hit == null ? 0 : int.tryParse(hit.group(1) ?? '0') ?? 0;
      }

      hWins = winsFor(m.homeTeam);
      aWins = winsFor(m.awayTeam);

      final drawMatch = RegExp(r'(\d+)\s+Draws?\b', caseSensitive: false).firstMatch(rawH2H);
      if (drawMatch != null) {
        draws = int.tryParse(drawMatch.group(1) ?? '0') ?? 0;
      }
      final totalMatch = RegExp(r'of last (\d+) meetings?', caseSensitive: false).firstMatch(rawH2H);
      total = totalMatch == null ? hWins + aWins + draws : (int.tryParse(totalMatch.group(1) ?? '0') ?? 0);
    }

    final bool isFirstMeeting = total == 0;

    final homePct = isFirstMeeting ? 0 : ((hWins / total) * 100).round();
    final drawPct = isFirstMeeting ? 0 : ((draws / total) * 100).round();
    final awayPct = isFirstMeeting ? 0 : (100 - homePct - drawPct).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorderOf(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _insightCardHeader(
            Icons.compare_arrows_rounded,
            const Color(0xFFF59E0B),
            'Head-to-Head',
            total > 0 ? '$total MEETINGS' : 'H2H',
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 16),

          // 3-Column H2H Distribution Graphic
          Row(
            children: [
              // Home Team Stat Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        m.homeTeam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFirstMeeting ? '—' : '$hWins Wins',
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        isFirstMeeting ? 'No data' : '$homePct%',
                        style: TextStyle(
                          color: AppTheme.success.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Draws Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Draws',
                        style: TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFirstMeeting ? '—' : '$draws',
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        isFirstMeeting ? 'No data' : '$drawPct%',
                        style: TextStyle(
                          color: Colors.orange.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Away Team Stat Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        m.awayTeam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFirstMeeting ? '—' : '$aWins Wins',
                        style: TextStyle(
                          color: AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        isFirstMeeting ? 'No data' : '$awayPct%',
                        style: TextStyle(
                          color: AppTheme.secondary.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isFirstMeeting)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 12,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorderOf(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (homePct > 0)
                      Expanded(
                        flex: homePct,
                        child: Container(color: AppTheme.success),
                      ),
                    if (drawPct > 0)
                      Expanded(
                        flex: drawPct,
                        child: Container(color: Colors.orange),
                      ),
                    if (awayPct > 0)
                      Expanded(
                        flex: awayPct,
                        child: Container(color: AppTheme.secondary),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),

          // Summary pill
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBorderOf(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.analytics_rounded, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isFirstMeeting
                        ? 'No previous meetings — this could be a historic first encounter!'
                        : hWins > aWins
                            ? '${m.homeTeam} has dominated past head-to-head encounters.'
                            : aWins > hWins
                                ? '${m.awayTeam} holds the advantage in past meetings.'
                                : 'Both teams are evenly matched in past head-to-head meetings.',
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildRecentFormCard() {
    final m = _liveMatch;
    final homeRecent = _buildRecentMatchesFromForm(m.homeForm);
    final awayRecent = _buildRecentMatchesFromForm(m.awayForm);
    if (homeRecent.isEmpty && awayRecent.isEmpty) return const SizedBox.shrink();

    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _insightCardHeader(
              Icons.history_rounded, textSecondary, 'Recent Form', 'LAST 5', textSecondary),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  m.homeTeam,
                  style: TextStyle(
                      color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  m.awayTeam,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.9),
                      fontWeight: FontWeight.w800,
                      fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 5-result streak rails, one per team, matching their rows below
          Row(
            children: [
              Expanded(
                child: _buildFormStringRail(m.homeForm, CrossAxisAlignment.start),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormStringRail(m.awayForm, CrossAxisAlignment.end),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < 5; i++)
                      if (i < homeRecent.length)
                        _buildFormTile(context, homeRecent[i])
                      else
                        const SizedBox(height: 39),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < 5; i++)
                      if (i < awayRecent.length)
                        _buildFormTile(context, awayRecent[i])
                      else
                        const SizedBox(height: 39),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// A team's last-5 result string as a row of colored bars (W/D/L).
  Widget _buildFormStringRail(String? form, CrossAxisAlignment align) {
    final chars = (form ?? '').replaceAll(' ', '').toUpperCase().split('').take(5).toList();
    return Row(
      mainAxisAlignment: align == CrossAxisAlignment.start
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      children: chars
          .map((c) => Container(
                margin: const EdgeInsets.only(right: 3),
                width: 9,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2.5),
                  color: c == 'L'
                      ? const Color(0xFF6366F1)
                      : c == 'D'
                          ? const Color(0xFFF59E0B)
                          : AppTheme.success,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildFormTile(BuildContext context, model.RecentMatch r) {
    Color color = const Color(0xFFF59E0B);
    String status = 'Draw';
    if (r.result == 'W') {
      color = AppTheme.success;
      status = 'Win';
    } else if (r.result == 'L') {
      color = const Color(0xFF6366F1);
      status = 'Loss';
    }

    // Result color + label; the full 5-game string is drawn once under each team name.

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorderOf(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(r.result,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status,
              style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${days[local.weekday - 1]} ${local.day} ${months[local.month - 1]}';
  }

  List<model.RecentMatch> _buildRecentMatchesFromForm(String? form) {
    if (form == null || form.isEmpty) return [];
    return form.split('').take(5).toList().map((c) {
      return model.RecentMatch(
        opponent: '',
        goalsFor: c == 'W' ? 1 : 0,
        goalsAgainst: c == 'L' ? 1 : 0,
        result: c,
        isHome: true,
      );
    }).toList();
  }
}

/// Dotted vertical spine painted down the center of the split timeline.
class _TimelineSpinePainter extends CustomPainter {
  final Color dashColor;
  _TimelineSpinePainter(this.dashColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dashColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const dashLen = 3.0;
    const gap = 6.0;
    final cx = size.width / 2;
    double y = 4;
    while (y < size.height) {
      final end = (y + dashLen) < size.height ? y + dashLen : size.height;
      canvas.drawLine(Offset(cx, y), Offset(cx, end), paint);
      y += dashLen + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineSpinePainter oldDelegate) =>
      oldDelegate.dashColor != dashColor;
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  final Color borderColor;

  _SliverTabBarDelegate(this.tabBar, {required this.backgroundColor, required this.borderColor});

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent ? borderColor : Colors.transparent,
            width: 1,
          ),
        ),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.borderColor != borderColor;
  }
}

/// ─────────────────────────────────────────────────────────────────
/// Gauge ring used by the AI Insights tab (C-style radial design).
/// ─────────────────────────────────────────────────────────────────
class _ModelGauge extends StatelessWidget {
  final double percent;
  final Color color;
  final Color track;
  final Color surface;
  final String label;
  final String sub;

  const _ModelGauge({
    required this.percent,
    required this.color,
    required this.track,
    required this.surface,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 66,
          height: 66,
          child: CustomPaint(
            painter: _GaugePainter(
              fraction: (percent / 100.0).clamp(0.02, 1.0),
              color: color,
              track: track,
            ),
            child: Center(
              child: Text(
                '${percent.round()}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          sub,
          style: TextStyle(
            color: AppTheme.textSecondaryOf(context),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color track;

  _GaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 6.5;
    final radius = (size.shortestSide - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * fraction,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.fraction != fraction || old.color != color || old.track != track;
}
