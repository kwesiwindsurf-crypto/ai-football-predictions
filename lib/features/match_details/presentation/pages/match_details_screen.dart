import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/app_settings_service.dart';
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
                  icon: Icon(Icons.sports_soccer_rounded, size: 18),
                  text: 'Tactical Board',
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
          _buildTacticalTab(),
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
            AppTheme.surface,
            AppTheme.primary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'AI Win Probability',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
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
                    m.homeTeam, home, AppTheme.success, true),
              ),
              Expanded(
                child: _buildProbBarColumn('Draw', draw, Colors.orange, false),
              ),
              Expanded(
                child: _buildProbBarColumn(
                    m.awayTeam, away, AppTheme.secondary, false),
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
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('AI',
                      style: TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('RECOMMENDATION',
                          style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                        m.prediction.recommendation,
                        style: const TextStyle(
                            color: Colors.white,
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
      String label, double prob, Color color, bool highlight) {
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
            color: Colors.white.withValues(alpha: 0.04),
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
          style: const TextStyle(
              color: AppTheme.textSecondary, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildAIPredictionCard() {
    final m = widget.match;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              const Text('AI Analysis',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            m.prediction.analysis,
            style: const TextStyle(
                color: AppTheme.textSecondary, height: 1.6, fontSize: 13),
          ),
          if (m.oddsRating != null) ...[
            const SizedBox(height: 12),
            _buildOddsRatingChip(m.oddsRating!),
          ],
        ],
      ),
    );
  }

  Widget _buildOddsRatingChip(int rating) {
    Color color;
    String label;
    if (rating < -10) {
      color = AppTheme.success;
      label = 'Strong Home Advantage';
    } else if (rating > 10) {
      color = AppTheme.secondary;
      label = 'Strong Away Advantage';
    } else if (rating < 0) {
      color = Colors.lightGreen;
      label = 'Slight Home Lean';
    } else if (rating > 0) {
      color = Colors.deepOrangeAccent;
      label = 'Slight Away Lean';
    } else {
      color = Colors.orange;
      label = 'Balanced Match';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Rating: $rating  ·  $label',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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

    // Default graphics values if no prior meetings found
    if (total == 0) {
      hWins = (m.prediction.homeWinProbability / 20).round().clamp(1, 4);
      aWins = (m.prediction.awayWinProbability / 20).round().clamp(1, 4);
      draws = 1;
      total = hWins + aWins + draws;
    }

    final homePct = ((hWins / total) * 100).round();
    final drawPct = ((draws / total) * 100).round();
    final awayPct = (100 - homePct - drawPct).clamp(0, 100);

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
              Column(
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
                    'Past $total Matches Overall Record',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
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
                        '$hWins Wins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$homePct%',
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
                        '$draws',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$drawPct%',
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
                        '$aWins Wins',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '$awayPct%',
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

          // Multi-color Segmented Progress Bar
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
                    hWins > aWins
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text('Recent Form',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(m.homeTeam,
                    style: const TextStyle(
                        color: AppTheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: Text(m.awayTeam,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: AppTheme.secondary,
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
                          ? _buildFormRow(homeRecent[i], true)
                          : const SizedBox()),
                  const SizedBox(width: 8),
                  Expanded(
                      child: i < awayRecent.length
                          ? _buildFormRow(awayRecent[i], false)
                          : const SizedBox()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormRow(model.RecentMatch r, bool isHome) {
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
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 10),
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
        color: AppTheme.surface,
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
              const Text('Staking Recommendations',
                  style: TextStyle(
                      color: Colors.white,
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
                        style: const TextStyle(
                            color: Colors.white,
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
  // TACTICAL BOARD TAB
  // ─────────────────────────────────────────────────────────────
  Widget _buildTacticalTab() {
    final homeLineup = widget.match.homeLineup;
    final awayLineup = widget.match.awayLineup;
    final hasLineups = (homeLineup != null && homeLineup.startingXI.isNotEmpty) ||
        (awayLineup != null && awayLineup.startingXI.isNotEmpty);

    if (!hasLineups) return _buildLineupPendingCard();

    return _TacticalBoardView(match: widget.match, header: _buildHeroHeader());
  }

  Widget _buildLineupPendingCard() {
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroHeader(),
        const SizedBox(height: 32),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: Icon(Icons.sports_soccer_rounded,
                      color: primary, size: 48),
                ),
                const SizedBox(height: 24),
                Text('Tactical Board Pending',
                    style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  'Official lineups are announced approximately\n1 hour before kickoff.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: textSecondary, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: primary, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AI predictions & odds are ready on the Insights tab.',
                          style: TextStyle(
                              color: primary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

// ─────────────────────────────────────────────────────────────
// TACTICAL BOARD AS SEPARATE STATEFUL WIDGET
// ─────────────────────────────────────────────────────────────
class _TacticalBoardView extends StatefulWidget {
  final model.Match match;
  final Widget? header;
  const _TacticalBoardView({required this.match, this.header});

  @override
  State<_TacticalBoardView> createState() => _TacticalBoardViewState();
}

class _TacticalBoardViewState extends State<_TacticalBoardView> {
  bool _showHome = true;

  @override
  Widget build(BuildContext context) {
    final homeLineup = widget.match.homeLineup;
    final awayLineup = widget.match.awayLineup;
    final current = _showHome ? homeLineup : awayLineup;
    final settings = AppSettingsService.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final is3d = settings.is3dPitch; // If 2d is unchecked, make it 3d!

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.header != null) ...[
              widget.header!,
              const SizedBox(height: 16),
            ],

            // Team toggle + 2D/3D Perspective Switcher
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceOf(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorderOf(context)),
                    ),
                    child: Row(
                      children: [
                        _buildToggle(widget.match.homeTeam, true),
                        _buildToggle(widget.match.awayTeam, false),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 2D / 3D Mode Selector
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceOf(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorderOf(context)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPerspectiveToggle('2D', !is3d, () => settings.setUse2dPitch(true)),
                      _buildPerspectiveToggle('3D', is3d, () => settings.setUse2dPitch(false)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Avg rating badge
            if (current != null && (current.avgRating ?? 0) > 0)
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    '∅ ${current.avgRating} Squad Rating',
                    style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ),

            // Pitch board (2D or 3D based on setting)
            if (current != null && current.startingXI.isNotEmpty) ...[
              _buildPitchBoard(current.startingXI, is3d),
              const SizedBox(height: 16),
            ],

            // Bench
            if (current != null && current.bench.isNotEmpty)
              _buildBenchSection(current.bench),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildPerspectiveToggle(String label, bool active, VoidCallback onTap) {
    final primary = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == '3D') ...[
              Icon(Icons.view_in_ar_rounded, size: 14, color: active ? Colors.black : AppTheme.textSecondaryOf(context)),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.black : AppTheme.textSecondaryOf(context),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle(String teamName, bool isHome) {
    final active = _showHome == isHome;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _showHome = isHome),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              teamName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? Colors.black : AppTheme.textPrimaryOf(context),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPitchBoard(List<model.PlayerLineup> starters, bool is3d) {
    if (is3d) {
      return _build3dPitchBoard(starters, _showHome);
    }
    return _build2dPitchBoard(starters, _showHome);
  }

  // ─────────────────────────────────────────────────────────────
  // 2D PITCH BOARD (Left team faces right, Right team faces left)
  // ─────────────────────────────────────────────────────────────
  Widget _build2dPitchBoard(List<model.PlayerLineup> starters, bool isHome) {
    final gks = starters.where((p) => p.position == 'GK').toList();
    final dfs = starters.where((p) => p.position == 'DF').toList();
    final mfs = starters.where((p) => p.position == 'MF').toList();
    final fws = starters
        .where((p) => p.position == 'ST' || p.position == 'FW')
        .toList();

    // Left team faces right: GK -> DF -> MF -> FW
    // Right team faces left: FW -> MF -> DF -> GK
    final columns = isHome
        ? [
            gks.isNotEmpty ? gks : starters.skip(10).take(1).toList(),
            dfs.isNotEmpty ? dfs : starters.skip(6).take(4).toList(),
            mfs.isNotEmpty ? mfs : starters.skip(2).take(4).toList(),
            fws.isNotEmpty ? fws : starters.take(2).toList(),
          ]
        : [
            fws.isNotEmpty ? fws : starters.take(2).toList(),
            mfs.isNotEmpty ? mfs : starters.skip(2).take(4).toList(),
            dfs.isNotEmpty ? dfs : starters.skip(6).take(4).toList(),
            gks.isNotEmpty ? gks : starters.skip(10).take(1).toList(),
          ];

    return Container(
      width: double.infinity,
      height: 360,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: const _PitchPainter(is3d: false))),
            // Direction Banner
            Positioned(
              top: 8,
              left: isHome ? 12 : null,
              right: !isHome ? 12 : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isHome) const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 12),
                    Text(
                      isHome ? 'ATTACKING RIGHT ➡️' : '⬅️ ATTACKING LEFT',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isHome) const Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 12),
                  ],
                ),
              ),
            ),
            // Left & Right Goal indicators
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Center(child: _buildHorizontalGoalPost(isLeft: true)),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(child: _buildHorizontalGoalPost(isLeft: false)),
            ),
            // Players arranged horizontally
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: columns.map(_build2dPlayerColumn).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build2dPlayerColumn(List<model.PlayerLineup> players) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map(_build2dPlayerNode).toList(),
    );
  }

  Widget _build2dPlayerNode(model.PlayerLineup player) {
    Color ratingColor = AppTheme.textSecondary;
    if (player.rating >= 75) { ratingColor = const Color(0xFFFFD700); }
    else if (player.rating >= 65) { ratingColor = AppTheme.primary; }
    else if (player.rating >= 50) { ratingColor = Colors.orangeAccent; }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF132A13),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4)
                ],
              ),
              child: Center(
                child: Text(
                  player.number.isNotEmpty ? '#${player.number}' : player.position,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10),
                ),
              ),
            ),
            if (player.rating > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ratingColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${player.rating}',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 8)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          constraints: const BoxConstraints(maxWidth: 62),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            player.name.split(' ').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w600),
          ),
        ),
        Text(player.position,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 8,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 3D ISOMETRIC STADIUM PITCH BOARD (Interactive Real-Time Motion)
  // ─────────────────────────────────────────────────────────────
  Widget _build3dPitchBoard(List<model.PlayerLineup> starters, bool isHome) {
    return _Interactive3dPitchBoard(starters: starters, isHome: isHome);
  }

  Widget _buildHorizontalGoalPost({required bool isLeft}) {
    return Container(
      width: 8,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        border: Border(
          top: const BorderSide(color: Colors.white, width: 2),
          bottom: const BorderSide(color: Colors.white, width: 2),
          left: isLeft ? const BorderSide(color: Colors.white, width: 2.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 2.5) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBenchSection(List<model.PlayerLineup> bench) {
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final primary = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.airline_seat_recline_normal_rounded,
                  color: primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Bench / Substitutes (${bench.length})',
                style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bench.map((player) {
            Color ratingColor = textSecondary;
            if (player.rating >= 75) { ratingColor = const Color(0xFFFFD700); }
            else if (player.rating >= 65) { ratingColor = primary; }
            else if (player.rating >= 50) { ratingColor = Colors.orangeAccent; }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: textPrimary.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: textPrimary.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Text(
                        player.number.isNotEmpty ? '#${player.number}' : '-',
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(player.name,
                            style: TextStyle(
                                color: textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        if (player.stats != null && player.stats!.isNotEmpty)
                          Text('Games/Goals: ${player.stats}',
                              style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 11)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: textPrimary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(player.position,
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (player.rating > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ratingColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: ratingColor.withValues(alpha: 0.5)),
                      ),
                      child: Text('${player.rating}',
                          style: TextStyle(
                              color: ratingColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Interactive3dPitchBoard extends StatefulWidget {
  final List<model.PlayerLineup> starters;
  final bool isHome;

  const _Interactive3dPitchBoard({
    required this.starters,
    required this.isHome,
  });

  @override
  State<_Interactive3dPitchBoard> createState() => _Interactive3dPitchBoardState();
}

class _Interactive3dPitchBoardState extends State<_Interactive3dPitchBoard>
    with SingleTickerProviderStateMixin {
  static const double _defaultTiltX = 0.44;
  static const double _defaultRotY = 0.0;
  static const double _defaultScale = 1.0;

  double _tiltX = _defaultTiltX;
  double _rotY = _defaultRotY;
  double _scale = _defaultScale;
  double _baseScale = _defaultScale;

  late AnimationController _resetController;
  late Animation<double> _tiltAnimation;
  late Animation<double> _rotAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(() {
        setState(() {
          _tiltX = _tiltAnimation.value;
          _rotY = _rotAnimation.value;
          _scale = _scaleAnimation.value;
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _resetToDefault() {
    _tiltAnimation = Tween<double>(begin: _tiltX, end: _defaultTiltX).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _rotAnimation = Tween<double>(begin: _rotY, end: _defaultRotY).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _scaleAnimation = Tween<double>(begin: _scale, end: _defaultScale).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0);
  }

  bool get _isModified =>
      (_tiltX - _defaultTiltX).abs() > 0.03 ||
      _rotY.abs() > 0.03 ||
      (_scale - _defaultScale).abs() > 0.03;

  @override
  Widget build(BuildContext context) {
    final gks = widget.starters.where((p) => p.position == 'GK').toList();
    final dfs = widget.starters.where((p) => p.position == 'DF').toList();
    final mfs = widget.starters.where((p) => p.position == 'MF').toList();
    final fws = widget.starters
        .where((p) => p.position == 'ST' || p.position == 'FW')
        .toList();

    // Left team faces right: GK -> DF -> MF -> FW
    // Right team faces left: FW -> MF -> DF -> GK
    final columns = widget.isHome
        ? [
            gks.isNotEmpty ? gks : widget.starters.skip(10).take(1).toList(),
            dfs.isNotEmpty ? dfs : widget.starters.skip(6).take(4).toList(),
            mfs.isNotEmpty ? mfs : widget.starters.skip(2).take(4).toList(),
            fws.isNotEmpty ? fws : widget.starters.take(2).toList(),
          ]
        : [
            fws.isNotEmpty ? fws : widget.starters.take(2).toList(),
            mfs.isNotEmpty ? mfs : widget.starters.skip(2).take(4).toList(),
            dfs.isNotEmpty ? dfs : widget.starters.skip(6).take(4).toList(),
            gks.isNotEmpty ? gks : widget.starters.skip(10).take(1).toList(),
          ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.95,
          colors: [
            Color(0xFF0F3A1B), // Stadium turf glow
            Color(0xFF071B0D), // Night atmosphere
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 3D Stadium Interactive Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_rounded, color: Color(0xFF10B981), size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      '3D INTERACTIVE • DRAG TO ROTATE',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (_isModified) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _resetToDefault,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.restart_alt_rounded, color: Color(0xFF10B981), size: 12),
                              SizedBox(width: 3),
                              Text(
                                'Reset',
                                style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    widget.isHome ? 'LEFT ➡️ RIGHT' : 'RIGHT ⬅️ LEFT',
                    style: TextStyle(
                      color: widget.isHome ? const Color(0xFF38BDF8) : const Color(0xFFF472B6),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Interactive 3D Perspective Pitch with Real-Time Motion
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (details) {
              _resetController.stop();
              _baseScale = _scale;
            },
            onScaleUpdate: (details) {
              setState(() {
                if (details.pointerCount == 1) {
                  // 1-finger drag: pan/rotate
                  _rotY = (_rotY + details.focalPointDelta.dx * 0.005).clamp(-0.55, 0.55);
                  _tiltX = (_tiltX - details.focalPointDelta.dy * 0.004).clamp(0.12, 0.72);
                } else if (details.pointerCount >= 2) {
                  // 2-finger pinch: scale
                  _scale = (_baseScale * details.scale).clamp(0.85, 1.30);
                }
              });
            },
            onDoubleTap: _resetToDefault,
            child: SizedBox(
              height: 380,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..scaleByDouble(_scale, _scale, 1.0, 1.0)
                  ..rotateX(_tiltX)
                  ..rotateY(_rotY),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                    boxShadow: [
                      // 3D Turf thickness bevel shadow
                      BoxShadow(
                        color: const Color(0xFF09290D),
                        offset: Offset(0, 14 * _scale),
                        blurRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        offset: Offset(0, 26 * _scale),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        // Alternating grass stripes & horizontal pitch lines
                        Positioned.fill(
                          child: const CustomPaint(
                            painter: _PitchPainter(is3d: true),
                          ),
                        ),
                        // Left Goal Post
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _buildHorizontalGoalPost(isLeft: true)),
                        ),
                        // Right Goal Post
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _buildHorizontalGoalPost(isLeft: false)),
                        ),
                        // Players positioned horizontally across pitch in 3D
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: columns.map(_build3dPlayerColumn).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Interactive Subtitle Tip
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Drag with finger to rotate & tilt • Pinch to zoom • Double-tap to reset',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalGoalPost({required bool isLeft}) {
    return Container(
      width: 8,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        border: Border(
          top: const BorderSide(color: Colors.white, width: 2),
          bottom: const BorderSide(color: Colors.white, width: 2),
          left: isLeft ? const BorderSide(color: Colors.white, width: 2.5) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: Colors.white, width: 2.5) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _build3dPlayerColumn(List<model.PlayerLineup> players) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map(_build3dPlayerNode).toList(),
    );
  }

  Widget _build3dPlayerNode(model.PlayerLineup player) {
    Color ratingColor = AppTheme.textSecondary;
    if (player.rating >= 75) {
      ratingColor = const Color(0xFFFFD700);
    } else if (player.rating >= 65) {
      ratingColor = const Color(0xFF38BDF8);
    } else if (player.rating >= 50) {
      ratingColor = Colors.orangeAccent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Counter-tilt & counter-rotate player dynamically so it stands upright facing camera
        Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..rotateX(-_tiltX)
            ..rotateY(-_rotY),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D Player Avatar Badge
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E7D32), Color(0xFF0F3A1B)],
                      ),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.55),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        player.number.isNotEmpty ? '#${player.number}' : player.position,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  if (player.rating > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: ratingColor,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 3),
                          ],
                        ),
                        child: Text(
                          '${player.rating}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              // Floating Name Pill
              Container(
                constraints: const BoxConstraints(maxWidth: 68),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Text(
                  player.name.split(' ').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Elliptical turf drop shadow
        Container(
          width: 24,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: const BorderRadius.all(Radius.elliptical(24, 5)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PITCH PAINTER
// ─────────────────────────────────────────────────────────────
class _PitchPainter extends CustomPainter {
  final bool is3d;
  const _PitchPainter({this.is3d = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: is3d ? 0.45 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = is3d ? 2.0 : 1.5;

    // Alternating vertical grass mowing stripes
    final stripePaint = Paint()
      ..color = is3d
          ? const Color(0xFF144D19).withValues(alpha: 0.35)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    const stripeCount = 10;
    final stripeW = size.width / stripeCount;
    for (int i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(
          Rect.fromLTWH(i * stripeW, 0, stripeW, size.height), stripePaint);
    }

    // Outer pitch boundary
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Halfway line (vertical down center)
    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      paint,
    );

    // Center circle & center spot
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 40, paint);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2.5, paint);
    paint.style = PaintingStyle.stroke;

    // Left penalty box (Home)
    const boxW = 52.0;
    const boxH = 140.0;
    final boxY = (size.height - boxH) / 2;
    canvas.drawRect(Rect.fromLTWH(0, boxY, boxW, boxH), paint);

    // Left 6-yard goal area
    const goalBoxW = 20.0;
    const goalBoxH = 70.0;
    final goalBoxY = (size.height - goalBoxH) / 2;
    canvas.drawRect(Rect.fromLTWH(0, goalBoxY, goalBoxW, goalBoxH), paint);

    // Left penalty spot
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(36, size.height / 2), 2, paint);
    paint.style = PaintingStyle.stroke;

    // Right penalty box (Away)
    canvas.drawRect(Rect.fromLTWH(size.width - boxW, boxY, boxW, boxH), paint);

    // Right 6-yard goal area
    canvas.drawRect(Rect.fromLTWH(size.width - goalBoxW, goalBoxY, goalBoxW, goalBoxH), paint);

    // Right penalty spot
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width - 36, size.height / 2), 2, paint);
    paint.style = PaintingStyle.stroke;
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) => oldDelegate.is3d != is3d;
}
