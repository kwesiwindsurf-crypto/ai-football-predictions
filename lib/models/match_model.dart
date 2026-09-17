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
  final List<String>? homeLineup;
  final List<String>? awayLineup;

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
      homeLineup: _parseLineupList(json['homeLineup']),
      awayLineup: _parseLineupList(json['awayLineup']),
    );
  }

  static List<String>? _parseLineupList(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is Map) {
      final list = raw['players'] ?? raw['roster'] ?? raw['lineup'];
      if (list is List) {
        return list.map((e) => e.toString()).toList();
      }
    }
    return null;
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
    final rawXI = json['startingXI'];
    final rawBench = json['bench'];
    return TeamLineupData(
      avgRating: json['avgRating'] is int ? json['avgRating'] : int.tryParse(json['avgRating']?.toString() ?? ''),
      startingXI: (rawXI is List)
              ? rawXI.whereType<Map>().map((e) => PlayerLineup.fromJson(Map<String, dynamic>.from(e))).toList()
              : [],
      bench: (rawBench is List)
              ? rawBench.whereType<Map>().map((e) => PlayerLineup.fromJson(Map<String, dynamic>.from(e))).toList()
              : [],
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
      opponent: json['opponent']?.toString() ?? '',
      goalsFor: (json['goalsFor'] as num?)?.toInt() ?? 0,
      goalsAgainst: (json['goalsAgainst'] as num?)?.toInt() ?? 0,
      result: json['result']?.toString() ?? 'D',
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
    final rawStaking = json['stakingOptions'];
    List<String> staking = [];
    if (rawStaking is List) {
      staking = rawStaking.map((e) => e.toString()).toList();
    }
    return AIPrediction(
      homeWinProbability: (json['homeWinProbability'] as num?)?.toDouble() ?? 33.3,
      drawProbability: (json['drawProbability'] as num?)?.toDouble() ?? 33.3,
      awayWinProbability: (json['awayWinProbability'] as num?)?.toDouble() ?? 33.3,
      recommendation: json['recommendation']?.toString() ?? '',
      analysis: json['analysis']?.toString() ?? '',
      stakingOptions: staking,
    );
  }

  static bool _isBigGame(String home, String away) {
    const bigTeams = [
  'manchester city',
  'arsenal',
  'liverpool',
  'chelsea',
  'manchester united',
  'tottenham hotspur',
  'newcastle united',
  'aston villa',
  'brighton & hove albion',
  'west ham united',
  'leeds united',
  'leicester city',
  'southampton',
  'burnley',
  'sheffield united',
  'west bromwich albion',
  'norwich city',
  'middlesbrough',
  'sunderland',
  'coventry city',
  'watford',
  'hull city',
  'birmingham city',
  'wrexham',
  'charlton athletic',
  'huddersfield town',
  'bolton wanderers',
  'reading',
  'peterborough united',
  'barnsley',
  'blackpool',
  'wycombe wanderers',
  'rotherham united',
  'bradford city',
  'chesterfield',
  'mk dons',
  'notts county',
  'doncaster rovers',
  'gillingham',
  'port vale',
  'carlisle united',
  'walsall',
  'afc wimbledon',
  'tranmere rovers',
  'real madrid',
  'fc barcelona',
  'atlético madrid',
  'athletic club',
  'real sociedad',
  'villarreal',
  'real betis',
  'sevilla',
  'girona',
  'real zaragoza',
  'sporting gijón',
  'levante',
  'real oviedo',
  'deportivo la coruña',
  'elche',
  'granada',
  'cádiz',
  'racing santander',
  'cd tenerife',
  'sd eibar',
  'albacete balompié',
  'mallorca',
  'osasuna',
  'inter milan',
  'juventus',
  'ac milan',
  'napoli',
  'as roma',
  'atalanta',
  'ss lazio',
  'fiorentina',
  'bologna',
  'sampdoria',
  'palermo',
  'sassuolo',
  'frosinone',
  'salernitana',
  'cremonese',
  'spezia',
  'bari',
  'brescia',
  'modena',
  'cesena',
  'pisa',
  'bayern munich',
  'bayer leverkusen',
  'borussia dortmund',
  'rb leipzig',
  'vfb stuttgart',
  'eintracht frankfurt',
  'vfl wolfsburg',
  'sc freiburg',
  'borussia mönchengladbach',
  'hamburger sv',
  'fc schalke 04',
  '1. fc köln',
  'hertha bsc',
  'fortuna düsseldorf',
  'hannover 96',
  '1. fc nürnberg',
  '1. fc kaiserslautern',
  'karlsruher sc',
  'sv darmstadt 98',
  'sc paderborn',
  'paris saint-germain',
  'as monaco',
  'olympique de marseille',
  'olympique lyonnais',
  'losc lille',
  'ogc nice',
  'rc lens',
  'stade rennais',
  'stade brestois',
  'fc metz',
  'fc lorient',
  'sm caen',
  'paris fc',
  'ea guingamp',
  'troyes',
  'ac ajaccio',
  'clermont foot',
  'amiens sc',
  'grenoble foot',
  'fc nantes',
  'toulouse fc',
  'ajax',
  'psv eindhoven',
  'feyenoord',
  'az alkmaar',
  'fc twente',
  'fc utrecht',
  'sl benfica',
  'fc porto',
  'sporting cp',
  'sc braga',
  'vitória de guimarães',
  'fc famalicão',
  'galatasaray',
  'fenerbahçe',
  'beşiktaş',
  'trabzonspor',
  'i̇stanbul başakşehir',
  'samsunspor',
  'adana demirspor',
  'antalyaspor',
  'club brugge',
  'rsc anderlecht',
  'royale union saint-gilloise',
  'krc genk',
  'royal antwerp',
  'kaa gent',
  'standard liège',
  'cercle brugge',
  'celtic',
  'rangers',
  'aberdeen',
  'heart of midlothian',
  'hibernian',
  'kilmarnock',
  'olympiacos',
  'panathinaikos',
  'aek athens',
  'paok thessaloniki',
  'aris thessaloniki',
  'atromitos',
  'ofi crete',
  'zenit saint petersburg',
  'spartak moscow',
  'cska moscow',
  'fc krasnodar',
  'dynamo moscow',
  'lokomotiv moscow',
  'fc rostov',
  'rubin kazan',
  'shakhtar donetsk',
  'dynamo kyiv',
  'kryvbas kryvyi rih',
  'polissya zhytomyr',
  'zorya luhansk',
  'karpaty lviv',
  'red bull salzburg',
  'sk sturm graz',
  'lask',
  'sk rapid wien',
  'fk austria wien',
  'wolfsberger ac',
  'bsc young boys',
  'fc basel',
  'fc zürich',
  'servette fc',
  'fc lugano',
  'fc st. gallen',
  'fc luzern',
  'fc copenhagen',
  'fc midtjylland',
  'brøndby if',
  'fc nordsjælland',
  'agf aarhus',
  'silkeborg if',
  'fk bodø/glimt',
  'molde fk',
  'rosenborg bk',
  'sk brann',
  'viking fk',
  'lillestrøm sk',
  'malmö ff',
  'aik',
  'djurgårdens if',
  'ifk göteborg',
  'bk häcken',
  'if elfsborg',
  'hammarby if',
  'ifk norrköping',
  'legia warsaw',
  'lech poznań',
  'raków częstochowa',
  'jagiellonia białystok',
  'pogoń szczecin',
  'górnik zabrze',
  'śląsk wrocław',
  'cracovia',
  'slavia prague',
  'sparta prague',
  'fc viktoria plzeň',
  'baník ostrava',
  'fk mladá boleslav',
  'fc slovan liberec',
  'sigma olomouc',
  'inter miami cf',
  'columbus crew',
  'los angeles fc',
  'lafc',
  'la galaxy',
  'seattle sounders fc',
  'fc cincinnati',
  'philadelphia union',
  'atlanta united',
  'new york red bulls',
  'new york city fc',
  'houston dynamo',
  'club américa',
  'cruz azul',
  'chivas guadalajara',
  'tigres uanl',
  'cf monterrey',
  'deportivo toluca',
  'cf pachuca',
  'pumas unam',
  'club león',
  'santos laguna',
  'flamengo',
  'palmeiras',
  'atlético mineiro',
  'botafogo',
  'são paulo fc',
  'fluminense',
  'internacional',
  'grêmio',
  'corinthians',
  'cruzeiro',
  'athletico paranaense',
  'fortaleza',
  'bahia',
  'river plate',
  'boca juniors',
  'racing club',
  'independiente',
  'san lorenzo',
  'estudiantes de la plata',
  'vélez sarsfield',
  'rosario central',
  'talleres de córdoba',
  'colo-colo',
  'universidad de chile',
  'universidad católica',
  'unión española',
  'palestino',
  'everton de viña del mar',
  'cobresal',
  'cobreloa',
  'atlético nacional',
  'millonarios fc',
  'américa de cali',
  'junior fc',
  'independiente santa fe',
  'independiente medellín',
  'deportivo cali',
  'deportes tolima',
  'al hilal',
  'al nassr',
  'al ittihad',
  'al ahli',
  'al shabab',
  'al ettifaq',
  'al taawoun',
  'al fateh',
  'mamelodi sundowns',
  'orlando pirates',
  'kaizer chiefs',
  'stellenbosch fc',
  'supersport united',
  'sekhukhune united',
  'cape town city fc',
  'peñarol',
  'nacional',
  'independiente del valle',
  'olimpia',
  'cerro porteño',
  'lanús',
  'defensa y justicia',
  'red bull bragantino',
  'belgrano',
  'ldu quito'
];
    final h = home.toLowerCase();
    final a = away.toLowerCase();
    return bigTeams.any((t) => h.contains(t)) && bigTeams.any((t) => a.contains(t));
  }

  static double _parseForm(String? formStr) {
    if (formStr == null || formStr.isEmpty) return 50.0;
    final clean = formStr.toUpperCase().replaceAll(RegExp(r'[^WDL]'), '');
    if (clean.isEmpty) return 50.0;
    
    int pts = 0;
    for (int i = 0; i < clean.length; i++) {
      if (clean[i] == 'W') {
        pts += 3;
      } else if (clean[i] == 'D') {
        pts += 1;
      }
    }
    return (pts / (clean.length * 3)) * 100.0;
  }

  factory AIPrediction.generateLocal(String homeTeam, String awayTeam, String? homeForm, String? awayForm, String? h2hSummary, {int? homeRank, int? homePts, int? awayRank, int? awayPts, double? realHomeOdds, double? realDrawOdds, double? realAwayOdds, String league = '', int? oddsRating}) {
    final bool hasOdds = realHomeOdds != null && realAwayOdds != null && realHomeOdds > 0 && realAwayOdds > 0;
    
    double oddsHp = 45.0, oddsDp = 25.0, oddsAp = 30.0;
    if (hasOdds) {
      final rawH = 1.0 / realHomeOdds;
      final rawD = realDrawOdds != null ? 1.0 / realDrawOdds : (1.0 - rawH - (1.0 / realAwayOdds) > 0 ? 1.0 - rawH - (1.0 / realAwayOdds) : 0.25);
      final rawA = 1.0 / realAwayOdds;
      final total = rawH + rawD + rawA;
      oddsHp = (rawH / total) * 100;
      oddsDp = (rawD / total) * 100;
      oddsAp = (rawA / total) * 100;
    }
    
    final double hForm = _parseForm(homeForm);
    final double aForm = _parseForm(awayForm);
    double formHp = 38.0, formDp = 24.0, formAp = 38.0;
    if (hForm != 50.0 || aForm != 50.0) {
      final totalF = hForm + aForm;
      if (totalF > 0) {
        formHp = (hForm / totalF) * 100;
        formAp = (aForm / totalF) * 100;
        final gap = (formHp - formAp).abs();
        formDp = 30.0 - gap;
        if (formDp < 5.0) formDp = 5.0;
        final fTotal = formHp + formAp + formDp;
        formHp = (formHp / fTotal) * 100;
        formAp = (formAp / fTotal) * 100;
        formDp = (formDp / fTotal) * 100;
      }
    }

    int hWins = 0, aWins = 0, draws = 0;
    bool hasH2H = false;
    double h2hHp = 0.0, h2hDp = 0.0, h2hAp = 0.0;
    
    if (h2hSummary != null && h2hSummary.isNotEmpty) {
      final cleanH2H = h2hSummary.replaceAll(RegExp(r'\s*\([\d\-,\s]+\)'), '');
      final wonMatches = RegExp(r'([A-Za-z0-9\s\.\-]+?)\s+won\s+(\d+)', caseSensitive: false).allMatches(cleanH2H);
      for (final m in wonMatches) {
        final tName = (m.group(1) ?? '').trim().toLowerCase();
        final count = int.tryParse(m.group(2) ?? '0') ?? 0;
        final hClean = homeTeam.toLowerCase();
        final aClean = awayTeam.toLowerCase();
        if (tName.contains(hClean) || hClean.contains(tName)) {
          hWins += count;
        } else if (tName.contains(aClean) || aClean.contains(tName)) {
          aWins += count;
        }
      }
      final drawMatch = RegExp(r'(\d+)\s+Draw', caseSensitive: false).firstMatch(cleanH2H);
      if (drawMatch != null) {
        draws = int.tryParse(drawMatch.group(1) ?? '0') ?? 0;
      }
      
      final total = hWins + aWins + draws;
      if (total > 0) {
        hasH2H = true;
        h2hHp = (hWins / total) * 100;
        h2hDp = (draws / total) * 100;
        h2hAp = (aWins / total) * 100;
      }
    }
    
    
    
    final wOdds = hasH2H ? 0.40 : 0.50;
    final wForm = hasH2H ? 0.30 : 0.40;
    final wH2H  = hasH2H ? 0.20 : 0.00;
    final wHome = 0.10;
    
    const double homeAdvHp = 60.0, homeAdvDp = 20.0, homeAdvAp = 20.0;
    
    double fHp = (oddsHp * wOdds) + (formHp * wForm) + (h2hHp * wH2H) + (homeAdvHp * wHome);
    double fDp = (oddsDp * wOdds) + (formDp * wForm) + (h2hDp * wH2H) + (homeAdvDp * wHome);
    double fAp = (oddsAp * wOdds) + (formAp * wForm) + (h2hAp * wH2H) + (homeAdvAp * wHome);
    
    final fTotal = fHp + fDp + fAp;
    fHp = (fHp / fTotal) * 100;
    fDp = (fDp / fTotal) * 100;
    fAp = (fAp / fTotal) * 100;
    
    final isBig = _isBigGame(homeTeam, awayTeam);
    final maxProb = [fHp, fDp, fAp].reduce((a, b) => a > b ? a : b);
    final isHomeFav = fHp > fAp || ((fHp - fAp).abs() <= 3.0 && hForm >= aForm);
    final fav = isHomeFav ? homeTeam : awayTeam;
    final favOdds = isHomeFav ? realHomeOdds : realAwayOdds;

    final formGap = (hForm - aForm).abs();
    final isFormFav = formGap >= 25 || hForm >= 60 || aForm >= 60;
    final formFav = hForm >= aForm ? homeTeam : awayTeam;
    final isHomeFormFav = hForm >= aForm;
    
    String rec = '';
    String strategyAnalysis = '';
    String primarySafe = '';
    
    if (maxProb >= 60) {
      if (fHp >= 60) {
        rec = '$homeTeam to Win (1)';
        primarySafe = 'Safe: 1X ($homeTeam or Draw)';
      } else {
        rec = '$awayTeam to Win (2)';
        primarySafe = 'Safe: X2 ($awayTeam or Draw)';
      }
      strategyAnalysis = 'Clear Favorite (Prob >= 60%): Direct Win.';
    } else if (isBig) {
      rec = '$fav or Draw (Double Chance)';
      primarySafe = 'Safe: ${isHomeFav ? '1X' : 'X2'} ($fav or Draw)';
      strategyAnalysis = 'Big Game + Tight Match: Double Chance / Over 1.5 Goals.';
    } else if (maxProb >= 55) {
      rec = '$fav or Draw (Double Chance)';
      primarySafe = 'Safe: ${isHomeFav ? '1X' : 'X2'} ($fav or Draw)';
      strategyAnalysis = 'Moderate Favorite (Prob 55-59%): Double Chance.';
    } else {
      rec = 'Over 0.5 Goals or Under 2.5 Goals';
      primarySafe = 'Safe: Over 0.5 Goals';
      strategyAnalysis = 'Not Big Teams & Tight: Goals Market (Under 2.5 / Over 0.5).';
    }
    
    final dnbOdds = favOdds != null ? (favOdds * 0.82).clamp(1.30, 9.99) : 1.70;
    final stakingOptions = [
      primarySafe,
      'Value: $fav Draw No Bet (${dnbOdds.toStringAsFixed(2)})',
      (isBig && maxProb < 55) ? 'Goals: Over 1.5 Total Goals (1.30)' : 'Risky: $fav to WIN by 2+ Goals (2.85)',
      'BTTS: Both Teams To Score - Yes (1.78)',
      maxProb < 45 ? 'Alternative: Under 2.5 Goals (1.80)' : 'Alternative: Over 2.5 Total Goals (1.70)'
    ];

    return AIPrediction(
      homeWinProbability: fHp.roundToDouble(),
      drawProbability: fDp.roundToDouble(),
      awayWinProbability: fAp.roundToDouble(),
      recommendation: rec,
      analysis: '$strategyAnalysis\nHomeForm: ${hForm.round()}%, AwayForm: ${aForm.round()}%, BigGame: $isBig',
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
        homeLineup: ['Raya (GK)', 'White (DF)', 'Saliba (DF)', 'Gabriel (DF)', 'Zinchenko (DF)', 'Rice (MF)', 'Odegaard (MF)', 'Partey (MF)', 'Saka (FW)', 'Havertz (FW)', 'Martinelli (FW)'],
        awayLineup: ['Petrovic (GK)', 'Gusto (DF)', 'Disasi (DF)', 'Badiashile (DF)', 'Cucurella (DF)', 'Caicedo (MF)', 'Fernandez (MF)', 'Gallagher (MF)', 'Palmer (FW)', 'Jackson (FW)', 'Sterling (FW)'],
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
