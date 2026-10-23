import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/app_settings_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/theme/app_theme.dart';
import 'league_display_order_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AppSettingsService _settings = AppSettingsService.instance;
  int _activeLeaguesCount = 10;

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView('SettingsScreen');
    _loadLeagueCount();
  }

  Future<void> _loadLeagueCount() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLeagues = prefs.getStringList('preferred_leagues') ?? [
      'Premier League', 'La Liga', 'Serie A', 'Bundesliga', 'Ligue 1',
      'UEFA Champions League', 'UEFA Europa League', 'Pro League',
      'Major League Soccer', 'Championship'
    ];
    int count = 0;
    for (var l in savedLeagues) {
      if (prefs.getBool('show_$l') ?? true) count++;
    }
    if (mounted) {
      setState(() {
        _activeLeaguesCount = count;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) {
        final primary = Theme.of(context).primaryColor;
        final textPrimary = AppTheme.textPrimaryOf(context);
        final textSecondary = AppTheme.textSecondaryOf(context);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: textPrimary,
              ),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: [
              // VIP / Pro Member Banner
              _buildProBanner(primary),
              const SizedBox(height: 24),

              // SECTION 1: APPEARANCE & THEME
              _buildSectionHeader('APPEARANCE & THEME', textSecondary),
              _buildGroupedCard([
                _buildThemeModeSelector(primary, textPrimary, textSecondary),
                _buildDivider(),
                _buildAccentColorSelector(primary, textPrimary, textSecondary),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.calculate_outlined,
                  iconBg: const Color(0xFF0EA5E9),
                  title: 'Odds Format',
                  subtitle: _settings.oddsFormat,
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                  onTap: () => _showOddsFormatPicker(context),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.schedule_rounded,
                  iconBg: const Color(0xFF6366F1),
                  title: 'Time Format',
                  subtitle: _settings.timeFormat == '24-hour' ? '24-Hour (20:45)' : '12-Hour (8:45 PM)',
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                  onTap: () => _showTimeFormatPicker(context),
                ),
              ]),
              const SizedBox(height: 24),

              // SECTION 2: NOTIFICATIONS & ALERTS
              _buildSectionHeader('NOTIFICATIONS & ALERTS', textSecondary),
              _buildGroupedCard([
                _buildSwitchTile(
                  icon: Icons.notifications_active_rounded,
                  iconBg: const Color(0xFF10B981),
                  title: 'Match Notifications',
                  subtitle: 'Enable push alerts & live updates',
                  value: _settings.masterAlerts,
                  onChanged: (val) => _settings.setMasterAlerts(val),
                  primary: primary,
                ),
                if (_settings.masterAlerts) ...[
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.alarm_on_rounded,
                    iconBg: const Color(0xFF14B8A6),
                    title: 'Kickoff Reminders',
                    subtitle: '15 minutes before scheduled kickoff',
                    value: _settings.alertKickoff,
                    onChanged: (val) => _settings.setAlertKickoff(val),
                    primary: primary,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.sports_soccer_rounded,
                    iconBg: const Color(0xFF22C55E),
                    title: 'Goal & Score Alerts',
                    subtitle: 'Instant alerts when score changes',
                    value: _settings.alertGoals,
                    onChanged: (val) => _settings.setAlertGoals(val),
                    primary: primary,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.auto_awesome_rounded,
                    iconBg: const Color(0xFFA855F7),
                    title: 'High AI Confidence Alerts',
                    subtitle: 'Notify on high value picks (>70% confidence)',
                    value: _settings.alertAiHighConfidence,
                    onChanged: (val) => _settings.setAlertAiHighConfidence(val),
                    primary: primary,
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.trending_up_rounded,
                    iconBg: const Color(0xFFEC4899),
                    title: 'Value Bet (+EV) Signals',
                    subtitle: 'Market drops & mathematical value alerts',
                    value: _settings.alertValueBets,
                    onChanged: (val) => _settings.setAlertValueBets(val),
                    primary: primary,
                  ),

                  _buildDivider(),
                  _buildSwitchTile(
                    icon: Icons.vibration_rounded,
                    iconBg: const Color(0xFF64748B),
                    title: 'Sound & Haptic Feedback',
                    subtitle: 'Vibrate on major match events',
                    value: _settings.alertSoundHaptics,
                    onChanged: (val) => _settings.setAlertSoundHaptics(val),
                    primary: primary,
                  ),
                ],
              ]),
              const SizedBox(height: 24),

              // SECTION 3: COMPETITIONS & FEED
              _buildSectionHeader('COMPETITIONS & FEED', textSecondary),
              _buildGroupedCard([

                _buildSwitchTile(
                  icon: Icons.visibility_off_outlined,
                  iconBg: const Color(0xFF6B7280),
                  title: 'Hide Finished Matches',
                  subtitle: 'Only show upcoming & live matches in feed',
                  value: _settings.hideFinishedMatches,
                  onChanged: (val) => _settings.setHideFinishedMatches(val),
                  primary: primary,
                ),

              ]),
              const SizedBox(height: 24),

              // SECTION 4: AI PREDICTIONS & ANALYTICS
              _buildSectionHeader('AI ENGINE & PREDICTIONS', textSecondary),
              _buildGroupedCard([
                _buildSettingsTile(
                  icon: Icons.tune_rounded,
                  iconBg: const Color(0xFF8B5CF6),
                  title: 'Confidence Filter',
                  subtitle: 'Min ${_settings.minConfidenceFilter}% confidence',
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                  onTap: () => _showConfidenceFilterPicker(context),
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.insights_rounded,
                  iconBg: const Color(0xFF10B981),
                  title: 'Expected Value (+EV) Badges',
                  subtitle: 'Display positive EV percentage on match cards',
                  value: _settings.showExpectedValue,
                  onChanged: (val) => _settings.setShowExpectedValue(val),
                  primary: primary,
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.stadium_rounded,
                  iconBg: const Color(0xFFF59E0B),
                  title: '2D Tactical Board',
                  subtitle: _settings.use2dPitch
                      ? '2D Top-Down View (Uncheck for 3D Isometric)'
                      : '3D Isometric Stadium Pitch Active',
                  value: _settings.use2dPitch,
                  onChanged: (val) => _settings.setUse2dPitch(val),
                  primary: primary,
                ),
              ]),
              const SizedBox(height: 24),

              // SECTION 5: APP MAINTENANCE & INFO
              _buildSectionHeader('DATA & ABOUT', textSecondary),
              _buildGroupedCard([
                _buildSettingsTile(
                  icon: Icons.cleaning_services_rounded,
                  iconBg: const Color(0xFFEF4444),
                  title: 'Clear Cache & Sync Data',
                  subtitle: 'Refresh local storage and match history',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => _clearCache(context),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.restore_rounded,
                  iconBg: const Color(0xFF64748B),
                  title: 'Reset All Preferences',
                  subtitle: 'Restore factory default settings',
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => _confirmResetPreferences(context),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconBg: const Color(0xFF3B82F6),
                  title: 'App Version',
                  subtitle: 'v1.4.2 · Pro Neural Engine',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Latest',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                ),
                _buildDivider(),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconBg: const Color(0xFF6366F1),
                  title: 'Privacy & Terms',
                  subtitle: 'Data usage & prediction disclaimer',
                  trailing: Icon(Icons.chevron_right_rounded, color: textSecondary),
                  onTap: () => _showPrivacyDialog(context),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  // --- SECTION WIDGETS ---

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildGroupedCard(List<Widget> children) {
    final surface = AppTheme.surfaceOf(context);
    final borderColor = AppTheme.cardBorderOf(context);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    final borderColor = AppTheme.cardBorderOf(context);
    return Divider(
      height: 1,
      indent: 58,
      thickness: 0.7,
      color: borderColor,
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconBg),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color primary,
  }) {
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconBg),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.4),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  // --- THEME & ACCENT PICKERS ---

  Widget _buildThemeModeSelector(Color primary, Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.palette_rounded, size: 20, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Theme',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Choose your preferred appearance mode',
                      style: TextStyle(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 3-way segmented controller
          Row(
            children: [
              Expanded(
                child: _buildThemeSegmentOption(
                  title: 'Light',
                  icon: Icons.light_mode_rounded,
                  mode: ThemeMode.light,
                  isSelected: _settings.themeMode == ThemeMode.light,
                  primary: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeSegmentOption(
                  title: 'Dark',
                  icon: Icons.dark_mode_rounded,
                  mode: ThemeMode.dark,
                  isSelected: _settings.themeMode == ThemeMode.dark,
                  primary: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeSegmentOption(
                  title: 'System',
                  icon: Icons.phone_android_rounded,
                  mode: ThemeMode.system,
                  isSelected: _settings.themeMode == ThemeMode.system,
                  primary: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSegmentOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required Color primary,
  }) {
    final borderColor = AppTheme.cardBorderOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);

    return GestureDetector(
      onTap: () => _settings.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? primary : AppTheme.textSecondaryOf(context),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primary : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccentColorSelector(Color primary, Color textPrimary, Color textSecondary) {
    final accents = [
      {'key': 'cyan', 'name': 'Neon Blue', 'color': const Color(0xFF38BDF8)},
      {'key': 'emerald', 'name': 'FotMob Green', 'color': const Color(0xFF10B981)},
      {'key': 'violet', 'name': 'Royal Violet', 'color': const Color(0xFF8B5CF6)},
      {'key': 'amber', 'name': 'Cyber Amber', 'color': const Color(0xFFF59E0B)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.color_lens_rounded, size: 20, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accent Style',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Primary highlight color',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: accents.map((acc) {
              final isSelected = _settings.accentKey == acc['key'];
              final color = acc['color'] as Color;

              return GestureDetector(
                onTap: () => _settings.setAccentKey(acc['key'] as String),
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- PRO BANNER ---

  Widget _buildProBanner(Color primary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B), // Deep indigo
            const Color(0xFF0F172A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AI Scorecast PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Active Member • Tier 1 Neural Predictions',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildProFeatureBullet('60s Live Polling'),
              _buildProFeatureBullet('+EV Calculations'),
              _buildProFeatureBullet('Tactical Lineups'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProFeatureBullet(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --- MODAL PICKERS ---

  void _showOddsFormatPicker(BuildContext context) {
    _showSelectionSheet(
      title: 'Select Odds Format',
      options: ['Decimal', 'Fractional', 'American'],
      current: _settings.oddsFormat,
      onSelect: (val) => _settings.setOddsFormat(val),
    );
  }

  void _showTimeFormatPicker(BuildContext context) {
    _showSelectionSheet(
      title: 'Select Time Format',
      options: ['24-hour', '12-hour'],
      current: _settings.timeFormat,
      onSelect: (val) => _settings.setTimeFormat(val),
    );
  }

  void _showDefaultTabPicker(BuildContext context) {
    _showSelectionSheet(
      title: 'Default Home Tab',
      options: ['Today', 'Tomorrow', 'Live'],
      current: _settings.defaultHomeTab,
      onSelect: (val) => _settings.setDefaultHomeTab(val),
    );
  }

  void _showConfidenceFilterPicker(BuildContext context) {
    _showSelectionSheet(
      title: 'Minimum Confidence Threshold',
      options: ['50', '60', '70', '80'],
      formatLabel: (val) => '$val% Minimum Win Probability',
      current: _settings.minConfidenceFilter.toString(),
      onSelect: (val) => _settings.setMinConfidenceFilter(int.parse(val)),
    );
  }

  void _showSelectionSheet({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelect,
    String Function(String)? formatLabel,
  }) {
    final primary = Theme.of(context).primaryColor;
    final surface = AppTheme.surfaceOf(context);
    final textPrimary = AppTheme.textPrimaryOf(context);
    final textSecondary = AppTheme.textSecondaryOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),
                const Divider(),
                ...options.map((opt) {
                  final isSelected = opt == current;
                  final label = formatLabel != null ? formatLabel(opt) : opt;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? primary : textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle_rounded, color: primary)
                        : Icon(Icons.radio_button_unchecked, color: textSecondary),
                    onTap: () {
                      onSelect(opt);
                      Navigator.pop(context);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _clearCache(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_matches_json');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared & data refreshed successfully!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmResetPreferences(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        title: Text('Reset Preferences?', style: TextStyle(color: AppTheme.textPrimaryOf(context))),
        content: Text(
          'This will reset all theme, alert, and feed customization settings back to default.',
          style: TextStyle(color: AppTheme.textSecondaryOf(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondaryOf(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _settings.resetAllSettings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preferences reset to default')),
                );
              }
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceOf(context),
        title: Text('Privacy & Terms', style: TextStyle(color: AppTheme.textPrimaryOf(context))),
        content: SingleChildScrollView(
          child: Text(
            'AI Scorecast provides automated football analytics, probability models, and team insights for informational purposes only.\n\n'
            'We do not accept bets or operate gambling services. Odds ratings and predictions represent statistical probabilities and do not guarantee future match outcomes.\n\n'
            'All match data is periodically synced and processed locally.',
            style: TextStyle(color: AppTheme.textSecondaryOf(context), fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }
}
