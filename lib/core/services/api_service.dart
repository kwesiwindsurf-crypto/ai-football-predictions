import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/match_model.dart';
import '../../models/standings_model.dart';

class ApiService {
  // Production Cloudflare Worker URL
  static const String _workerUrl = 'https://ai-football-bot.xantechs00.workers.dev';
  static const String _cacheMatchesKey = 'cached_cloudflare_matches_v1';
  static const String _cacheStandingsKey = 'cached_cloudflare_standings_v1';

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
      final String? cachedStr = prefs.getString(_cacheStandingsKey);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final Map<String, dynamic> data = json.decode(cachedStr);
        return _parseStandingsFromData(data);
      }
    } catch (_) {
      // Fallback silently if cache is corrupted
    }
    return null;
  }

  Future<List<Match>> fetchMatches() {
    return fetchMatchesFromUrl(_workerUrl);
  }

  Future<List<Match>> fetchMatchesFromUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Save to cache asynchronously
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_cacheMatchesKey, response.body);
          prefs.setString(_cacheStandingsKey, response.body);
        });

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
        // Save to cache asynchronously
        SharedPreferences.getInstance().then((prefs) {
          prefs.setString(_cacheMatchesKey, response.body);
          prefs.setString(_cacheStandingsKey, response.body);
        });

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
    final List<dynamic> matchesJson = (data['matchesData'] != null)
        ? data['matchesData']['matches'] ?? []
        : data['matches'] ?? [];
        
    final Map<String, dynamic> standingsData = (data['standingsData'] != null)
        ? data['standingsData']['standings'] ?? {}
        : {};
    
    return matchesJson.map((json) => Match.fromJson(json, standingsData)).toList();
  }

  List<LeagueStandings> _parseStandingsFromData(Map<String, dynamic> data) {
    final List<dynamic> leaguesJson = (data['standingsData'] != null)
        ? data['standingsData']['standingsByLeague'] ?? []
        : [];
        
    return leaguesJson.map((json) => LeagueStandings.fromJson(json)).toList();
  }
}

