import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';

class TrackedBet {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final String league;
  final DateTime date;
  final String pick;
  final double odds;
  final int? homeScore;
  final int? awayScore;
  final String status; // 'won', 'lost', 'void', 'live', 'pending'
  final double stake; // default 1.0 unit
  final double profit; // (odds - 1) * stake if won, -stake if lost, 0 if void/pending
  final bool isSettled;

  TrackedBet({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    this.homeLogo,
    this.awayLogo,
    required this.league,
    required this.date,
    required this.pick,
    required this.odds,
    this.homeScore,
    this.awayScore,
    required this.status,
    this.stake = 1.0,
    required this.profit,
    required this.isSettled,
  });

  /// Canonical identifier key based on alphanumeric team names
  String get normalizedTeamsKey {
    final h = homeTeam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final a = awayTeam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$h-$a';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'homeLogo': homeLogo,
    'awayLogo': awayLogo,
    'league': league,
    'date': date.toIso8601String(),
    'pick': pick,
    'odds': odds,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'status': status,
    'stake': stake,
    'profit': profit,
    'isSettled': isSettled,
  };

  factory TrackedBet.fromJson(Map<String, dynamic> json) => TrackedBet(
    id: json['id'] ?? '',
    homeTeam: json['homeTeam'] ?? '',
    awayTeam: json['awayTeam'] ?? '',
    homeLogo: json['homeLogo'],
    awayLogo: json['awayLogo'],
    league: json['league'] ?? '',
    date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    pick: json['pick'] ?? '',
    odds: (json['odds'] as num?)?.toDouble() ?? 1.85,
    homeScore: json['homeScore'],
    awayScore: json['awayScore'],
    status: json['status'] ?? 'pending',
    stake: (json['stake'] as num?)?.toDouble() ?? 1.0,
    profit: (json['profit'] as num?)?.toDouble() ?? 0.0,
    isSettled: json['isSettled'] ?? false,
  );
}

class CumulativePoint {
  final DateTime date;
  final double cumulativeUnits;
  final double runningWinRate;
  final int totalBets;

  CumulativePoint({
    required this.date,
    required this.cumulativeUnits,
    required this.runningWinRate,
    required this.totalBets,
  });
}

class TrackerStats {
  final int totalBets;
  final int settledBets;
  final int wins;
  final int losses;
  final int voids;
  final int live;
  final int pending;
  final double winRate; // 0 - 100
  final double netProfit; // in units
  final double roi; // (netProfit / totalStaked) * 100
  final double averageOdds;
  final int currentStreak; // positive for win streak, negative for loss streak
  final List<String> recentForm; // e.g. ['W', 'W', 'L', 'W', 'W']
  final List<CumulativePoint> progression;

  TrackerStats({
    required this.totalBets,
    required this.settledBets,
    required this.wins,
    required this.losses,
    required this.voids,
    required this.live,
    required this.pending,
    required this.winRate,
    required this.netProfit,
    required this.roi,
    required this.averageOdds,
    required this.currentStreak,
    required this.recentForm,
    required this.progression,
  });

  factory TrackerStats.empty() => TrackerStats(
    totalBets: 0,
    settledBets: 0,
    wins: 0,
    losses: 0,
    voids: 0,
    live: 0,
    pending: 0,
    winRate: 0.0,
    netProfit: 0.0,
    roi: 0.0,
    averageOdds: 0.0,
    currentStreak: 0,
    recentForm: const [],
    progression: const [],
  );
}

class BettingTrackerService extends ChangeNotifier {
  static final BettingTrackerService instance = BettingTrackerService._internal();
  BettingTrackerService._internal();

  static const String _userStartDateKey = 'app_user_tracking_start_date_v2';
  static const String _trackedBetsKey = 'app_tracked_bets_records_v2';

  DateTime _userStartDate = DateTime.now();
  List<TrackedBet> _bets = [];
  final Map<String, TrackedBet> _betsById = {};
  bool _isInitialized = false;

