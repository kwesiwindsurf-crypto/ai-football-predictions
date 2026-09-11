class LeagueStandings {
  final int id;
  final String name;
  final String logo;
  final String? flag;
  final List<TeamStanding> standings;

  LeagueStandings({
    required this.id,
    required this.name,
    required this.logo,
    this.flag,
    required this.standings,
  });

  factory LeagueStandings.fromJson(Map<String, dynamic> json) {
    var standingsList = json['standings'] as List? ?? [];
    List<TeamStanding> standings = standingsList.map((i) => TeamStanding.fromJson(i)).toList();
    
    // Ensure they are sorted by rank
    standings.sort((a, b) => a.rank.compareTo(b.rank));

    return LeagueStandings(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
      flag: json['flag'],
      standings: standings,
    );
  }
}

class TeamStanding {
  final int rank;
  final String name;
  final String logo;
  final int points;
  final int goalsDiff;
  final String? form;
  final int played;
  final int win;
  final int draw;
  final int lose;
  final String? group;

  TeamStanding({
    required this.rank,
    required this.name,
    required this.logo,
    required this.points,
    required this.goalsDiff,
    this.form,
    required this.played,
    required this.win,
    required this.draw,
    required this.lose,
    this.group,
  });

  factory TeamStanding.fromJson(Map<String, dynamic> json) {
    return TeamStanding(
      rank: json['rank'] ?? 99,
      name: json['name'] ?? '',
      logo: json['logo'] ?? '',
      points: json['points'] ?? 0,
      goalsDiff: json['goalsDiff'] ?? 0,
      form: json['form'],
      played: json['played'] ?? 0,
      win: json['win'] ?? 0,
      draw: json['draw'] ?? 0,
      lose: json['lose'] ?? 0,
      group: json['group'],
    );
  }
}
