import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._internal();
  AppSettingsService._internal();

  // Theme settings
  ThemeMode _themeMode = ThemeMode.dark;
  String _accentKey = 'cyan'; // 'cyan', 'emerald', 'violet', 'amber'
  String _oddsFormat = 'Decimal'; // 'Decimal', 'Fractional', 'American'
  String _timeFormat = '24-hour'; // '24-hour', '12-hour'

  // Alert & Notification settings
  bool _masterAlerts = true;
  bool _alertKickoff = true;
  bool _alertGoals = true;
  bool _alertAiHighConfidence = true;
  bool _alertValueBets = true;
  bool _alertDailyDigest = false;
  bool _alertSoundHaptics = true;

  // AI & Content settings
  bool _hasSeenOnboarding = false;
  bool _hideFinishedMatches = false;
  int _minConfidenceFilter = 50; // 50, 60, 70, 80
  bool _showExpectedValue = true;
  bool _showTacticalLineups = true;
  bool _use2dPitch = true; // true = 2D, false = 3D ("if 2d tactiaclboard is unchecked make it 3d then")
  String _defaultHomeTab = 'Today';

  // Getters
  ThemeMode get themeMode => _themeMode;
  String get accentKey => _accentKey;
  String get oddsFormat => _oddsFormat;
  String get timeFormat => _timeFormat;

  bool get masterAlerts => _masterAlerts;
  bool get alertKickoff => _alertKickoff;
  bool get alertGoals => _masterAlerts && _alertGoals;
  bool get alertAiHighConfidence => _masterAlerts && _alertAiHighConfidence;
  bool get alertValueBets => _masterAlerts && _alertValueBets;
  bool get alertDailyDigest => _masterAlerts && _alertDailyDigest;
  bool get alertSoundHaptics => _alertSoundHaptics;

  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get hideFinishedMatches => _hideFinishedMatches;
  int get minConfidenceFilter => _minConfidenceFilter;
  bool get showExpectedValue => _showExpectedValue;
  bool get showTacticalLineups => _showTacticalLineups;
  bool get use2dPitch => _use2dPitch;
  bool get is3dPitch => !_use2dPitch;
  String get defaultHomeTab => _defaultHomeTab;

  Color get accentColor {
    switch (_accentKey) {
      case 'emerald':
        return const Color(0xFF10B981); // FotMob Emerald Green
      case 'violet':
        return const Color(0xFF8B5CF6); // Royal Violet
      case 'amber':
        return const Color(0xFFF59E0B); // Cyber Amber
      case 'cyan':
      default:
        return const Color(0xFF38BDF8); // Neon Blue
    }
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Theme mode
    final themeStr = prefs.getString('app_theme_mode') ?? 'dark';
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'system') {
      _themeMode = ThemeMode.system;
    } else {
      _themeMode = ThemeMode.dark;
    }

    _accentKey = prefs.getString('app_accent_key') ?? 'cyan';
    _oddsFormat = prefs.getString('app_odds_format') ?? 'Decimal';
    _timeFormat = prefs.getString('app_time_format') ?? '24-hour';

    _masterAlerts = prefs.getBool('app_master_alerts') ?? true;
    _alertKickoff = prefs.getBool('app_alert_kickoff') ?? true;
    _alertGoals = prefs.getBool('app_alert_goals') ?? true;
    _alertAiHighConfidence = prefs.getBool('app_alert_ai_high_confidence') ?? true;
    _alertValueBets = prefs.getBool('app_alert_value_bets') ?? true;
    _alertDailyDigest = prefs.getBool('app_alert_daily_digest') ?? false;
    _alertSoundHaptics = prefs.getBool('app_alert_sound_haptics') ?? true;

    _hasSeenOnboarding = prefs.getBool('app_has_seen_onboarding') ?? false;
    _hideFinishedMatches = prefs.getBool('app_hide_finished_matches') ?? false;
    _minConfidenceFilter = prefs.getInt('app_min_confidence_filter') ?? 50;
    _showExpectedValue = prefs.getBool('app_show_expected_value') ?? true;
    _showTacticalLineups = prefs.getBool('app_show_tactical_lineups') ?? true;
    _use2dPitch = prefs.getBool('app_use_2d_pitch') ?? true;
    _defaultHomeTab = prefs.getString('app_default_home_tab') ?? 'Today';

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final str = mode == ThemeMode.light
        ? 'light'
        : mode == ThemeMode.system
            ? 'system'
            : 'dark';
    await prefs.setString('app_theme_mode', str);
  }

  Future<void> setAccentKey(String key) async {
    _accentKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_accent_key', key);
  }

  Future<void> setOddsFormat(String format) async {
    _oddsFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_odds_format', format);
  }

  Future<void> setTimeFormat(String format) async {
    _timeFormat = format;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_time_format', format);
  }

  Future<void> setMasterAlerts(bool value) async {
    _masterAlerts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_master_alerts', value);
  }

  Future<void> setAlertKickoff(bool value) async {
    _alertKickoff = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_kickoff', value);
  }

  Future<void> setAlertGoals(bool value) async {
    _alertGoals = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_goals', value);
  }

  Future<void> setAlertAiHighConfidence(bool value) async {
    _alertAiHighConfidence = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_ai_high_confidence', value);
  }

  Future<void> setAlertValueBets(bool value) async {
    _alertValueBets = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_value_bets', value);
  }

  Future<void> setAlertDailyDigest(bool value) async {
    _alertDailyDigest = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_daily_digest', value);
  }

  Future<void> setAlertSoundHaptics(bool value) async {
    _alertSoundHaptics = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_alert_sound_haptics', value);
  }

  Future<void> setHasSeenOnboarding(bool value) async {
    _hasSeenOnboarding = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_has_seen_onboarding', value);
  }

  Future<void> setHideFinishedMatches(bool value) async {
    _hideFinishedMatches = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_hide_finished_matches', value);
  }

  Future<void> setMinConfidenceFilter(int value) async {
    _minConfidenceFilter = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('app_min_confidence_filter', value);
  }

  Future<void> setShowExpectedValue(bool value) async {
    _showExpectedValue = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_show_expected_value', value);
  }

  Future<void> setShowTacticalLineups(bool value) async {
    _showTacticalLineups = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_show_tactical_lineups', value);
  }

  Future<void> setUse2dPitch(bool value) async {
    _use2dPitch = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_use_2d_pitch', value);
  }

  Future<void> setDefaultHomeTab(String value) async {
    _defaultHomeTab = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_default_home_tab', value);
  }

  Future<void> resetAllSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_theme_mode');
    await prefs.remove('app_accent_key');
    await prefs.remove('app_odds_format');
    await prefs.remove('app_time_format');
    await prefs.remove('app_master_alerts');
    await prefs.remove('app_alert_kickoff');
    await prefs.remove('app_alert_goals');
    await prefs.remove('app_alert_ai_high_confidence');
    await prefs.remove('app_alert_value_bets');
    await prefs.remove('app_alert_daily_digest');
    await prefs.remove('app_alert_sound_haptics');
    await prefs.remove('app_hide_finished_matches');
    await prefs.remove('app_min_confidence_filter');
    await prefs.remove('app_show_expected_value');
    await prefs.remove('app_show_tactical_lineups');
    await prefs.remove('app_use_2d_pitch');
    await prefs.remove('app_default_home_tab');
    await loadSettings();
  }
}
