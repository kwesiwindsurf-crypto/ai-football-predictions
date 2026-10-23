import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../models/country_leagues_model.dart';
import 'country_leagues_sheet.dart';

class LeaguesHubScreen extends StatefulWidget {
  const LeaguesHubScreen({super.key});

  @override
  State<LeaguesHubScreen> createState() => _LeaguesHubScreenState();
}

class _LeaguesHubScreenState extends State<LeaguesHubScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leagues & Competitions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: textPrimary,
              ),
            ),
            Text(
              '${LeagueRegistry.totalLeaguesCount}+ Competitions Scraped & Predicted',
              style: TextStyle(
                fontSize: 12,
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: TextStyle(color: textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search country or competition...',
                  hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded, color: textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: textSecondary, size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
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
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
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
