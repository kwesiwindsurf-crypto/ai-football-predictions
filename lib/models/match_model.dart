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
  final List<String>? homeScorers;
  final List<String>? awayScorers;
  final List<MatchEvent>? events;
  final String? referee;
  final MatchStats? stats;
  final String? venue;
  final int? attendance;
  final String? seriesSummary;

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
    this.homeScorers,
    this.awayScorers,
    this.events,
    this.referee,
    this.stats,
    this.venue,
    this.attendance,
    this.seriesSummary,
  });

  /// Returns true if this match has been postponed, cancelled, or suspended.
  bool get isPostponed =>
      status == MatchStatus.postponed ||
      status == MatchStatus.cancelled ||
      statusShort?.toUpperCase() == 'PT' ||
      (statusShort?.toLowerCase().contains('postp') ?? false) ||
      (statusShort?.toLowerCase().contains('ppd') ?? false) ||
      (statusShort?.toLowerCase().contains('canc') ?? false) ||
      (statusShort?.toLowerCase().contains('susp') ?? false);

  /// True when a cached snapshot still marks this match as live, but kickoff
  /// is old enough that the game must have ended by now.
  ///
  /// A football match is over within ~3 hours of kickoff (90' + half-time +
  /// stoppage, or extra time + penalties). Anything older than that in the
  /// on-disk cache is a leftover from a previous session and must never be
  /// resurrected as LIVE on cold start.
  bool get isStaleLive {
    if (status != MatchStatus.live) return false;
    return DateTime.now().difference(date.toLocal()) > const Duration(hours: 3);
  }

  /// Returns a copy demoted from live to finished, keeping the last known score.
  /// Used to sanitize stale live entries loaded from the disk cache.
  Match markedFinished() {
    if (status != MatchStatus.live) return this;
    return Match(
      id: id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeLogo: homeLogo,
      awayLogo: awayLogo,
      league: league,
      date: date,
      status: MatchStatus.finished,
      homeScore: homeScore,
      awayScore: awayScore,
      prediction: prediction,
      homeRank: homeRank,
      homePoints: homePoints,
      homeForm: homeForm,
      awayRank: awayRank,
      awayPoints: awayPoints,
      awayForm: awayForm,
      h2hSummary: h2hSummary,
      elapsed: null,
      statusShort: 'FT',
      homeOdds: homeOdds,
      drawOdds: drawOdds,
      awayOdds: awayOdds,
      oddsRating: oddsRating,
      matchUrl: matchUrl,
      homeScorers: homeScorers,
      awayScorers: awayScorers,
      events: events,
      referee: referee,
      stats: stats,
      venue: venue,
      attendance: attendance,
      seriesSummary: seriesSummary,
    );
  }

  /// Canonical identifier key based on alphanumeric team names (case & punctuation insensitive).
  /// Guarantees that matches match across ESPN event IDs, Cloudflare date slugs, and Render deltas.
  String get normalizedTeamsKey {
    final h = homeTeam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final a = awayTeam.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$h-$a';
  }

  /// Merges live telemetry deltas (scores, clock, status, events, scorers, stats)
  /// from the lightweight Render /live endpoint while preserving the static AI prediction,
  /// H2H, and odds loaded from Cloudflare KV.
  Match mergeLiveDelta(Match delta) {
    final isDeltaPostponed = delta.isPostponed;
    return Match(
      id: id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeLogo: homeLogo.isNotEmpty ? homeLogo : delta.homeLogo,
      awayLogo: awayLogo.isNotEmpty ? awayLogo : delta.awayLogo,
      league: league.isNotEmpty ? league : delta.league,
      date: date,
      status: delta.status,
      homeScore: isDeltaPostponed ? null : (delta.homeScore ?? homeScore),
      awayScore: isDeltaPostponed ? null : (delta.awayScore ?? awayScore),
      prediction: delta.prediction.isServerPrediction
          ? delta.prediction
          : prediction,
      homeRank: homeRank,
      homePoints: homePoints,
      homeForm: homeForm,
      awayRank: awayRank,
      awayPoints: awayPoints,
      awayForm: awayForm,
      h2hSummary: h2hSummary,
      elapsed: isDeltaPostponed ? null : (delta.elapsed ?? elapsed),
      statusShort: delta.statusShort ?? statusShort,
      homeOdds: homeOdds,
      drawOdds: drawOdds,
      awayOdds: awayOdds,
      oddsRating: oddsRating,
      matchUrl: matchUrl ?? delta.matchUrl,
      homeScorers: delta.homeScorers ?? homeScorers,
      awayScorers: delta.awayScorers ?? awayScorers,
      events: delta.events ?? events,
      referee: delta.referee ?? referee,
      stats: delta.stats ?? stats,
      venue: delta.venue ?? venue,
      attendance: delta.attendance ?? attendance,
      seriesSummary: delta.seriesSummary ?? seriesSummary,
    );
  }

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

    // Use the prediction provided by the backend, or fallback to local generation if missing.
    AIPrediction pred;
    if (json['prediction'] != null) {
      pred = AIPrediction.fromJson(json['prediction']);
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

    final rawStatus = json['status']?.toString();
    final rawShort = (json['statusShort']?.toString() ?? '').toLowerCase();
    MatchStatus parsedStatus;
    if (rawStatus == 'postponed' ||
        rawStatus == 'cancelled' ||
        rawShort == 'pt' ||
        rawShort.contains('postp') ||
        rawShort.contains('ppd') ||
        rawShort.contains('canc') ||
        rawShort.contains('susp')) {
      parsedStatus = MatchStatus.postponed;
    } else {
      parsedStatus = MatchStatus.values.firstWhere(
        (e) => e.name == rawStatus,
        orElse: () => MatchStatus.notStarted,
      );
    }

    final isPostponedGame = parsedStatus == MatchStatus.postponed ||
        parsedStatus == MatchStatus.cancelled;
    final int? parsedHomeScore = isPostponedGame ? null : (json['homeScore'] as num?)?.toInt();
    final int? parsedAwayScore = isPostponedGame ? null : (json['awayScore'] as num?)?.toInt();

    return Match(
      id: json['id'],
      homeTeam: homeName,
      awayTeam: awayName,
      homeLogo: json['homeLogo'] ?? '',
      awayLogo: json['awayLogo'] ?? '',
      league: leagueName,
      date: DateTime.parse(json['date']),
      status: parsedStatus,
      homeScore: parsedHomeScore,
      awayScore: parsedAwayScore,
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
      homeScorers: json['homeScorers'] is List ? List<String>.from(json['homeScorers']) : null,
      awayScorers: json['awayScorers'] is List ? List<String>.from(json['awayScorers']) : null,
      events: json['events'] is List
          ? (json['events'] as List)
              .map((e) => MatchEvent.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : null,
      referee: json['referee']?.toString(),
      stats: json['stats'] is Map ? MatchStats.fromJson(Map<String, dynamic>.from(json['stats'])) : null,
      venue: json['venue']?.toString(),
      attendance: (json['attendance'] as num?)?.toInt(),
      seriesSummary: json['seriesSummary']?.toString(),
    );
  }
}

