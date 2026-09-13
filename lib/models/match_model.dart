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
    final homeName = json['homeTeam'] ?? '';
    final awayName = json['awayTeam'] ?? '';
    final leagueName = json['league'] ?? '';
    final h2h = json['h2hSummary'];

    if (standingsData != null) {
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

    final hOdds = json['homeOdds'] != null ? (json['homeOdds'] as num).toDouble() : null;
    final dOdds = json['drawOdds'] != null ? (json['drawOdds'] as num).toDouble() : null;
    final aOdds = json['awayOdds'] != null ? (json['awayOdds'] as num).toDouble() : null;
    final rating = json['oddsRating'] is int ? json['oddsRating'] : int.tryParse(json['oddsRating']?.toString() ?? '0');

    // Always recompute prediction locally using current strategy engine
    AIPrediction pred;
    if (json['prediction'] != null) {
      try {
        pred = AIPrediction.generateLocal(
          homeName,
          awayName,
          hForm,
          aForm,
          h2h,
          homeRank: hRank,
          homePts: hPts,
          awayRank: aRank,
          awayPts: aPts,
          realHomeOdds: hOdds,
          realDrawOdds: dOdds,
          realAwayOdds: aOdds,
          league: leagueName,
          oddsRating: rating,
        );
      } catch (_) {
        pred = AIPrediction.fromJson(json['prediction']);
      }
    } else {
      pred = AIPrediction.generateLocal(
        homeName,
        awayName,
        hForm,
        aForm,
        h2h,
        homeRank: hRank,
        homePts: hPts,
        awayRank: aRank,
        awayPts: aPts,
        realHomeOdds: hOdds,
        realDrawOdds: dOdds,
        realAwayOdds: aOdds,
        league: leagueName,
        oddsRating: rating,
      );
    }

    return Match(
      id: json['id'],
      homeTeam: homeName,
      awayTeam: awayName,
      homeLogo: json['homeLogo'] ?? '',
      awayLogo: json['awayLogo'] ?? '',
      league: leagueName,
      date: DateTime.parse(json['date']),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MatchStatus.notStarted,
      ),
      homeScore: json['homeScore'],
      awayScore: json['awayScore'],
      prediction: pred,
      homeRank: hRank,
      homePoints: hPts,
      homeForm: hForm,
      awayRank: aRank,
      awayPoints: aPts,
      awayForm: aForm,
      h2hSummary: h2h,
      elapsed: json['elapsed'],
      statusShort: json['statusShort'],
      homeOdds: hOdds,
      drawOdds: dOdds,
      awayOdds: aOdds,
      oddsRating: rating,
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

  factory AIPrediction.generateLocal(String homeTeam, String awayTeam, String? homeForm, String? awayForm, String? h2hSummary, {int? homeRank, int? homePts, int? awayRank, int? awayPts, double? realHomeOdds, double? realDrawOdds, double? realAwayOdds, String league = '', int? oddsRating}) {
    double hWin = 33.0;
    double dProb = 34.0;
    double aWin = 33.0;
    
    // If real odds are provided, convert them to implied probabilities
    if (realHomeOdds != null && realDrawOdds != null && realAwayOdds != null) {
      final hImplied = 100.0 / realHomeOdds;
      final dImplied = 100.0 / realDrawOdds;
      final aImplied = 100.0 / realAwayOdds;
      
      final totalImplied = hImplied + dImplied + aImplied;
      
      hWin = (hImplied / totalImplied) * 100;
      dProb = (dImplied / totalImplied) * 100;
      aWin = (aImplied / totalImplied) * 100;
    } else if (oddsRating != null && oddsRating != 0) {
      final r = oddsRating;
      if (r <= -15) { hWin = 70.0; dProb = 18.0; aWin = 12.0; }
      else if (r <= -10) { hWin = 60.0; dProb = 23.0; aWin = 17.0; }
      else if (r < 0) { hWin = 52.0; dProb = 28.0; aWin = 20.0; }
      else if (r >= 15) { hWin = 12.0; dProb = 18.0; aWin = 70.0; }
      else if (r >= 10) { hWin = 17.0; dProb = 23.0; aWin = 60.0; }
      else if (r > 0) { hWin = 20.0; dProb = 28.0; aWin = 52.0; }
    } else {
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

    int hWins = 0;
    int aWins = 0;
    if (h2hSummary != null) {
      final cleanH2H = h2hSummary.replaceAll(RegExp(r'\s*\([\d\-,\s]+\)'), '');
      final wonMatches = RegExp(r'([A-Za-z0-9\s\.\-]+?)\s+(?:won|holds)\s+(?:the\s+advantage|(\d+))', caseSensitive: false).allMatches(cleanH2H);
      for (final m in wonMatches) {
        final tName = (m.group(1) ?? '').trim().toLowerCase();
        final count = int.tryParse(m.group(2) ?? '3') ?? 3;
        if (tName.contains(homeTeam.toLowerCase()) || homeTeam.toLowerCase().contains(tName)) {
          hWins += count;
        } else if (tName.contains(awayTeam.toLowerCase()) || awayTeam.toLowerCase().contains(tName)) {
          aWins += count;
        }
      }
    }

    final isUCL = league.toLowerCase().contains('champions league') || league.toLowerCase().contains('ucl');
    final hasOdds = realHomeOdds != null && realAwayOdds != null && realHomeOdds > 0 && realAwayOdds > 0;
    final oddsDiff = hasOdds ? (realHomeOdds - realAwayOdds) : 0.0;
    final isEvenOdds = hasOdds ? (oddsDiff.abs() <= 0.15) : (hWins == aWins && hWins > 0);
    final isHomeFavorite = hasOdds ? (realHomeOdds <= 1.50) : (hWins > aWins + 1);
    final isHomeUnderdog = hasOdds ? (realHomeOdds >= realAwayOdds + 1.50) : (aWins > hWins || (aWin > hWin && !isEvenOdds));

    String rec = '';
    String strategyAnalysis = '';
    String primarySafeOption = '';

    double finalHWin = hWin;
    double finalDProb = dProb;
    double finalAWin = aWin;

    if (isUCL) {
      final isLeg1 = league.toLowerCase().contains('leg 1') || league.toLowerCase().contains('1st leg');
      if (isLeg1) {
        rec = '$homeTeam or Draw (1X)';
        primarySafeOption = 'Safe: 1X ($homeTeam or Draw)';
        strategyAnalysis = 'UCL Knockout Leg 1: Stalemate protection active ($rec).';
        finalDProb = 35.0; finalHWin = 45.0; finalAWin = 20.0;
      } else {
        rec = '$homeTeam or $awayTeam (Home or Away Win - 12)';
        primarySafeOption = 'Safe: 12 ($homeTeam or $awayTeam Win)';
        strategyAnalysis = 'UCL Group Stage / Leg 2: Forced attacking scenario active (12).';
        finalDProb = 10.0; finalHWin = 48.0; finalAWin = 42.0;
      }
    } else if (isEvenOdds) {
      if (hWins > aWins) {
        rec = '$homeTeam or Draw (1X)';
        primarySafeOption = 'Safe: 1X ($homeTeam or Draw)';
        strategyAnalysis = 'Even Odds Fixture: H2H favors home team ($hWins vs $aWins wins). Output 1X.';
        finalHWin = 52.0; finalDProb = 28.0; finalAWin = 20.0;
      } else if (aWins > hWins) {
        rec = '$awayTeam or Draw (X2)';
        primarySafeOption = 'Safe: X2 ($awayTeam or Draw)';
        strategyAnalysis = 'Even Odds Fixture: H2H favors away team ($aWins vs $hWins wins). Output X2.';
        finalHWin = 20.0; finalDProb = 28.0; finalAWin = 52.0;
      } else {
        rec = '$homeTeam or $awayTeam (Home or Away Win - 12)';
        primarySafeOption = 'Safe: 12 ($homeTeam or $awayTeam Win)';
        strategyAnalysis = 'Even Odds Fixture: H2H is a dead tie. Output 12 (Force a decisive outcome).';
        finalHWin = 45.0; finalDProb = 10.0; finalAWin = 45.0;
      }
    } else if (isHomeFavorite) {
      rec = '$homeTeam or Draw & Over 1.5 Goals (1X + Over 1.5)';
      primarySafeOption = 'Safe: 1X + Over 1.5 Goals ($homeTeam or Draw & Over 1.5 Goals)';
      strategyAnalysis = 'Home Favorite (Odds <= 1.50): Compound market 1X + Over 1.5 Goals executed to preserve multiplier value.';
      finalHWin = 70.0; finalDProb = 20.0; finalAWin = 10.0;
    } else if (isHomeUnderdog) {
      final isVolatileLeague = league.toLowerCase().contains('mls') || league.toLowerCase().contains('bundesliga');
      if (isVolatileLeague) {
        rec = '$homeTeam or $awayTeam (Home or Away Win - 12)';
        primarySafeOption = 'Safe: 12 ($homeTeam or $awayTeam Win)';
        strategyAnalysis = 'Home Underdog Exception: Volatile league historical draw rate < 20%. Output 12 to capture volatility.';
        finalHWin = 42.0; finalDProb = 10.0; finalAWin = 48.0;
      } else {
        rec = '$awayTeam or Draw (X2)';
        primarySafeOption = 'Safe: X2 ($awayTeam or Draw)';
        strategyAnalysis = 'Away Favored / Home Underdog: H2H/Odds favor $awayTeam. Output X2.';
        finalHWin = 11.0; finalDProb = 11.0; finalAWin = 78.0;
      }
    } else {
      if (hWins > aWins || hWin > aWin) {
        rec = '$homeTeam or Draw (1X)';
        primarySafeOption = 'Safe: 1X ($homeTeam or Draw)';
        strategyAnalysis = 'Standard Market: Home team favored by odds probability.';
        finalHWin = 55.0; finalDProb = 27.0; finalAWin = 18.0;
      } else if (aWins > hWins || aWin > hWin) {
        rec = '$awayTeam or Draw (X2)';
        primarySafeOption = 'Safe: X2 ($awayTeam or Draw)';
        strategyAnalysis = 'Standard Market: Away team favored by H2H / odds probability.';
        finalHWin = 11.0; finalDProb = 11.0; finalAWin = 78.0;
      } else {
        rec = '$homeTeam or $awayTeam (Home or Away Win - 12)';
        primarySafeOption = 'Safe: 12 ($homeTeam or $awayTeam Win)';
        strategyAnalysis = 'Standard Market: Balanced match, outputting double chance 12.';
        finalHWin = 45.0; finalDProb = 10.0; finalAWin = 45.0;
      }
    }

    final String fav = finalHWin >= finalAWin ? homeTeam : awayTeam;
    final double? favOdds = finalHWin >= finalAWin ? realHomeOdds : realAwayOdds;
    final double dnbOdds = favOdds != null ? (favOdds * 0.82).clamp(1.30, 9.99) : 1.70;

    List<String> stakingOptions = [
      primarySafeOption,
      'Value: $fav Draw No Bet (${dnbOdds.toStringAsFixed(2)})',
      'Risky: $fav to WIN by 2+ Goals (2.85)',
      'BTTS: Both Teams To Score - Yes (1.78)',
      'Goals: Over 1.5 Total Goals (1.34)'
    ];

    return AIPrediction(
      homeWinProbability: finalHWin,
      drawProbability: finalDProb,
      awayWinProbability: finalAWin,
      recommendation: rec,
      analysis: strategyAnalysis,
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
