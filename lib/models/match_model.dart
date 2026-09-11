class Match {
  final String id;
  final String homeTeam;
  final String awayTeam;
  final String homeLogo;
  final String awayLogo;
  final String league;
  final DateTime date;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final AIPrediction prediction;
  
  // Standings data
  final int? homeRank;
  final int? homePoints;
  final String? homeForm;
  final int? awayRank;
  final int? awayPoints;
  final String? awayForm;
  final String? h2hSummary;
  final int? elapsed;       // Minutes played, e.g. 67
  final String? statusShort; // e.g. "1H", "HT", "2H", "FT"
  
  final double? homeOdds;
  final double? drawOdds;
  final double? awayOdds;
  
  // Scraped data
  final int? oddsRating;
  final String? matchUrl;
  final TeamLineupData? homeLineup;
  final TeamLineupData? awayLineup;

  Match({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.league,
    required this.date,
    required this.status,
    this.homeScore,
    this.awayScore,
    required this.prediction,
    this.homeRank,
    this.homePoints,
    this.homeForm,
    this.awayRank,
    this.awayPoints,
    this.awayForm,
    this.h2hSummary,
    this.elapsed,
    this.statusShort,
    this.homeOdds,
    this.drawOdds,
    this.awayOdds,
    this.oddsRating,
    this.matchUrl,
    this.homeLineup,
    this.awayLineup,
  });

  factory Match.fromJson(Map<String, dynamic> json, [Map<String, dynamic>? standingsData]) {
    int? hRank = json['homeRank'];
    int? hPts = json['homePoints'];
    String? hForm = json['homeForm'];
    int? aRank = json['awayRank'];
    int? aPts = json['awayPoints'];
    String? aForm = json['awayForm'];

    if (standingsData != null) {
      final homeName = json['homeTeam'];
      final awayName = json['awayTeam'];
      
      if (standingsData.containsKey(homeName)) {
         final s = standingsData[homeName];
         hRank ??= s['rank'];
         hPts ??= s['points'];
         hForm ??= s['form'];
      }
      if (standingsData.containsKey(awayName)) {
         final s = standingsData[awayName];
         aRank ??= s['rank'];
         aPts ??= s['points'];
         aForm ??= s['form'];
      }
    }

    return Match(
      id: json['id'],
      homeTeam: json['homeTeam'],
      awayTeam: json['awayTeam'],
      homeLogo: json['homeLogo'],
      awayLogo: json['awayLogo'],
      league: json['league'],
      date: DateTime.parse(json['date']),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MatchStatus.notStarted,
      ),
      homeScore: json['homeScore'],
      awayScore: json['awayScore'],
      prediction: AIPrediction.fromJson(json['prediction']),
      homeRank: hRank,
      homePoints: hPts,
      homeForm: hForm,
      awayRank: aRank,
      awayPoints: aPts,
      awayForm: aForm,
      h2hSummary: json['h2hSummary'],
      elapsed: json['elapsed'],
      statusShort: json['statusShort'],
      homeOdds: json['homeOdds'] != null ? (json['homeOdds'] as num).toDouble() : null,
      drawOdds: json['drawOdds'] != null ? (json['drawOdds'] as num).toDouble() : null,
      awayOdds: json['awayOdds'] != null ? (json['awayOdds'] as num).toDouble() : null,
      oddsRating: json['oddsRating'],
      matchUrl: json['matchUrl'],
      homeLineup: json['homeLineup'] != null ? TeamLineupData.fromJson(json['homeLineup']) : null,
      awayLineup: json['awayLineup'] != null ? TeamLineupData.fromJson(json['awayLineup']) : null,
    );
  }
}

class PlayerLineup {
  final String number;
  final String name;
  final String position; // GK, DF, MF, ST
  final int rating;
  final String? stats;

  const PlayerLineup({
    required this.number,
    required this.name,
    required this.position,
    required this.rating,
    this.stats,
  });