  TrackerStats _cachedStats = TrackerStats.empty();
  TrackerStats _cachedTodayStats = TrackerStats.empty();

  DateTime get userStartDate => _userStartDate;
  List<TrackedBet> get bets => List.unmodifiable(_bets);
  bool get isInitialized => _isInitialized;
  TrackerStats get cachedStats => _cachedStats;
  TrackerStats get cachedTodayStats => _cachedTodayStats;

  TrackerStats getCachedStats({String timeframe = 'all'}) {
    return timeframe == 'today' ? _cachedTodayStats : _cachedStats;
  }

  /// O(1) lookup for leaf bet card selectors
  TrackedBet? getBetById(String id) => _betsById[id];

  int get daysActive {
    final now = DateTime.now();
    final startDay = DateTime(_userStartDate.year, _userStartDate.month, _userStartDate.day);
    final today = DateTime(now.year, now.month, now.day);
    return today.difference(startDay).inDays + 1;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();

    // 1. User tracking start date (persisted from day one)
    final startStr = prefs.getString(_userStartDateKey);
    if (startStr != null) {
      _userStartDate = DateTime.tryParse(startStr) ?? DateTime.now();
    } else {
      _userStartDate = DateTime.now();
      await prefs.setString(_userStartDateKey, _userStartDate.toIso8601String());
    }

    // 2. Load stored bets: purge dummy seeds and any future-dated pending games
    final betsStr = prefs.getString(_trackedBetsKey);
    if (betsStr != null && betsStr.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(betsStr);
        final now = DateTime.now();
        final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

        final rawLoaded = decoded
            .map((e) => TrackedBet.fromJson(e as Map<String, dynamic>))
            .where((b) =>
                !b.id.startsWith('hist_') &&
                (b.isSettled || b.status == 'live' || b.date.isBefore(endOfToday)))
            .toList();

        // Deduplicate any duplicates across different ID feeds
        final seenKeys = <String>{};
        _bets = [];
        for (final b in rawLoaded) {
          final dayKey = '${b.normalizedTeamsKey}-${b.date.year}-${b.date.month}-${b.date.day}';
          if (seenKeys.add(dayKey)) {
            _bets.add(b);
          }
        }
      } catch (_) {
        _bets = [];
      }
    } else {
      _bets = [];
    }

    // Save cleaned bets list and build lookup map + precomputed stats
    _rebuildLookupAndStats();
    await _saveBets(prefs);

