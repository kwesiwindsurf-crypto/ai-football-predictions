import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/country_leagues_model.dart';
import '../../../../models/standings_model.dart';

class LeagueTableScreen extends StatefulWidget {
  final ScrapedLeagueInfo league;

  const LeagueTableScreen({super.key, required this.league});

  @override
  State<LeagueTableScreen> createState() => _LeagueTableScreenState();
}

class _LeagueTableScreenState extends State<LeagueTableScreen> {
  bool _isLoading = true;
  String? _error;
  LeagueStandings? _standings;

  @override
  void initState() {
    super.initState();
    _fetchStandings();
  }

  Future<void> _fetchStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('https://site.api.espn.com/apis/v2/sports/soccer/${widget.league.slug}/standings');
      final res = await http.get(url).timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final children = data['children'] as List? ?? [];
        if (children.isNotEmpty) {
          final entries = children[0]['standings']?['entries'] as List? ?? [];
          final List<TeamStanding> teamStandings = [];

          for (final entry in entries) {
            final team = entry['team'] ?? {};
            final stats = (entry['stats'] as List? ?? []);

            int stat(String name) {
              final s = stats.firstWhere(
                (item) => item['name'] == name || item['type'] == name,
                orElse: () => null,
              );
              return s != null ? (s['value'] as num? ?? 0).toInt() : 0;
            }

            final logos = team['logos'] as List? ?? [];
            final logoUrl = logos.isNotEmpty ? (logos[0]['href'] ?? '') : '';

            teamStandings.add(TeamStanding(
              rank: stat('rank') > 0 ? stat('rank') : (teamStandings.length + 1),
              name: team['displayName'] ?? team['name'] ?? 'Team',
              logo: logoUrl,
              points: stat('points'),
              goalsDiff: stat('pointDifferential'),
              played: stat('gamesPlayed'),
              win: stat('wins'),
              draw: stat('ties'),
              lose: stat('losses'),
            ));
          }

          teamStandings.sort((a, b) => a.rank.compareTo(b.rank));

          if (mounted) {
            setState(() {
              _standings = LeagueStandings(
                id: 1,
                name: widget.league.name,
                logo: widget.league.logo,
                flag: widget.league.flagEmoji,
                standings: teamStandings,
              );
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _error = 'Standings not available yet for this competition.';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load standings (HTTP ${res.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not connect to live standings. Tap retry.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            if (widget.league.logo.isNotEmpty)
              CachedNetworkImage(
                imageUrl: widget.league.logo,
                width: 24,
                height: 24,
                errorWidget: (context, url, error) => const Icon(Icons.emoji_events_rounded, size: 22),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.league.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${widget.league.country} • ${widget.league.tier}',
                    style: TextStyle(fontSize: 11, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(primary, surface, borderColor, textPrimary, textSecondary),
    );
  }

  Widget _buildBody(Color primary, Color surface, Color borderColor, Color textPrimary, Color textSecondary) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primary),
            const SizedBox(height: 16),
            Text('Loading live table...', style: TextStyle(color: textSecondary)),
          ],
        ),
      );
    }

    if (_error != null || _standings == null || _standings!.standings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.table_chart_outlined, size: 52, color: textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                _error ?? 'No standings available for this tournament.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _fetchStandings,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final table = _standings!.standings;

    return RefreshIndicator(
      onRefresh: _fetchStandings,
      color: primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Table Header (Image 4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    color: const Color(0xFF10141D),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary)),
                        ),
                        Expanded(
                          child: Text('CLUB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text('P', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text('D', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 22,
                          child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('GD', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 28,
                          child: const Text('PTS', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace')),
                        ),
                        SizedBox(
                          width: 66,
                          child: Text('FORM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: textSecondary)),
                        ),
                      ],
                    ),
                  ),

                  // Table Rows (Image 4)
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: table.length,
                    separatorBuilder: (_, _) => Divider(color: borderColor.withValues(alpha: 0.6), height: 1),
                    itemBuilder: (context, idx) {
                      final team = table[idx];
                      Color zoneColor = Colors.transparent;
                      if (idx < 4) {
                        zoneColor = const Color(0xFF3B82F6); // UCL blue
                      } else if (idx == 4) {
                        zoneColor = const Color(0xFFF59E0B); // UEL amber
                      } else if (idx >= table.length - 3) {
                        zoneColor = const Color(0xFFEF4444); // Relegation red
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Row(
                          children: [
                            // Left Zone Bar
                            Container(
                              width: 3.5,
                              height: 16,
                              decoration: BoxDecoration(
                                color: zoneColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Rank Number
                            SizedBox(
                              width: 18,
                              child: Text(
                                '${team.rank}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white70,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),

                            // Team Badge Box + Name
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF161B22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _teamCode(team.name),
                                      style: const TextStyle(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white70,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      team.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Stats Columns: P, W, D, L, GD, PTS
                            SizedBox(width: 22, child: Text('${team.played}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textSecondary, fontFamily: 'monospace'))),
                            SizedBox(width: 22, child: Text('${team.win}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textSecondary, fontFamily: 'monospace'))),
                            SizedBox(width: 22, child: Text('${team.draw}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textSecondary, fontFamily: 'monospace'))),
                            SizedBox(width: 22, child: Text('${team.lose}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: textSecondary, fontFamily: 'monospace'))),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${team.goalsDiff > 0 ? '+' : ''}${team.goalsDiff}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: team.goalsDiff > 0
                                      ? const Color(0xFF00D06C)
                                      : (team.goalsDiff < 0 ? const Color(0xFFEF4444) : textSecondary),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${team.points}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            SizedBox(
                              width: 66,
                              child: _buildFormBadges(team.form),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Qualification & Relegation Zones Legend (Image 4)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUALIFICATION & RELEGATION ZONES',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('UEFA Champions League (1-4)', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFF59E0B), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('UEFA Europa League (5)', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('Relegation Zone (18-20)', style: TextStyle(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 32),
        ],
      ),
    );
  }

  String _teamCode(String name) {
    if (name.contains('Arsenal')) return 'ARS';
    if (name.contains('City')) return 'MCI';
    if (name.contains('Liverpool')) return 'LIV';
    if (name.contains('Villa')) return 'AVL';
    if (name.contains('Tottenham') || name.contains('Spurs')) return 'TOT';
    if (name.contains('United')) return 'MUN';
    if (name.contains('Newcastle')) return 'NEW';
    if (name.contains('Chelsea')) return 'CHE';
    if (name.contains('Brighton')) return 'BHA';
    if (name.contains('West Ham')) return 'WHU';
    if (name.contains('Bournemouth')) return 'BOU';
    if (name.contains('Fulham')) return 'FUL';
    if (name.contains('Wolves')) return 'WOL';
    if (name.contains('Palace')) return 'CRY';
    if (name.contains('Brentford')) return 'BRE';
    if (name.contains('Everton')) return 'EVE';
    if (name.contains('Forest')) return 'NFO';
    if (name.contains('Luton')) return 'LUT';
    if (name.contains('Burnley')) return 'BUR';
    if (name.contains('Sheffield')) return 'SHU';
    if (name.contains('Hilal')) return 'HIL';
    if (name.contains('Nassr')) return 'NAS';
    if (name.contains('Ittihad')) return 'ITT';
    if (name.contains('Ahli')) return 'AHL';
    if (name.contains('Faisaly')) return 'FAI';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 3 ? 3 : name.length).toUpperCase();
  }

  Widget _buildFormBadges(String? formStr) {
    if (formStr == null || formStr.trim().isEmpty) return const SizedBox.shrink();
    final form = formStr.trim();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: form.split('').take(5).map((c) {
        Color bg = const Color(0xFFF59E0B);
        Color textC = Colors.black;
        if (c == 'W') {
          bg = const Color(0xFF10B981);
        } else if (c == 'L') {
          bg = const Color(0xFFEF4444);
          textC = Colors.white;
        }
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 11,
          height: 11,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Center(
            child: Text(
              c,
              style: TextStyle(
                color: textC,
                fontSize: 6.5,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
