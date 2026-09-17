import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';

import '../../../../core/services/analytics_service.dart';


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

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('MatchDetailsScreen');
    AnalyticsService.instance.logMatchView(
      matchId: widget.match.id,
      homeTeam: widget.match.homeTeam,
      awayTeam: widget.match.awayTeam,
      league: widget.match.league,
    );
    _tabController = TabController(length: 2, vsync: this);
    _headerAnim =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeIn = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: textPrimary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.arrow_back_ios_new, size: 16, color: textPrimary),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.match.league,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primary,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: primary,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(
                  icon: Icon(Icons.smart_toy_rounded, size: 18),
                  text: 'AI Insights',
                ),
                Tab(
                  icon: Icon(Icons.people_alt_rounded, size: 18),
                  text: 'Lineups',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAIInsightsTab(),
          _buildLineupsTab(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HERO HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    final m = widget.match;
    final isLive = m.status == model.MatchStatus.live;
    final isFinished = m.status == model.MatchStatus.finished;
    final timeStr = _formatTime(m.date);
    final dateStr = _formatDate(m.date);
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return FadeTransition(
      opacity: _fadeIn,
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // League badge & Match status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      m.league,
                      style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (isLive)
                  _buildLivePulse("${m.elapsed ?? 0}'")
                else if (isFinished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: textSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Full Time',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  Text(
                    dateStr,
                    style: TextStyle(color: textSecondary, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Teams row
            Row(
              children: [
                Expanded(child: _buildTeamCard(m.homeTeam, m.homeLogo, true)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      if (isLive || isFinished) ...[
                        Text(
                          '${m.homeScore ?? 0} - ${m.awayScore ?? 0}',
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ] else ...[
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kickoff',
                          style: TextStyle(color: textSecondary, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(child: _buildTeamCard(m.awayTeam, m.awayLogo, false)),
              ],
            ),

            if (m.homeOdds != null || m.drawOdds != null || m.awayOdds != null) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOddsPill('1', m.homeOdds, AppTheme.success),
                  const SizedBox(width: 8),
                  _buildOddsPill('X', m.drawOdds, Colors.orange),
                  const SizedBox(width: 8),
                  _buildOddsPill('2', m.awayOdds, AppTheme.secondary),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(String name, String logo, bool isHome) {
    return Column(
      children: [
        // Team crest
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                (isHome ? AppTheme.primary : AppTheme.secondary).withValues(alpha: 0.15),
                Colors.transparent,
              ],
            ),
            border: Border.all(
              color: (isHome ? AppTheme.primary : AppTheme.secondary).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: ClipOval(child: _buildTeamLogo(logo, name)),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppTheme.textPrimaryOf(context),
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        // Form badge under name
        if ((isHome ? widget.match.homeForm : widget.match.awayForm) != null) ...[
          const SizedBox(height: 4),
          _buildMiniForm(
              (isHome ? widget.match.homeForm : widget.match.awayForm)!),
        ],
      ],
    );
  }

  Widget _buildTeamLogo(String logo, String teamName) {
    // Try cricket/football team CDN first (logo via clearbit-style search)
    // Use soccer-rating.com flag as logo, or initials fallback
    if (logo.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logo,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => _teamInitials(teamName),
        placeholder: (context, url) => const SizedBox(width: 56, height: 56),
      );
    }
    return _teamInitials(teamName);
  }

  Widget _teamInitials(String name) {
    final parts = name.split(' ');
    final initials = parts.length > 1
        ? '${parts[0][0]}${parts[1][0]}'
        : name.substring(0, min(2, name.length));
    return Container(
      color: Colors.transparent,
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
      ),
    );
  }

  Widget _buildMiniForm(String form) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: form.split('').take(5).map((c) {
        Color color = Colors.orange;
        if (c == 'W') color = AppTheme.success;
        if (c == 'L') color = AppTheme.secondary;
        return Container(
          margin: const EdgeInsets.only(left: 2),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(c,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 7,
                    fontWeight: FontWeight.bold)),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLivePulse(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Colors.red, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
      ],
    );
  }

  Widget _buildOddsPill(String label, double? odds, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          Text(
            odds != null ? odds.toStringAsFixed(2) : '-',
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // AI INSIGHTS TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildAIInsightsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 16),
        _buildPredictionGraph(),
        const SizedBox(height: 16),
        _buildAIPredictionCard(),
        const SizedBox(height: 16),
        _buildH2HGraphicalCard(),
        const SizedBox(height: 16),
        _buildRecentFormCard(),
        const SizedBox(height: 16),
        _buildStakingCard(),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildPredictionGraph() {
    final m = widget.match;
    final home = m.prediction.homeWinProbability;
    final draw = m.prediction.drawProbability;
    final away = m.prediction.awayWinProbability;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceOf(context),
            AppTheme.primaryOf(context).withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryOf(context).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.smart_toy_rounded, color: AppTheme.primaryOf(context), size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Win Probability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimaryOf(context),
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('LIVE ODDS',
                    style: TextStyle(
                        color: AppTheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
              )
            ],
          ),
          const SizedBox(height: 20),

          // Donut-style bar graph
          Row(
            children: [
              Expanded(
                child: _buildProbBarColumn(
                    context, m.homeTeam, home, AppTheme.success, true),
              ),
              Expanded(
                child: _buildProbBarColumn(
                    context, 'Draw', draw, Colors.orange, false),
              ),
              Expanded(
                child: _buildProbBarColumn(
                    context, m.awayTeam, away, AppTheme.secondary, false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Unified horizontal bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(
                      flex: home.round(),
                      child: Container(color: AppTheme.success)),
                  Expanded(
                      flex: draw.round(),
                      child: Container(color: Colors.orange)),
                  Expanded(
                      flex: away.round(),
                      child: Container(color: AppTheme.secondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // AI Recommendation badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.backgroundOf(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primaryOf(context).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOf(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('AI',
                      style: TextStyle(
                          color: AppTheme.primaryOf(context),
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('RECOMMENDATION',
                          style: TextStyle(
                              color: AppTheme.textSecondaryOf(context),
                              fontSize: 9,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                        m.prediction.recommendation,
                        style: TextStyle(
                            color: AppTheme.textPrimaryOf(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios,
                    size: 14, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProbBarColumn(
      BuildContext context, String label, double prob, Color color, bool highlight) {
    final height = (prob / 100 * 90).clamp(12.0, 90.0);
    return Column(
      children: [
        Text(
          '${prob.round()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.textPrimaryOf(context).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  color,
                  color.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: AppTheme.textSecondaryOf(context), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAIPredictionCard() {
    final m = widget.match;
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
    final m = widget.match;
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
    final m = widget.match;
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
    if (r.result == 'W') color = AppTheme.success;
    if (r.result == 'L') color = AppTheme.secondary;

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
          const SizedBox(width: 6),
          Expanded(
            child: Text('${r.goalsFor}-${r.goalsAgainst} vs ${r.opponent}',
                style: TextStyle(
                    color: AppTheme.textPrimaryOf(context), fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStakingCard() {
    final m = widget.match;
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
    final m = widget.match;
    if (m.homeLineup == null || m.awayLineup == null || m.homeLineup!.isEmpty || m.awayLineup!.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeroHeader(),
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
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 24),
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
                        _buildTeamLogo(m.homeLogo, m.homeTeam),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(m.homeTeam,
                              style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
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
                          child: Text(m.awayTeam,
                              textAlign: TextAlign.right,
                              style: TextStyle(color: AppTheme.textPrimaryOf(context), fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        _buildTeamLogo(m.awayLogo, m.awayTeam),
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
    return form.split('').take(5).toList().asMap().entries.map((e) {
      final c = e.value;
      return model.RecentMatch(
        opponent: 'Opponent ${e.key + 1}',
        goalsFor: c == 'W' ? 2 : c == 'L' ? 0 : 1,
        goalsAgainst: c == 'L' ? 2 : c == 'W' ? 0 : 1,
        result: c,
        isHome: e.key % 2 == 0,
      );
    }).toList();
  }
}
