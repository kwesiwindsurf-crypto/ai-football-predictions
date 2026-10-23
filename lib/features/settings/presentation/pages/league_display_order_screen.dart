import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class LeagueDisplayOrderScreen extends StatefulWidget {
  const LeagueDisplayOrderScreen({super.key});

  @override
  State<LeagueDisplayOrderScreen> createState() => _LeagueDisplayOrderScreenState();
}

class _LeagueDisplayOrderScreenState extends State<LeagueDisplayOrderScreen> {
  List<String> _leagues = [];
  bool _isLoading = true;
  String _searchQuery = '';

  final List<String> _defaultLeagues = [
    'Premier League',
    'La Liga',
    'Serie A',
    'Bundesliga',
    'Ligue 1',
    'UEFA Champions League',
    'UEFA Europa League',
    'Pro League',
    'Major League Soccer',
    'Championship',
  ];

  final Map<String, bool> _leagueToggles = {};

  @override
  void initState() {
    super.initState();
    for (var league in _defaultLeagues) {
      _leagueToggles[league] = true;
    }
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLeagues = prefs.getStringList('preferred_leagues');

    if (savedLeagues != null && savedLeagues.isNotEmpty) {
      setState(() {
        _leagues = savedLeagues;
        for (var league in _leagues) {
          _leagueToggles[league] = prefs.getBool('show_$league') ?? true;
        }
        _isLoading = false;
      });
    } else {
      setState(() {
        _leagues = List.from(_defaultLeagues);
        _isLoading = false;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('preferred_leagues', _leagues);
    for (var league in _leagues) {
      await prefs.setBool('show_$league', _leagueToggles[league] ?? true);
    }
  }

  void _onReorderItem(int oldIndex, int newIndex) {
    setState(() {
      final String item = _leagues.removeAt(oldIndex);
      _leagues.insert(newIndex, item);
    });
    _savePreferences();
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _leagues = List.from(_defaultLeagues);
      for (var l in _leagues) {
        _leagueToggles[l] = true;
      }
    });
    await _savePreferences();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leagues reset to default order'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    final filteredLeagues = _searchQuery.isEmpty
        ? _leagues
        : _leagues
            .where((l) => l.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'League Display Order',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset to default',
            onPressed: _resetToDefault,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primary))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Info banner
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Drag the handle on the left to reorder leagues. Toggle switches to show or hide from matchday feed.',
                          style: TextStyle(fontSize: 12, color: textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim();
                      });
                    },
                    style: TextStyle(color: textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Filter leagues...',
                      hintStyle: TextStyle(color: textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                      filled: true,
                      fillColor: surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Reorderable list
                Expanded(
                  child: _searchQuery.isNotEmpty
                      ? ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredLeagues.length,
                          itemBuilder: (context, index) {
                            final league = filteredLeagues[index];
                            final isEnabled = _leagueToggles[league] ?? true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: borderColor),
                              ),
                              child: ListTile(
                                leading: Icon(Icons.sports_soccer_rounded, color: primary, size: 22),
                                title: Text(
                                  league,
                                  style: TextStyle(
                                    color: isEnabled ? textPrimary : textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: Switch(
                                  value: isEnabled,
                                  activeThumbColor: primary,
                                  activeTrackColor: primary.withValues(alpha: 0.4),
                                  onChanged: (val) {
                                    setState(() {
                                      _leagueToggles[league] = val;
                                    });
                                    _savePreferences();
                                  },
                                ),
                              ),
                            );
                          },
                        )
                      : Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _leagues.length,
                            onReorderItem: _onReorderItem,
                            itemBuilder: (context, index) {
                              final league = _leagues[index];
                              final isEnabled = _leagueToggles[league] ?? true;

                              return Container(
                                key: ValueKey(league),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: Icon(Icons.drag_indicator_rounded, color: textSecondary),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.sports_soccer_rounded, color: primary, size: 20),
                                    ],
                                  ),
                                  title: Text(
                                    league,
                                    style: TextStyle(
                                      color: isEnabled ? textPrimary : textSecondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Switch(
                                    value: isEnabled,
                                    activeThumbColor: primary,
                                    activeTrackColor: primary.withValues(alpha: 0.4),
                                    onChanged: (val) {
                                      setState(() {
                                        _leagueToggles[league] = val;
                                      });
                                      _savePreferences();
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}
