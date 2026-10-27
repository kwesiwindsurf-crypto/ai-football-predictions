import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';
import '../../models/standings_model.dart';

class ApiService {
  // Production 24/7 Unlimited Live Engine URL on Render.com
  static const String _workerUrl = 'https://ai-football-predictions.onrender.com';
  static const String _cacheMatchesKey = 'cached_cloudflare_matches_v1';
  static const String _cacheStandingsKey = 'cached_cloudflare_standings_v1';

  // Global notifier for live matches updated from the worker
  static final ValueNotifier<List<Match>> liveMatchesNotifier = ValueNotifier<List<Match>>([]);

  Future<List<Match>?> getCachedMatches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedStr = prefs.getString(_cacheMatchesKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(cachedStr);
        return _parseMatchesFromData(data);
      }
    } catch (_) {
      // Fallback silently if cache is corrupted
    }
    return null;
  }

  Future<List<LeagueStandings>?> getCachedStandings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Standings and matches share the same Cloudflare worker payload
      final String? cachedStr = prefs.getString(_cacheMatchesKey) ?? prefs.getString(_cacheStandingsKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(cachedStr);
        return _parseStandingsFromData(data);
      }
    } catch (_) {
      // Fallback silently if cache is corrupted
    }
    return null;
  }

  Future<void> _saveCache(String body) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clean up legacy duplicate key if present to free up browser localStorage quota
      if (prefs.containsKey(_cacheStandingsKey)) {
        await prefs.remove(_cacheStandingsKey);
      }
      await prefs.setString(_cacheMatchesKey, body);
    } catch (_) {
      // Silently catch quota exceeded errors on web or storage-restricted environments
    }
  }

  Future<List<Match>> fetchMatches() {
    return fetchMatchesFromUrl(_workerUrl);
  }

  Future<List<Match>> fetchMatchesFromUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final cacheBuster = {'t': DateTime.now().millisecondsSinceEpoch.toString()};
      final freshUri = uri.replace(queryParameters: {...uri.queryParameters, ...cacheBuster});
      final response = await http.get(freshUri);

      if (response.statusCode == 200) {
        // Save to cache asynchronously and safely
        _saveCache(response.body);

        final Map<String, dynamic> data = json.decode(response.body);
        return _parseMatchesFromData(data);
      } else {
        throw Exception('Failed to load matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching matches: $e');
    }
  }

  Future<List<LeagueStandings>> fetchStandings() async {
    try {
      final response = await http.get(Uri.parse(_workerUrl));
      if (response.statusCode == 200) {
        // Save to cache asynchronously and safely
        _saveCache(response.body);

        final Map<String, dynamic> data = json.decode(response.body);
        return _parseStandingsFromData(data);
      } else {
        throw Exception('Failed to load standings: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching standings: $e');
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
    for (var item in matchesJson) {
      if (item is Map) {
        try {
          matches.add(Match.fromJson(Map<String, dynamic>.from(item), standingsData));
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