enum MatchStatus { notStarted, live, finished, postponed, cancelled }

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
  final bool isServerPrediction;

  AIPrediction({
    required this.homeWinProbability,
    required this.drawProbability,
    required this.awayWinProbability,
    required this.recommendation,
    required this.analysis,
    required this.stakingOptions,
    this.isServerPrediction = true,
  });

  double get confidence {
    double maxP = homeWinProbability > awayWinProbability ? homeWinProbability : awayWinProbability;
    return maxP > drawProbability ? maxP : drawProbability;
  }

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
      isServerPrediction: true,
    );
  }

  static bool _isEliteGame(String home, String away) {
    const eliteTeams = [
      'manchester city',
      'arsenal',
      'liverpool',
      'chelsea',
      'manchester united',
      'tottenham hotspur',
      'real madrid',
      'fc barcelona',
      'atlético madrid',
      'inter milan',
      'juventus',
      'ac milan',
      'napoli',
      'bayern munich',
      'borussia dortmund',
      'bayer leverkusen',
      'paris saint-germain',
    ];
    final h = home.toLowerCase();
    final a = away.toLowerCase();
    return eliteTeams.any((t) => h.contains(t)) && eliteTeams.any((t) => a.contains(t));
  }

  static bool _isMajorGame(String home, String away) {
    const majorTeams = [
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
    return majorTeams.any((t) => h.contains(t)) && majorTeams.any((t) => a.contains(t));
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
    } else {
      // No market price: mirror the backend's season-rates proxy instead of a
      // fixed 45/25/30 guess. Strength blends season points with last-5 form,
      // and draws are likelier when the two sides are evenly matched.
      double strength(int? pts, String? form) {
        final p = (pts ?? 0).clamp(0, 90) / 90.0;
        return (p * 0.7) + ((_parseForm(form) / 100.0) * 0.3);
      }

      double drawRateOf(String? form) {
        if (form == null) return 1 / 3;
        final chars =
            form.toUpperCase().replaceAll(RegExp(r'[^WDL]'), '').split('');
        if (chars.isEmpty) return 1 / 3;
        return chars.where((c) => c == 'D').length / chars.length;
      }

      final hStr = (strength(homePts, homeForm) + 0.02) * 1.10;
      final aStr = (strength(awayPts, awayForm) + 0.02) * 0.92;
      final total = hStr + aStr;
      final homeShare = total > 0 ? hStr / total : 0.5;
      final hi = hStr > aStr ? hStr : aStr;
      final gap = (hStr - aStr).abs() / (hi > 0.01 ? hi : 0.01);
      final drawRate = (((drawRateOf(homeForm) + drawRateOf(awayForm)) / 2) *
              (1 - (gap * 0.6)))
          .clamp(0.14, 0.34);
      oddsHp = homeShare * (1 - drawRate) * 100;
      oddsDp = drawRate * 100;
      oddsAp = (1 - homeShare) * (1 - drawRate) * 100;
    }
    
    final double hForm = _parseForm(homeForm);
    final double aForm = _parseForm(awayForm);
    double formHp = 38.0, formDp = 24.0, formAp = 38.0;
    if (hForm != 50.0 || aForm != 50.0) {
      final denom = hForm + aForm + 50.0;
      final rawH = ((hForm + 25.0) / denom) * 100.0;
      final rawA = ((aForm + 25.0) / denom) * 100.0;
      final gap = (rawH - rawA).abs();
      formDp = (30.0 - gap * 0.25).clamp(16.0, 30.0);
      final winPool = 100.0 - formDp;
      formHp = (rawH / 100.0) * winPool;
      formAp = (rawA / 100.0) * winPool;
    }

    int hWins = 0, aWins = 0, draws = 0;
    bool hasH2H = false;
    double h2hHp = 0.0, h2hDp = 0.0, h2hAp = 0.0;
    
    if (h2hSummary != null && h2hSummary.isNotEmpty) {
      // Literal club name: a character class drops accents and mis-credits the fragment.
      int winsFor(String team) {
        final hit = RegExp('${RegExp.escape(team)}\\s+won\\s+(\\d+)', caseSensitive: false).firstMatch(h2hSummary);
        return hit == null ? 0 : int.tryParse(hit.group(1) ?? '0') ?? 0;
      }

      hWins = winsFor(homeTeam);
      aWins = winsFor(awayTeam);
      final drawMatch = RegExp(r'(\d+)\s+Draws?\b', caseSensitive: false).firstMatch(h2hSummary);
      if (drawMatch != null) {
        draws = int.tryParse(drawMatch.group(1) ?? '0') ?? 0;
      }

      final totalMatch = RegExp(r'of last (\d+) meetings?', caseSensitive: false).firstMatch(h2hSummary);
      final total = totalMatch == null ? hWins + aWins + draws : (int.tryParse(totalMatch.group(1) ?? '0') ?? 0);
      if (total > 0) {
        hasH2H = true;
        h2hHp = (hWins / total) * 100;
        h2hDp = (draws / total) * 100;
        h2hAp = (aWins / total) * 100;
      }
    }

    const double wHome = 0.05;
    final double wOdds = hasOdds ? (hasH2H ? 0.65 : 0.75) : (hasH2H ? 0.45 : 0.60);
    final double wForm = hasOdds ? (hasH2H ? 0.15 : 0.20) : (hasH2H ? 0.25 : 0.35);
    final double wH2H  = hasOdds ? (hasH2H ? 0.15 : 0.00) : (hasH2H ? 0.25 : 0.00);
    
    const double homeAdvHp = 60.0, homeAdvDp = 20.0, homeAdvAp = 20.0;
    
    double fHp = (oddsHp * wOdds) + (formHp * wForm) + (h2hHp * wH2H) + (homeAdvHp * wHome);
    double fDp = (oddsDp * wOdds) + (formDp * wForm) + (h2hDp * wH2H) + (homeAdvDp * wHome);
    double fAp = (oddsAp * wOdds) + (formAp * wForm) + (h2hAp * wH2H) + (homeAdvAp * wHome);
    
    final fTotal = fHp + fDp + fAp;
    fHp = (fHp / fTotal) * 100;
    fDp = (fDp / fTotal) * 100;
    fAp = (fAp / fTotal) * 100;
    
    final isElite = _isEliteGame(homeTeam, awayTeam);
    final isMajor = _isMajorGame(homeTeam, awayTeam);
    final lStr = league.toLowerCase();
    final isLowerLeague = lStr.contains('championship') ||
        lStr.contains('league one') ||
        lStr.contains('league two') ||
        lStr.contains('national league') ||
        lStr.contains('segunda') ||
        lStr.contains('serie b') ||
        lStr.contains('2. bundesliga') ||
        lStr.contains('ligue 2') ||
        lStr.contains('keuken') ||
        lStr.contains('eerste divisie');

    final maxProb = [fHp, fDp, fAp].reduce((a, b) => a > b ? a : b);
    final isHomeFav = fHp > fAp || ((fHp - fAp).abs() <= 3.0 && hForm >= aForm);
    final fav = isHomeFav ? homeTeam : awayTeam;
    final favOdds = isHomeFav ? realHomeOdds : realAwayOdds;
    final prob1X = fHp + fDp;
    final probX2 = fAp + fDp;

    String rec = '';
    String strategyAnalysis = '';
    String primarySafe = '';
    final isFriendly = lStr.contains('friendly') || lStr.contains('friendlies');
    final isMajorTopLeague = lStr.contains('premier league') ||
        (lStr.contains('la liga') && !lStr.contains('2')) ||
        (lStr.contains('serie a') && !lStr.contains('brazil')) ||
        (lStr.contains('bundesliga') && !lStr.contains('2.')) ||
        lStr.contains('ligue 1') ||
        lStr.contains('champions league') ||
        lStr.contains('europa');

    if (isFriendly) {
      rec = 'Over 1.5 Goals';
      primarySafe = 'Safe: Over 1.5 Goals';
      strategyAnalysis = 'Club Friendly: Goals Market (Over 1.5).';
    } else if (!hasOdds && !isMajorTopLeague && !isElite) {
      rec = 'Over 1.5 Goals';
      primarySafe = 'Safe: Over 1.5 Goals';
      strategyAnalysis = 'No-Odds Fixture: Avoids cross-tier form guesses (Over 1.5).';
    } else if (isLowerLeague) {
      if (fHp >= 74 || (realHomeOdds != null && realHomeOdds <= 1.35)) {
        rec = '$homeTeam to Win (1)';
        primarySafe = 'Safe: 1X ($homeTeam or Draw)';
        strategyAnalysis = 'Lower League Heavy Mismatch: Direct Win.';
      } else if (fAp >= 70 || (realAwayOdds != null && realAwayOdds <= 1.38)) {
        rec = '$awayTeam to Win (2)';
        primarySafe = 'Safe: X2 ($awayTeam or Draw)';
        strategyAnalysis = 'Lower League Heavy Mismatch: Direct Win.';
      } else if (isHomeFav && prob1X >= 64) {
        rec = '1X ($homeTeam or Draw)';
        primarySafe = 'Safe: 1X ($homeTeam or Draw)';
        strategyAnalysis = 'Lower League Strategy: Home Double Chance Shield.';
      } else if (!isHomeFav && probX2 >= 64) {
        rec = 'X2 ($awayTeam or Draw)';
        primarySafe = 'Safe: X2 ($awayTeam or Draw)';
        strategyAnalysis = 'Lower League Strategy: Away Double Chance Shield.';
      } else {
        rec = 'Over 1.5 Goals';
        primarySafe = 'Safe: Over 1.5 Goals';
        strategyAnalysis = 'Lower League Goals Market: Tight matchup (Over 1.5).';
      }
    } else if (maxProb >= 62) {
      if (fHp >= 62) {
        rec = '$homeTeam to Win (1)';
        primarySafe = 'Safe: 1X ($homeTeam or Draw)';
      } else {
        rec = '$awayTeam to Win (2)';
        primarySafe = 'Safe: X2 ($awayTeam or Draw)';
      }
      strategyAnalysis = 'Clear Favorite (Prob >= 62%): Direct Win.';
    } else if (isElite) {
      rec = 'Over 1.5 Goals';
      primarySafe = 'Safe: Over 1.5 Goals';
      strategyAnalysis = 'Elite Big Game: High-likelihood goals market (Over 1.5).';
    } else if ((isHomeFav && prob1X >= 64) || (!isHomeFav && probX2 >= 64) || maxProb >= 55) {
      final dcCode = isHomeFav ? '1X' : 'X2';
      rec = '$dcCode ($fav or Draw)';
      primarySafe = 'Safe: $dcCode ($fav or Draw)';
      strategyAnalysis = 'Moderate Favorite: Double Chance Shield.';
    } else if (isMajor) {
      rec = 'Over 1.5 Goals';
      primarySafe = 'Safe: Over 1.5 Goals';
      strategyAnalysis = 'Big Game + Tight Match: Expecting goals (Over 1.5).';
    } else {
      rec = 'Over 1.5 Goals';
      primarySafe = 'Safe: Over 1.5 Goals';
      strategyAnalysis = 'Not Big Teams & Tight: Goals Market (Over 1.5).';
    }

    if (hasH2H && (rec.contains('to Win (1)') || rec.contains('to Win (2)'))) {
      final h2hEven = (h2hHp - h2hAp).abs() <= 20;
      final h2hDrawHeavy = h2hDp >= 35;
      if (h2hEven || h2hDrawHeavy) {
        final pickingHome = rec.contains('to Win (1)');
        final extremeOdds = hasOdds &&
            (pickingHome ? realHomeOdds <= 1.38 : realAwayOdds <= 1.38);
        if (!extremeOdds) {
          if (pickingHome && prob1X >= 64) {
            rec = '1X ($homeTeam or Draw)';
            primarySafe = 'Safe: 1X ($homeTeam or Draw)';
          } else if (!pickingHome && probX2 >= 64) {
            rec = 'X2 ($awayTeam or Draw)';
            primarySafe = 'Safe: X2 ($awayTeam or Draw)';
          } else {
            rec = 'Over 1.5 Goals';
            primarySafe = 'Safe: Over 1.5 Goals';
          }
          strategyAnalysis = 'H2H Balance Guard: Evenly matched past meetings.';
        }
      }
    }

    // Only quote a price when the market gave us one — never invent 1.70.
    final dnbOdds = favOdds != null ? (favOdds * 0.82).clamp(1.30, 9.99) : null;
    final stakingOptions = [
      primarySafe,
      dnbOdds != null
          ? 'Value: $fav Draw No Bet (${dnbOdds.toStringAsFixed(2)})'
          : 'Value: $fav Draw No Bet',
      (isElite && maxProb < 55) ? 'Goals: Over 1.5 Total Goals' : 'Risky: $fav to WIN by 2+ Goals',
      'BTTS: Both Teams To Score - Yes',
      maxProb < 45 ? 'Alternative: Under 2.5 Goals' : 'Alternative: Over 2.5 Total Goals'
    ];

    return AIPrediction(
      homeWinProbability: fHp.roundToDouble(),
      drawProbability: fDp.roundToDouble(),
      awayWinProbability: fAp.roundToDouble(),
      recommendation: rec,
      analysis: '$strategyAnalysis\nHomeForm: ${hForm.round()}%, AwayForm: ${aForm.round()}%, BigGame: ${isElite || isMajor}',
      stakingOptions: stakingOptions,
      isServerPrediction: false,
    );
  }
}