    _isInitialized = true;
    notifyListeners();
  }

  /// Clears all bets and resets tracking to clean slate
  Future<void> clearAllBets() async {
    final prefs = await SharedPreferences.getInstance();
    _bets = [];
    _betsById.clear();
    _cachedStats = TrackerStats.empty();
    _cachedTodayStats = TrackerStats.empty();
    await prefs.remove(_trackedBetsKey);
    notifyListeners();
  }

  /// Syncs newly fetched matches (pending today, live, or finished) into the persistent tracking database
  Future<void> syncMatches(List<Match> matches) async {
    final prefs = await SharedPreferences.getInstance();
    bool changed = false;

    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    for (final match in matches) {
      final isFinished = match.status == MatchStatus.finished;
      final isLive = match.status == MatchStatus.live;
      final isPostponed = match.isPostponed;
      final isTodayOrPast = match.date.isBefore(endOfToday);

      // Option 2: Tracker strictly focuses on today + settled/live/postponed results.
      // Future dates (tomorrow and beyond) belong on the Home Screen.
      if (!isFinished && !isLive && !isPostponed && !isTodayOrPast) {
        continue;
      }

      final matchDayKey = '${match.normalizedTeamsKey}-${match.date.year}-${match.date.month}-${match.date.day}';
      final existingIndex = _bets.indexWhere((b) =>
          b.id == match.id ||
          b.normalizedTeamsKey == match.normalizedTeamsKey ||
          '${b.normalizedTeamsKey}-${b.date.year}-${b.date.month}-${b.date.day}' == matchDayKey);
      final eval = _evaluateMatchBet(match);

      if (existingIndex >= 0) {
        // Update existing if score, status, or prediction pick changed
        final existing = _bets[existingIndex];
        if (existing.status != eval.status ||
            existing.homeScore != eval.homeScore ||
            existing.awayScore != eval.awayScore ||
            existing.pick != eval.pick ||
            existing.id != eval.id) {
          _bets[existingIndex] = eval;
          changed = true;
        }
      } else {
        _bets.add(eval);
        changed = true;
      }
    }

    // Purge any pending bets beyond today that might have been cached earlier
    final initialCount = _bets.length;
    _bets.removeWhere((b) => b.status == 'pending' && b.date.isAfter(endOfToday));
    if (_bets.length != initialCount) {
      changed = true;
    }

    if (changed) {
      // Sort newest first
      _bets.sort((a, b) => b.date.compareTo(a.date));
      _rebuildLookupAndStats();
      await _saveBets(prefs);
      debugPrint('⚡ [BettingTrackerService] Synced matches & updated cached stats. Notifying selectors...');
      notifyListeners();
    }
  }

  void _rebuildLookupAndStats() {
    _betsById.clear();
    for (final b in _bets) {
      _betsById[b.id] = b;
      _betsById[b.normalizedTeamsKey] = b;
    }
    _cachedStats = _computeStats(timeframe: 'all');
    _cachedTodayStats = _computeStats(timeframe: 'today');
  }

  /// Structural accessor: returns filtered list of Bet IDs.
  /// Tier 1 list Selectors use this with [listEquals] so card lists only re-layout
  /// when a match transitions status (e.g. LIVE -> FT / WON / LOST).
  List<String> getBetIdsForFilter({String timeframe = 'all', String statusFilter = 'all'}) {
    final now = DateTime.now();
    return _bets.where((b) {
      // Timeframe filter
      if (timeframe == 'today') {
        if (b.date.year != now.year || b.date.month != now.month || b.date.day != now.day) {
          return false;
        }
      }
      // Status filter
      if (statusFilter != 'all' && b.status != statusFilter) {
        return false;
      }
      return true;
    }).map((b) => b.id).toList();
  }

  TrackedBet _evaluateMatchBet(Match match) {
    final isFinished = match.status == MatchStatus.finished;
    final isLive = match.status == MatchStatus.live;

    final rec = match.prediction.recommendation;
    final homeName = match.homeTeam.toLowerCase();
    final awayName = match.awayTeam.toLowerCase();
    final recLower = rec.toLowerCase();

    // Determine odds for the AI pick
    double odds = 1.85;
    if (recLower.contains(homeName) && match.homeOdds != null) {
      odds = match.homeOdds!;
    } else if (recLower.contains(awayName) && match.awayOdds != null) {
      odds = match.awayOdds!;
    } else if (recLower.contains('draw') && match.drawOdds != null) {
      odds = match.drawOdds!;
    }

    // Postponed / Cancelled / Suspended matches -> VOID (stake refunded, 0 profit)
    if (match.isPostponed) {
      return TrackedBet(
        id: match.id,
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        homeLogo: match.homeLogo,
        awayLogo: match.awayLogo,
        league: match.league,
        date: match.date,
        pick: rec,
        odds: odds,
        homeScore: null,
        awayScore: null,
        status: 'void',
        profit: 0.0,
        isSettled: true,
      );
    }

    // Pending / Upcoming
    if (!isFinished && !isLive) {
      return TrackedBet(
        id: match.id,
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        homeLogo: match.homeLogo,
        awayLogo: match.awayLogo,
        league: match.league,
        date: match.date,
        pick: rec,
        odds: odds,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        status: 'pending',
        profit: 0.0,
        isSettled: false,
      );
    }

    // Live In-Play
    if (isLive) {
      return TrackedBet(
        id: match.id,
        homeTeam: match.homeTeam,
        awayTeam: match.awayTeam,
        homeLogo: match.homeLogo,
        awayLogo: match.awayLogo,
        league: match.league,
        date: match.date,
        pick: rec,
        odds: odds,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        status: 'live',
        profit: 0.0,
        isSettled: false,
      );
    }

    // Finished match: evaluate win/loss
    final hScore = match.homeScore ?? 0;
    final aScore = match.awayScore ?? 0;
    final totalGoals = hScore + aScore;
    bool won = false;

    final evalOver05 = recLower.contains('over 0.5');
    final evalUnder15 = recLower.contains('under 1.5');
    final evalUnder25 = recLower.contains('under 2.5');
    final evalOver15 = recLower.contains('over 1.5');
    final evalOver25 = recLower.contains('over 2.5');
    final evalUnder35 = recLower.contains('under 3.5');
    final evalOver35 = recLower.contains('over 3.5');

    // 1. Double chance or compound recommendation (e.g. "Draw (X) or Under 2.5 Goals")
    if (recLower.contains('or')) {
      bool opt1 = false;
      bool opt2 = false;

      if (recLower.contains('draw') || recLower.contains('(x)')) {
        if (hScore == aScore) opt1 = true;
      }
      if (recLower.contains(homeName) || recLower.contains('home') || recLower.contains('(1)')) {
        if (hScore > aScore) opt1 = true;
      }
      if (recLower.contains(awayName) || recLower.contains('away') || recLower.contains('(2)')) {
        if (aScore > hScore) opt1 = true;
      }

      if (evalOver05 && totalGoals > 0.5) opt2 = true;
      if (evalUnder15 && totalGoals < 1.5) opt2 = true;
      if (evalUnder25 && totalGoals < 2.5) opt2 = true;
      if (evalOver25 && totalGoals > 2.5) opt2 = true;
      if (evalOver15 && totalGoals > 1.5) opt2 = true;
      if (evalUnder35 && totalGoals < 3.5) opt2 = true;
      if (evalOver35 && totalGoals > 3.5) opt2 = true;

      won = opt1 || opt2;
    } else if (evalOver05) {
      won = totalGoals > 0.5;
    } else if (evalUnder15) {
      won = totalGoals < 1.5;
    } else if (evalUnder25) {
      won = totalGoals < 2.5;
    } else if (evalOver25) {
      won = totalGoals > 2.5;
    } else if (evalOver15) {
      won = totalGoals > 1.5;
    } else if (evalUnder35) {
      won = totalGoals < 3.5;
    } else if (evalOver35) {
      won = totalGoals > 3.5;
    } else if (hScore > aScore && (recLower.contains(homeName) || recLower.contains('home') || recLower.contains('(1)'))) {
      won = true;
    } else if (aScore > hScore && (recLower.contains(awayName) || recLower.contains('away') || recLower.contains('(2)'))) {
      won = true;
    } else if (hScore == aScore && (recLower.contains('draw') || recLower.contains('(x)'))) {
      won = true;
    } else if (hScore >= aScore && recLower.contains(homeName) && recLower.contains('draw')) {
      won = true;
    } else if (aScore >= hScore && recLower.contains(awayName) && recLower.contains('draw')) {
      won = true;
    }

    final profit = won ? (odds - 1.0) * 1.0 : -1.0;

    return TrackedBet(
      id: match.id,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      homeLogo: match.homeLogo,
      awayLogo: match.awayLogo,
      league: match.league,
      date: match.date,
      pick: rec,
      odds: odds,
      homeScore: hScore,
      awayScore: aScore,
      status: won ? 'won' : 'lost',
      profit: double.parse(profit.toStringAsFixed(2)),
      isSettled: true,
    );
  }

  TrackerStats getStats({String timeframe = 'all', String statusFilter = 'all'}) {
    // 🎯 Fast O(1) path for standard views: return pre-calculated cache without looping
    if (statusFilter == 'all') {
      return timeframe == 'today' ? _cachedTodayStats : _cachedStats;
    }
    return _computeStats(timeframe: timeframe, statusFilter: statusFilter);
  }

  TrackerStats _computeStats({String timeframe = 'all', String statusFilter = 'all'}) {
    final now = DateTime.now();

    // 1. Timeframe filtering
    final allInTimeframe = _bets.where((b) {
      if (timeframe == 'today') {
        return b.date.year == now.year && b.date.month == now.month && b.date.day == now.day;
      }
      return true; // 'all'
    }).toList();

    int totalBets = allInTimeframe.length;
    int settledBets = 0;
    int wins = 0;
    int losses = 0;
    int voids = 0;
    int live = 0;
    int pending = 0;
    double netProfit = 0.0;
    double oddsSum = 0.0;

    // Chronological order for progression calculation
    final chronological = List<TrackedBet>.from(allInTimeframe)
      ..sort((a, b) => a.date.compareTo(b.date));

    List<CumulativePoint> progression = [];
    double runningUnits = 0.0;
    int runningWins = 0;
    int runningSettled = 0;

    for (final b in chronological) {
      if (b.status == 'live') {
        live++;
      } else if (b.status == 'pending') {
        pending++;
      } else if (b.isSettled) {
        settledBets++;
        oddsSum += b.odds;
        netProfit += b.profit;
        runningUnits += b.profit;

        if (b.status == 'won') {
          wins++;
          runningWins++;
        } else if (b.status == 'lost') {
          losses++;
        } else if (b.status == 'void') {
          voids++;
        }
        runningSettled++;

        progression.add(
          CumulativePoint(
            date: b.date,
            cumulativeUnits: double.parse(runningUnits.toStringAsFixed(2)),
            runningWinRate: (runningWins / runningSettled) * 100,
            totalBets: runningSettled,
          ),
        );
      }
    }

    final winRate = settledBets > 0 ? (wins / settledBets) * 100 : 0.0;
    final roi = settledBets > 0 ? (netProfit / settledBets) * 100 : 0.0;
    final avgOdds = settledBets > 0 ? oddsSum / settledBets : 0.0;

    // Streak and Form (from newest settled to oldest)
    final settledNewestFirst = _bets
        .where((b) => b.isSettled && (b.status == 'won' || b.status == 'lost'))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int currentStreak = 0;
    if (settledNewestFirst.isNotEmpty) {
      final firstStatus = settledNewestFirst.first.status;
      for (final b in settledNewestFirst) {
        if (b.status == firstStatus) {
          currentStreak++;
        } else {
          break;
        }
      }
      if (firstStatus == 'lost') {
        currentStreak = -currentStreak;
      }
    }

    final List<String> recentForm = settledNewestFirst
        .take(5)
        .map((b) => b.status == 'won' ? 'W' : 'L')
        .toList();

    return TrackerStats(
      totalBets: totalBets,
      settledBets: settledBets,
      wins: wins,
      losses: losses,
      voids: voids,
      live: live,
      pending: pending,
      winRate: double.parse(winRate.toStringAsFixed(1)),
      netProfit: double.parse(netProfit.toStringAsFixed(2)),
      roi: double.parse(roi.toStringAsFixed(1)),
      averageOdds: double.parse(avgOdds.toStringAsFixed(2)),
      currentStreak: currentStreak,
      recentForm: recentForm,
      progression: progression,
    );
  }

  Future<void> _saveBets(SharedPreferences prefs) async {
    final encoded = jsonEncode(_bets.map((b) => b.toJson()).toList());
    await prefs.setString(_trackedBetsKey, encoded);
  }
}
