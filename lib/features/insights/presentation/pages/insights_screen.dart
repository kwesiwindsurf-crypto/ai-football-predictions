import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/betting_tracker_service.dart';
import '../../../../core/services/matches_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/breathing_gradient.dart';
import '../../../../models/match_model.dart' as model;
import '../../../match_details/presentation/pages/match_details_screen.dart';

/// AI Insights — a GoalFlow-style feed of the strongest AI picks.
/// Date tabs (Yesterday / Today / Tomorrow) + filter pills
/// (All / Major / Hot / Value) over insight cards ranked by confidence.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> with TickerProviderStateMixin {
  int _dayOffset = 0; // -1 yesterday, 0 today, 1 tomorrow
  String _filter = 'All';
  final PageController _heroController = PageController(viewportFraction: 0.88);
  Timer? _heroAutoScroll;
  int _heroPage = 0;
  // Slow "Ken Burns" breathing/zoom applied to the active hero photo.
  late final AnimationController _heroZoom = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
    lowerBound: 0.0,
    upperBound: 1.0,
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _startHeroAutoScroll();
  }

  void _startHeroAutoScroll() {
    _heroAutoScroll?.cancel();
    _heroAutoScroll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_heroController.hasClients) return;
      final pages = _heroPickCount();
      if (pages <= 1) return;
      final next = _heroPage + 1 >= pages ? 0 : _heroPage + 1;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubicEmphasized,
      );
    });
  }

  int _heroPickCount() {
    final featured = _candidates()
      ..sort((a, b) => b.prediction.confidence.compareTo(a.prediction.confidence));
    final n = featured.take(8).length;
    return n < 1 ? 1 : n;
  }

  @override
  void dispose() {
    _heroAutoScroll?.cancel();
    _heroZoom.dispose();
    _heroController.dispose();
    super.dispose();
  }

  static const List<String> _tabs = ['Yesterday', 'Today', 'Tomorrow'];
  static const List<String> _filters = ['All', 'Major', 'Hot', 'Value'];

  bool _isMajorLeague(String league) {
    const majors = [
      'premier league',
      'la liga',
      'serie a',
      'bundesliga',
      'ligue 1',
      'champions league',
      'europa league',
      'eredivisie',
      'primeira liga',
      'saudi pro league',
      'mls',
      'liga mx',
    ];
    final l = league.toLowerCase();
    return majors.any(l.contains);
  }

  /// Confidence is only "hot" when the model is highly decisive or the
  /// game is live right now (momentum reads).
  bool _isHot(model.Match m) {
    final c = m.prediction.confidence;
    return m.status == model.MatchStatus.live || c >= 68;
  }

  /// Value edge = model probability minus bookmaker implied probability
  /// for the recommended favourite outcome.
  ({double edge, model.Match match})? _computeValueEdge(model.Match m) {
    final p = m.prediction;
    final isHomeFav = p.homeWinProbability >= p.awayWinProbability;
    final favProb = isHomeFav ? p.homeWinProbability : p.awayWinProbability;
    final odds = isHomeFav ? m.homeOdds : m.awayOdds;
    if (odds == null || odds <= 1.01) return null;
    final implied = 1.0 / odds * 100; // bookmaker margin included, conservative
    final edge = favProb - implied;
    return (edge: edge, match: m);
  }

  List<model.Match> _candidates() {
    final provider = context.read<MatchesProvider>();
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _dayOffset));
    final dayEnd = dayStart.add(const Duration(days: 1));

    return provider.allMatches
        .where((m) =>
            !m.isPostponed &&
            m.status != model.MatchStatus.cancelled &&
            m.date.isAfter(dayStart) &&
            m.date.isBefore(dayEnd))
        .toList();
  }

  List<(model.Match, double?)> _insights() {
    // Snapshot candidates with their value edge up front (it is used by
    // both the filter and the card badge).
    final entries = _candidates().map((m) {
      final v = _computeValueEdge(m);
      return (m, v?.edge);
    }).toList();

    List<(model.Match, double?)> filtered;
    switch (_filter) {
      case 'Major':
        filtered = entries.where((e) => _isMajorLeague(e.$1.league)).toList();
        break;
      case 'Hot':
        filtered = entries.where((e) => _isHot(e.$1)).toList();
        break;
      case 'Value':
        filtered =
            entries.where((e) => e.$2 != null && e.$2! >= 8).toList();
        break;
      default:
        filtered = entries;
    }

    // Strongest model reads first; within the same confidence, bigger
    // value edge wins.
    filtered.sort((a, b) {
      final c = a.$1.prediction.confidence.compareTo(b.$1.prediction.confidence);
      if (c != 0) return c;
      return (b.$2 ?? double.negativeInfinity)
          .compareTo(a.$2 ?? double.negativeInfinity);
    });
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(86),
        child: Stack(
          children: [
            Container(
              // Light: clean white header (only the accents breathe).
              // Dark: the GoalFlow band, unchanged.
              color: AppTheme.isDark(context)
                  ? const Color(0xFF0D1117)
                  : AppTheme.surfaceOf(context),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart_rounded,
                          color: AppTheme.isDark(context)
                              ? AppTheme.primary
                              : const Color(0xFF00A855),
                          size: 26),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BreathingText(
                            'Insights',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI-powered football insights',
                            style: TextStyle(
                              color: AppTheme.textSecondaryOf(context),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.isDark(context)
                              ? AppTheme.primary
                              : const Color(0xFFF3EFFD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.isDark(context)
                                ? Colors.transparent
                                : const Color(0xFF7C3AED)
                                    .withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          'AI',
                          style: TextStyle(
                            color: AppTheme.isDark(context)
                                ? Colors.black
                                : const Color(0xFF5B21B6),
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BreathingUnderline(),
            ),
          ],
        ),
      ),
      // The screen has no local loading state — it renders directly from
      // MatchesProvider. This subscription makes the whole feed rebuild the
      // moment new match data lands (otherwise the screen stays in its empty
      // state until the user taps a tab or filter pill and forces a setState).
      body: Selector<MatchesProvider, List<String>>(
        selector: (_, p) => p.liveMatchIds,
        builder: (context, _, _) => Column(
          children: [
            _buildHeroCarousel(),
            _buildHeroDots(),
            _buildDateTabs(),
            _buildFilterPills(),
            Expanded(child: _buildInsightFeed()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDots() {
    final count = _heroPickCount();
    if (count <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == _heroPage;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.primary
                  : AppTheme.textSecondaryOf(context).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  /// GoalFlow-style featured carousel: stadium-photo cards with big team
  /// overlay text, league + kick-off chips. Shows the strongest model reads
  /// of the selected day, independent of the filter pills below.
  Widget _buildHeroCarousel() {
    final pool = _candidates();
    // Live/upcoming reads first; settled matches only when the day is over.
    final pending =
        pool.where((m) => m.status != model.MatchStatus.finished).toList();
    final featured = (pending.isEmpty ? pool : pending)
      ..sort((a, b) =>
          b.prediction.confidence.compareTo(a.prediction.confidence));
    final picks = featured.take(8).toList();

    if (picks.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 150,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (n) {
          // Keep the show going, but restart the clock after manual swipes.
          if (n.direction != ScrollDirection.idle) _startHeroAutoScroll();
          return false;
        },
        child: PageView.builder(
          controller: _heroController,
          itemCount: picks.length,
          onPageChanged: (i) => setState(() => _heroPage = i),
          itemBuilder: (context, i) => _buildHeroCard(context, picks[i], i),
        ),
      ),
    );
  }

  /// Default stadium backdrop: drawn top-down pitch used whenever a hero
  /// card has no real stadium photo (or the photo fails to load).
  Widget _defaultStadium() {
    return LayoutBuilder(
      builder: (context, constraints) => CustomPaint(
        size: Size(constraints.maxWidth, constraints.maxHeight),
        painter: _StadiumPitchPainter(),
      ),
    );
  }

  Widget _buildHeroCard(BuildContext context, model.Match m, int index) {
    // Verified-realistic stadium shots only (visually checked), alternating
    // with slightly different crops so consecutive cards don't repeat identically.
    const photos = [
      (
        url:
            'https://images.unsplash.com/photo-1522778119026-d647f0596c20', // packed floodlit bowl at night
        extra: '',
      ),
      (
        url:
            'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9', // stadium interior, red seats + pitch
        extra: '&crop=focalpoint&fp-y=0.65&fp-z=1.15', // lower, tighter crop variant
      ),
      (
        url:
            'https://images.unsplash.com/photo-1522778119026-d647f0596c20',
        extra: '&crop=entropy', // wide auto-crop variant
      ),
      (
        url:
            'https://images.unsplash.com/photo-1489944440615-453fc2b6a9a9',
        extra: '&crop=edges', // edges-crop variant
      ),
    ];
    final p = photos[index % photos.length];
    final photo =
        '${p.url}?auto=format&fit=crop&w=800&q=70${p.extra}';
    final isLive = m.status == model.MatchStatus.live;
    final isFinished = m.status == model.MatchStatus.finished;
    final kickoff =
        DateFormat('HH:mm').format(m.date.toLocal()).replaceAll(':', ':');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: m)),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF0E1219),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Stadium photo backdrop with a slow Ken Burns zoom
            AnimatedBuilder(
              animation: _heroZoom,
              builder: (context, child) {
                final t = _heroZoom.value;
                final scale = 1.05 + 0.06 * t; // 1.05 → 1.11 breathing zoom
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _defaultStadium(),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(color: const Color(0xFF14202F));
                },
              ),
            ),
            // Dark overlay for text legibility
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            // Chips row: league (left) + time (right)
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.league.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFFB8C4D0),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLive
                          ? Colors.red.withValues(alpha: 0.85)
                          : Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isLive
                          ? (m.statusShort == 'HT'
                              ? 'HT LIVE'
                              : (m.elapsed != null
                                  ? "${m.elapsed}' LIVE"
                                  : 'LIVE'))
                          : isFinished
                              ? '${m.homeScore ?? 0} - ${m.awayScore ?? 0}  FT'
                              : kickoff,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Big team names overlay
            Positioned(
              left: 14,
              right: 14,
              bottom: 34,
              child: Text(
                '${_short(m.homeTeam)} VS ${_short(m.awayTeam)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
            ),
            // Kickoff chip bottom-left
            Positioned(
              left: 14,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'KICKOFF: $kickoff',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _short(String team) {
    final words = team.trim().split(RegExp(r'\s+'));
    final drop = {
      'afc', 'fc', 'cf', 'sc', 'club', 'the',
    };
    final kept = words.where((w) => !drop.contains(w.toLowerCase())).toList();
    return kept.join(' ');
  }


  Widget _buildDateTabs() {
    final borderColor = AppTheme.cardBorderOf(context);
    final now = DateTime.now();
    final selected =
        DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
    final pickCount = _candidates().length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          _dateStepper(
            enabled: _dayOffset > -1,
            icon: Icons.chevron_left_rounded,
            onTap: () => setState(() => _dayOffset -= 1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _dayOffset = 0),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _tabs[_dayOffset + 1],
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: AppTheme.textPrimaryOf(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('EEE MMM dd').format(selected).toUpperCase()} · $pickCount PICKS',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      color: Color(0xFF8B99A8),
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _dateStepper(
            enabled: _dayOffset < 1,
            icon: Icons.chevron_right_rounded,
            onTap: () => setState(() => _dayOffset += 1),
          ),
        ],
      ),
    );
  }

  Widget _dateStepper({
    required bool enabled,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? borderColor : borderColor.withValues(alpha: 0.4),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled
              ? textSecondary
              : textSecondary.withValues(alpha: 0.35),
        ),
      ),
    );
  }

  Widget _buildFilterPills() {
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      color: surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _filter = _filters[i]),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: _filter == _filters[i]
                      ? AppTheme.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _filter == _filters[i]
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : borderColor,
                  ),
                ),
                child: Text(
                  _filters[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _filter == _filters[i] ? FontWeight.w800 : FontWeight.w600,
                    color: _filter == _filters[i]
                        ? AppTheme.primary
                        : textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightFeed() {
    final provider = context.read<MatchesProvider>();
    final insights = _insights();
    final hasAnyData = provider.allMatches.isNotEmpty;

    if (insights.isEmpty) {
      // While the master fetch is still landing, show progress rather than a
      // bare empty state — the subscription above swaps this out as soon as
      // the data arrives.
      if (!hasAnyData) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: 14),
              Text(
                'Fetching the latest AI picks…',
                style: TextStyle(
                  color: AppTheme.textPrimaryOf(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined,
                size: 44, color: AppTheme.textSecondaryOf(context)),
            const SizedBox(height: 12),
            Text(
              'No insights for this filter yet',
              style: TextStyle(
                color: AppTheme.textPrimaryOf(context),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another date or loosen the filter to see more AI picks.',
              style: TextStyle(
                color: AppTheme.textSecondaryOf(context),
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: insights.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => i == 0
          ? _buildSpotlightCard(context)
          : _buildInsightCard(context, insights[i - 1]),
    );
  }

  /// ─────────────────────────────────────────────────────────────
  /// PICK OF THE DAY — spotlight card, top-confidence read of the day.
  /// ─────────────────────────────────────────────────────────────
  model.Match? _pickOfTheDay() {
    final pool = _candidates();
    // Prefer a match that can still be played; fall back to settled ones so
    // past days still get a spotlight.
    final pending =
        pool.where((m) => m.status != model.MatchStatus.finished).toList();
    final featured = (pending.isEmpty ? pool : pending)
      ..sort((a, b) => b.prediction.confidence.compareTo(a.prediction.confidence));
    return featured.isEmpty ? null : featured.first;
  }

  /// (pick label, odds, tier) from staking payload — priority Safe→Value→Goals→Risky;
  /// odds only when the payload carries one. Falls back to recommendation.
  (String, double?, String) _spotlightPick(model.Match m) {
    final p = m.prediction;
    String? label;
    double? odds;
    String tier = 'ai';
    for (final key in ['safe', 'value', 'goals', 'risky']) {
      for (final raw in p.stakingOptions) {
        if (!raw.toLowerCase().startsWith('$key:')) continue;
        final text = raw.substring(raw.indexOf(':') + 1).trim();
        final cleaned =
            text.replaceAll(RegExp(r'\(\s*\d+(?:\.\d+)?\s*\)'), '').trim();
        if (cleaned.isEmpty) continue;
        label = cleaned;
        tier = key;
        final m1 = RegExp(r'\((\d+(?:\.\d+)?)\)\s*$').firstMatch(text);
        odds = m1 == null ? null : double.tryParse(m1.group(1)!);
        break;
      }
      if (label != null) break;
    }
    label ??= p.recommendation;
    return (label, odds, tier);
  }

  Widget _buildSpotlightCard(BuildContext context) {
    final m = _pickOfTheDay();
    if (m == null) return const SizedBox.shrink();
    final p = m.prediction;
    final isLive = m.status == model.MatchStatus.live;
    final isFinished = m.status == model.MatchStatus.finished;
    final green = AppTheme.primaryOf(context);
    const amber = Color(0xFFF59E0B);
    const indigo = Color(0xFF6366F1);
    const fedGreen = Color(0xFF00D06C);
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);

    final (pickName, pickOdds, pickTier) = _spotlightPick(m);

    // Real value edge (model prob - bookmaker implied), when available.
    final edge = _computeValueEdge(m)?.edge;

    final tierChip = switch (pickTier) {
      'safe' => 'SAFE PICK',
      'value' => 'VALUE PICK',
      'goals' => 'GOALS PICK',
      'risky' => 'RISKY PICK',
      _ => 'AI PICK',
    };

    // Day suffix on the league line, relative to today.
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final matchDay0 = DateTime(m.date.year, m.date.month, m.date.day);
    final dayDiff = matchDay0.difference(today0).inDays;
    final dayLabel = switch (dayDiff) {
      0 => 'TODAY',
      1 => 'TOMORROW',
      -1 => 'YESTERDAY',
      _ => DateFormat('EEE dd MMM').format(m.date.toLocal()).toUpperCase(),
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: m)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isLive ? Colors.red.withValues(alpha: 0.35) : borderColor,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              green.withValues(alpha: 0.14),
              surface,
              indigo.withValues(alpha: 0.10),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner strip - TOP READ OF THE DAY
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              color: Colors.black.withValues(alpha: 0.25),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppTheme.isDark(context)
                        ? const Color(0xFF00D06C)
                        : const Color(0xFF04895A),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TOP READ OF THE DAY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: AppTheme.isDark(context)
                          ? const Color(0xFF00D06C)
                          : const Color(0xFF04895A),
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    m.league.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: textSecondary,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Compact body: identity row + pick row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: crest + teams + league/day + kickoff time
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMiniLogo(m.homeLogo, m.homeTeam),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_short(m.homeTeam)} vs ${_short(m.awayTeam)}',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${m.league.toUpperCase()} · $dayLabel',
                              style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (isLive)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            m.statusShort == 'HT'
                                ? 'HT LIVE'
                                : "${m.elapsed ?? 80}' LIVE",
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: Colors.white,
                            ),
                          ),
                        )
                      else if (isFinished)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'FULL TIME',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontFamily: 'monospace',
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${m.homeScore ?? 0} - ${m.awayScore ?? 0}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'KICK OFF',
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                                fontFamily: 'monospace',
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              DateFormat('HH:mm').format(m.date.toLocal()),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: amber,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Row 2: confidence ring + tier chip/edge/odds + H-D-A bars
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CustomPaint(
                          painter: _TriGaugePainter(
                            home: p.homeWinProbability / 100.0,
                            draw: p.drawProbability / 100.0,
                            away: p.awayWinProbability / 100.0,
                          ),
                          child: Center(
                            child: Text(
                              '${p.confidence.round()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: fedGreen.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    tierChip,
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.6,
                                      fontFamily: 'monospace',
                                      color: fedGreen,
                                    ),
                                  ),
                                ),
                                if (edge != null && edge >= 1)
                                  Text(
                                    'EDG +${edge.toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'monospace',
                                      color: fedGreen,
                                    ),
                                  ),
                                if (pickOdds != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: green,
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      'ADD ${pickOdds.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                        fontFamily: 'monospace',
                                        color: AppTheme.isDark(context)
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              pickName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // H/D/A mini bar chart, bar heights = real probabilities
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _spotProbabilityBar(
                              p.homeWinProbability, fedGreen, textSecondary),
                          const SizedBox(width: 4),
                          _spotProbabilityBar(
                              p.drawProbability, amber, textSecondary),
                          const SizedBox(width: 4),
                          _spotProbabilityBar(
                              p.awayWinProbability, indigo, textSecondary),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One vertical probability bar of the spotlight mini chart.
  Widget _spotProbabilityBar(
      double pct, Color color, Color labelColor) {
    final height =
        4.0 + (pct.clamp(1, 100)) / 100.0 * 24.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${pct.round()}',
          style: TextStyle(
            fontSize: 6.5,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: labelColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(BuildContext context, (model.Match, double?) entry) {
    final m = entry.$1;
    final p = m.prediction;
    final isLive = m.status == model.MatchStatus.live;
    final isFinished = m.status == model.MatchStatus.finished;
    // Real settlement of the AI pick once the match is over.
    final verdict =
        isFinished ? BettingTrackerService.instance.pickVerdict(m) : null;
    final confidence = p.confidence;
    // Real odds from the staking payload — drives the pick progress gauge.
    final (_, pickOdds, _) = _spotlightPick(m);
    final pickImplied =
        pickOdds == null ? null : (100.0 / pickOdds).clamp(1.0, 100.0);
    // Model probability the pick itself: derivable from the real H/D/A
    // shares for 1X/X2/12/1/2 verdicts; otherwise the true implied(1/odds).
    final rec = p.recommendation.toLowerCase().trim();
    double pickChance;
    if (rec.startsWith('1x')) {
      pickChance = p.homeWinProbability + p.drawProbability;
    } else if (rec.startsWith('x2')) {
      pickChance = p.drawProbability + p.awayWinProbability;
    } else if (RegExp(r'^12(?![\d.])').hasMatch(rec)) {
      pickChance = p.homeWinProbability + p.awayWinProbability;
    } else if (RegExp(r'^1(?![\d.x])').hasMatch(rec)) {
      pickChance = p.homeWinProbability;
    } else if (RegExp(r'^2(?![\d.])(?!x)').hasMatch(rec)) {
      pickChance = p.awayWinProbability;
    } else {
      // No verdict-derivable model number: true odds-implied chance when
      // the payload carries odds, else the model's own confidence.
      pickChance = pickImplied ?? p.confidence;
    }
    pickChance = pickChance.clamp(1.0, 100.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MatchDetailsScreen(match: m)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceOf(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isLive
                ? Colors.red.withValues(alpha: 0.35)
                : AppTheme.cardBorderOf(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header: league left, status/time + confidence right
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.06),
                border: Border(
                  bottom: BorderSide(color: AppTheme.cardBorderOf(context)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildLeagueChip(m.league),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            m.league.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppTheme.textSecondaryOf(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Live header shows only the clock — the slot below carries
                  // the LIVE word, so it is never printed twice.
                  if (isLive && (m.elapsed != null || m.statusShort == 'HT'))
                    Text(
                      m.statusShort == 'HT' ? 'HT' : "${m.elapsed}'",
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                        color: Colors.red,
                      ),
                    )
                  else if (isFinished)
                    const Text(
                      'FT',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        color: Color(0xFF8B99A8),
                      ),
                    ),
                ],
              ),
            ),
            // Stacked teams + kickoff column (example style)
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 13, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildMiniLogo(m.homeLogo, m.homeTeam),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _short(m.homeTeam),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            _buildMiniLogo(m.awayLogo, m.awayTeam),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _short(m.awayTeam),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppTheme.textPrimaryOf(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // State slot: kickoff only before the match, LIVE while it
                  // runs, final score + pick verdict after the whistle.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLive) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                                letterSpacing: 0.6,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ] else if (isFinished) ...[
                        Text(
                          '${m.homeScore ?? 0} - ${m.awayScore ?? 0}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                            letterSpacing: 0.5,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        if (verdict == 'won' || verdict == 'lost') ...[
                          const SizedBox(height: 3),
                          _buildVerdictBadge(verdict!),
                        ],
                      ] else ...[
                        Text(
                          DateFormat('HH:mm').format(m.date.toLocal()),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimaryOf(context),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pre match',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // AI pick strip: bolt + verbatim recommendation + chance ring
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(13, 0, 13, 10),
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              decoration: BoxDecoration(
                color: AppTheme.isDark(context)
                    ? AppTheme.secondary.withValues(alpha: 0.08)
                    : const Color(0xFFEDF9FC),
                border: Border.all(
                  color: AppTheme.isDark(context)
                      ? AppTheme.secondary.withValues(alpha: 0.22)
                      : const Color(0xFF0891B2).withValues(alpha: 0.28),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: AppTheme.isDark(context)
                        ? AppTheme.secondary
                        : const Color(0xFF0891B2),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      p.recommendation.isNotEmpty
                          ? p.recommendation
                          : _spotlightPick(m).$1,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: AppTheme.textPrimaryOf(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 9),
                  SizedBox(
                      width: 30,
                      height: 30,
                      child: CustomPaint(
                        painter: _RingProgressPainter(
                          value: (pickChance / 100.0).clamp(0.0, 1.0),
                          color: AppTheme.secondary,
                          trackColor: AppTheme.isDark(context)
                              ? Colors.white.withValues(alpha: 0.10)
                              : Colors.black.withValues(alpha: 0.08),
                        ),
                        child: Center(
                          child: Text(
                            '${pickChance.round()}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: AppTheme.textPrimaryOf(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Probability bar + confidence dots + pick progress gauge
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
              child: Column(
                children: [
                  Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: SizedBox(
                        height: 5,
                        child: Row(
                          children: [
                            Expanded(
                              flex: p.homeWinProbability.round().clamp(1, 100),
                              child: Container(color: const Color(0xFF00D06C)),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: p.drawProbability.round().clamp(1, 100),
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              flex: p.awayWinProbability.round().clamp(1, 100),
                              child: Container(color: const Color(0xFF6366F1)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Confidence dots (5)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (i) {
                      final filled =
                          (confidence / 20).ceil().clamp(0, 5) > i;
                      return Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(left: 2.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled
                              ? _confidenceColor(confidence)
                              : AppTheme.cardBorderOf(context),
                        ),
                      );
                    }),
                  ),
                ],
              ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Country/competition chip for the league header strip — same scheme
  /// used on the home screen league groups.
  Widget _buildLeagueChip(String league) {
    if (league.contains('Premier') || league.contains('England')) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.flag_rounded,
          color: Color(0xFFA78BFA),
          size: 11,
        ),
      );
    }
    final code = _leagueCode(league);
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 7,
          color: AppTheme.textSecondaryOf(context),
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  String _leagueCode(String league) {
    const map = {
      'Saudi': 'SA',
      'Serie A': 'IT',
      'Italy': 'IT',
      'La Liga': 'ES',
      'Spain': 'ES',
      'Premier': 'EN',
      'England': 'EN',
      'Bundesliga': 'DE',
      'Germany': 'DE',
      'Ligue 1': 'FR',
      'France': 'FR',
      'MLS': 'US',
      'Champions': 'UCL',
      'UEFA': 'UCL',
      'Europa': 'UEL',
      'Portugal': 'PT',
      'Netherlands': 'NL',
      'Uruguay': 'UY',
      'Argentina': 'AR',
      'Colombia': 'CO',
      'Chile': 'CL',
      'Peru': 'PE',
      'Ecuador': 'EC',
      'Paraguay': 'PY',
      'Bolivia': 'BO',
      'Venezuela': 'VE',
      'Mexico': 'MX',
      'Brazil': 'BR',
      'Japan': 'JP',
      'Korea': 'KR',
      'Australia': 'AU',
      'Turkey': 'TR',
      'Greece': 'GR',
      'Belgium': 'BE',
      'Scotland': 'SC',
      'Egypt': 'EG',
      'Morocco': 'MA',
    };
    for (final e in map.entries) {
      if (league.contains(e.key)) return e.value;
    }
    final words = league.split(' ');
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return league
        .substring(0, league.length >= 2 ? 2 : league.length)
        .toUpperCase();
  }

  /// WON / LOST pill for a settled AI pick (real settlement result).
  Widget _buildVerdictBadge(String verdict) {
    final won = verdict == 'won';
    final color = won ? const Color(0xFF00D06C) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        won ? '✓ WON' : '✗ LOST',
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          fontFamily: 'monospace',
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }

  Color _confidenceColor(double confidence) {
    if (confidence >= 65) return AppTheme.primary;
    if (confidence >= 50) return const Color(0xFFF59E0B);
    return AppTheme.textSecondaryOf(context);
  }

  Widget _buildMiniLogo(String logoUrl, String teamName) {
    if (logoUrl.isNotEmpty &&
        (logoUrl.startsWith('http://') || logoUrl.startsWith('https://'))) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorWidget: (_, _, _) => _buildFallbackCrest(teamName),
        placeholder: (_, _) => _buildFallbackCrest(teamName),
      );
    }
    return _buildFallbackCrest(teamName);
  }

  Widget _buildFallbackCrest(String teamName) {
    final words = teamName.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : teamName.substring(0, teamName.length >= 2 ? 2 : teamName.length).toUpperCase();

    final colors = [
      const [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
      const [Color(0xFF831843), Color(0xFFEC4899)],
      const [Color(0xFF065F46), Color(0xFF10B981)],
      const [Color(0xFF7C2D12), Color(0xFFF97316)],
      const [Color(0xFF581C87), Color(0xFF8B5CF6)],
    ];
    final pair = colors[teamName.codeUnits.fold(0, (a, c) => a + c) % colors.length];

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pair,
        ),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────
/// Drawn default stadium view — top-down pitch with markings, used
/// as the fallback/backdrop for insight hero cards without photos.
/// ─────────────────────────────────────────────────────────────────
class _StadiumPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Turf gradient base (dark, matches the card's night-match look)
    final turf = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFF0B3D24), Color(0xFF0E1219), Color(0xFF0B3D24)],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, turf);

    // Mown-strip stripes for texture
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.025);
    final stripeW = size.width / 8;
    for (var i = 0; i < 8; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(i * stripeW, 0, stripeW, size.height),
        stripe,
      );
    }

    // Pitch markings — scaled to whatever the card size is
    final lineColor = Colors.white.withValues(alpha: 0.30);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final insetX = size.width * 0.10;
    final insetY = size.height * 0.14;
    final pitch = Rect.fromPoints(
      Offset(insetX, insetY),
      Offset(size.width - insetX, size.height - insetY),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitch, const Radius.circular(7)),
      line,
    );

    // Halfway line + center circle
    canvas.drawLine(
      Offset(pitch.center.dx, pitch.top),
      Offset(pitch.center.dx, pitch.bottom),
      line,
    );
    final circleR = pitch.height * 0.17;
    canvas.drawCircle(pitch.center, circleR, line);
    canvas.drawCircle(pitch.center, 2.2, Paint()..color = lineColor);

    // Penalty boxes, both ends
    final boxW = pitch.width * 0.14;
    final boxH = pitch.height * 0.52;
    canvas.drawRect(
      Rect.fromLTWH(pitch.left, pitch.center.dy - boxH / 2, boxW, boxH),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(pitch.right - boxW, pitch.center.dy - boxH / 2, boxW, boxH),
      line,
    );

    // Corner arcs
    final cornerR = pitch.width * 0.03;
    for (final c in [
      pitch.topLeft,
      pitch.topRight,
      pitch.bottomLeft,
      pitch.bottomRight,
    ]) {
      canvas.drawCircle(c, cornerR, line);
    }

    // Soft vignette so overlay text stays legible
    final vignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0x66000000),
          Color(0x00000000),
          Color(0x8C000000),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(covariant _StadiumPitchPainter oldDelegate) => false;
}

/// ─────────────────────────────────────────────────────────────────
/// Three-segment conic ring for the Pick-of-the-Day spotlight — the
/// home/draw/away shares as colored arcs (green/amber/indigo).
/// ─────────────────────────────────────────────────────────────────
class _TriGaugePainter extends CustomPainter {
  final double home;
  final double draw;
  final double away;

  _TriGaugePainter({
    required this.home,
    required this.draw,
    required this.away,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 6.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF8B99A8).withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, track);

    final seg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double sweep = 0;
    void drawSegment(double fraction, Color color) {
      if (fraction <= 0) return;
      seg.color = color;
      canvas.drawArc(
          rect, -math.pi / 2 + sweep, 2 * math.pi * fraction, false, seg);
      sweep += 2 * math.pi * fraction;
    }

    drawSegment(home, const Color(0xFF00D06C));
    drawSegment(draw, const Color(0xFFF59E0B));
    drawSegment(away, const Color(0xFF6366F1));
  }

  @override
  bool shouldRepaint(covariant _TriGaugePainter old) =>
      old.home != home || old.draw != draw || old.away != away;
}

/// ─────────────────────────────────────────────────────────────────
/// Single-arc circular progress — used under the pick rows for the
/// AI pick's implied chance (1 / pick odds from the staking payload).
/// ─────────────────────────────────────────────────────────────────
class _RingProgressPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color trackColor;

  _RingProgressPainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 3.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final sweep = 2 * math.pi * value.clamp(0.0, 1.0);
    if (sweep > 0) {
      canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter old) =>
      old.value != value || old.color != color;
}
