import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/match_model.dart' as model;
import '../../../../core/theme/app_theme.dart';
import '../../../../models/match_model.dart' show MockData;

class MatchDetailsScreen extends StatelessWidget {
  final model.Match match;

  const MatchDetailsScreen({super.key, required this.match});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildMatchHeader(context),
            const SizedBox(height: 24),
            _buildTeamFormAndStandings(context),
            const SizedBox(height: 24),
            _buildRecentMatchesSection(context),
            const SizedBox(height: 24),
            _buildTacticalLineupsSection(context),
            const SizedBox(height: 24),
            _buildAIPredictionCard(context),
            const SizedBox(height: 24),
            _buildAIAnalysisText(context),
            const SizedBox(height: 24),
            _buildStakingOptions(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchHeader(BuildContext context) {
    return Column(
      children: [
        Text(
          match.league,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildTeam(match.homeTeam, match.homeLogo),
            if (match.status == model.MatchStatus.notStarted)
              const Text('VS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
            else
              Text('${match.homeScore} - ${match.awayScore}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            _buildTeam(match.awayTeam, match.awayLogo),
          ],
        ),
      ],
    );
  }

  Widget _buildTeam(String name, String logoUrl) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.1),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ],
          ),
          child: CircleAvatar(
            backgroundColor: Colors.transparent,
            radius: 35,
            child: logoUrl.startsWith('http')
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: logoUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.contain,
                      errorWidget: (context, url, error) => const Icon(Icons.sports_soccer, size: 28, color: AppTheme.primary),
                      placeholder: (context, url) => const SizedBox(width: 50, height: 50),
                    ),
                  )
                : Text(logoUrl, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 100,
          child: Text(
            name, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamFormAndStandings(BuildContext context) {
    if (match.homeRank == null && match.awayRank == null && match.h2hSummary == null) {
       return const SizedBox.shrink(); // No standings data available
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.leaderboard, color: AppTheme.secondary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'League Standings & Form',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (match.homeRank != null || match.homeForm != null) ...[
            _buildTeamFormRow(match.homeTeam, match.homeRank, match.homePoints, match.homeForm),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
          ],
          if (match.awayRank != null || match.awayForm != null)
            _buildTeamFormRow(match.awayTeam, match.awayRank, match.awayPoints, match.awayForm),
          if (match.h2hSummary != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.history, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Head-to-Head',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              match.h2hSummary!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamFormRow(String teamName, int? rank, int? points, String? form) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            rank != null ? '#$rank' : '-',
            style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Text(
            teamName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          points != null ? '$points pts' : '',
          style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(width: 12),
        if (form != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: form.split('').map((char) {
              Color color = AppTheme.textSecondary;
              if (char == 'W') color = AppTheme.success;
              if (char == 'L') color = AppTheme.secondary;
              
              return Container(
                margin: const EdgeInsets.only(left: 4),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    char,
                    style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }).toList(),
          )
      ],
    );
  }

  List<model.RecentMatch> _generateMockRecentMatchesFromForm(String form) {
    // Form is usually 5 characters like 'WWDLW' (newest first or last depending on API, assuming standard)
    List<model.RecentMatch> matches = [];
    final chars = form.split('');
    
    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      int gFor = 0;
      int gAgainst = 0;
      
      if (char == 'W') {
        gFor = 2; gAgainst = 0;
      } else if (char == 'L') {
        gFor = 0; gAgainst = 2;
      } else if (char == 'D') {
        gFor = 1; gAgainst = 1;
      }
      
      matches.add(model.RecentMatch(
        opponent: 'Team ${String.fromCharCode(65 + i)}',
        goalsFor: gFor,
        goalsAgainst: gAgainst,
        result: char,
        isHome: i % 2 == 0,
      ));
    }
    
    return matches;
  }

  Widget _buildRecentMatchesSection(BuildContext context) {
    var homeRecent = MockData.getRecentMatches(match.homeTeam);
    var awayRecent = MockData.getRecentMatches(match.awayTeam);

    if (homeRecent.isEmpty && match.homeForm != null) {
      homeRecent = _generateMockRecentMatchesFromForm(match.homeForm!);
    }
    if (awayRecent.isEmpty && match.awayForm != null) {
      awayRecent = _generateMockRecentMatchesFromForm(match.awayForm!);
    }

    if (homeRecent.isEmpty && awayRecent.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_toggle_off, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Last 3 Matches',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Two-column header
          Row(
            children: [
              Expanded(
                child: Text(
                  match.homeTeam,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  match.awayTeam,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppTheme.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // List of last 5 games side by side
          ...List.generate(5, (i) {
            final home = i < homeRecent.length ? homeRecent[i] : null;
            final away = i < awayRecent.length ? awayRecent[i] : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Home team match
                  Expanded(child: home != null ? _buildRecentMatchRow(home, isHomeTeam: true) : const SizedBox()),
                  const SizedBox(width: 8),
                  // Away team match
                  Expanded(child: away != null ? _buildRecentMatchRow(away, isHomeTeam: false) : const SizedBox()),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentMatchRow(model.RecentMatch recent, {required bool isHomeTeam}) {
    Color resultColor;
    switch (recent.result) {
      case 'W':
        resultColor = AppTheme.success;
        break;
      case 'L':
        resultColor = AppTheme.secondary;
        break;
      default:
        resultColor = Colors.orange;
    }

    final scoreText = '${recent.goalsFor}-${recent.goalsAgainst}';
    final venueLabel = recent.isHome ? 'H' : 'A';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: resultColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: resultColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Result badge
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                recent.result,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Opponent & score
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recent.opponent,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$scoreText · $venueLabel',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIPredictionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surface,
            AppTheme.surface.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smart_toy, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'AI Match Prediction',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildUnifiedProbabilityBar(context),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                  child: const Text('AI', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI RECOMMENDATION:',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 10, letterSpacing: 1),
                      ),
                      Text(
                        match.prediction.recommendation,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildUnifiedProbabilityBar(BuildContext context) {
    final home = match.prediction.homeWinProbability;
    final draw = match.prediction.drawProbability;
    final away = match.prediction.awayWinProbability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildProbLabel(match.homeTeam, home, AppTheme.success),
            _buildProbLabel('Draw', draw, AppTheme.textSecondary.withValues(alpha: 0.8)),
            _buildProbLabel(match.awayTeam, away, AppTheme.secondary, isRight: true),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                Expanded(
                  flex: home.round(),
                  child: Container(color: AppTheme.success),
                ),
                Expanded(
                  flex: draw.round(),
                  child: Container(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                ),
                Expanded(
                  flex: away.round(),
                  child: Container(color: AppTheme.secondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProbLabel(String text, double prob, Color color, {bool isRight = false}) {
    return Column(
      crossAxisAlignment: isRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          '${prob.round()}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Analysis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Text(
          match.prediction.analysis,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStakingOptions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.monetization_on, color: AppTheme.success),
            const SizedBox(width: 8),
            Text(
              'Staking Recommendations',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...match.prediction.stakingOptions.map((option) => _buildStakeOptionCard(option)),
      ],
    );
  }

  Widget _buildStakeOptionCard(String optionText) {
    // Basic parsing to color code Safe/Value/Risky
    Color tagColor = AppTheme.primary;
    if (optionText.toLowerCase().contains('safe')) tagColor = AppTheme.success;
    if (optionText.toLowerCase().contains('value')) tagColor = AppTheme.primary;
    if (optionText.toLowerCase().contains('risky')) tagColor = AppTheme.secondary;
    if (optionText.toLowerCase().contains('btts')) tagColor = Colors.orange;
    if (optionText.toLowerCase().contains('1st half')) tagColor = Colors.purpleAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tagColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: tagColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              optionText,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTacticalLineupsSection(BuildContext context) {
    final homeLineup = match.homeLineup;
    final awayLineup = match.awayLineup;

    if ((homeLineup == null || homeLineup.startingXI.isEmpty) &&
        (awayLineup == null || awayLineup.startingXI.isEmpty)) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_soccer_rounded, color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tactical Board & Lineups',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Official rosters announced ~1 hour before kickoff',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppTheme.secondary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Algorithmic AI prediction and odds analysis are ready above. Tactical rosters will unlock automatically once confirmed.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    bool showHome = true;

    return StatefulBuilder(
      builder: (context, setState) {
        final currentLineup = showHome ? homeLineup : awayLineup;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_soccer_rounded, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tactical Board & Lineups',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                  ],
                ),
                if (currentLineup?.avgRating != null && currentLineup!.avgRating! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '∅ ${currentLineup.avgRating} Rating',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Team selector switch
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showHome = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: showHome ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            match.homeTeam,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: showHome ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showHome = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !showHome ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            match.awayTeam,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: !showHome ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tactical Pitch Board
            if (currentLineup != null && currentLineup.startingXI.isNotEmpty) ...[
              _buildPitchBoard(currentLineup.startingXI),
              const SizedBox(height: 16),
            ],

            // Bench section
            if (currentLineup != null && currentLineup.bench.isNotEmpty) ...[
              _buildBenchSection(currentLineup.bench),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPitchBoard(List<model.PlayerLineup> startingXI) {
    final gks = startingXI.where((p) => p.position == 'GK').toList();
    final dfs = startingXI.where((p) => p.position == 'DF').toList();
    final mfs = startingXI.where((p) => p.position == 'MF').toList();
    final fws = startingXI.where((p) => p.position == 'ST' || p.position == 'FW').toList();

    return Container(
      width: double.infinity,
      height: 440,
      decoration: BoxDecoration(
        color: const Color(0xFF1B5E20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PitchPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPlayerRow(fws.isNotEmpty ? fws : startingXI.take(2).toList()),
                  _buildPlayerRow(mfs.isNotEmpty ? mfs : startingXI.skip(2).take(4).toList()),
                  _buildPlayerRow(dfs.isNotEmpty ? dfs : startingXI.skip(6).take(4).toList()),
                  _buildPlayerRow(gks.isNotEmpty ? gks : startingXI.skip(10).take(1).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(List<model.PlayerLineup> players) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: players.map((player) => _buildPlayerNode(player)).toList(),
    );
  }

  Widget _buildPlayerNode(model.PlayerLineup player) {
    Color ratingColor = AppTheme.textSecondary;
    if (player.rating >= 75) {
      ratingColor = const Color(0xFFFFD700);
    } else if (player.rating >= 65) {
      ratingColor = AppTheme.primary;
    } else if (player.rating >= 50) {
      ratingColor = Colors.orangeAccent;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF132A13),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                  )
                ],
              ),
              child: Center(
                child: Text(
                  player.number.isNotEmpty ? '#${player.number}' : player.position,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            if (player.rating > 0)
              Positioned(
                right: -6,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: ratingColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${player.rating}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 3),
        Container(
          constraints: const BoxConstraints(maxWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            player.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          player.position,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBenchSection(List<model.PlayerLineup> bench) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.airline_seat_recline_normal_rounded, color: AppTheme.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Bench / Substitutes (${bench.length})',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...bench.map((player) {
            Color ratingColor = AppTheme.textSecondary;
            if (player.rating >= 75) {
              ratingColor = const Color(0xFFFFD700);
            } else if (player.rating >= 65) {
              ratingColor = AppTheme.primary;
            } else if (player.rating >= 50) {
              ratingColor = Colors.orangeAccent;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Center(
                      child: Text(
                        player.number.isNotEmpty ? '#${player.number}' : '-',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          player.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (player.stats != null && player.stats!.isNotEmpty)
                          Text(
                            'Games/Goals: ${player.stats}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      player.position,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (player.rating > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: ratingColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: ratingColor.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        '${player.rating}',
                        style: TextStyle(
                          color: ratingColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Grass stripes
    final stripePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    const stripeCount = 8;
    final stripeHeight = size.height / stripeCount;
    for (int i = 0; i < stripeCount; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeHeight, size.width, stripeHeight),
        stripePaint,
      );
    }

    // Outer boundary
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Center line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 45, paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;

    // Top Penalty Box (Away goal)
    final boxWidth = size.width * 0.55;
    final boxHeight = 60.0;
    canvas.drawRect(
      Rect.fromLTWH((size.width - boxWidth) / 2, 0, boxWidth, boxHeight),
      paint,
    );
    // Top Goal Box
    final smallBoxWidth = size.width * 0.28;
    canvas.drawRect(
      Rect.fromLTWH((size.width - smallBoxWidth) / 2, 0, smallBoxWidth, 22),
      paint,
    );

    // Bottom Penalty Box (Home goal)
    canvas.drawRect(
      Rect.fromLTWH((size.width - boxWidth) / 2, size.height - boxHeight, boxWidth, boxHeight),
      paint,
    );
    // Bottom Goal Box
    canvas.drawRect(
      Rect.fromLTWH((size.width - smallBoxWidth) / 2, size.height - 22, smallBoxWidth, 22),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
