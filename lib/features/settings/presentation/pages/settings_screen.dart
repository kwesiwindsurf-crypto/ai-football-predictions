import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String> _leagues = [];
  bool _isLoading = true;

  // Default priority if not set
  final List<String> _defaultLeagues = [
    'Premier League', 'La Liga', 'Serie A', 'Bundesliga', 'Ligue 1',
    'UEFA Champions League', 'UEFA Europa League', 'Pro League',
    'Major League Soccer', 'Championship'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings & Preferences',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPremiumBanner(),
                const SizedBox(height: 24),
                const Text(
                  'League Display Order',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Drag handles to reorder. Toggle off to hide a league.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Theme(
                    data: ThemeData(
                      canvasColor: AppTheme.surface,
                    ),
                    child: ReorderableListView.builder(
                      itemCount: _leagues.length,
                      onReorderItem: _onReorderItem,
                      itemBuilder: (context, index) {
                        final league = _leagues[index];
                        final isEnabled = _leagueToggles[league] ?? true;
                        
                        return Container(
                          key: ValueKey(league),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: const Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                            title: Row(
                              children: [
                                const Icon(Icons.sports_soccer, size: 20, color: AppTheme.primary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    league,
                                    style: TextStyle(
                                      color: isEnabled ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Switch(
                              value: isEnabled,
                              activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
                              activeThumbColor: AppTheme.primary,
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
          ),
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.secondary.withValues(alpha: 0.8),
            AppTheme.primary.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
              const SizedBox(width: 12),
              const Text(
                'AI Pro Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('PRO', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Unlock Expected Value (+EV) calculations, real-time live odds alerts, and premium staking options.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
