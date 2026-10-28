import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../match_details/presentation/pages/match_details_screen.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/betting_tracker_service.dart';
import '../../../../core/services/app_settings_service.dart';
import '../widgets/dynamic_live_island.dart';
import '../widgets/featured_ai_banner.dart';
import '../widgets/live_matches_carousel.dart';
import '../../../../models/country_leagues_model.dart';
import '../../../leagues/presentation/pages/league_table_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  DateTime? _selectedDate;
  
  List<model.Match>? _matches = ApiService.inMemoryCache;
  bool _isLoading = ApiService.inMemoryCache == null || ApiService.inMemoryCache!.isEmpty;
  String? _error;

  List<String> _preferredLeagues = [];
  Set<String> _hiddenLeagues = {};
  final Map<String, bool> _leagueExpandedState = {};
  Timer? _liveRefreshTimer;

  final Map<String, String> _previousScores = {};
  final Set<String> _notifiedPredictions = {};

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('HomeScreen');
    if (_matches != null && _matches!.isNotEmpty) {
      _updateSelectedDate(_matches!);
    }
    _loadData();
    _loadPreferences();
    ApiService.liveMatchesNotifier.addListener(_onLiveMatchesNotified);
    ApiService.allMatchesNotifier.addListener(_onAllMatchesNotified);
  }

  void _onAllMatchesNotified() {
    if (!mounted) return;
    final all = ApiService.allMatchesNotifier.value;
    if (all == null || all.isEmpty) return;
    setState(() {
      _matches = all;
      _updateSelectedDate(all);
    });
  }

  void _onLiveMatchesNotified() {
    if (!mounted || _matches == null) return;
    final live = ApiService.liveMatchesNotifier.value;
    if (live.isEmpty) return;
    final liveMap = {for (var m in live) m.id: m};
    setState(() {
      _matches = _matches!.map((m) => liveMap[m.id] ?? m).toList();
    });
  }

  @override
  void dispose() {
    ApiService.liveMatchesNotifier.removeListener(_onLiveMatchesNotified);
    ApiService.allMatchesNotifier.removeListener(_onAllMatchesNotified);
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  /// Starts a fast 30-second live polling timer if any match is live or within 3 h of
  /// kickoff (active window). Uses lightweight /live endpoint so updates are instant (<50ms).
  void _startLiveRefreshIfNeeded(List<model.Match> matches) {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;

    final now = DateTime.now();
    final hasLive = matches.any((m) => m.status == model.MatchStatus.live);

    // Consider any match that kicked off in the last 3 h as "active"
    // (covers backend lag where status is still notStarted at kickoff)
    final hasActiveWindow = matches.any((m) {
      final minsAfterKickoff = now.difference(m.date.toLocal()).inMinutes;
      return minsAfterKickoff >= 0 && minsAfterKickoff < 180;
    });

    if (hasLive || hasActiveWindow) {
      _liveRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        final updated = await _apiService.fetchLiveUpdates();
        if (updated != null && mounted) {
          setState(() {
            _matches = updated;
          });
        }
      });
      return;
    }

    // No live or active match — schedule a one-shot refresh at the next kickoff
    final upcoming = matches
        .where((m) => m.status == model.MatchStatus.notStarted && m.date.isAfter(now))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    if (upcoming.isNotEmpty) {
      final nextKickoff = upcoming.first.date;
      final delay = nextKickoff.difference(now);
      if (delay.isNegative || delay > const Duration(hours: 12)) return;
      _liveRefreshTimer = Timer(delay, () {
        _loadData();
      });
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _preferredLeagues = prefs.getStringList('preferred_leagues') ?? [];
        _hiddenLeagues = (prefs.getStringList('hidden_leagues') ?? []).toSet();
      });
    }
  }

  List<DateTime> _getAvailableDates(List<model.Match> matches) {
    final Set<DateTime> dateSet = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var m in matches) {
      final local = m.date.toLocal();
      final matchDate = DateTime(local.year, local.month, local.day);
      // Include yesterday, today, and future dates so users can review yesterday's results
      if (!matchDate.isBefore(yesterday)) {
        dateSet.add(matchDate);
      }
    }
    // If no recent/future dates, include all match dates so data is never hidden
    if (dateSet.isEmpty) {
      for (var m in matches) {
        final local = m.date.toLocal();
        dateSet.add(DateTime(local.year, local.month, local.day));
      }
    }
    final dates = dateSet.toList()..sort();
    return dates;
  }

  void _updateSelectedDate(List<model.Match> matches) {
    final dates = _getAvailableDates(matches);
    if (dates.isEmpty) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_selectedDate != null && dates.contains(_selectedDate)) {
      return;
    }

    // Check if today has matches
    final todayHasMatches = matches.any((m) {
      final l = m.date.toLocal();
      return l.year == today.year && l.month == today.month && l.day == today.day;
    });

    if (dates.contains(today) && todayHasMatches) {
      _selectedDate = today;
    } else {
      // Pick the date that actually has matches
      _selectedDate = dates.firstWhere(
        (d) => matches.any((m) {
          final l = m.date.toLocal();
          return l.year == d.year && l.month == d.month && l.day == d.day;
        }),
        orElse: () => dates.first,
      );
    }
  }

  Future<void> _loadData({bool isBackground = false}) async {
    // 1. If we already have fresh in-memory matches from Render, use them instantly
    if (_matches == null || _matches!.isEmpty) {
      final inMemory = await _apiService.getCachedMatches();
      if (inMemory != null && inMemory.isNotEmpty && mounted) {
        setState(() {
          _matches = inMemory;
          _updateSelectedDate(inMemory);
          _isLoading = false;
          _error = null;
        });
      } else if (!isBackground && mounted) {
        // Otherwise leave on shimmering while waiting for Render
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
    }

    // 2. Fetch fresh matches from Render
    try {
      final freshMatches = await _apiService.fetchMatches();
      if (mounted) {
        try {
          _checkNotifications(freshMatches);
        } catch (_) {}
        try {
          await BettingTrackerService.instance.syncMatches(freshMatches);
        } catch (trackerErr) {
          debugPrint('⚠️ Tracker sync note: $trackerErr');
        }
        setState(() {
          _matches = freshMatches;
          _updateSelectedDate(freshMatches);
          _isLoading = false;
          _error = null;
        });
        _startLiveRefreshIfNeeded(freshMatches);
      }
    } catch (e, stack) {
      debugPrint('❌ HomeScreen fresh load error: $e\n$stack');
      // No fallback to mock data: if user has no data yet, keep them on shimmering and retry
      if (mounted && (_matches == null || _matches!.isEmpty)) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
        // Auto-retry in 3 seconds if still empty
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && (_matches == null || _matches!.isEmpty)) {
            _loadData(isBackground: true);
          }
        });
      }
    }
  }

  void _checkNotifications(List<model.Match> freshMatches) {
    for (final match in freshMatches) {
      final key = match.id;
      final homeScore = match.homeScore ?? 0;
      final awayScore = match.awayScore ?? 0;
      final currentScoreStr = '$homeScore-$awayScore';

      // Goal notification check for live/finished matches
      if (_previousScores.containsKey(key)) {
        final prevScoreStr = _previousScores[key];
        if (prevScoreStr != currentScoreStr) {
          final prevParts = prevScoreStr!.split('-');
          final prevHome = int.tryParse(prevParts[0]) ?? 0;
          final prevAway = int.tryParse(prevParts[1]) ?? 0;

          String? scoringTeam;
          if (homeScore > prevHome) {
            scoringTeam = match.homeTeam;
          } else if (awayScore > prevAway) {
            scoringTeam = match.awayTeam;
          }

          NotificationService.instance.showGoalAlert(
            id: key.hashCode,
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            homeScore: homeScore,
            awayScore: awayScore,
            scoringTeam: scoringTeam,
          );
        }
      }
      _previousScores[key] = currentScoreStr;

      // High confidence AI pick notification check (>70%)
      if (!_notifiedPredictions.contains(key)) {
        final double homeWin = match.prediction.homeWinProbability;
        final double awayWin = match.prediction.awayWinProbability;
        if (homeWin >= 70.0 || awayWin >= 70.0) {
          _notifiedPredictions.add(key);
          final bestPick = homeWin >= 70.0
              ? '${match.homeTeam} Win'
              : '${match.awayTeam} Win';
          final confidence = homeWin >= 70.0 ? homeWin : awayWin;

          NotificationService.instance.showHighConfidenceAlert(
            id: ('ai_$key').hashCode,
            homeTeam: match.homeTeam,
            awayTeam: match.awayTeam,
            prediction: bestPick,
            confidence: confidence,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches ?? [];
    final availableDates = _getAvailableDates(matches);
    debugPrint('🔥🔥🔥 HomeScreen build called! matches=${matches.length}, dates=${availableDates.length}, isLoading=$_isLoading, error=$_error');

    // Live matches list
    final liveMatches = matches.where((m) => m.status == model.MatchStatus.live).toList();

    // Find highest EV value match for Featured Banner
    model.Match? featuredMatch;
    if (matches.isNotEmpty) {
      if (liveMatches.isNotEmpty) {
        featuredMatch = liveMatches.first;
      } else {
        featuredMatch = matches.reduce((curr, next) {
          final currMax = curr.prediction.homeWinProbability >= curr.prediction.awayWinProbability
              ? curr.prediction.homeWinProbability
              : curr.prediction.awayWinProbability;
          final nextMax = next.prediction.homeWinProbability >= next.prediction.awayWinProbability
              ? next.prediction.homeWinProbability
              : next.prediction.awayWinProbability;
          return currMax >= nextMax ? curr : next;
        });
      }
    }

    // Count matches for today
    final now = DateTime.now();
    final todayCount = matches.where((m) {
      return m.date.year == now.year && m.date.month == now.month && m.date.day == now.day;
    }).length;
    final displayTodayCount = todayCount > 0 ? todayCount : matches.length;

    return ListenableBuilder(
      listenable: AppSettingsService.instance,
      builder: (context, _) {
        final primary = AppTheme.primaryOf(context);
        final surface = AppTheme.surfaceOf(context);
        final borderColor = AppTheme.cardBorderOf(context);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(liveMatches.isNotEmpty ? 104 : 64),
            child: Container(
              color: surface,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dynamic Island Centered on Top (Matching FotMob / iOS Island)
                    if (liveMatches.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Center(
                          child: DynamicLiveIsland(liveMatches: liveMatches),
                        ),
                      ),

                    // Header Row with Brand & Actions (Image 2)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: primary,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.sports_soccer, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'AI SCORECAST',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F242C),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PRO',
                              style: TextStyle(
                                color: primary,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          const Spacer(),

                          // League Filter / Sliders Button (Matching Image 1)
                          GestureDetector(
                            onTap: () => _showFiltersBottomSheet(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF161B22),
                                border: Border.all(
                                  color: const Color(0xFF00D06C).withValues(alpha: 0.35),
                                  width: 1.2,
                                ),
                              ),
                              child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF00D06C)),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Notification Bell Button with live green badge
                          GestureDetector(
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF161B22),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  content: Row(
                                    children: [
                                      Icon(Icons.notifications_active_rounded, color: primary, size: 20),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Live Goal & High AI Edge Alerts Active',
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF161B22),
                                border: Border.all(color: borderColor),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.notifications_none_rounded, size: 18, color: Colors.white70),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
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
            onRefresh: _loadData,
            color: primary,
            backgroundColor: surface,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                // 1. Live Carousel (Scrolls with page)
                if (liveMatches.isNotEmpty)
                  SliverToBoxAdapter(
                    child: LiveMatchesCarousel(liveMatches: liveMatches),
                  ),

                // 2. Featured AI Consensus Pick Banner (Scrolls with page)
                if (featuredMatch != null)
                  SliverToBoxAdapter(
                    child: FeaturedAiBanner(featuredMatch: featuredMatch),
                  ),

                // 3. FotMob Date Ribbon (Pinned cleanly beneath AppBar when scrolling)
                if (availableDates.isNotEmpty)
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _DateSelectorHeaderDelegate(
                      child: _buildDateSelector(availableDates, displayTodayCount),
                      height: 54.0,
                    ),
                  ),

                // 4. Main Matches Feed (Sliver List)
                ..._buildMatchesSlivers(context, availableDates),

                // Bottom padding to ensure last card is never obscured by navigation bar
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMatchesSlivers(BuildContext context, List<DateTime> availableDates) {
    if (_isLoading && (_matches == null || _matches!.isEmpty)) {
      return const [
        SliverToBoxAdapter(
          child: MatchListShimmer(),
        ),
      ];
    }

    if (_error != null && (_matches == null || _matches!.isEmpty)) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Unable to load latest matches.\nPlease check your connection and tap retry.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }

    final matches = _matches ?? [];
    final dates = availableDates;

    if (matches.isEmpty || dates.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_soccer_rounded, size: 48, color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(height: 12),
                  const Text('No matches available at this time.', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Pull down to refresh and sync with live worker data.', style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    // Filter matches by the selected date
    final selectedDate = _selectedDate ?? (dates.isNotEmpty ? dates.first : null);
    final hideFinished = AppSettingsService.instance.hideFinishedMatches;

    List<model.Match> filteredMatches = selectedDate == null
        ? matches
        : matches.where((match) {
            if (hideFinished && match.status == model.MatchStatus.finished) {
              return false;
            }
            final localDate = match.date.toLocal();
            return localDate.year == selectedDate.year &&
                   localDate.month == selectedDate.month &&
                   localDate.day == selectedDate.day;
          }).toList();

    // If hideFinished hid all matches on this date, show all matches for this date anyway
    if (filteredMatches.isEmpty && selectedDate != null) {
      filteredMatches = matches.where((match) {
        final localDate = match.date.toLocal();
        return localDate.year == selectedDate.year &&
               localDate.month == selectedDate.month &&
               localDate.day == selectedDate.day;
      }).toList();
    }

    // If still empty (e.g. date has 0 matches), show matches from the nearest date or all upcoming matches
    if (filteredMatches.isEmpty && matches.isNotEmpty) {
      if (dates.isNotEmpty) {
        final dateWithMatches = dates.firstWhere(
          (d) => matches.any((m) {
            final l = m.date.toLocal();
            return l.year == d.year && l.month == d.month && l.day == d.day;
          }),
          orElse: () => dates.first,
        );
        filteredMatches = matches.where((match) {
          final localDate = match.date.toLocal();
          return localDate.year == dateWithMatches.year &&
                 localDate.month == dateWithMatches.month &&
                 localDate.day == dateWithMatches.day;
        }).toList();
      } else {
        filteredMatches = matches;
      }
    }

    if (filteredMatches.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(child: Text('No matches on this date.', style: TextStyle(color: Colors.white70))),
          ),
        ),
      ];
    }

    // Group matches by league
    final Map<String, List<model.Match>> grouped = {};
    for (var m in filteredMatches) {
      grouped.putIfAbsent(m.league, () => []).add(m);
      _leagueExpandedState.putIfAbsent(m.league, () => true);
    }

    // Filter out hidden leagues and sort based on _preferredLeagues
    final visibleLeagues = grouped.keys.where((l) => !_hiddenLeagues.contains(l)).toList();
    visibleLeagues.sort((a, b) {
      int indexA = _preferredLeagues.indexOf(a);
      int indexB = _preferredLeagues.indexOf(b);
      if (indexA == -1) indexA = 999;
      if (indexB == -1) indexB = 999;
      return indexA.compareTo(indexB);
    });

    final displayLeagues = visibleLeagues.isNotEmpty ? visibleLeagues : grouped.keys.toList();

    if (displayLeagues.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('All leagues hidden for this date.'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showFiltersBottomSheet(context),
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('Configure Leagues'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final league = displayLeagues[index];
              final leagueMatches = grouped[league]!;
              final isExpanded = _leagueExpandedState[league] ?? true;
              final flag = _getLeagueFlag(league);
              final liveCount = leagueMatches.where((m) => m.status == model.MatchStatus.live).length;
              final hasLive = liveCount > 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: hasLive
                        ? Colors.red.withValues(alpha: 0.35)
                        : AppTheme.cardBorderOf(context),
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
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // League Accordion Header (Click to collapse/expand)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _leagueExpandedState[league] = !isExpanded;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10141D),
                          border: Border(
                            bottom: BorderSide(
                              color: isExpanded ? AppTheme.cardBorderOf(context) : Colors.transparent,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      league,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (hasLive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$liveCount Live',
                                            style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    Text(
                                      '• ${leagueMatches.length} ${leagueMatches.length == 1 ? 'Match' : 'Matches'}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textSecondaryOf(context),
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  Icon(
                                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                    color: AppTheme.textSecondaryOf(context),
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            // Direct Standings Table Pill Button
                            GestureDetector(
                              onTap: () => _openTableForLeague(league),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  border: Border.all(
                                    color: AppTheme.primary.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Table',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 13,
                                      color: AppTheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      ...leagueMatches.map((m) => _buildMatchCard(context, m)),
                  ],
                ),
              );
            },
            childCount: displayLeagues.length,
          ),
        ),
      ),
    ];
  }

  void _openTableForLeague(String leagueName) {
    // Search registry for matching competition
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

    // Default to premier league or generic slug if not directly found
    targetLeague ??= const ScrapedLeagueInfo(
      slug: 'eng.1',
      name: 'Premier League',
      country: 'England',
      flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
      tier: 'Tier 1',
      logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeagueTableScreen(league: targetLeague!),
      ),
    );
  }

  String _getLeagueFlag(String league) {
    if (league.contains('Spain')) return '🇪🇸';
    if (league.contains('England') || league.contains('UK')) return '🇬🇧';
    if (league.contains('France')) return '🇫🇷';
    if (league.contains('Germany')) return '🇩🇪';
    if (league.contains('Italy')) return '🇮🇹';
    if (league.contains('Netherlands')) return '🇳🇱';
    if (league.contains('Portugal')) return '🇵🇹';
    if (league.contains('Brazil')) return '🇧🇷';
    if (league.contains('Argentina')) return '🇦🇷';
    if (league.contains('Mexico')) return '🇲🇽';
    if (league.contains('USA') || league.contains('MLS')) return '🇺🇸';
    if (league.contains('Ecuador')) return '🇪🇨';
    if (league.contains('Saudi')) return '🇸🇦';
    if (league.contains('Turkey')) return '🇹🇷';
    if (league.contains('Belgium')) return '🇧🇪';
    if (league.contains('Scotland')) return '🏴󠁧󠁢󠁳󠁣󠁴󠁿';
    if (league.contains('Champions League') || league.contains('Europa') || league.contains('UEFA')) return '🏆';
    return '⚽';
  }

  Widget _buildDateSelector(List<DateTime> availableDates, int todayMatchCount) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final selectedDate = _selectedDate ?? availableDates.first;

    return Container(
      height: 54.0,
      decoration: BoxDecoration(
        color: AppTheme.surfaceOf(context),
        border: Border(
          bottom: BorderSide(color: AppTheme.cardBorderOf(context), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: availableDates.map((date) {
                  final isSelected = selectedDate.year == date.year &&
                      selectedDate.month == date.month &&
                      selectedDate.day == date.day;
                  final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  String label;
                  if (isToday) {
                    label = 'Today';
                  } else if (date.year == yesterday.year &&
                      date.month == yesterday.month &&
                      date.day == yesterday.day) {
                    label = 'Yesterday';
                  } else if (date.year == tomorrow.year &&
                      date.month == tomorrow.month &&
                      date.day == tomorrow.day) {
                    label = 'Tomorrow';
                  } else {
                    label = DateFormat('MMM d').format(date);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDate = date;
                          _leagueExpandedState.clear();
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 16 : 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.black
                                    : AppTheme.textSecondaryOf(context),
                                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (isToday && isSelected) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '$todayMatchCount',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Vertical divider line
          Container(
            height: 20,
            width: 1,
            color: AppTheme.cardBorderOf(context),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // Calendar picker button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 20,
              color: AppTheme.textSecondaryOf(context),
            ),
            tooltip: 'Select Date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() {
                  _selectedDate = picked;
                  _leagueExpandedState.clear();
                });
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, model.Match match) {
    final isLive = match.status == model.MatchStatus.live;
    final isFinished = match.status == model.MatchStatus.finished;
    final bestConf = match.prediction.homeWinProbability >= match.prediction.awayWinProbability
        ? match.prediction.homeWinProbability.round()
        : match.prediction.awayWinProbability.round();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailsScreen(match: match),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppTheme.cardBorderOf(context).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // Top Section: Teams on Left, Score/Time on Right
            Row(
              children: [
                // Team rows
                Expanded(
                  child: Column(
                    children: [
                      // Home Team Row
                      Row(
                        children: [
                          _buildMiniLogo(match.homeLogo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              match.homeTeam,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: (isLive || isFinished) && (match.homeScore ?? 0) > (match.awayScore ?? 0)
                                    ? Colors.white
                                    : AppTheme.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive || isFinished)
                            Text(
                              '${match.homeScore ?? 0}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: (match.homeScore ?? 0) > (match.awayScore ?? 0)
                                    ? AppTheme.primary
                                    : AppTheme.textSecondaryOf(context),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Away Team Row
                      Row(
                        children: [
                          _buildMiniLogo(match.awayLogo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              match.awayTeam,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: (isLive || isFinished) && (match.awayScore ?? 0) > (match.homeScore ?? 0)
                                    ? Colors.white
                                    : AppTheme.textPrimaryOf(context),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLive || isFinished)
                            Text(
                              '${match.awayScore ?? 0}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: (match.awayScore ?? 0) > (match.homeScore ?? 0)
                                    ? AppTheme.primary
                                    : AppTheme.textSecondaryOf(context),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Right Status / Time column
                Container(
                  width: 58,
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: AppTheme.cardBorderOf(context).withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isLive) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              match.statusShort == 'HT' ? 'HT' : "${match.elapsed ?? 80}'",
                              style: const TextStyle(
                                color: Colors.red,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ] else if (isFinished) ...[
                        const Text(
                          'FT',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ended',
                          style: TextStyle(color: Colors.white30, fontSize: 9),
                        ),
                      ] else ...[
                        Text(
                          DateFormat('HH:mm').format(match.date.toLocal()),
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Pre-match',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Goal Scorers Row (if any)
            if ((match.homeScorers != null && match.homeScorers!.isNotEmpty) ||
                (match.awayScorers != null && match.awayScorers!.isNotEmpty)) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      (match.homeScorers ?? []).map((s) => '⚽ $s').join(' · '),
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (match.awayScorers ?? []).map((s) => '$s ⚽').join(' · '),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Bottom AI Recommendation footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.cardBorderOf(context).withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'AI PICK',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      match.prediction.recommendation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$bestConf% Conf',
                    style: TextStyle(
                      color: AppTheme.primary,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 13,
                    color: AppTheme.textSecondaryOf(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniLogo(String logoUrl) {
    return logoUrl.startsWith('http')
        ? CachedNetworkImage(
            imageUrl: logoUrl,
            width: 20,
            height: 20,
            errorWidget: (context, url, error) => const Icon(Icons.sports_soccer, size: 16),
          )
        : const Icon(Icons.sports_soccer, size: 20, color: AppTheme.textSecondary);
  }


  String _getLeagueCountry(String league) {
    if (league.contains('Premier') || league.contains('England') || league.contains('Championship')) return 'England';
    if (league.contains('La Liga') || league.contains('Spain') || league.contains('Copa del Rey')) return 'Spain';
    if (league.contains('Serie A') || league.contains('Italy')) return 'Italy';
    if (league.contains('Bundesliga') || league.contains('Germany')) return 'Germany';
    if (league.contains('Ligue 1') || league.contains('France')) return 'France';
    if (league.contains('Saudi')) return 'Saudi Arabia';
    if (league.contains('Champions League') || league.contains('Europa') || league.contains('UEFA')) return 'Europe';
    if (league.contains('MLS') || league.contains('USA')) return 'USA';
    if (league.contains('Pro League') || league.contains('Belgium')) return 'Belgium';
    if (league.contains('Eredivisie') || league.contains('Netherlands')) return 'Netherlands';
    if (league.contains('Liga Portugal') || league.contains('Portugal')) return 'Portugal';
    if (league.contains('Brazil')) return 'Brazil';
    return 'International';
  }

  String _getLeagueBadge(String league) {
    if (league.contains('Saudi')) return 'SA';
    if (league.contains('Serie A') || league.contains('Italy')) return 'IT';
    if (league.contains('La Liga') || league.contains('Spain')) return 'ES';
    if (league.contains('Premier') || league.contains('England')) return 'EN';
    if (league.contains('Bundesliga') || league.contains('Germany')) return 'DE';
    if (league.contains('Ligue 1') || league.contains('France')) return 'FR';
    if (league.contains('MLS')) return 'US';
    if (league.contains('Champions') || league.contains('UEFA')) return 'UCL';
    if (league.contains('Europa')) return 'UEL';
    if (league.contains('Portugal')) return 'PT';
    if (league.contains('Netherlands')) return 'NL';
    final words = league.split(' ');
    if (words.length >= 2) {
      return (words[0][0] + words[1][0]).toUpperCase();
    }
    return league.substring(0, league.length >= 2 ? 2 : league.length).toUpperCase();
  }

  Widget _buildLeagueBadgeWidget(String league) {
    if (league.contains('Premier') || league.contains('England')) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.flag_rounded, color: Color(0xFFA78BFA), size: 18),
      );
    }
    final code = _getLeagueBadge(league);
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Colors.white,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext context) {
    // Collect all unique leagues from matches, preferences, and standard list
    final Set<String> allLeaguesSet = {};
    for (var m in (_matches ?? [])) {
      allLeaguesSet.add(m.league);
    }
    for (var l in _preferredLeagues) {
      allLeaguesSet.add(l);
    }
    const defaultLeagues = [
      'Premier League',
      'Saudi Pro League',
      'Serie A',
      'La Liga',
      'Bundesliga',
      'Ligue 1',
      'UEFA Champions League',
      'UEFA Europa League',
      'Pro League',
      'Major League Soccer',
    ];
    for (var l in defaultLeagues) {
      allLeaguesSet.add(l);
    }

    // Build the ordered list preserving user preferred order
    final List<String> orderedLeagues = [];
    for (var l in _preferredLeagues) {
      if (allLeaguesSet.contains(l) && !orderedLeagues.contains(l)) {
        orderedLeagues.add(l);
      }
    }
    for (var l in allLeaguesSet) {
      if (!orderedLeagues.contains(l)) {
        orderedLeagues.add(l);
      }
    }

    // Selected leagues: all minus _hiddenLeagues
    final Set<String> selectedLeagues = orderedLeagues.where((l) => !_hiddenLeagues.contains(l)).toSet();

    // Match count per league for selected date (or total fallback)
    final Map<String, int> matchCounts = {};
    for (var m in (_matches ?? [])) {
      final isDateMatch = _selectedDate == null ||
          (m.date.toLocal().year == _selectedDate!.year &&
           m.date.toLocal().month == _selectedDate!.month &&
           m.date.toLocal().day == _selectedDate!.day);
      if (isDateMatch) {
        matchCounts[m.league] = (matchCounts[m.league] ?? 0) + 1;
      }
    }

    String searchQuery = '';
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final displayedLeagues = searchQuery.isEmpty
              ? orderedLeagues
              : orderedLeagues.where((l) {
                  final q = searchQuery.toLowerCase();
                  final c = _getLeagueCountry(l).toLowerCase();
                  return l.toLowerCase().contains(q) || c.contains(q);
                }).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0E1219),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Pill Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF384355),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Row: Sliders Icon + Title/Subtitle on left, Circular (X) on right
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.tune_rounded, color: Color(0xFF00D06C), size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Choose Leagues to Display',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Toggle competitions to customize your feed',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondaryOf(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E2430),
                              border: Border.all(color: const Color(0xFF2E384A), width: 1),
                            ),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Search & Quick Actions Row
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161C24),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF263040), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    onChanged: (val) {
                                      setModalState(() {
                                        searchQuery = val.trim();
                                      });
                                    },
                                    style: const TextStyle(color: Colors.white, fontSize: 13),
                                    decoration: const InputDecoration(
                                      hintText: 'Search leagues or nations...',
                                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      searchController.clear();
                                      setModalState(() {
                                        searchQuery = '';
                                      });
                                    },
                                    child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.white54),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedLeagues.addAll(allLeaguesSet);
                            });
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2633),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2E384A), width: 1),
                            ),
                            child: const Text(
                              'Select All',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setModalState(() {
                              selectedLeagues.clear();
                            });
                          },
                          child: Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F2633),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2E384A), width: 1),
                            ),
                            child: const Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Leagues Reorderable List
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: searchQuery.isEmpty
                          ? ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              itemCount: displayedLeagues.length,
                              // ignore: deprecated_member_use
                              onReorder: (oldIndex, newIndex) {
                                setModalState(() {
                                  if (oldIndex < newIndex) {
                                    newIndex -= 1;
                                  }
                                  final item = orderedLeagues.removeAt(oldIndex);
                                  orderedLeagues.insert(newIndex, item);
                                });
                              },
                              itemBuilder: (context, index) {
                                final league = displayedLeagues[index];
                                return _buildLeagueRow(
                                  league: league,
                                  index: index,
                                  isReorderable: true,
                                  isSelected: selectedLeagues.contains(league),
                                  country: _getLeagueCountry(league),
                                  matchCount: matchCounts[league] ?? 0,
                                  onToggle: () {
                                    setModalState(() {
                                      if (selectedLeagues.contains(league)) {
                                        selectedLeagues.remove(league);
                                      } else {
                                        selectedLeagues.add(league);
                                      }
                                    });
                                  },
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: displayedLeagues.length,
                              itemBuilder: (context, index) {
                                final league = displayedLeagues[index];
                                return _buildLeagueRow(
                                  league: league,
                                  index: index,
                                  isReorderable: false,
                                  isSelected: selectedLeagues.contains(league),
                                  country: _getLeagueCountry(league),
                                  matchCount: matchCounts[league] ?? 0,
                                  onToggle: () {
                                    setModalState(() {
                                      if (selectedLeagues.contains(league)) {
                                        selectedLeagues.remove(league);
                                      } else {
                                        selectedLeagues.add(league);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),

                  // Bottom Sticky Green Button (Matching Image 2)
                  Padding(
                    padding: const EdgeInsets.all(18.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00D06C),
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                        ),
                        onPressed: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setStringList('preferred_leagues', orderedLeagues);

                          final hidden = allLeaguesSet.where((l) => !selectedLeagues.contains(l)).toList();
                          await prefs.setStringList('hidden_leagues', hidden);

                          if (mounted) {
                            setState(() {
                              _preferredLeagues = List.from(orderedLeagues);
                              _hiddenLeagues = hidden.toSet();
                            });
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.black, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              selectedLeagues.length == allLeaguesSet.length
                                  ? 'Show All Leagues'
                                  : 'Apply (${selectedLeagues.length} Leagues)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
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
          );
        },
      ),
    );
  }

  Widget _buildLeagueRow({
    required String league,
    required int index,
    required bool isReorderable,
    required bool isSelected,
    required String country,
    required int matchCount,
    required VoidCallback onToggle,
  }) {
    final cardContent = Row(
      children: [
        // Left side: Drag Handle & Badge / Flag
        if (isReorderable)
          ReorderableDragStartListener(
            index: index,
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(left: 14, right: 10, top: 12, bottom: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.drag_indicator_rounded, color: Colors.white38, size: 20),
                  const SizedBox(width: 8),
                  _buildLeagueBadgeWidget(league),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 10, top: 12, bottom: 12),
            child: _buildLeagueBadgeWidget(league),
          ),

        // Middle: Title & Country / Match Count
        Expanded(
          child: GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    league,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$country • $matchCount ${matchCount == 1 ? 'Match' : 'Matches'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondaryOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Right side: Checkbox Button (Green when active)
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF00D06C) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? const Color(0xFF00D06C) : const Color(0xFF334155),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.black, size: 18)
                  : null,
            ),
          ),
        ),
      ],
    );

    return Container(
      key: ValueKey(league),
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF10141D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF00D06C).withValues(alpha: 0.45)
              : const Color(0xFF222B3A),
          width: 1.2,
        ),
      ),
      child: cardContent,
    );
  }
}

class _DateSelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _DateSelectorHeaderDelegate({
    required this.child,
    this.height = 54.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _DateSelectorHeaderDelegate oldDelegate) {
    return true;
  }
}



