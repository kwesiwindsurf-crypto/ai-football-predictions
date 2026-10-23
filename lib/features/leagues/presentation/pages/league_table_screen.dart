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
                errorWidget: (_, __, ___) => const Icon(Icons.emoji_events_rounded, size: 22),
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
                  // Table Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: primary.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('#', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        Expanded(
                          child: Text('Club', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('P', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('W', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('D', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text('L', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 32,
                          child: Text('GD', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text('PTS', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primary)),
                        ),
                      ],
                    ),
                  ),

                  // Table Rows
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: table.length,
                    separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
                    itemBuilder: (context, idx) {
                      final team = table[idx];
                      final isTop4 = idx < 4;
                      final isRelegation = idx >= table.length - 3;

                      Color rankColor = textSecondary;
                      if (isTop4) rankColor = const Color(0xFF10B981); // Champions League green
                      if (isRelegation) rankColor = const Color(0xFFEF4444); // Relegation red

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '${team.rank}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: rankColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  if (team.logo.isNotEmpty)
                                    CachedNetworkImage(
                                      imageUrl: team.logo,
                                      width: 18,
                                      height: 18,
                                      errorWidget: (_, __, ___) => const Icon(Icons.shield_outlined, size: 16),
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      team.name,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('${team.played}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('${team.win}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('${team.draw}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                            ),
                            SizedBox(
                              width: 28,
                              child: Text('${team.lose}', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: textSecondary)),
                            ),
                            SizedBox(
                              width: 32,
                              child: Text(
                                '${team.goalsDiff > 0 ? '+' : ''}${team.goalsDiff}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: team.goalsDiff > 0 ? const Color(0xFF10B981) : (team.goalsDiff < 0 ? const Color(0xFFEF4444) : textSecondary),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              child: Text(
                                '${team.points}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: primary,
                                ),
                              ),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Continental / Top Tier', style: TextStyle(fontSize: 11, color: textSecondary)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Relegation Zone', style: TextStyle(fontSize: 11, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
