import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../models/match_model.dart';
import 'api_service.dart';
import 'betting_tracker_service.dart';

/// Central, app-level live synchronization engine.
///
/// Features:
/// 1. Runs a non-overlapping heartbeat every 25 seconds while active matches exist.
/// 2. Concurrency-safe mutex lock (`_isFetching`) prevents request pile-ups on slow networks.
/// 3. Lifecycle-aware (`WidgetsBindingObserver`): Pauses when the app is backgrounded/locked
///    to eliminate battery & Render bandwidth drain, and executes an instant sync upon resume.
/// 4. Broadcasts fresh live updates directly to [BettingTrackerService] and any registered listeners.
class LiveSyncEngine with WidgetsBindingObserver {
  static final LiveSyncEngine instance = LiveSyncEngine._internal();
  factory LiveSyncEngine() => instance;
  LiveSyncEngine._internal();

  Timer? _heartbeatTimer;
  bool _isFetching = false;
  bool _isRunning = false;
  bool _isInitialized = false;
  DateTime? _lastSyncTime;

  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isFetching => _isFetching;
  bool get isRunning => _isRunning;

  final List<void Function(List<Match> matches)> _listeners = [];

  /// Registers a callback to receive fresh match deltas whenever a live tick succeeds.
  void addSyncListener(void Function(List<Match> matches) listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
  }

  /// Unregisters a sync callback.
  void removeSyncListener(void Function(List<Match> matches) listener) {
    _listeners.remove(listener);
  }

  /// Initializes lifecycle observation and starts the background heartbeat.
  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    WidgetsBinding.instance.addObserver(this);
    debugPrint('🟢 [LiveSyncEngine] Initialized and observing app lifecycle.');
    start();
  }

  /// Starts or resumes the periodic 25-second live polling heartbeat.
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    debugPrint('▶️ [LiveSyncEngine] Started (25s cadence). Triggering initial tick...');
    _tick(forceSync: true); // Immediate sync on launch or unlock
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) => _tick());
  }

  /// Pauses the polling timer (e.g. when app is backgrounded).
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    debugPrint('⏸️ [LiveSyncEngine] Paused (saving battery & Render bandwidth).');
  }

  /// Permanently disposes the engine and unregisters lifecycle observation.
  void dispose() {
    stop();
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
    }
  }

  /// Concurrency-safe tick: fetches live deltas and broadcasts to the tracker & listeners.
  Future<void> _tick({bool forceSync = false}) async {
    // 🛡️ Mutex lock: Prevent overlapping requests if Render takes >25s
    if (_isFetching || !_isRunning) return;
    _isFetching = true;

    try {
      // Ensure in-memory cache is warmed up from disk if cold
      if (ApiService.inMemoryCache == null || ApiService.inMemoryCache!.isEmpty) {
        await ApiService.instance.getCachedMatches();
      }

      final freshMatches = await ApiService.instance.fetchLiveUpdates(forceSync: forceSync);
      if (freshMatches != null && freshMatches.isNotEmpty) {
        _lastSyncTime = DateTime.now();
        debugPrint('⚡ [LiveSyncEngine] Received ${freshMatches.length} updated matches at $_lastSyncTime');

        // 1. Instantly auto-sync Tracker so live scores & newly settled FT bets update in RAM
        try {
          await BettingTrackerService.instance.syncMatches(freshMatches);
        } catch (trackerErr) {
          debugPrint('⚠️ [LiveSyncEngine] Tracker sync note: $trackerErr');
        }

        // 2. Broadcast to all registered providers/listeners
        for (final listener in List.of(_listeners)) {
          try {
            listener(freshMatches);
          } catch (listenerErr) {
            debugPrint('⚠️ [LiveSyncEngine] Listener callback error: $listenerErr');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LiveSyncEngine] Tick error: $e');
    } finally {
      _isFetching = false;
    }
  }

  /// Manually trigger an immediate out-of-band live tick (e.g. on user demand).
  Future<void> syncNow({bool force = true}) => _tick(forceSync: force);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('📱 [LiveSyncEngine] App resumed -> Instant sync & resuming timer.');
        start();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        debugPrint('📱 [LiveSyncEngine] App backgrounded -> Pausing heartbeat to conserve resources.');
        stop();
        break;
      case AppLifecycleState.detached:
        dispose();
        break;
    }
  }
}
