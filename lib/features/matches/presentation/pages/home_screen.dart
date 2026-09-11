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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  DateTime? _selectedDate;
  
  List<model.Match>? _matches;
  bool _isLoading = true;
  String? _error;

  List<String> _preferredLeagues = [];
  final Map<String, bool> _leagueExpandedState = {};
  Timer? _liveRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadPreferences();
  }

  @override
  void dispose() {
    _liveRefreshTimer?.cancel();
    super.dispose();
  }

  /// Starts a 60-second polling timer if any match is currently live.
  /// Also schedules a one-shot refresh when the next upcoming match kicks off.
  void _startLiveRefreshIfNeeded(List<model.Match> matches) {
    _liveRefreshTimer?.cancel();
    _liveRefreshTimer = null;

    final now = DateTime.now();
    final hasLive = matches.any((m) => m.status == model.MatchStatus.live);

    if (hasLive) {
      // Poll every 60 seconds while a match is live
      _liveRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        _loadData();
      });
      return;
    }

    // No live match — find the next upcoming kickoff and schedule a one-shot refresh
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
      });
    }
  }

  List<DateTime> _getAvailableDates(List<model.Match> matches) {
    final Set<DateTime> dateSet = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var m in matches) {
      final local = m.date.toLocal();
      final matchDate = DateTime(local.year, local.month, local.day);
      // Only include today and future dates (exclude past days once today passes)
      if (!matchDate.isBefore(today)) {
        dateSet.add(matchDate);
      }
    }
    final dates = dateSet.toList()..sort();
    // Limit to top 6 days ahead that have games
    if (dates.length > 6) {
      return dates.sublist(0, 6);
    }
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

    if (dates.contains(today)) {
      _selectedDate = today;
    } else {
      _selectedDate = dates.first;
    }
  }

  Future<void> _loadData() async {
    // 1. Try to load cached matches immediately
    final cached = await _apiService.getCachedMatches();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _matches = cached;
        _updateSelectedDate(cached);
        _isLoading = false;
        _error = null;
      });
    }

    // 2. Fetch fresh matches in background (or initial load if no cache)
    try {
      final freshMatches = await _apiService.fetchMatches();
      if (mounted) {
        setState(() {
          _matches = freshMatches;
          _updateSelectedDate(freshMatches);
          _isLoading = false;
          _error = null;
        });
        _startLiveRefreshIfNeeded(freshMatches);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_matches == null) {
            _error = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var matches = _matches ?? [];
    if (matches.isEmpty && !_isLoading) {
      matches = model.MockData.getMatches();
    }
    final availableDates = _getAvailableDates(matches);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, color: AppTheme.primary),
            const SizedBox(width: 8),
            const Text(
              'AI Scorecast',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () => _showFiltersBottomSheet(context),
            tooltip: 'Filter Matches',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (availableDates.isNotEmpty) _buildDateSelector(availableDates),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'Featured AI Picks',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: _buildMatchesContent(availableDates),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesContent(List<DateTime> availableDates) {
    if (_isLoading && (_matches == null || _matches!.isEmpty)) {
      return const MatchListShimmer();
    }

    if (_error != null && (_matches == null || _matches!.isEmpty)) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                    Text(
                      'Error loading matches\n$_error',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
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
      );
    }

    var matches = _matches ?? [];
    var dates = availableDates;
    
    // Fallback to Mock Data if API rate limit was reached (empty response)
    if (matches.isEmpty || dates.isEmpty) {
      matches = model.MockData.getMatches();
      dates = _getAvailableDates(matches);
    }
    
    if (matches.isEmpty || dates.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const SizedBox(
            height: 400,
            child: Center(child: Text('No matches found.')),
          ),
        ),
      );
    }

    // Filter matches by the selected date
    final selectedDate = _selectedDate ?? dates.first;
    final filteredMatches = matches.where((match) {
      final localDate = match.date.toLocal();
      return localDate.year == selectedDate.year &&
             localDate.month == selectedDate.month &&
             localDate.day == selectedDate.day;
    }).toList();

    if (filteredMatches.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: const SizedBox(
            height: 400,
            child: Center(child: Text('No matches on this date.')),
          ),
        ),
      );
    }

    // Group matches by league
    final Map<String, List<model.Match>> grouped = {};
    for (var m in filteredMatches) {
      grouped.putIfAbsent(m.league, () => []).add(m);
      _leagueExpandedState.putIfAbsent(m.league, () => true);
    }

    // Sort league keys based on _preferredLeagues
    final sortedLeagues = grouped.keys.toList();
    sortedLeagues.sort((a, b) {
      int indexA = _preferredLeagues.indexOf(a);
      int indexB = _preferredLeagues.indexOf(b);
      if (indexA == -1) indexA = 999;
      if (indexB == -1) indexB = 999;
      return indexA.compareTo(indexB);
    });

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      backgroundColor: AppTheme.surface,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: sortedLeagues.length,
        itemBuilder: (context, index) {
          final league = sortedLeagues[index];
          final leagueMatches = grouped[league]!;
          final isExpanded = _leagueExpandedState[league] ?? true;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _leagueExpandedState[league] = !isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      const Icon(Icons.emoji_events, color: AppTheme.secondary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        league,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppTheme.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded)
                ...leagueMatches.map((m) => _buildMatchCard(context, m)),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDateSelector(List<DateTime> availableDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final selectedDate = _selectedDate ?? availableDates.first;

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: availableDates.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final date = availableDates[index];
          final isSelected = selectedDate == date;

          String label;
          if (date == today) {
            label = 'Today';
          } else if (date == yesterday) {
            label = 'Yesterday';
          } else if (date == tomorrow) {
            label = 'Tomorrow';
          } else {
            label = DateFormat('MMM d').format(date);
          }

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = date;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
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

  Widget _buildMatchCard(BuildContext context, model.Match match) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MatchDetailsScreen(match: match),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TOP ROW: League • Kickoff/Live • AI Confidence
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          match.league,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        const SizedBox(width: 8),
                        if (match.status == model.MatchStatus.live)
                          _buildLiveBadge(match)
                        else if (match.status == model.MatchStatus.finished)
                          const Text('FT', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold))
                        else
                          Text(
                            DateFormat('HH:mm').format(match.date),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${match.prediction.homeWinProbability.round() >= match.prediction.awayWinProbability.round() ? match.prediction.homeWinProbability.round() : match.prediction.awayWinProbability.round()}% Confidence',
                      style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // CENTER ROW: Team vs Team (Horizontal)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Home Team
                  Expanded(
                    child: Row(
                      children: [
                        _buildMiniLogo(match.homeLogo),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            match.homeTeam,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Score / VS
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildScoreOrVs(match),
                  ),
                  
                  // Away Team
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            match.awayTeam,
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildMiniLogo(match.awayLogo),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // BOTTOM ROW: Mini probability bar & AI Pick
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildMiniProbabilityBar(match.prediction),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            match.oddsRating != null 
                                ? 'Odds Rating: ${match.oddsRating}'
                                : 'AI Value: ${match.prediction.stakingOptions.firstWhere((e) => e.startsWith('Value:'), orElse: () => match.prediction.stakingOptions.first).replaceAll('Value: ', '')}',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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

  Widget _buildScoreOrVs(model.Match match) {
    if (match.status == model.MatchStatus.notStarted) {
      return const Text('VS', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        '${match.homeScore} - ${match.awayScore}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
      ),
    );
  }

  Widget _buildMiniProbabilityBar(model.AIPrediction prediction) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: prediction.homeWinProbability.round(),
              child: Container(color: AppTheme.success),
            ),
            Expanded(
              flex: prediction.drawProbability.round(),
              child: Container(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            ),
            Expanded(
              flex: prediction.awayWinProbability.round(),
              child: Container(color: AppTheme.secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveBadge(model.Match match) {
    // Determine what label to show
    String label;
    Color badgeColor = AppTheme.secondary;

    if (match.statusShort == 'HT') {
      label = 'HT';
      badgeColor = Colors.orange;
    } else if (match.elapsed != null) {
      label = "${match.elapsed}'";
    } else {
      label = 'LIVE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (match.statusShort != 'HT')
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: badgeColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showFiltersBottomSheet(BuildContext context) {
    final allLeagues = (_matches ?? [])
        .map((m) => m.league)
        .toSet()
        .toList()
      ..sort();

    List<String> tempSelected = List.from(_preferredLeagues);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preferred Leagues',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (tempSelected.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempSelected.clear();
                        });
                      },
                      child: const Text('Reset All', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Selected leagues appear first on your board. If a league has no games on the selected date, it is automatically hidden.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allLeagues.map((league) {
                      final isSelected = tempSelected.contains(league);
                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isSelected) {
                              tempSelected.remove(league);
                            } else {
                              tempSelected.add(league);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primary.withValues(alpha: 0.2)
                                : Colors.black.withValues(alpha: 0.25),
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.white.withValues(alpha: 0.1),
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                const Icon(Icons.check_rounded, color: AppTheme.primary, size: 16),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                league,
                                style: TextStyle(
                                  color: isSelected ? AppTheme.primary : Colors.white70,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setStringList('preferred_leagues', tempSelected);
                    if (mounted) {
                      setState(() {
                        _preferredLeagues = tempSelected;
                      });
                    }
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    tempSelected.isEmpty
                        ? 'Show All Leagues'
                        : 'Apply (${tempSelected.length} Preferred)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

