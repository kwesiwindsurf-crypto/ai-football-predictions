import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../models/standings_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/widgets/shimmer_loading.dart';

class StandingsScreen extends StatefulWidget {
  const StandingsScreen({super.key});

  @override
  State<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends State<StandingsScreen> {
  final ApiService _apiService = ApiService();
  LeagueStandings? _selectedLeague;
  List<LeagueStandings> _allLeagues = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStandings();
  }

  Future<void> _loadStandings() async {
    // 1. Load cached standings immediately
    final cached = await _apiService.getCachedStandings();
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() {
        _allLeagues = cached;
        _selectedLeague = cached.firstWhere(
          (l) => l.id == _selectedLeague?.id,
          orElse: () => cached.first,
        );
        _isLoading = false;
        _error = null;
      });
    }

    // 2. Fetch fresh standings from Cloudflare
    try {
      final fresh = await _apiService.fetchStandings();
      if (mounted && fresh.isNotEmpty) {
        setState(() {
          _allLeagues = fresh;
          _selectedLeague = fresh.firstWhere(
            (l) => l.id == _selectedLeague?.id,
            orElse: () => fresh.first,
          );
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (_allLeagues.isEmpty) {
            _error = e.toString();
          }
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('League Standings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStandings,
        color: AppTheme.primary,
        backgroundColor: AppTheme.surface,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _allLeagues.isEmpty) {
      return Column(
        children: const [
          LeaguePillsShimmer(),
          Expanded(child: StandingsTableShimmer()),
        ],
      );
    }

    if (_error != null && _allLeagues.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: 400,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Error loading standings\n$_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.black),
                    onPressed: _loadStandings,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_allLeagues.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: const SizedBox(
          height: 400,
          child: Center(child: Text('No standings data available.')),
        ),
      );
    }

    return Column(
      children: [
        _buildLeagueSelector(),
        Expanded(
          child: _selectedLeague == null 
            ? const Center(child: Text('Select a league'))
            : _buildStandingsTable(_selectedLeague!),
        ),
      ],
    );
  }

  Widget _buildLeagueSelector() {
    if (_allLeagues.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _allLeagues.length,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemBuilder: (context, index) {
          final league = _allLeagues[index];
          final isSelected = _selectedLeague?.id == league.id;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedLeague = league;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                children: [
                  if (league.logo.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: league.logo,
                      width: 20,
                      height: 20,
                      errorWidget: (context, url, error) => const Icon(Icons.emoji_events, size: 20),
                      placeholder: (context, url) => const SizedBox(width: 20, height: 20),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    league.name,
                    style: TextStyle(
                      color: isSelected ? Colors.black : AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStandingsTable(LeagueStandings league) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const SizedBox(width: 30, child: Text('#', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
                  const Expanded(child: Text('Team', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 30, child: Text('P', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 40, child: Text('GD', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 30, child: Text('Pts', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            // Table Rows
            Expanded(
              child: ListView.separated(
                itemCount: league.standings.length,
                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                itemBuilder: (context, index) {
                  final team = league.standings[index];
                  
                  // Zone colors (Champions League, Relegation, etc)
                  Color rankColor = AppTheme.textSecondary;
                  if (index < 4) {
                    rankColor = AppTheme.success; // Top 4
                  } else if (index >= league.standings.length - 3) {
                    rankColor = AppTheme.secondary; // Bottom 3
                  }
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${team.rank}',
                            style: TextStyle(color: rankColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            children: [
                              if (team.logo.isNotEmpty)
                                CachedNetworkImage(
                                  imageUrl: team.logo,
                                  width: 20,
                                  height: 20,
                                  errorWidget: (context, url, error) => const SizedBox(width: 20),
                                  placeholder: (context, url) => const SizedBox(width: 20, height: 20),
                                ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  team.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text('${team.played}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${team.goalsDiff > 0 ? '+' : ''}${team.goalsDiff}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${team.points}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
