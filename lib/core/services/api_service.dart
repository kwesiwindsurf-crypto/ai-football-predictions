import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();
  factory ApiService() => instance;
  ApiService._internal();

  // 1. Edge CDN for instant 0ms cold-start master fixture & AI prediction load
  static const String _cloudflareUrl = 'https://ai-football-bot.xantechs00.workers.dev';

  // 2. 24/7 Live Engine for lightweight score, clock & event deltas (< 20 KB)
  static const String _renderLiveUrl = 'https://ai-football-predictions.onrender.com';

  static const String _cacheKey = 'cached_master_matches_json_v2';
  static const String _cacheTimestampKey = 'cached_master_timestamp';
  static const String _overridesKey = 'cached_live_overrides_v1';

  /// Live telemetry decays. A stored LIVE snapshot from just before the app was
  /// backgrounded must never be replayed much later — the match may have ended
  /// while no tick ran, and the stale entry would resurrect it as LIVE with a
  /// frozen score. Finished (FT) snapshots keep their age: they are facts.
  static const Duration _liveOverrideMaxAge = Duration(minutes: 20);

  // Global notifier for live matches updated from the worker
  static final ValueNotifier<List<Match>> liveMatchesNotifier = ValueNotifier<List<Match>>([]);

  // Global notifier for full match list updates (including newly finished FT matches)
  static final ValueNotifier<List<Match>?> allMatchesNotifier = ValueNotifier<List<Match>?>(null);

  // In-memory cache of the latest fresh matches received from network or disk
  static List<Match>? _inMemoryCache;
  static List<Match>? get inMemoryCache => _inMemoryCache;

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
        var parsed = service._parseMatchesFromData(data);

        // Replay the last known live telemetry so the first frame after a cold start
        // shows the real score instead of whatever the daily KV snapshot said.
        final overridesStr = prefs.getString(_overridesKey);
        if (overridesStr != null && overridesStr.isNotEmpty) {
          try {
            parsed = _mergeLiveOverrides(parsed, overridesStr);
          } catch (e) {
            debugPrint('⚠️ Live override replay note: $e');
          }
        }

        final staleLive = parsed.where((m) => m.isStaleLive).toList();
        final matches = staleLive.isEmpty
            ? parsed
            : parsed.map((m) => m.isStaleLive ? m.markedFinished() : m).toList();
        if (staleLive.isNotEmpty) {
          debugPrint('🧹 Demoted ${staleLive.length} stale LIVE matches from disk cache.');
        }
        if (matches.isNotEmpty) {
          _inMemoryCache = matches;
          final live = matches.where((m) => m.status == MatchStatus.live).toList();
          liveMatchesNotifier.value = live;
          allMatchesNotifier.value = matches;
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

  /// Persists only the telemetry needed to repaint a scoreboard on cold start, keyed by
  /// match id. The previous implementation re-read, re-encoded and re-wrote the entire
  /// 1.3MB master bundle on every 25s tick; this keeps that write to roughly 10KB.
  Future<void> _saveLiveOverrides(List<dynamic> rawLiveMatches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final byId = <String, Map<String, dynamic>>{};

      final existing = prefs.getString(_overridesKey);
      final nowUtc = DateTime.now().toUtc();
      if (existing != null && existing.isNotEmpty) {
        for (final item in (json.decode(existing) as List)) {
          if (item is Map && item['id'] != null) {
            final entry = Map<String, dynamic>.from(item);
            final status = entry['status']?.toString();
            final isFinished = status == 'finished';
            final savedAt = DateTime.tryParse(entry['savedAt']?.toString() ?? '');

            // Finished snapshots are durable facts — keep them indefinitely.
            if (isFinished) {
              byId[entry['id'].toString()] = entry;
              continue;
            }
            // Legacy entries predating the savedAt stamp have unknown age: a
            // LIVE snapshot of unknown age would resurrect a frozen clock.
            if (!isFinished && savedAt == null) continue;
            if (!isFinished &&
                savedAt != null &&
                nowUtc.difference(savedAt.toUtc()) > _liveOverrideMaxAge) {
              continue;
            }
            byId[entry['id'].toString()] = entry;
          }
        }
      }

      for (final item in rawLiveMatches) {
        if (item is! Map || item['id'] == null) continue;
        byId[item['id'].toString()] = <String, dynamic>{
          'id': item['id'],
          'homeTeam': item['homeTeam'],
          'awayTeam': item['awayTeam'],
          'date': item['date'],
          'status': item['status'],
          'statusShort': item['statusShort'],
          'homeScore': item['homeScore'],
          'awayScore': item['awayScore'],
          'elapsed': item['elapsed'],
          'savedAt': nowUtc.toIso8601String(),
        };
      }

      // A match cannot still be in play six hours after kickoff, so anything older than
      // that would only ever be resurrected as a frozen clock by isStaleLive's guard.
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 6));
      byId.removeWhere((_, entry) {
        final kickoff = DateTime.tryParse(entry['date']?.toString() ?? '');
        return kickoff == null || kickoff.toUtc().isBefore(cutoff);
      });

      await prefs.setString(_overridesKey, json.encode(byId.values.toList()));
    } catch (e) {
      debugPrint('⚠️ Live override save note: $e');
    }
  }

  static Match? _findMatchingDelta(
    Match base,
    Map<String, Match> byId,
    Map<String, List<Match>> byTeams,
  ) {
    final exact = byId[base.id];
    if (exact != null) return exact;
    final candidates = byTeams[base.normalizedTeamsKey];
    if (candidates == null) return null;
    for (final candidate in candidates) {
      if (base.isSameFixtureAs(candidate)) return candidate;
    }
    return null;
  }

  /// Replays the stored telemetry onto a freshly parsed match list, preserving every
  /// static field (prediction, odds, ranks, form) that the override entry does not carry.
  static List<Match> _mergeLiveOverrides(List<Match> base, String overridesJson) {
    final nowUtc = DateTime.now().toUtc();
    final deltas = <Match>[];
    for (final item in (json.decode(overridesJson) as List)) {
      if (item is! Map) continue;
      // Same decay policy as _saveLiveOverrides: finished snapshots are facts
      // and always replay, but a LIVE snapshot only replays while it is fresh.
      if (item['status']?.toString() != 'finished') {
        final savedAt = DateTime.tryParse(item['savedAt']?.toString() ?? '');
        if (savedAt == null) continue; // legacy entry of unknown age
        if (nowUtc.difference(savedAt.toUtc()) > _liveOverrideMaxAge) continue;
      }
      try {
        deltas.add(Match.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {}
    }
    if (deltas.isEmpty) return base;

    final byId = <String, Match>{};
    final byTeams = <String, List<Match>>{};
    for (final d in deltas) {
      byId[d.id] = d;
      byTeams.putIfAbsent(d.normalizedTeamsKey, () => []).add(d);
    }
    return base.map((m) {
      final delta = _findMatchingDelta(m, byId, byTeams);
      return delta == null ? m : m.mergeLiveDelta(delta);
    }).toList();
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
            final Map<String, Match> updateMapById = {};
            final Map<String, List<Match>> updateMapByTeams = {};
            for (final m in liveUpdatedList) {
              updateMapById[m.id] = m;
              updateMapByTeams.putIfAbsent(m.normalizedTeamsKey, () => []).add(m);
            }
            _inMemoryCache = _inMemoryCache!.map((existing) {
              final delta = _findMatchingDelta(existing, updateMapById, updateMapByTeams);
              if (delta != null) {
                return existing.mergeLiveDelta(delta);
              }
              return existing;
            }).toList();

            final live = _inMemoryCache!.where((m) => m.status == MatchStatus.live).toList();
            liveMatchesNotifier.value = live;
            allMatchesNotifier.value = _inMemoryCache;
            debugPrint('⚡ Render Live Sync: updated ${liveUpdatedList.length} active/FT matches (${live.length} LIVE)');
            unawaited(_saveLiveOverrides(rawMatches));
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
          final dayKey = m.normalizedTeamsDayKey;
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
}

