import 'package:flutter/foundation.dart';
import '../../models/match_model.dart';
import 'api_service.dart';
import 'live_sync_engine.dart';

/// Central reactive provider for leagues hub, standings, and live match counters.
///
/// Features:
/// 1. Fast O(1) lookup of live match counts per league.
/// 2. Smart Delta Guard: Only calls notifyListeners() if active/live match counts per league change.
/// 3. Automatically registered to [LiveSyncEngine] so live counts update in real time.
class LeaguesProvider extends ChangeNotifier {
  static final LeaguesProvider instance = LeaguesProvider._internal();
  factory LeaguesProvider() => instance;
  LeaguesProvider._internal();

  final Map<String, int> _liveCountByLeague = {};
  List<Match> _liveMatches = [];
  bool _isInitialized = false;

  List<Match> get liveMatches => List.unmodifiable(_liveMatches);
  int get totalLiveMatches => _liveMatches.length;
  bool get hasLiveMatches => _liveMatches.isNotEmpty;

  /// Fast O(1) lookup for live match count in a specific league.
  int getLiveMatchCount(String leagueName) {
    return _liveCountByLeague[leagueName.toLowerCase()] ?? 0;
  }

  /// Alias for [getLiveMatchCount]
  int getLiveCountForLeague(String leagueName) => getLiveMatchCount(leagueName);

  /// Alias for [updateActiveMatches]
  void updateFromMatches(List<Match> matches) => updateActiveMatches(matches);

  /// Initializes with cached data and connects to LiveSyncEngine.
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Attach to LiveSyncEngine
    LiveSyncEngine.instance.addSyncListener(updateActiveMatches);

    // Also follow ApiService's canonical list: fetchMatches() runs a background
    // live sync that updates ApiService directly, bypassing LiveSyncEngine.
    ApiService.allMatchesNotifier.addListener(_onApiMatchesUpdated);

    // Initial calculation from in-memory cache
    final cached = ApiService.inMemoryCache;
    if (cached != null && cached.isNotEmpty) {
      updateActiveMatches(cached);
    }
  }

  void _onApiMatchesUpdated() {
    final latest = ApiService.allMatchesNotifier.value;
    if (latest == null || latest.isEmpty) return;
    updateActiveMatches(latest);
  }

  /// 🛡️ Smart Delta Guard:
  /// Updates live match counts per league and notifies only when the count changes.
  void updateActiveMatches(List<Match> matches) {
    final live = matches.where((m) => m.status == MatchStatus.live).toList();
    final Map<String, int> newCounts = {};

    for (final m in live) {
      final key = m.league.toLowerCase();
      newCounts[key] = (newCounts[key] ?? 0) + 1;
    }

    // Check if counts actually changed
    bool countsChanged = _liveMatches.length != live.length;
    if (!countsChanged) {
      if (newCounts.length != _liveCountByLeague.length) {
        countsChanged = true;
      } else {
        for (final entry in newCounts.entries) {
          if (_liveCountByLeague[entry.key] != entry.value) {
            countsChanged = true;
            break;
          }
        }
      }
    }

    if (countsChanged) {
      _liveMatches = live;
      _liveCountByLeague.clear();
      _liveCountByLeague.addAll(newCounts);
      debugPrint('⚡ [LeaguesProvider] Live league counts updated (${_liveMatches.length} live). Notifying...');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    LiveSyncEngine.instance.removeSyncListener(updateActiveMatches);
    ApiService.allMatchesNotifier.removeListener(_onApiMatchesUpdated);
    super.dispose();
  }
}