  factory PlayerLineup.fromJson(Map<String, dynamic> json) {
    return PlayerLineup(
      number: json['number']?.toString() ?? '',
      name: json['name'] ?? '',
      position: json['position'] ?? 'MF',
      rating: json['rating'] is int ? json['rating'] : int.tryParse(json['rating']?.toString() ?? '0') ?? 0,
      stats: json['stats']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'name': name,
    'position': position,
    'rating': rating,
    'stats': stats,
  };
}

class TeamLineupData {
  final int? avgRating;
  final List<PlayerLineup> startingXI;
  final List<PlayerLineup> bench;

  const TeamLineupData({
    this.avgRating,
    required this.startingXI,
    required this.bench,
  });

  factory TeamLineupData.fromJson(Map<String, dynamic> json) {
    return TeamLineupData(
      avgRating: json['avgRating'] is int ? json['avgRating'] : int.tryParse(json['avgRating']?.toString() ?? ''),
      startingXI: (json['startingXI'] as List<dynamic>?)
              ?.map((e) => PlayerLineup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      bench: (json['bench'] as List<dynamic>?)
              ?.map((e) => PlayerLineup.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'avgRating': avgRating,
    'startingXI': startingXI.map((e) => e.toJson()).toList(),
    'bench': bench.map((e) => e.toJson()).toList(),
  };
}

enum MatchStatus { notStarted, live, finished }

/// Represents a single previous match result for a team.
class RecentMatch {
  final String opponent;
  final int goalsFor;
  final int goalsAgainst;
  final String result; // 'W', 'L', or 'D'
  final bool isHome;

  const RecentMatch({
    required this.opponent,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.result,
    required this.isHome,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> json) {
    return RecentMatch(
      opponent: json['opponent'],
      goalsFor: json['goalsFor'],
      goalsAgainst: json['goalsAgainst'],
      result: json['result'],
      isHome: json['isHome'] ?? true,
    );
  }
}

class AIPrediction {
  final double homeWinProbability;
  final double drawProbability;
  final double awayWinProbability;
  final String recommendation;
  final String analysis;
  final List<String> stakingOptions;

  AIPrediction({
    required this.homeWinProbability,
    required this.drawProbability,
    required this.awayWinProbability,
    required this.recommendation,
    required this.analysis,
    required this.stakingOptions,
  });

  factory AIPrediction.fromJson(Map<String, dynamic> json) {
    return AIPrediction(
      homeWinProbability: (json['homeWinProbability'] as num).toDouble(),
      drawProbability: (json['drawProbability'] as num).toDouble(),
      awayWinProbability: (json['awayWinProbability'] as num).toDouble(),
      recommendation: json['recommendation'],
      analysis: json['analysis'],
      stakingOptions: List<String>.from(json['stakingOptions']),
    );
  }

  factory AIPrediction.generateLocal(String homeTeam, String awayTeam, String? homeForm, String? awayForm, String? h2hSummary, {int? homeRank, int? homePts, int? awayRank, int? awayPts, double? realHomeOdds, double? realDrawOdds, double? realAwayOdds}) {
    double hWin = 33.0;
    double dProb = 34.0;
    double aWin = 33.0;
    
    // If real odds are provided, convert them to implied probabilities
    if (realHomeOdds != null && realDrawOdds != null && realAwayOdds != null) {
      final hImplied = 100.0 / realHomeOdds;
      final dImplied = 100.0 / realDrawOdds;
      final aImplied = 100.0 / realAwayOdds;
      
      // Normalize to 100% (remove bookmaker overround)
      final totalImplied = hImplied + dImplied + aImplied;
      
      hWin = (hImplied / totalImplied) * 100;
      dProb = (dImplied / totalImplied) * 100;
      aWin = (aImplied / totalImplied) * 100;
    } else {
      // Fallback form-based calculation if no odds available
      int hScore = 0;
      if (homeForm != null) {
        hScore += homeForm.split('W').length - 1;
      }
      int aScore = 0;
      if (awayForm != null) {
        aScore += awayForm.split('W').length - 1;
      }
      
      if (hScore > aScore) {
         hWin = 55.0; dProb = 25.0; aWin = 20.0;
      } else if (aScore > hScore) {
         hWin = 20.0; dProb = 25.0; aWin = 55.0;
      } else {
         hWin = 40.0; dProb = 30.0; aWin = 30.0;
      }
    }

    String rec = hWin > aWin ? '$homeTeam to WIN' : (aWin > hWin ? '$awayTeam to WIN' : 'Draw');
    
    List<String> stakingOptions = [
      'Safe: ${hWin > aWin ? '1X (Home or Draw)' : 'X2 (Away or Draw)'} (1.30)',
      'Value: ${hWin > aWin ? '$homeTeam Draw No Bet' : '$awayTeam Draw No Bet'} (1.80)',
      'Risky: Exact Score 2-1 (9.00)',
      'BTTS: Both Teams To Score - Yes (1.75)',
      '1st Half: Over 0.5 Goals (1.40)'
    ];

    String analysisText = 'Our AI model heavily weights recent form and league standing. '
        '${homeForm != null && awayForm != null
            ? '$homeTeam comes in with a $homeForm form (${homePts ?? '?'} pts, Rank #${homeRank ?? '?'}), '
              'while $awayTeam holds a $awayForm form (${awayPts ?? '?'} pts, Rank #${awayRank ?? '?'}). '
            : 'Factoring in historical data and standard home advantages, '}'
        'Current probability modeling suggests a ${hWin.round()}% chance of a home victory.';

    return AIPrediction(
      homeWinProbability: hWin,
      drawProbability: dProb,
      awayWinProbability: aWin,
      recommendation: rec,
      analysis: analysisText,
      stakingOptions: stakingOptions,
    );
  }
}

class MockData {
  static List<Match> getMatches() {
    final now = DateTime.now();
    return [
      Match(
        id: '1',
        homeTeam: 'Arsenal',
        awayTeam: 'Chelsea',
        homeLogo: 'ARS',
        awayLogo: 'CHE',
        league: 'Premier League',
        date: now.add(const Duration(hours: 2)),
        status: MatchStatus.notStarted,
        homeRank: 2,
        homePoints: 58,
        homeForm: 'WWWWL',
        awayRank: 6,
        awayPoints: 41,
        awayForm: 'LWDLL',
        h2hSummary: 'Arsenal won 3 of last 5 meetings.',
        homeOdds: 1.65,
        drawOdds: 4.00,
        awayOdds: 5.50,
        prediction: AIPrediction.generateLocal('Arsenal', 'Chelsea', 'WWWWL', 'LWDLL', 'Arsenal won 3 of last 5 meetings.', homeRank: 2, homePts: 58, awayRank: 6, awayPts: 41, realHomeOdds: 1.65, realDrawOdds: 4.00, realAwayOdds: 5.50),
      ),
      Match(
        id: '2',
        homeTeam: 'Real Madrid',
        awayTeam: 'Barcelona',
        homeLogo: 'RMA',
        awayLogo: 'FCB',
        league: 'La Liga',
        date: now.subtract(const Duration(minutes: 45)),
        status: MatchStatus.live,
        homeScore: 1,
        awayScore: 1,
        homeRank: 1,
        homePoints: 72,
        homeForm: 'WWWWW',
        awayRank: 2,
        awayPoints: 69,
        awayForm: 'WWWWW',
        h2hSummary: 'Real Madrid won 2, Barcelona won 2, 1 Draw.',
        homeOdds: 2.20,
        drawOdds: 3.50,
        awayOdds: 3.10,
        prediction: AIPrediction.generateLocal('Real Madrid', 'Barcelona', 'WWWDW', 'WWDWW', 'Even split in last 5 (2W-1D-2L each).', homeRank: 1, homePts: 72, awayRank: 2, awayPts: 69, realHomeOdds: 2.10, realDrawOdds: 3.50, realAwayOdds: 3.20),
      ),
      Match(
        id: '3',
        homeTeam: 'Bayern Munich',
        awayTeam: 'Dortmund',
        homeLogo: 'BAY',
        awayLogo: 'BVB',
        league: 'Bundesliga',
        date: now.add(const Duration(days: 1)),
        status: MatchStatus.notStarted,
        homeRank: 1,
        homePoints: 64,
        homeForm: 'WWWLD',
        awayRank: 4,
        awayPoints: 48,
        awayForm: 'LLWWD',
        h2hSummary: 'Bayern Munich dominated last 5 (4 Wins).',
        homeOdds: 1.45,
        drawOdds: 4.50,
        awayOdds: 6.50,
        prediction: AIPrediction.generateLocal('Bayern Munich', 'Dortmund', 'WWWLD', 'LLWWD', 'Bayern Munich dominated last 5 (4 Wins).', homeRank: 1, homePts: 64, awayRank: 4, awayPts: 48, realHomeOdds: 1.45, realDrawOdds: 4.50, realAwayOdds: 6.50),
      ),
    ];
  }

  /// Returns last 5 recent matches for a given team name (mock data).
  static List<RecentMatch> getRecentMatches(String teamName) {
    final data = <String, List<RecentMatch>>{
      'Arsenal': [
        const RecentMatch(opponent: 'Man City', goalsFor: 2, goalsAgainst: 0, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Tottenham', goalsFor: 3, goalsAgainst: 1, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Liverpool', goalsFor: 1, goalsAgainst: 1, result: 'D', isHome: true),
        const RecentMatch(opponent: 'Aston Villa', goalsFor: 2, goalsAgainst: 1, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Man United', goalsFor: 0, goalsAgainst: 1, result: 'L', isHome: true),
      ],
      'Chelsea': [
        const RecentMatch(opponent: 'Newcastle', goalsFor: 1, goalsAgainst: 2, result: 'L', isHome: false),
        const RecentMatch(opponent: 'West Ham', goalsFor: 0, goalsAgainst: 1, result: 'L', isHome: true),
        const RecentMatch(opponent: 'Brighton', goalsFor: 1, goalsAgainst: 1, result: 'D', isHome: false),
        const RecentMatch(opponent: 'Wolves', goalsFor: 0, goalsAgainst: 2, result: 'L', isHome: true),
        const RecentMatch(opponent: 'Brentford', goalsFor: 0, goalsAgainst: 1, result: 'L', isHome: false),
      ],
      'Real Madrid': [
        const RecentMatch(opponent: 'Atletico Madrid', goalsFor: 3, goalsAgainst: 1, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Sevilla', goalsFor: 2, goalsAgainst: 0, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Villarreal', goalsFor: 4, goalsAgainst: 1, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Betis', goalsFor: 2, goalsAgainst: 0, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Valencia', goalsFor: 3, goalsAgainst: 2, result: 'W', isHome: true),
      ],
      'Barcelona': [
        const RecentMatch(opponent: 'Atletico Madrid', goalsFor: 2, goalsAgainst: 1, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Girona', goalsFor: 3, goalsAgainst: 0, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Osasuna', goalsFor: 2, goalsAgainst: 1, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Celta Vigo', goalsFor: 4, goalsAgainst: 2, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Getafe', goalsFor: 1, goalsAgainst: 0, result: 'W', isHome: false),
      ],
      'Bayern Munich': [
        const RecentMatch(opponent: 'Leipzig', goalsFor: 3, goalsAgainst: 0, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Leverkusen', goalsFor: 2, goalsAgainst: 2, result: 'D', isHome: false),
        const RecentMatch(opponent: 'Frankfurt', goalsFor: 4, goalsAgainst: 1, result: 'W', isHome: true),
        const RecentMatch(opponent: 'Stuttgart', goalsFor: 1, goalsAgainst: 2, result: 'L', isHome: false),
        const RecentMatch(opponent: 'Wolfsburg', goalsFor: 3, goalsAgainst: 0, result: 'W', isHome: true),
      ],
      'Dortmund': [
        const RecentMatch(opponent: 'Leipzig', goalsFor: 0, goalsAgainst: 2, result: 'L', isHome: false),
        const RecentMatch(opponent: 'Mainz', goalsFor: 0, goalsAgainst: 1, result: 'L', isHome: true),
        const RecentMatch(opponent: 'Frankfurt', goalsFor: 2, goalsAgainst: 1, result: 'W', isHome: false),
        const RecentMatch(opponent: 'Leverkusen', goalsFor: 1, goalsAgainst: 1, result: 'D', isHome: true),
        const RecentMatch(opponent: 'Cologne', goalsFor: 2, goalsAgainst: 0, result: 'W', isHome: false),
      ],
    };
    return data[teamName] ?? [];
  }
}
