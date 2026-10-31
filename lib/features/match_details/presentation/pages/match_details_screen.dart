import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/app_settings_service.dart';
import '../../../../models/country_leagues_model.dart';
import 'package:ai_football_predictions/features/leagues/presentation/pages/league_table_screen.dart';


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

  double _pitchRotateX = 0.8;
  double _pitchRotateZ = 0.0;

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
    _tabController = TabController(length: 4, vsync: this, initialIndex: initialTab);
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
              color: const Color(0xFF161B22),
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () => _openTableForMatchLeague(_liveMatch.league),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _liveMatch.league,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white70),
                ],
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
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                shape: BoxShape.circle,
                border: Border.all(color: borderColor),
              ),
              child: const Icon(Icons.star_border_rounded, size: 19, color: Colors.white70),
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
                    tabAlignment: TabAlignment.start,
                    indicatorColor: primary,
                    indicatorWeight: 3,
                    labelColor: primary,
                    unselectedLabelColor: textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                      const Tab(text: 'Lineups'),
                      const Tab(text: 'Match Stats'),
                    ],
                  ),
                  backgroundColor: surface,
                  borderColor: borderColor,
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildTimelineTab(),
              _buildAIInsightsTab(),
              _buildLineupsTab(),
              _buildMatchStatsTab(),
            ],
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
              const Color(0xFF0D1117),
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
                      ] else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${m.homeScore ?? 0}',
                              style: TextStyle(
                                color: (m.homeScore ?? 0) > (m.awayScore ?? 0)
                                    ? AppTheme.primary
                                    : Colors.white,
                                fontSize: 32,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              '-',
                              style: TextStyle(
                                color: Colors.white30,
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
                                    : Colors.white,
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
                              const Icon(Icons.sports_soccer, size: 12, color: AppTheme.textSecondary),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  s,
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
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
                                  style: const TextStyle(
                                    color: Colors.white70,
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
                    const Icon(Icons.stadium_outlined, size: 13, color: Colors.white54),
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
                    const Icon(Icons.people_outline, size: 13, color: Colors.white54),
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
            Row(
              children: [
                _buildFotMobOddsButton(
                  context,
                  '1 (${_shortTeamName(m.homeTeam)})',
                  m.homeOdds ?? 9.00,
                  false,
                ),
                const SizedBox(width: 8),
                _buildFotMobOddsButton(
                  context,
                  'Draw (X)',
                  m.drawOdds ?? 6.50,
                  false,
                ),
                const SizedBox(width: 8),
                _buildFotMobOddsButton(
                  context,
                  '2 (${_shortTeamName(m.awayTeam)})',
                  m.awayOdds ?? 1.24,
                  true, // Highlighted pick
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
    double odds,
    bool isHighlighted,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF161B22),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Text(
                'Added $label @ ${odds.toStringAsFixed(2)} to slip',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isHighlighted
                ? AppTheme.primary.withValues(alpha: 0.12)
                : const Color(0xFF121721),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isHighlighted
                  ? AppTheme.primary.withValues(alpha: 0.7)
                  : AppTheme.cardBorderOf(context),
              width: isHighlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isHighlighted ? AppTheme.primary : AppTheme.textSecondaryOf(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                odds.toStringAsFixed(2),
                style: TextStyle(
                  color: isHighlighted ? AppTheme.primary : Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
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
            color: const Color(0xFF141923),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white12,
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
          style: const TextStyle(
            color: Colors.white,
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
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
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
              const Text(
                'No Match Events Yet',
                style: TextStyle(
                  color: Colors.white,
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
      );
    }

    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(14, 12, 14, bottomInset + 32),
      children: [
        const Text(
          'LIVE MATCH EVENTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppTheme.textSecondary,
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
            eventColor = AppTheme.primary;
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
            eventColor = Colors.white70;
            eventIcon = Icons.event_note_rounded;
            eventBadge = ev.type.toUpperCase();
          }

          final teamLabel = ev.team == 'home' ? m.homeTeam : m.awayTeam;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Minute column
                SizedBox(
                  width: 36,
                  child: Text(
                    "$minute'",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      color: eventColor,
                      fontSize: 13,
                    ),
                  ),
                ),
                // Icon pill
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: eventColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: eventColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(eventIcon, size: 14, color: eventColor),
                ),
                // Event details card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: eventColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                eventBadge,
                                style: TextStyle(
                                  color: eventColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              teamLabel,
                              style: TextStyle(
                                color: AppTheme.textSecondaryOf(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          ev.player,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AI INSIGHTS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildAIInsightsTab() {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(14, 14, 14, bottomInset + 32),
      children: [
        _buildLiveWinProbabilityCard(),
        const SizedBox(height: 14),
        _buildExpectedGoalsCard(),
        const SizedBox(height: 14),
        _buildAlgorithmicBettingTiersCard(),
        const SizedBox(height: 14),
        _buildAIPredictionCard(),
        if (_liveMatch.h2hSummary != null && _liveMatch.h2hSummary!.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildH2HGraphicalCard(),
        ],
        const SizedBox(height: 14),
        _buildRecentFormCard(),
        const SizedBox(height: 14),
        _buildStakingCard(),
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
                const Text(
                  'Live Telemetry Starts at Kickoff',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white30,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              // Away Team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Text(
                        m.awayTeam,
                        style: const TextStyle(
                          color: Colors.white,
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
                style: const TextStyle(
                  color: Colors.white,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                homeValue,
                style: TextStyle(
                  color: highlightHome ? homeColor : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                awayValue,
                style: TextStyle(
                  color: !highlightHome ? awayColor : Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
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
  // AI INSIGHTS SUB-CARDS (Image 2)
  // ─────────────────────────────────────────────────────────────
  Widget _buildLiveWinProbabilityCard() {
    final m = _liveMatch;
    final home = m.prediction.homeWinProbability;
    final draw = m.prediction.drawProbability;
    final away = m.prediction.awayWinProbability;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy_outlined, color: Color(0xFF00D06C), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Live Win Probability',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D06C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE MODEL v3.4',
                  style: TextStyle(
                    color: Color(0xFF00D06C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Horizontal segmented bar with percentages inside
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 20,
              child: Row(
                children: [
                  Expanded(
                    flex: home.round().clamp(5, 90),
                    child: Container(
                      color: const Color(0xFF00D06C),
                      alignment: Alignment.center,
                      child: Text(
                        '${home.round()}%',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: draw.round().clamp(5, 90),
                    child: Container(
                      color: const Color(0xFFF59E0B),
                      alignment: Alignment.center,
                      child: Text(
                        '${draw.round()}%',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: away.round().clamp(5, 90),
                    child: Container(
                      color: const Color(0xFF6366F1),
                      alignment: Alignment.center,
                      child: Text(
                        '${away.round()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Legend row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProbLegendDot(const Color(0xFF00D06C), '${_shortTeamName(m.homeTeam)}: ${home.round()}%'),
              _buildProbLegendDot(const Color(0xFFF59E0B), 'Draw: ${draw.round()}%'),
              _buildProbLegendDot(const Color(0xFF6366F1), '${_shortTeamName(m.awayTeam)}: ${away.round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProbLegendDot(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildExpectedGoalsCard() {
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final homeProb = _liveMatch.prediction.homeWinProbability;
    final awayProb = _liveMatch.prediction.awayWinProbability;
    final homeXg = (homeProb / 100 * 2.5).clamp(0.2, 3.8);
    final awayXg = (awayProb / 100 * 2.5).clamp(0.2, 3.8);
    final delta = (awayXg - homeXg).abs();
    final homeFlex = (homeXg / (homeXg + awayXg) * 100).round().clamp(10, 90);
    final awayFlex = 100 - homeFlex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Expected Goals (xG)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Shot Quality: ${(homeProb * 0.25).round()} vs ${(awayProb * 0.25).round()}',
                style: TextStyle(color: textSecondary, fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${homeXg.toStringAsFixed(2)} xG',
                style: const TextStyle(
                  color: Color(0xFFF59E0B),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Delta +${delta.toStringAsFixed(2)}',
                style: TextStyle(color: textSecondary, fontSize: 11),
              ),
              Text(
                '${awayXg.toStringAsFixed(2)} xG',
                style: const TextStyle(
                  color: Color(0xFF00D06C),
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: Row(
                children: [
                  Expanded(
                    flex: homeFlex,
                    child: Container(color: const Color(0xFFF59E0B)),
                  ),
                  Expanded(
                    flex: awayFlex,
                    child: Container(color: const Color(0xFF00D06C)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlgorithmicBettingTiersCard() {
    final m = _liveMatch;
    final surface = AppTheme.surfaceOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ALGORITHMIC BETTING TIERS',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            Text(
              'KELLY ADJUSTED',
              style: TextStyle(
                color: AppTheme.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SAFE PICK',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            m.prediction.recommendation.isNotEmpty
                                ? m.prediction.recommendation
                                : '${_shortTeamName(m.awayTeam)} to WIN',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      m.prediction.confidence > 60
                          ? 'High model confidence (${m.prediction.confidence.round()}%). Kelly-optimized simulation rating.'
                          : 'Calculated algorithmic edge based on form, rankings, and market odds.',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${_shortTeamName(m.awayTeam)} Win @ ${(m.awayOdds ?? 1.24).toStringAsFixed(2)} to slip'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (m.awayOdds ?? 1.24).toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.add, size: 14, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAIPredictionCard() {
    final m = _liveMatch;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text('AI Analysis',
                  style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            m.prediction.analysis,
            style: TextStyle(
                color: AppTheme.textSecondaryOf(context), height: 1.6, fontSize: 13),
          ),
        ],
      ),
    );
  }


  Widget _buildH2HGraphicalCard() {
    final m = _liveMatch;
    final primary = Theme.of(context).primaryColor;
    final textSecondary = AppTheme.textSecondaryOf(context);

    int hWins = 0;
    int aWins = 0;
    int draws = 0;
    int total = 0;

    final rawH2H = m.h2hSummary;
    if (rawH2H != null && rawH2H.isNotEmpty) {
      final cleanH2H = rawH2H.replaceAll(RegExp(r'\s*\([\d\-,\s]+\)'), '');
      
      final wonMatches = RegExp(r'([A-Za-z0-9\s\.\-]+?)\s+won\s+(\d+)', caseSensitive: false).allMatches(cleanH2H);
      for (final match in wonMatches) {
        final tName = (match.group(1) ?? '').trim().toLowerCase();
        final count = int.tryParse(match.group(2) ?? '0') ?? 0;
        final homeClean = m.homeTeam.toLowerCase();
        final awayClean = m.awayTeam.toLowerCase();
        
        if (tName.contains(homeClean) || homeClean.contains(tName)) {
          hWins = count;
        } else if (tName.contains(awayClean) || awayClean.contains(tName)) {
          aWins = count;
        }
      }

      final drawMatch = RegExp(r'(\d+)\s+Draw', caseSensitive: false).firstMatch(cleanH2H);
      if (drawMatch != null) {
        draws = int.tryParse(drawMatch.group(1) ?? '0') ?? 0;
      }
      total = hWins + aWins + draws;
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.compare_arrows_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Head-to-Head History',
                      style: TextStyle(
                        color: AppTheme.textPrimaryOf(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      isFirstMeeting ? '🆕 No previous meetings recorded' : 'Past $total Matches Overall Record',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
                Icon(Icons.analytics_rounded, size: 16, color: primary),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text('Recent Form',
                  style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(m.homeTeam,
                    style: TextStyle(
                        color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Text(m.awayTeam,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(
            max(homeRecent.length, awayRecent.length),
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                      child: i < homeRecent.length
                          ? _buildFormRow(context, homeRecent[i], true)
                          : const SizedBox()),
                  const SizedBox(width: 8),
                  Expanded(
                      child: i < awayRecent.length
                          ? _buildFormRow(context, awayRecent[i], false)
                          : const SizedBox()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow(BuildContext context, model.RecentMatch r, bool isHome) {
    Color color = Colors.orange;
    String status = 'Draw';
    if (r.result == 'W') {
      color = AppTheme.success;
      status = 'Win';
    } else if (r.result == 'L') {
      color = AppTheme.secondary;
      status = 'Loss';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(r.result,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(status,
                style: TextStyle(
                    color: AppTheme.textPrimaryOf(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStakingCard() {
    final m = _liveMatch;
    if (m.prediction.stakingOptions.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on, color: AppTheme.success, size: 20),
              const SizedBox(width: 8),
              Text('Staking Recommendations',
                  style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          ...m.prediction.stakingOptions.map((opt) {
            Color c = AppTheme.primary;
            if (opt.toLowerCase().contains('safe')) c = AppTheme.success;
            if (opt.toLowerCase().contains('risky')) c = AppTheme.secondary;
            if (opt.toLowerCase().contains('value')) c = AppTheme.primary;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Container(
                      width: 4,
                      height: 30,
                      decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(opt,
                        style: TextStyle(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LINEUPS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildLineupsTab() {
    final m = _liveMatch;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    if (m.homeLineupData != null && m.awayLineupData != null) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 32),
        children: [
          _buildRichLineupView(m.homeTeam, m.homeLogo, m.homeLineupData!, m.awayTeam, m.awayLogo, m.awayLineupData!),
        ],
      );
    }

    if (m.homeLineup == null || m.awayLineup == null || m.homeLineup!.isEmpty || m.awayLineup!.isEmpty) {
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 32),
        children: [
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 12),
                Text('Lineups not available yet',
                    style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 16)),
              ],
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.05)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildTeamLogo(m.homeLogo, m.homeTeam, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.homeTeam,
                                  style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.bold),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (m.homeLineupData?.formation != null && m.homeLineupData!.formation!.isNotEmpty)
                                Text(m.homeLineupData!.formation!,
                                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...m.homeLineup!.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(p, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
                    )),
                  ],
                ),
              ),
              Container(width: 1, height: 300, color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.1)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(m.awayTeam,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.bold),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              if (m.awayLineupData?.formation != null && m.awayLineupData!.formation!.isNotEmpty)
                                Text(m.awayLineupData!.formation!,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildTeamLogo(m.awayLogo, m.awayTeam, size: 26),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...m.awayLineup!.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(p, textAlign: TextAlign.right, style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isValidTacticalFormation(String f) {
    final clean = f.trim();
    final parts = clean.split('-').map((s) => int.tryParse(s.trim())).toList();
    if (parts.any((p) => p == null)) return false;
    // Real football formation has 3 or 4 outfield lines (e.g. 4-4-2, 5-4-1, or 4-2-3-1)
    if (parts.length < 3 || parts.length > 4) return false;
    // No line has 0 or > 5 outfield players (e.g. 11-0-0 is invalid)
    if (parts.any((p) => p! <= 0 || p > 5)) return false;
    final sum = parts.fold(0, (acc, p) => acc + p!);
    return sum == 10;
  }

  String _resolveFormation(model.TeamLineupData data) {
    if (data.formation != null && data.formation!.trim().isNotEmpty) {
      final f = data.formation!.trim();
      if (_isValidTacticalFormation(f)) {
        return f;
      }
    }
    final lines = _groupPlayersByLine(data.startingXI, data.formation);
    final defCount = lines[1].length;
    final midCount = lines[2].length;
    final fwdCount = lines[3].length;
    if (defCount > 0 && midCount > 0 && fwdCount > 0 && defCount <= 5 && midCount <= 5 && fwdCount <= 4) {
      return '$defCount-$midCount-$fwdCount';
    }
    return '4-3-3';
  }

  Widget _buildRichLineupView(
    String homeName, String homeLogo, model.TeamLineupData homeData,
    String awayName, String awayLogo, model.TeamLineupData awayData,
  ) {
    final homeFormation = _resolveFormation(homeData);
    final awayFormation = _resolveFormation(awayData);

    return Column(
      children: [
        // Top Matchup & Formation Header Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceOf(context),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Home Team
              Expanded(
                child: Row(
                  children: [
                    _buildTeamLogo(homeLogo, homeName, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            homeName,
                            style: TextStyle(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (homeFormation.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                homeFormation,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Center VS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              // Away Team
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            awayName,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppTheme.textPrimaryOf(context),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (awayFormation.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                awayFormation,
                                style: const TextStyle(
                                  color: AppTheme.secondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildTeamLogo(awayLogo, awayName, size: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        // Tactical Pitch Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.stadium_outlined, size: 16, color: AppTheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'TACTICAL FORMATIONS',
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (homeFormation.isNotEmpty && awayFormation.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$homeFormation vs $awayFormation',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textSecondaryOf(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Interactive 2D/3D switcher
            AnimatedBuilder(
              animation: AppSettingsService.instance,
              builder: (context, _) {
                final is2d = AppSettingsService.instance.use2dPitch;
                return InkWell(
                  onTap: () {
                    AppSettingsService.instance.setUse2dPitch(!is2d);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(is2d ? Icons.view_in_ar : Icons.crop_square, size: 13, color: AppTheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          is2d ? '3D View' : '2D View',
                          style: TextStyle(color: AppTheme.textPrimaryOf(context), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        
        // Tactical Pitch Canvas
        _buildTacticalPitch(
          homeName, homeLogo, homeFormation, homeData.startingXI,
          awayName, awayLogo, awayFormation, awayData.startingXI,
        ),
        
        // Substitutes Bench
        if (homeData.bench.isNotEmpty || awayData.bench.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.event_seat, size: 16, color: AppTheme.secondary),
                  const SizedBox(width: 6),
                  Text(
                    'SUBSTITUTES BENCH',
                    style: TextStyle(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Text(
                '${homeData.bench.length} vs ${awayData.bench.length} Players',
                style: TextStyle(
                  color: AppTheme.textSecondaryOf(context),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOf(context),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // Dual Team Bench Header with Formations
                Row(
                  children: [
                    // Home Bench Header
                    Expanded(
                      child: Row(
                        children: [
                          _buildTeamLogo(homeLogo, homeName, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  homeName,
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryOf(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  homeFormation.isNotEmpty
                                      ? 'Formation: $homeFormation'
                                      : '${homeData.bench.length} Subs',
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryOf(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.12),
                    ),
                    // Away Bench Header
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  awayName,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryOf(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  awayFormation.isNotEmpty
                                      ? 'Formation: $awayFormation'
                                      : '${awayData.bench.length} Subs',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppTheme.textSecondaryOf(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTeamLogo(awayLogo, awayName, size: 20),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08),
                ),
                const SizedBox(height: 12),
                // Bench player list
                _buildPlayerListGrid(homeData.bench, awayData.bench),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<List<model.PlayerLineup>> _groupPlayersByLine(List<model.PlayerLineup> players, [String? formation]) {
    if (players.isEmpty) return [[], [], [], []];

    // 1. First attempt: standard position-based categorization
    List<model.PlayerLineup> gks = [];
    List<model.PlayerLineup> defs = [];
    List<model.PlayerLineup> mids = [];
    List<model.PlayerLineup> fwds = [];

    for (var p in players) {
      final pos = p.position.toUpperCase().trim();
      if (pos == 'GK' || pos == 'G' || pos.contains('GOAL')) {
        gks.add(p);
      } else if (pos == 'DF' || pos == 'D' || pos == 'CB' || pos == 'LB' || pos == 'RB' || pos == 'WB' || pos == 'SW' || pos.contains('DEF')) {
        defs.add(p);
      } else if (pos == 'MF' || pos == 'M' || pos == 'DM' || pos == 'CM' || pos == 'AM' || pos == 'LM' || pos == 'RM' || pos.contains('MID')) {
        mids.add(p);
      } else if (pos == 'FW' || pos == 'F' || pos == 'ST' || pos == 'CF' || pos == 'LW' || pos == 'RW' || pos.contains('ATT') || pos.contains('FORW')) {
        fwds.add(p);
      } else {
        // Fallback for unknown / generic positions: check jersey number 1/12/13/22 for GK
        if (gks.isEmpty && (p.number == '1' || p.number == '12' || p.number == '13' || p.number == '22')) {
          gks.add(p);
        } else {
          mids.add(p);
        }
      }
    }

    // 2. Check if position distribution is collapsed (e.g. 11-0-0 bug where all 11 players ended up in one line)
    final isCollapsed = gks.isEmpty ||
        defs.length >= 7 ||
        mids.length >= 7 ||
        fwds.length >= 7 ||
        (defs.isEmpty && mids.isEmpty) ||
        (mids.isEmpty && fwds.isEmpty && defs.length > 5);

    if (isCollapsed && players.length >= 7) {
      final allOutfield = List<model.PlayerLineup>.from(players);

      // Find or pick the Goalkeeper
      model.PlayerLineup? gk;
      final gkIndex = allOutfield.indexWhere((p) =>
          p.position.toUpperCase().contains('G') ||
          p.number == '1' ||
          p.number == '12' ||
          p.number == '13');
      if (gkIndex != -1) {
        gk = allOutfield.removeAt(gkIndex);
      } else {
        gk = allOutfield.removeAt(0);
      }

      // Parse target line counts from formation or default to 4-3-3
      List<int> lineCounts = [4, 3, 3];
      if (formation != null && _isValidTacticalFormation(formation)) {
        lineCounts = formation.split('-').map((s) => int.parse(s.trim())).toList();
      }

      List<model.PlayerLineup> autoDefs = [];
      List<model.PlayerLineup> autoMids = [];
      List<model.PlayerLineup> autoFwds = [];

      int currentIndex = 0;
      if (lineCounts.length >= 3) {
        final defTarget = lineCounts[0].clamp(0, allOutfield.length);
        autoDefs = allOutfield.take(defTarget).toList();
        currentIndex += defTarget;

        if (lineCounts.length == 3) {
          final midTarget = lineCounts[1].clamp(0, allOutfield.length - currentIndex);
          autoMids = allOutfield.skip(currentIndex).take(midTarget).toList();
          currentIndex += midTarget;
          autoFwds = allOutfield.skip(currentIndex).toList();
        } else if (lineCounts.length == 4) {
          final midTarget = (lineCounts[1] + lineCounts[2]).clamp(0, allOutfield.length - currentIndex);
          autoMids = allOutfield.skip(currentIndex).take(midTarget).toList();
          currentIndex += midTarget;
          autoFwds = allOutfield.skip(currentIndex).toList();
        }
      }

      return [[gk], autoDefs, autoMids, autoFwds];
    }

    // Ensure we have at least 1 goalkeeper if 11 players are playing
    if (gks.isEmpty && players.length == 11) {
      if (defs.isNotEmpty) {
        gks.add(defs.removeAt(0));
      } else if (mids.isNotEmpty) {
        gks.add(mids.removeAt(0));
      }
    }

    return [gks, defs, mids, fwds];
  }

  Widget _buildTacticalPitch(
    String homeName, String homeLogo, String homeFormation, List<model.PlayerLineup> homeXI,
    String awayName, String awayLogo, String awayFormation, List<model.PlayerLineup> awayXI,
  ) {
    return AnimatedBuilder(
      animation: AppSettingsService.instance,
      builder: (context, _) {
        final is2d = AppSettingsService.instance.use2dPitch;

        Widget pitch = Container(
          width: double.infinity,
          height: 540, // Generous height for comfortable line spacing
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment.center,
              radius: 1.1,
              colors: [
                Color(0xFF1B5329),
                Color(0xFF154521),
                Color(0xFF0E3518),
              ],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Team Watermarks in each half
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: 0.08,
                    child: _buildTeamLogo(homeLogo, homeName, size: 110),
                  ),
                ),
              ),
              Positioned(
                bottom: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: 0.08,
                    child: _buildTeamLogo(awayLogo, awayName, size: 110),
                  ),
                ),
              ),

              // Pitch lines (center line, circle)
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
              ),
              // Center spot
              Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Home Penalty Box (Top)
              Positioned(
                top: 0,
                left: 65,
                right: 65,
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
              ),
              // Away Penalty Box (Bottom)
              Positioned(
                bottom: 0,
                left: 65,
                right: 65,
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                  ),
                ),
              ),

              // Floating Home Formation Banner (Top Left)
              Positioned(
                top: 10,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTeamLogo(homeLogo, homeName, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        homeName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      if (homeFormation.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            homeFormation,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Floating Away Formation Banner (Bottom Right)
              Positioned(
                bottom: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 4),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (awayFormation.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            awayFormation,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        awayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                      const SizedBox(width: 6),
                      _buildTeamLogo(awayLogo, awayName, size: 16),
                    ],
                  ),
                ),
              ),

              // Players Formation Lines
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 28, bottom: 4),
                        child: _buildTeamHalf(homeXI, true, AppTheme.primary, homeFormation),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 28),
                        child: _buildTeamHalf(awayXI, false, AppTheme.secondary, awayFormation),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        if (!is2d) {
          pitch = GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _pitchRotateX -= details.delta.dy * 0.01;
                _pitchRotateZ -= details.delta.dx * 0.01;
                _pitchRotateX = _pitchRotateX.clamp(0.0, 1.5);
              });
            },
            child: Transform(
              alignment: FractionalOffset.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateX(_pitchRotateX) // tilt
                ..rotateZ(_pitchRotateZ) // spin
                // ignore: deprecated_member_use
                ..scale(0.85, 0.85, 1.0)
                // ignore: deprecated_member_use
                ..translate(0.0, -25.0, 0.0),
              child: pitch,
            ),
          );
        }

        return Container(
          width: double.infinity,
          height: 540,
          clipBehavior: Clip.none,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.black.withValues(alpha: 0.1),
          ),
          child: Center(child: pitch),
        );
      },
    );
  }

  Widget _buildTeamHalf(List<model.PlayerLineup> players, bool isHome, Color teamColor, [String? formation]) {
    final lines = _groupPlayersByLine(players, formation);
    if (!isHome) {
      lines.setAll(0, lines.reversed.toList()); // Reverse for away team so GK is at the bottom
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: lines.map((linePlayers) {
        if (linePlayers.isEmpty) return const SizedBox();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: linePlayers.map((p) => _buildPitchPlayer(p, teamColor)).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPitchPlayer(model.PlayerLineup p, Color teamColor) {
    final lastName = p.name.trim().split(' ').last;
    final events = _liveMatch.events ?? [];
    final pLower = p.name.toLowerCase();
    final lastLower = lastName.toLowerCase();
    bool hasGoal = false;
    bool hasYellow = false;
    bool hasRed = false;

    for (final ev in events) {
      final evPlayer = ev.player.toLowerCase();
      if (pLower.isNotEmpty && (evPlayer.contains(pLower) || pLower.contains(evPlayer) || evPlayer.contains(lastLower))) {
        if (ev.scoringPlay || ev.type.toLowerCase().contains('goal')) hasGoal = true;
        if (ev.yellowCard) hasYellow = true;
        if (ev.redCard) hasRed = true;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: teamColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                p.number == '?' || p.number.isEmpty ? '-' : p.number,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            if (hasGoal)
              const Positioned(
                right: -6,
                top: -6,
                child: Text('⚽', style: TextStyle(fontSize: 8)),
              )
            else if (hasRed)
              const Positioned(
                right: -5,
                top: -5,
                child: Text('🟥', style: TextStyle(fontSize: 7)),
              )
            else if (hasYellow)
              const Positioned(
                right: -5,
                top: -5,
                child: Text('🟨', style: TextStyle(fontSize: 7)),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          constraints: const BoxConstraints(maxWidth: 58),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Text(
            lastName,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerListGrid(List<model.PlayerLineup> homeList, List<model.PlayerLineup> awayList) {
    final int maxLen = max(homeList.length, awayList.length);
    List<Widget> rows = [];
    for (int i = 0; i < maxLen; i++) {
      final homeP = i < homeList.length ? homeList[i] : null;
      final awayP = i < awayList.length ? awayList[i] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: homeP != null ? _buildPlayerRow(homeP, true) : const SizedBox()),
              Container(
                width: 1,
                height: 24,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08),
              ),
              Expanded(child: awayP != null ? _buildPlayerRow(awayP, false) : const SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildPlayerRow(model.PlayerLineup p, bool isHome) {
    Widget numBadge = Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.08)),
      ),
      child: Text(
        p.number.isNotEmpty && p.number != '?' ? p.number : '-',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textSecondaryOf(context)),
      ),
    );

    Color posColor = Colors.grey;
    final String pos = p.position.toUpperCase();
    if (pos.contains('G')) {
      posColor = const Color(0xFFF59E0B); // Amber
    } else if (pos.contains('D') || (pos.contains('C') && !pos.contains('M')) || pos.contains('B')) {
      posColor = const Color(0xFF3B82F6); // Blue
    } else if (pos.contains('M')) {
      posColor = const Color(0xFF10B981); // Emerald Green
    } else if (pos.contains('F') || pos.contains('S') || pos.contains('W')) {
      posColor = const Color(0xFFEF4444); // Red
    }

    Widget posBadge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: posColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: posColor.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        pos.isEmpty ? '-' : pos,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: posColor),
      ),
    );

    // Check if substitute came onto the pitch during match
    final events = _liveMatch.events ?? [];
    final pLower = p.name.toLowerCase();
    String? subClock;
    bool hasGoal = false;
    bool hasCard = false;

    for (final ev in events) {
      final evPlayer = ev.player.toLowerCase();
      if (pLower.isNotEmpty && (evPlayer.contains(pLower) || pLower.contains(evPlayer))) {
        if (ev.type.toLowerCase().contains('substitution')) {
          subClock = ev.clock.isNotEmpty ? "${ev.clock}'" : 'SUB';
        }
        if (ev.scoringPlay || ev.type.toLowerCase().contains('goal')) hasGoal = true;
        if (ev.yellowCard || ev.redCard) hasCard = true;
      }
    }

    Widget subBadge = subClock != null
        ? Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '▲ $subClock',
              style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          )
        : const SizedBox.shrink();

    Widget statusIcon = hasGoal
        ? const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('⚽', style: TextStyle(fontSize: 9)))
        : hasCard
            ? const Padding(padding: EdgeInsets.symmetric(horizontal: 2), child: Text('🟨', style: TextStyle(fontSize: 8)))
            : const SizedBox.shrink();

    if (isHome) {
      return Row(
        children: [
          numBadge,
          const SizedBox(width: 5),
          posBadge,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              p.name,
              style: TextStyle(
                color: AppTheme.textPrimaryOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subBadge,
          statusIcon,
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          statusIcon,
          subBadge,
          Expanded(
            child: Text(
              p.name,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.textPrimaryOf(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          posBadge,
          const SizedBox(width: 5),
          numBadge,
        ],
      );
    }
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

  void _openTableForMatchLeague(String leagueName) {
    ScrapedLeagueInfo? targetLeague;
    final lLower = leagueName.toLowerCase();
    for (final c in LeagueRegistry.countries) {
      for (final l in c.leagues) {
        if (lLower.contains(l.name.toLowerCase()) || l.name.toLowerCase().contains(lLower)) {
          targetLeague = l;
          break;
        }
      }
      if (targetLeague != null) break;
    }

    targetLeague ??= const ScrapedLeagueInfo(
      slug: 'ksa.1',
      name: 'Saudi Pro League',
      country: 'Saudi Arabia',
      flagEmoji: '🇸🇦',
      tier: 'Tier 1',
      logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/spl.png',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeagueTableScreen(league: targetLeague!),
      ),
    );
  }
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
