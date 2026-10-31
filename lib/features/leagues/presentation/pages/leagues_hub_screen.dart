import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/country_leagues_model.dart';
import '../../../../models/match_model.dart' as model;
import 'package:provider/provider.dart';
import '../../../../core/services/matches_provider.dart';
import '../../../../core/services/leagues_provider.dart';
import '../../../matches/presentation/widgets/dynamic_live_island.dart';
import 'country_leagues_sheet.dart';

class LeaguesHubScreen extends StatefulWidget {
  const LeaguesHubScreen({super.key});

  @override
  State<LeaguesHubScreen> createState() => _LeaguesHubScreenState();
}

class _LeaguesHubScreenState extends State<LeaguesHubScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    final filteredCountries = LeagueRegistry.countries.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final countryMatch = c.country.toLowerCase().contains(q);
      final leagueMatch = c.leagues.any((l) => l.name.toLowerCase().contains(q));
      return countryMatch || leagueMatch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(context.select<MatchesProvider, bool>((p) => p.hasLiveMatches) ? 108 : 64),
        child: Container(
          color: AppTheme.surfaceOf(context),
          child: SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Centered Dynamic Live Island (Matching FotMob / iOS Island)
                Selector<MatchesProvider, List<model.Match>>(
                  selector: (_, p) => p.liveMatches,
                  shouldRebuild: (prev, next) {
                    if (prev.length != next.length) return true;
                    for (int i = 0; i < prev.length; i++) {
                      if (prev[i].id != next[i].id ||
                          prev[i].homeScore != next[i].homeScore ||
                          prev[i].awayScore != next[i].awayScore ||
                          prev[i].elapsed != next[i].elapsed) {
                        return true;
                      }
                    }
                    return false;
                  },
                  builder: (context, liveList, _) {
                    if (liveList.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Center(
                        child: DynamicLiveIsland(liveMatches: liveList),
                      ),
                    );
                  },
                ),
                    // Header Row: Trophy + LEAGUES & CUPS on left, 14 Scraped badge on right
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: Color(0xFF00D06C),
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'LEAGUES & CUPS',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131821),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF272F3D), width: 1),
                        ),
                        child: const Text(
                          '14 Scraped',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8B949E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar (Matching Image 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161C24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF272F3D), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Search country, Premier League, La Liga...',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _searchQuery = ''),
                      child: const Icon(Icons.cancel_rounded, size: 16, color: Colors.white54),
                    ),
                ],
              ),
            ),
          ),

          // Countries Grid / List
          Expanded(
            child: filteredCountries.isEmpty
                ? Center(
                    child: Text(
                      'No countries or competitions match "$_searchQuery"',
                      style: TextStyle(color: textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredCountries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final country = filteredCountries[index];
                      return InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CountryLeaguesSheet(countryData: country),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              // Country Flag
                              Container(
                                width: 44,
                                height: 44,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).scaffoldBackgroundColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  country.flagEmoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Country Title and League names preview
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.country,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      country.leagues.map((l) => l.name).join(' • '),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Live match badge (if any match is live in this country)
                              Selector<LeaguesProvider, int>(
                                selector: (_, p) {
                                  int count = 0;
                                  for (final l in country.leagues) {
                                    count += p.getLiveCountForLeague(l.name);
                                  }
                                  return count;
                                },
                                builder: (context, liveCount, _) {
                                  if (liveCount <= 0) return const SizedBox.shrink();
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    margin: const EdgeInsets.only(right: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$liveCount LIVE',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              // Badge count
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${country.totalLeagues} ${country.totalLeagues == 1 ? "League" : "Leagues"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.chevron_right_rounded, color: textSecondary, size: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
