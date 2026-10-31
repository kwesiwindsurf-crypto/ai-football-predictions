import 'package:flutter/foundation.dart';
import '../../models/match_model.dart';
import 'api_service.dart';
import 'live_sync_engine.dart';

/// Central reactive provider for match fixtures and live game scores.
///
/// Features:
/// 1. Strict O(1) hash map lookup via [_matchesById] so leaf card Selectors
///    never iterate through linear lists during high-frequency live ticks.
/// 2. Smart Delta Dirty Guard: Compares incoming live score/clock/status deltas against
///    cached values. If zero pitch events changed during the tick, `notifyListeners()`
///    is completely skipped, preventing redundant widget builds.
/// 3. Tier 1 Structural Accessors: Exposes ID lists (`getMatchIdsForDate`, `liveMatchIds`)
///    for outer list Selectors so lists only re-layout when matches transition state.
/// 4. Automatically registered to [LiveSyncEngine] so live ticks flow directly into RAM.
class MatchesProvider extends ChangeNotifier {
  static final MatchesProvider instance = MatchesProvider._internal();
  factory MatchesProvider() => instance;
  MatchesProvider._internal();

  final Map<String, Match> _matchesById = {};
  final Map<String, String> _idByTeamsKey = {};
  List<Match> _allMatches = [];
  List<Match> _liveMatches = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  // ── O(1) & Fast Accessors ──────────────────────────────────────────────────
  Match? getMatchById(String id) {
    final direct = _matchesById[id];
    if (direct != null) return direct;
    final canonicalId = _idByTeamsKey[id];
    if (canonicalId != null) return _matchesById[canonicalId];
    return null;
  }

  List<Match> get allMatches => List.unmodifiable(_allMatches);
  List<Match> get liveMatches => List.unmodifiable(_liveMatches);
  bool get hasLiveMatches => _liveMatches.isNotEmpty;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Structural accessor: returns list of match IDs for a given calendar date.
  /// Used by structural list Selectors so match lists don't re-render unless an item is added/removed.
  List<String> getMatchIdsForDate(DateTime date) {
    final targetY = date.year;
    final targetM = date.month;
    final targetD = date.day;
    return _allMatches
        .where((m) {
          final local = m.date.toLocal();
          return local.year == targetY && local.month == targetM && local.day == targetD;
        })
        .map((m) => m.id)
        .toList();
  }

  /// Structural accessor: returns list of match IDs currently in-play (LIVE)
  List<String> get liveMatchIds => _liveMatches.map((m) => m.id).toList();

  /// Initializes the provider with pre-warmed cache and attaches to LiveSyncEngine.
  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Hook up to LiveSyncEngine to automatically receive all live ticks
    LiveSyncEngine.instance.addSyncListener(applyDeltas);

    // 1b. Also follow ApiService's canonical list. `fetchMatches()` kicks off a
    // background live sync that updates ApiService directly (without going
    // through LiveSyncEngine); without this the provider would keep the
    // pre-sync statuses while the API cache already had fresh ones.
    ApiService.allMatchesNotifier.addListener(_onApiMatchesUpdated);

    // 2. Load from in-memory or disk cache
    final cached = ApiService.inMemoryCache ?? await ApiService.instance.getCachedMatches();
    if (cached != null && cached.isNotEmpty) {
      setInitialMatches(cached);
    }

    _isInitialized = true;
    notifyListeners();
  }

  void _onApiMatchesUpdated() {
    final latest = ApiService.allMatchesNotifier.value;
    if (latest == null || latest.isEmpty) return;
    applyDeltas(latest);
  }

  /// Populates the initial master fixture set (from Cloudflare KV or local cache).
  void setInitialMatches(List<Match> matches) {
    _matchesById.clear();
    _idByTeamsKey.clear();
    final uniqueMatches = <String, Match>{};
    for (final m in matches) {
      final dayKey = '${m.normalizedTeamsKey}-${m.date.year}-${m.date.month}-${m.date.day}';
      if (!uniqueMatches.containsKey(dayKey)) {
        uniqueMatches[dayKey] = m;
      }
      final canonical = uniqueMatches[dayKey]!;
      _matchesById[m.id] = canonical;
      _idByTeamsKey[m.normalizedTeamsKey] = canonical.id;
      _idByTeamsKey[dayKey] = canonical.id;
    }
    _allMatches = uniqueMatches.values.toList();
    _liveMatches = _allMatches.where((m) => m.status == MatchStatus.live).toList();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// 🛡️ Smart Delta Dirty Guard:
  /// Compares incoming live score, clock, and status deltas from Render.
  /// If no pitch event changed across any match, notifyListeners() is skipped entirely!
  void applyDeltas(List<Match> deltas) {
    if (deltas.isEmpty) return;

    bool hasMeaningfulChange = false;

    for (final delta in deltas) {
      final deltaDayKey = '${delta.normalizedTeamsKey}-${delta.date.year}-${delta.date.month}-${delta.date.day}';
      Match? existing = _matchesById[delta.id];
      if (existing == null) {
        final canonicalId = _idByTeamsKey[deltaDayKey] ?? _idByTeamsKey[delta.normalizedTeamsKey];
        if (canonicalId != null) {
          existing = _matchesById[canonicalId];
        }
      }

      if (existing == null) {
        // Brand new match entered scope
        _matchesById[delta.id] = delta;
        _idByTeamsKey[delta.normalizedTeamsKey] = delta.id;
        _idByTeamsKey[deltaDayKey] = delta.id;
        _allMatches.add(delta);
        hasMeaningfulChange = true;
      } else {
        // Compare live telemetry attributes
        final scoreChanged = existing.homeScore != delta.homeScore ||
                             existing.awayScore != delta.awayScore;
        final statusChanged = existing.status != delta.status ||
                              existing.statusShort != delta.statusShort;
        final minuteChanged = existing.elapsed != delta.elapsed;
        final eventsChanged = (existing.events?.length ?? 0) != (delta.events?.length ?? 0);

        if (scoreChanged || statusChanged || minuteChanged || eventsChanged) {
          final merged = existing.mergeLiveDelta(delta);
          _matchesById[existing.id] = merged;
          _matchesById[delta.id] = merged; // Alias incoming delta ID as well
          _idByTeamsKey[existing.normalizedTeamsKey] = existing.id;
          _idByTeamsKey[deltaDayKey] = existing.id;

          final canonicalExisting = existing;
          final idx = _allMatches.indexWhere((m) => m.id == canonicalExisting.id || m.normalizedTeamsKey == canonicalExisting.normalizedTeamsKey);
          if (idx >= 0) {
            _allMatches[idx] = merged;
          } else {
            _allMatches.add(merged);
          }
          hasMeaningfulChange = true;
        }
      }
    }

    if (hasMeaningfulChange) {
      _liveMatches = _allMatches.where((m) => m.status == MatchStatus.live).toList();
      debugPrint('⚡ [MatchesProvider] Applied meaningful live deltas (${_liveMatches.length} LIVE). Notifying selectors...');
      notifyListeners();
    }
  }

  /// Manually trigger a fresh network fetch of the full master fixtures.
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await ApiService.instance.fetchMatches(forceRefresh: true);
      setInitialMatches(fresh);
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    LiveSyncEngine.instance.removeSyncListener(applyDeltas);
    ApiService.allMatchesNotifier.removeListener(_onApiMatchesUpdated);
    super.dispose();
  }
}