class MatchEvent {
  final String type;
  final String clock;
  final String team; // 'home' or 'away'
  final String player;
  final bool scoringPlay;
  final bool redCard;
  final bool yellowCard;
  final bool penalty;
  final bool ownGoal;

  MatchEvent({
    required this.type,
    required this.clock,
    required this.team,
    required this.player,
    this.scoringPlay = false,
    this.redCard = false,
    this.yellowCard = false,
    this.penalty = false,
    this.ownGoal = false,
  });

  factory MatchEvent.fromJson(Map<String, dynamic> json) {
    return MatchEvent(
      type: json['type']?.toString() ?? '',
      clock: json['clock']?.toString() ?? '',
      team: json['team']?.toString() ?? 'home',
      player: json['player']?.toString() ?? '',
      scoringPlay: json['scoringPlay'] == true,
      redCard: json['redCard'] == true,
      yellowCard: json['yellowCard'] == true,
      penalty: json['penalty'] == true,
      ownGoal: json['ownGoal'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'clock': clock,
    'team': team,
    'player': player,
    'scoringPlay': scoringPlay,
    'redCard': redCard,
    'yellowCard': yellowCard,
    'penalty': penalty,
    'ownGoal': ownGoal,
  };
}

/// Real-time in-game telemetry statistics (possession, shots, corners, fouls, passes, tackles)
class MatchStats {
  final double possessionHome;
  final double possessionAway;
  final int shotsHome;
  final int shotsAway;
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final int cornersHome;
  final int cornersAway;
  final int foulsHome;
  final int foulsAway;
  final int yellowCardsHome;
  final int yellowCardsAway;
  final int redCardsHome;
  final int redCardsAway;
  final int savesHome;
  final int savesAway;
  final int offsidesHome;
  final int offsidesAway;
  final int accuratePassesHome;
  final int accuratePassesAway;
  final int totalPassesHome;
  final int totalPassesAway;
  final int passAccuracyHome;
  final int passAccuracyAway;
  final int tacklesHome;
  final int tacklesAway;
  final int interceptionsHome;
  final int interceptionsAway;

  const MatchStats({
    this.possessionHome = 50.0,
    this.possessionAway = 50.0,
    this.shotsHome = 0,
    this.shotsAway = 0,
    this.shotsOnTargetHome = 0,
    this.shotsOnTargetAway = 0,
    this.cornersHome = 0,
    this.cornersAway = 0,
    this.foulsHome = 0,
    this.foulsAway = 0,
    this.yellowCardsHome = 0,
    this.yellowCardsAway = 0,
    this.redCardsHome = 0,
    this.redCardsAway = 0,
    this.savesHome = 0,
    this.savesAway = 0,
    this.offsidesHome = 0,
    this.offsidesAway = 0,
    this.accuratePassesHome = 0,
    this.accuratePassesAway = 0,
    this.totalPassesHome = 0,
    this.totalPassesAway = 0,
    this.passAccuracyHome = 0,
    this.passAccuracyAway = 0,
    this.tacklesHome = 0,
    this.tacklesAway = 0,
    this.interceptionsHome = 0,
    this.interceptionsAway = 0,
  });

  factory MatchStats.fromJson(Map<String, dynamic> json) {
    return MatchStats(
      possessionHome: (json['possessionHome'] as num?)?.toDouble() ?? 50.0,
      possessionAway: (json['possessionAway'] as num?)?.toDouble() ?? 50.0,
      shotsHome: (json['shotsHome'] as num?)?.toInt() ?? 0,
      shotsAway: (json['shotsAway'] as num?)?.toInt() ?? 0,
      shotsOnTargetHome: (json['shotsOnTargetHome'] as num?)?.toInt() ?? 0,
      shotsOnTargetAway: (json['shotsOnTargetAway'] as num?)?.toInt() ?? 0,
      cornersHome: (json['cornersHome'] as num?)?.toInt() ?? 0,
      cornersAway: (json['cornersAway'] as num?)?.toInt() ?? 0,
      foulsHome: (json['foulsHome'] as num?)?.toInt() ?? 0,
      foulsAway: (json['foulsAway'] as num?)?.toInt() ?? 0,
      yellowCardsHome: (json['yellowCardsHome'] as num?)?.toInt() ?? 0,
      yellowCardsAway: (json['yellowCardsAway'] as num?)?.toInt() ?? 0,
      redCardsHome: (json['redCardsHome'] as num?)?.toInt() ?? 0,
      redCardsAway: (json['redCardsAway'] as num?)?.toInt() ?? 0,
      savesHome: (json['savesHome'] as num?)?.toInt() ?? 0,
      savesAway: (json['savesAway'] as num?)?.toInt() ?? 0,
      offsidesHome: (json['offsidesHome'] as num?)?.toInt() ?? 0,
      offsidesAway: (json['offsidesAway'] as num?)?.toInt() ?? 0,
      accuratePassesHome: (json['accuratePassesHome'] as num?)?.toInt() ?? 0,
      accuratePassesAway: (json['accuratePassesAway'] as num?)?.toInt() ?? 0,
      totalPassesHome: (json['totalPassesHome'] as num?)?.toInt() ?? 0,
      totalPassesAway: (json['totalPassesAway'] as num?)?.toInt() ?? 0,
      passAccuracyHome: (json['passAccuracyHome'] as num?)?.toInt() ?? 0,
      passAccuracyAway: (json['passAccuracyAway'] as num?)?.toInt() ?? 0,
      tacklesHome: (json['tacklesHome'] as num?)?.toInt() ?? 0,
      tacklesAway: (json['tacklesAway'] as num?)?.toInt() ?? 0,
      interceptionsHome: (json['interceptionsHome'] as num?)?.toInt() ?? 0,
      interceptionsAway: (json['interceptionsAway'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'possessionHome': possessionHome,
    'possessionAway': possessionAway,
    'shotsHome': shotsHome,
    'shotsAway': shotsAway,
    'shotsOnTargetHome': shotsOnTargetHome,
    'shotsOnTargetAway': shotsOnTargetAway,
    'cornersHome': cornersHome,
    'cornersAway': cornersAway,
    'foulsHome': foulsHome,
    'foulsAway': foulsAway,
    'yellowCardsHome': yellowCardsHome,
    'yellowCardsAway': yellowCardsAway,
    'redCardsHome': redCardsHome,
    'redCardsAway': redCardsAway,
    'savesHome': savesHome,
    'savesAway': savesAway,
    'offsidesHome': offsidesHome,
    'offsidesAway': offsidesAway,
    'accuratePassesHome': accuratePassesHome,
    'accuratePassesAway': accuratePassesAway,
    'totalPassesHome': totalPassesHome,
    'totalPassesAway': totalPassesAway,
    'passAccuracyHome': passAccuracyHome,
    'passAccuracyAway': passAccuracyAway,
    'tacklesHome': tacklesHome,
    'tacklesAway': tacklesAway,
    'interceptionsHome': interceptionsHome,
    'interceptionsAway': interceptionsAway,
  };
}

