class ScrapedLeagueInfo {
  final String slug;
  final String name;
  final String country;
  final String flagEmoji;
  final String tier;
  final String logo;

  const ScrapedLeagueInfo({
    required this.slug,
    required this.name,
    required this.country,
    required this.flagEmoji,
    required this.tier,
    required this.logo,
  });
}

class CountryLeagues {
  final String country;
  final String flagEmoji;
  final List<ScrapedLeagueInfo> leagues;

  const CountryLeagues({
    required this.country,
    required this.flagEmoji,
    required this.leagues,
  });

  int get totalLeagues => leagues.length;
}

class LeagueRegistry {
  static const List<CountryLeagues> countries = [
    CountryLeagues(
      country: 'England',
      flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'eng.1',
          name: 'Premier League',
          country: 'England',
          flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/23.png',
        ),
        ScrapedLeagueInfo(
          slug: 'eng.2',
          name: 'Championship',
          country: 'England',
          flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
          tier: 'Tier 2',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/24.png',
        ),
        ScrapedLeagueInfo(
          slug: 'eng.3',
          name: 'League One',
          country: 'England',
          flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
          tier: 'Tier 3',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/25.png',
        ),
        ScrapedLeagueInfo(
          slug: 'eng.4',
          name: 'League Two',
          country: 'England',
          flagEmoji: '🏴󠁧󠁢󠁥󠁮󠁧󠁿',
          tier: 'Tier 4',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/26.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Spain',
      flagEmoji: '🇪🇸',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'esp.1',
          name: 'La Liga',
          country: 'Spain',
          flagEmoji: '🇪🇸',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/15.png',
        ),
        ScrapedLeagueInfo(
          slug: 'esp.2',
          name: 'Segunda División',
          country: 'Spain',
          flagEmoji: '🇪🇸',
          tier: 'Tier 2',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/87.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Italy',
      flagEmoji: '🇮🇹',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'ita.1',
          name: 'Serie A',
          country: 'Italy',
          flagEmoji: '🇮🇹',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/12.png',
        ),
        ScrapedLeagueInfo(
          slug: 'ita.2',
          name: 'Serie B',
          country: 'Italy',
          flagEmoji: '🇮🇹',
          tier: 'Tier 2',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/85.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Germany',
      flagEmoji: '🇩🇪',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'ger.1',
          name: 'Bundesliga',
          country: 'Germany',
          flagEmoji: '🇩🇪',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/10.png',
        ),
        ScrapedLeagueInfo(
          slug: 'ger.2',
          name: '2. Bundesliga',
          country: 'Germany',
          flagEmoji: '🇩🇪',
          tier: 'Tier 2',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/83.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'France',
      flagEmoji: '🇫🇷',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'fra.1',
          name: 'Ligue 1',
          country: 'France',
          flagEmoji: '🇫🇷',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/9.png',
        ),
        ScrapedLeagueInfo(
          slug: 'fra.2',
          name: 'Ligue 2',
          country: 'France',
          flagEmoji: '🇫🇷',
          tier: 'Tier 2',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/81.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Netherlands',
      flagEmoji: '🇳🇱',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'ned.1',
          name: 'Eredivisie',
          country: 'Netherlands',
          flagEmoji: '🇳🇱',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/11.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Portugal',
      flagEmoji: '🇵🇹',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'por.1',
          name: 'Primeira Liga',
          country: 'Portugal',
          flagEmoji: '🇵🇹',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/14.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Turkey',
      flagEmoji: '🇹🇷',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'tur.1',
          name: 'Süper Lig',
          country: 'Turkey',
          flagEmoji: '🇹🇷',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/18.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Belgium',
      flagEmoji: '🇧🇪',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'bel.1',
          name: 'Belgian Pro League',
          country: 'Belgium',
          flagEmoji: '🇧🇪',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/6.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Scotland',
      flagEmoji: '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'sco.1',
          name: 'Scottish Premiership',
          country: 'Scotland',
          flagEmoji: '🏴󠁧󠁢󠁳󠁣󠁴󠁿',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/45.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'United States',
      flagEmoji: '🇺🇸',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'usa.1',
          name: 'Major League Soccer',
          country: 'United States',
          flagEmoji: '🇺🇸',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/19.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Brazil',
      flagEmoji: '🇧🇷',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'bra.1',
          name: 'Brasileirão Série A',
          country: 'Brazil',
          flagEmoji: '🇧🇷',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/8.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Saudi Arabia',
      flagEmoji: '🇸🇦',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'sau.1',
          name: 'Saudi Pro League',
          country: 'Saudi Arabia',
          flagEmoji: '🇸🇦',
          tier: 'Tier 1',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2800.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'Europe (UEFA)',
      flagEmoji: '🇪🇺',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'uefa.champions',
          name: 'UEFA Champions League',
          country: 'Europe (UEFA)',
          flagEmoji: '🇪🇺',
          tier: 'Top Continental',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2.png',
        ),
        ScrapedLeagueInfo(
          slug: 'uefa.europa',
          name: 'UEFA Europa League',
          country: 'Europe (UEFA)',
          flagEmoji: '🇪🇺',
          tier: 'Tier 2 Continental',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2034.png',
        ),
        ScrapedLeagueInfo(
          slug: 'uefa.europa.conf',
          name: 'UEFA Conference League',
          country: 'Europe (UEFA)',
          flagEmoji: '🇪🇺',
          tier: 'Tier 3 Continental',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2070.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'South America (CONMEBOL)',
      flagEmoji: '🌎',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'conmebol.libertadores',
          name: 'Copa Libertadores',
          country: 'South America (CONMEBOL)',
          flagEmoji: '🌎',
          tier: 'Top Continental',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2069.png',
        ),
        ScrapedLeagueInfo(
          slug: 'conmebol.sudamericana',
          name: 'Copa Sudamericana',
          country: 'South America (CONMEBOL)',
          flagEmoji: '🌎',
          tier: 'Tier 2 Continental',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/2071.png',
        ),
      ],
    ),
    CountryLeagues(
      country: 'International (FIFA & Global)',
      flagEmoji: '🏆',
      leagues: [
        ScrapedLeagueInfo(
          slug: 'fifa.world',
          name: 'FIFA World Cup',
          country: 'International (FIFA)',
          flagEmoji: '🏆',
          tier: 'World Championship',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/4.png',
        ),
        ScrapedLeagueInfo(
          slug: 'uefa.euro',
          name: 'UEFA European Championship',
          country: 'Europe (UEFA)',
          flagEmoji: '🇪🇺',
          tier: 'Continental Championship',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/53.png',
        ),
        ScrapedLeagueInfo(
          slug: 'conmebol.america',
          name: 'Copa América',
          country: 'South America (CONMEBOL)',
          flagEmoji: '🌎',
          tier: 'Continental Championship',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/17.png',
        ),
        ScrapedLeagueInfo(
          slug: 'caf.nations',
          name: 'Africa Cup of Nations',
          country: 'Africa (CAF)',
          flagEmoji: '🌍',
          tier: 'Continental Championship',
          logo: 'https://a.espncdn.com/i/leaguelogos/soccer/500/35.png',
        ),
      ],
    ),
  ];

  static int get totalLeaguesCount =>
      countries.fold(0, (sum, c) => sum + c.totalLeagues);
}
