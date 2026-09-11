import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

import '../../../../models/match_model.dart' as model;
import '../../../../core/services/api_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  final ApiService _apiService = ApiService();
  List<model.Match>? _matches;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final matches = await _apiService.fetchMatches();
      if (mounted) {
        setState(() {
          _matches = matches;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _didPredictionWin(model.Match match) {
    if (match.homeScore == null || match.awayScore == null) return false;
    final hScore = match.homeScore!;
    final aScore = match.awayScore!;
    final rec = match.prediction.recommendation.toLowerCase();

    final homeName = match.homeTeam.toLowerCase();
    final awayName = match.awayTeam.toLowerCase();

    if (hScore > aScore && rec.contains(homeName)) return true;
    if (aScore > hScore && rec.contains(awayName)) return true;
    if (hScore == aScore && rec.contains('draw')) return true;
    
    // Double chance logic fallback
    if (hScore >= aScore && rec.contains(homeName) && rec.contains('draw')) return true;
    if (aScore >= hScore && rec.contains(awayName) && rec.contains('draw')) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    List<model.Match> playedMatches = [];
    int wins = 0;
    int winRate = 0;

    if (_matches != null) {
      playedMatches = _matches!
          .where((m) => m.status == model.MatchStatus.finished || m.status == model.MatchStatus.live)
          .toList();
      
      // Sort newest first
      playedMatches.sort((a, b) => b.date.compareTo(a.date));

      for (var m in playedMatches) {
        if (_didPredictionWin(m)) {
          wins++;
        }
      }
      
      if (playedMatches.isNotEmpty) {
        winRate = ((wins / playedMatches.length) * 100).round();
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('AI Performance Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStatsOverview(winRate, playedMatches.length),
                  const SizedBox(height: 32),
                  const Text(
                    'Today\'s Tracker (Live & FT)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (playedMatches.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No played or live matches today to track yet.', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                    )
                  else
                    _buildRecentPicksList(playedMatches),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsOverview(int winRate, int totalPicks) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.8),
            AppTheme.primary.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'TODAY\'S WIN RATE',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                winRate.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const Text(
                '%',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatMetric('Total ROI', '+14.2%', AppTheme.success), // Mock ROI for now
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatMetric('Total Picks', totalPicks.toString(), Colors.white),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildStatMetric('Avg Odds', '1.85', Colors.white), // Mock odds for now
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatMetric(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentPicksList(List<model.Match> matches) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        final bool won = _didPredictionWin(match);
        final bool isLive = match.status == model.MatchStatus.live;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLive 
                      ? Colors.orange.withValues(alpha: 0.15)
                      : (won ? AppTheme.success : AppTheme.secondary).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isLive 
                      ? Icons.access_time_rounded 
                      : (won ? Icons.check_circle : Icons.cancel),
                  color: isLive 
                      ? Colors.orange 
                      : (won ? AppTheme.success : AppTheme.secondary),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${match.homeTeam} vs ${match.awayTeam}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'AI: ${match.prediction.recommendation}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLive ? (match.statusShort ?? 'LIVE') : 'FT',
                          style: TextStyle(
                            color: isLive ? Colors.orange : AppTheme.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Score: ${match.homeScore ?? 0} - ${match.awayScore ?? 0}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

