import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';
import '../../models/standings_model.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  ApiService._internal();

  // 1. Edge CDN for instant 0ms cold-start master fixture & AI prediction load
  static const String _cloudflareUrl = 'https://ai-football-bot.xantechs00.workers.dev';

  // 2. 24/7 Live Engine for lightweight score, clock, event & lineup deltas (< 20 KB)
  static const String _renderLiveUrl = 'https://ai-football-predictions.onrender.com';

  static const String _cacheKey = 'cached_master_matches_json_v2';
  static const String _cacheTimestampKey = 'cached_master_timestamp';

  // Global notifier for live matches updated from the worker
  static final ValueNotifier<List<Match>> liveMatchesNotifier = ValueNotifier<List<Match>>([]);

  // Global notifier for full match list updates (including newly finished FT matches)
  static final ValueNotifier<List<Match>?> allMatchesNotifier = ValueNotifier<List<Match>?>(null);

  // In-memory cache of the latest fresh matches received from network or disk
  static List<Match>? _inMemoryCache;
  static List<Match>? get inMemoryCache => _inMemoryCache;
  static List<LeagueStandings>? _inMemoryStandings;
  static List<LeagueStandings>? get inMemoryStandings => _inMemoryStandings;

  /// Pre-warms the cache from persistent local storage on disk (SharedPreferences).
  /// Called in main() before runApp() so that HomeScreen starts with data in 0ms!
  static Future<List<Match>?> preWarmCache() async {
    if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
      return _inMemoryCache;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(cachedStr);
        final service = ApiService();
        // A snapshot saved in a previous session can still say "live" for
        // matches that finished hours ago. Demote those before anything reads
        // the cache so the LIVE badge, island and list agree from frame one.
        final parsed = service._parseMatchesFromData(data);
        final staleLive = parsed.where((m) => m.isStaleLive).toList();
        final matches = staleLive.isEmpty
            ? parsed
            : parsed.map((m) => m.isStaleLive ? m.markedFinished() : m).toList();
        if (staleLive.isNotEmpty) {
          debugPrint('🧹 Demoted ${staleLive.length} stale LIVE matches from disk cache.');
        }
        final standings = service._parseStandingsFromData(data);
        if (matches.isNotEmpty) {
          _inMemoryCache = matches;
          final live = matches.where((m) => m.status == MatchStatus.live).toList();
          liveMatchesNotifier.value = live;
          allMatchesNotifier.value = matches;
        }
        if (standings.isNotEmpty) {
          _inMemoryStandings = standings;
        }
        if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
          debugPrint('⚡ Pre-warmed ${_inMemoryCache!.length} matches from local disk cache.');
          return _inMemoryCache;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Pre-warm cache error: $e');
    }
    return null;
  }

  Future<List<Match>?> getCachedMatches() async {
    if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
      return _inMemoryCache;
    }
    return await preWarmCache();
  }

  Future<List<LeagueStandings>?> getCachedStandings() async {
    if (_inMemoryStandings != null && _inMemoryStandings!.isNotEmpty) {
      return _inMemoryStandings;
    }
    await preWarmCache();
    return _inMemoryStandings;
  }

  Future<void> _saveOptimizedCache(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(data));
      await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Persisted master matches bundle to local disk cache.');
    } catch (e) {
      debugPrint('⚠️ Error saving master cache to disk: $e');
    }
  }

  Future<void> _patchDiskCache(List<dynamic> rawLiveMatches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKey);
      if (cachedStr == null || cachedStr.isEmpty) return;

      final Map<String, dynamic> cachedData = json.decode(cachedStr);
      final dynamic rawMatches = (cachedData['matchesData'] != null && cachedData['matchesData'] is Map)
          ? cachedData['matchesData']['matches']
          : cachedData['matches'];

      if (rawMatches is! List) return;

      final Map<String, Map<String, dynamic>> updateJsonMap = {};
      for (var item in rawLiveMatches) {
        if (item is Map) {
          if (item['id'] != null) {
            updateJsonMap[item['id'].toString()] = Map<String, dynamic>.from(item);
          }
          final home = item['homeTeam']?.toString() ?? '';
          final away = item['awayTeam']?.toString() ?? '';
          if (home.isNotEmpty && away.isNotEmpty) {
            final legacyKey = '$home-$away'.replaceAll(RegExp(r'\s+'), '-');
            updateJsonMap.putIfAbsent(legacyKey, () => Map<String, dynamic>.from(item));
          }
        }
      }

      bool changed = false;
      for (int i = 0; i < rawMatches.length; i++) {
        final existingItem = rawMatches[i];
        if (existingItem is Map) {
          final id = existingItem['id']?.toString() ?? '';
          final home = existingItem['homeTeam']?.toString() ?? '';
          final away = existingItem['awayTeam']?.toString() ?? '';
          final legacyKey = '$home-$away'.replaceAll(RegExp(r'\s+'), '-');

          final delta = updateJsonMap[id] ?? updateJsonMap[legacyKey];
          if (delta != null) {
            if (existingItem['homeScore'] != delta['homeScore'] ||
                existingItem['awayScore'] != delta['awayScore'] ||
                existingItem['status'] != delta['status'] ||
                existingItem['statusShort'] != delta['statusShort']) {
              existingItem['homeScore'] = delta['homeScore'];
              existingItem['awayScore'] = delta['awayScore'];
              existingItem['status'] = delta['status'];
              existingItem['statusShort'] = delta['statusShort'];
              if (delta['elapsed'] != null) existingItem['elapsed'] = delta['elapsed'];
              if (delta['events'] != null) existingItem['events'] = delta['events'];
              if (delta['homeScorers'] != null) existingItem['homeScorers'] = delta['homeScorers'];
              if (delta['awayScorers'] != null) existingItem['awayScorers'] = delta['awayScorers'];
              if (delta['stats'] != null) existingItem['stats'] = delta['stats'];
              changed = true;
            }
          }
        }
      }

      if (changed) {
        await prefs.setString(_cacheKey, json.encode(cachedData));
        debugPrint('💾 Persisted ${rawLiveMatches.length} live/FT score updates to local disk cache.');
      }
    } catch (e) {
      debugPrint('⚠️ Disk cache patch note: $e');
    }
  }

  // In-flight request deduplication & cache timestamp
  static Future<List<Match>>? _pendingFetch;
  static DateTime? _lastFetchTime;

  /// Lightweight live-scores poll: fetches only today's active & live matches (< 20 KB)
  /// and merges live scores/clocks directly into the existing match list.
  /// When [forceSync] is true (e.g. app launch), bypasses clock check to patch today's FT matches.
  Future<List<Match>?> fetchLiveUpdates({bool forceSync = false}) async {
    if (_inMemoryCache == null || _inMemoryCache!.isEmpty) return null;

    final now = DateTime.now().toUtc();

    // 1. Kickoff-Time Gating:
    // If not a forceSync, verify if any match is inside active play window (-5m to +180m from kickoff)
    if (!forceSync) {
      final hasActiveMatches = _inMemoryCache!.any((m) {
        if (m.status == MatchStatus.live) return true;
        if (m.status == MatchStatus.finished || m.isPostponed) return false;
        final mins = now.difference(m.date.toUtc()).inMinutes;
        return mins >= -5 && mins <= 180;
      });

      if (!hasActiveMatches) {
        return null;
      }
    }

    try {
      final uri = Uri.parse('$_renderLiveUrl/live');
      final cacheBuster = {'t': now.millisecondsSinceEpoch.toString()};
      final freshUri = uri.replace(queryParameters: cacheBuster);
      final response = await http.get(freshUri).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final dynamic rawMatches = (data['matchesData'] != null && data['matchesData'] is Map)
            ? data['matchesData']['matches']
            : data['matches'];
        if (rawMatches is List && _inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
          final liveUpdatedList = <Match>[];
          for (var item in rawMatches) {
            if (item is Map) {
              try {
                liveUpdatedList.add(Match.fromJson(Map<String, dynamic>.from(item)));
              } catch (_) {}
            }
          }

          if (liveUpdatedList.isNotEmpty) {
            final Map<String, Match> updateMapById = {
              for (var m in liveUpdatedList) m.id: m,
            };
            final Map<String, Match> updateMapByTeams = {
              for (var m in liveUpdatedList) m.normalizedTeamsKey: m,
            };
            _inMemoryCache = _inMemoryCache!.map((existing) {
              final delta = updateMapById[existing.id] ?? updateMapByTeams[existing.normalizedTeamsKey];
              if (delta != null) {
                return existing.mergeLiveDelta(delta);
              }
              return existing;
            }).toList();

            final live = _inMemoryCache!.where((m) => m.status == MatchStatus.live).toList();
            liveMatchesNotifier.value = live;
            allMatchesNotifier.value = _inMemoryCache;
            debugPrint('⚡ Render Live Sync: updated ${liveUpdatedList.length} active/FT matches (${live.length} LIVE)');
            unawaited(_patchDiskCache(rawMatches));
            return _inMemoryCache;
          }
        }
      }
    } catch (e) {
      debugPrint('Fast live-poll note: $e');
    }
    return null;
  }

  Future<List<Match>> fetchMatches({bool forceRefresh = false}) async {
    // 1. If cache is fresh (< 60s old) and forceRefresh is false, return immediately
    if (!forceRefresh &&
        _inMemoryCache != null &&
        _inMemoryCache!.isNotEmpty &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inSeconds < 60) {
      return _inMemoryCache!;
    }

    // 2. If a network fetch is already in flight, await that instead of launching a duplicate 5MB request
    if (_pendingFetch != null) {
      return _pendingFetch!;
    }

    _pendingFetch = _executeFetchMatches();
    try {
      final result = await _pendingFetch!;
      return result;
    } finally {
      _pendingFetch = null;
    }
  }

  Future<List<Match>> _executeFetchMatches() async {
    // 1. Load full 7-day fixture & prediction bundle from Cloudflare Edge (< 30ms, 0 cold start)
    try {
      debugPrint('⚡ Fetching master fixtures & predictions from Cloudflare Edge: $_cloudflareUrl');
      final matches = await fetchMatchesFromUrl(_cloudflareUrl).timeout(const Duration(seconds: 15));
      if (matches.isNotEmpty) {
        _inMemoryCache = matches;
        _lastFetchTime = DateTime.now();
        final live = matches.where((m) => m.status == MatchStatus.live).toList();
        liveMatchesNotifier.value = live;
        allMatchesNotifier.value = matches;
        debugPrint('✅ Received ${matches.length} matches from Cloudflare Edge.');

        // 2. Immediately sync today\'s completed FT and in-progress LIVE matches from Render in background!
        unawaited(fetchLiveUpdates(forceSync: true));

        return matches;
      }
    } catch (e) {
      debugPrint('⚠️ Cloudflare Edge fetch note: $e');
      // If we have an existing in-memory cache, preserve it and sync live deltas
      if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
        unawaited(fetchLiveUpdates(forceSync: true));
        return _inMemoryCache!;
      }
      // Check local disk cache
      final diskCached = await preWarmCache();
      if (diskCached != null && diskCached.isNotEmpty) {
        unawaited(fetchLiveUpdates(forceSync: true));
        return diskCached;
      }
      // Fallback to Render master endpoint if Cloudflare is ever unreachable and no disk cache exists
      try {
        debugPrint('⚡ Falling back to Render master fetch: $_renderLiveUrl');
        final matches = await fetchMatchesFromUrl(_renderLiveUrl).timeout(const Duration(seconds: 25));
        if (matches.isNotEmpty) {
          _inMemoryCache = matches;
          _lastFetchTime = DateTime.now();
          final live = matches.where((m) => m.status == MatchStatus.live).toList();
          liveMatchesNotifier.value = live;
          allMatchesNotifier.value = matches;
          return matches;
        }
      } catch (rErr) {
        debugPrint('⚠️ Render fallback note: $rErr');
      }
      rethrow;
    }

    if (_inMemoryCache != null && _inMemoryCache!.isNotEmpty) {
      return _inMemoryCache!;
    }

    throw Exception('Unable to load matches.');
  }

  Future<List<Match>> fetchMatchesFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final cacheBuster = {'t': DateTime.now().millisecondsSinceEpoch.toString()};
      final freshUri = uri.replace(queryParameters: {...uri.queryParameters, ...cacheBuster});
      final response = await http.get(freshUri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        _saveOptimizedCache(data);
        return _parseMatchesFromData(data);
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching matches from $url: $e');
    }
  }

  Future<List<LeagueStandings>> fetchStandings() async {
    try {
      return await _fetchStandingsFromUrl(_cloudflareUrl).timeout(const Duration(seconds: 10));
    } catch (cfError) {
      debugPrint('⚠️ Cloudflare standings note: $cfError');
      try {
        return await _fetchStandingsFromUrl(_renderLiveUrl).timeout(const Duration(seconds: 10));
      } catch (renderError) {
        debugPrint('⚠️ Render standings note: $renderError');
        final cached = await getCachedStandings();
        if (cached != null && cached.isNotEmpty) return cached;
        return [];
      }
    }
  }

  Future<List<LeagueStandings>> _fetchStandingsFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      _saveOptimizedCache(data);
      final standings = _parseStandingsFromData(data);
      if (standings.isNotEmpty) {
        _inMemoryStandings = standings;
      }
      return standings;
    } else {
      throw Exception('HTTP ${response.statusCode}');
    }
  }

  List<Match> _parseMatchesFromData(Map<String, dynamic> data) {
    dynamic rawMatches;
    if (data['matchesData'] != null && data['matchesData'] is Map) {
      rawMatches = data['matchesData']['matches'];
    } else {
      rawMatches = data['matches'];
    }

    final List<dynamic> matchesJson = (rawMatches is List) ? rawMatches : [];

    Map<String, dynamic> standingsData = {};
    if (data['standingsData'] != null && data['standingsData'] is Map) {
      if (data['standingsData']['standings'] is Map) {
        standingsData = Map<String, dynamic>.from(data['standingsData']['standings']);
      }
    }

    final List<Match> matches = [];
    final Set<String> seenKeys = {};
    for (var item in matchesJson) {
      if (item is Map) {
        try {
          final m = Match.fromJson(Map<String, dynamic>.from(item), standingsData);
          final dayKey = '${m.normalizedTeamsKey}-${m.date.year}-${m.date.month}-${m.date.day}';
          if (seenKeys.add(dayKey)) {
            matches.add(m);
          }
        } catch (_) {
          // Skip malformed match entry safely
        }
      }
    }
    final live = matches.where((m) => m.status == MatchStatus.live).toList();
    liveMatchesNotifier.value = live;
    return matches;
  }

  List<LeagueStandings> _parseStandingsFromData(Map<String, dynamic> data) {
    dynamic rawLeagues;
    if (data['standingsData'] != null && data['standingsData'] is Map) {
      rawLeagues = data['standingsData']['standingsByLeague'];
    } else {
      rawLeagues = data['standingsByLeague'];
    }

    final List<dynamic> leaguesJson = (rawLeagues is List) ? rawLeagues : [];

    final List<LeagueStandings> standings = [];
    for (var item in leaguesJson) {
      if (item is Map) {
        try {
          standings.add(LeagueStandings.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    return standings;
  }
}

