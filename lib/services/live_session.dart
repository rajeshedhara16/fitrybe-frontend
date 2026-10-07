import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'calorie_estimator.dart';
import 'health_service.dart';
import 'location_tracker.dart';
import 'socket_service.dart';

/// Whether a running workout is solo or part of a Clique.
enum LiveMode { solo, clique }

/// A snapshot of the running workout for the screens to draw.
@immutable
class LiveSessionState {
  const LiveSessionState({
    this.isActive = false,
    this.isPaused = false,
    this.mode = LiveMode.solo,
    this.sessionId,
    this.activityType = 'Running',
    this.title = 'Workout',
    this.elapsed = Duration.zero,
    this.distanceKm = 0,
    this.calories = 0,
    this.heartRate = 0,
    this.locationWarning,
    this.goalType,
    this.goalProgress,
  });

  final bool isActive;
  final bool isPaused;
  final LiveMode mode;
  final String? sessionId;
  final String activityType;
  final String title;
  final Duration elapsed;
  final double distanceKm;
  final int calories;

  /// Zero means no reading, which screens show as `--` rather than inventing one.
  final int heartRate;

  /// Why distance is not moving, when location could not be used.
  final String? locationWarning;

  /// The session's goal, when it has one: Distance, Duration or Calories.
  final String? goalType;

  /// How far through that goal this athlete is, where 1 is met. Null when the
  /// session has no goal.
  final double? goalProgress;

  bool get goalReached => goalProgress != null && goalProgress! >= 1;

  int get elapsedSeconds => elapsed.inSeconds;
}

/// What a finished workout measured, handed back for saving.
class LiveSessionSummary {
  const LiveSessionSummary({
    required this.mode,
    required this.sessionId,
    required this.activityType,
    required this.title,
    required this.elapsed,
    required this.distanceMetres,
    required this.calories,
    required this.route,
  });

  final LiveMode mode;
  final String? sessionId;
  final String activityType;
  final String title;
  final Duration elapsed;
  final double distanceMetres;
  final int calories;
  final List<Map<String, double>> route;

  double get distanceKm => distanceMetres / 1000;
}

/// The one place a workout in progress lives.
///
/// It used to live inside the recording screen, so walking back to the feed
/// disposed the timer and the GPS tracker, and returning started a new workout
/// from zero. Keeping it here means a session survives navigation, a rebuild,
/// and the app being killed: the clock is derived from timestamps rather than
/// counted by a ticker, and the essentials are written to disk as they change.
class LiveSession {
  LiveSession._();
  static final LiveSession _instance = LiveSession._();
  factory LiveSession() => _instance;

  static const _key = 'fitrybe_live_session';

  /// Telemetry is sent to the squad on this cadence while a Clique runs.
  static const telemetryInterval = Duration(seconds: 3);

  /// A workout nobody finished is given up on after this long, so a session
  /// left running overnight does not greet its owner still counting.
  static const staleAfter = Duration(hours: 12);

  /// How long a just-finished session refuses to start again. A screen rebuild
  /// or a lobby broadcast still in flight would otherwise start a second
  /// workout the moment the first one was saved.
  static const restartGuard = Duration(seconds: 30);

  /// Overridable so the clock can be tested without waiting for real time.
  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  final ValueNotifier<LiveSessionState> notifier =
      ValueNotifier<LiveSessionState>(const LiveSessionState());

  final LocationTracker tracker = LocationTracker();

  Timer? _ticker;
  Timer? _telemetry;

  LiveMode _mode = LiveMode.solo;
  String? _sessionId;
  String _activityType = 'Running';
  String _title = 'Workout';
  DateTime? _startedAt;
  DateTime? _pausedAt;
  Duration _pausedTotal = Duration.zero;

  /// Distance measured before the app was last killed. The tracker starts from
  /// zero each run, so the total is this plus whatever it has measured since.
  double _baseDistanceMetres = 0;
  String? _locationWarning;
  String? _goalType;
  double? _goalTarget;
  String? _lastFinishedSessionId;
  DateTime? _lastFinishedAt;

  bool _isViewOpen = false;

  /// Set by the screen showing this session, so the return banner knows to
  /// stay out of the way while the athlete is already looking at it.
  bool get isViewOpen => _isViewOpen;
  set isViewOpen(bool value) {
    if (_isViewOpen == value) return;
    _isViewOpen = value;
    _publish();
  }

  LiveSessionState get state => notifier.value;
  bool get isActive => state.isActive;
  bool get isPaused => state.isPaused;
  String? get sessionId => _sessionId;
  LiveMode get mode => _mode;

  /// How long the athlete has been going, excluding any time paused. Derived
  /// from timestamps, so backgrounding the app cannot make it drift.
  Duration get elapsed {
    final start = _startedAt;
    if (start == null) return Duration.zero;
    final pausedNow = _pausedAt == null ? Duration.zero : clock().difference(_pausedAt!);
    final total = clock().difference(start) - _pausedTotal - pausedNow;
    return total.isNegative ? Duration.zero : total;
  }

  double get distanceMetres => _baseDistanceMetres + tracker.distanceMeters;

  /// Begins a workout. Starting while one is already running does nothing, so
  /// a stray tap cannot wipe a session in progress.
  Future<void> start({
    required LiveMode mode,
    String? sessionId,
    required String activityType,
    String title = 'Workout',
    String? goalType,
    double? goalTarget,
  }) async {
    if (isActive) return;

    // The one just saved does not come straight back.
    if (sessionId != null &&
        sessionId == _lastFinishedSessionId &&
        _lastFinishedAt != null &&
        clock().difference(_lastFinishedAt!) < restartGuard) {
      return;
    }

    _goalType = goalType;
    _goalTarget = goalTarget;

    _mode = mode;
    _sessionId = sessionId;
    _activityType = activityType;
    _title = title;
    _startedAt = clock();
    _pausedAt = null;
    _pausedTotal = Duration.zero;
    _baseDistanceMetres = 0;
    _locationWarning = null;
    tracker.reset();
    tracker.isPaused = false;

    _publish();
    await _save();
    _startTicker();
    await _beginTracking();
    _startTelemetry();
  }

  /// Sets the goal after the fact, for a session whose details arrive from the
  /// server once it is already running.
  void updateGoal({String? type, double? target}) {
    if (_goalType == type && _goalTarget == target) return;
    _goalType = type;
    _goalTarget = target;
    _publish();
    _save();
  }

  /// How far through the goal this athlete is, or null without one.
  double? get goalProgress {
    final target = _goalTarget;
    final type = _goalType;
    if (type == null || target == null || target <= 0) return null;

    final km = distanceMetres / 1000;
    final current = switch (type) {
      'Duration' => elapsed.inSeconds / 60.0,
      'Calories' => CalorieEstimator.fromDistance(
          activity: _activityType,
          distanceKm: km,
        ).toDouble(),
      _ => km,
    };
    return current / target;
  }

  /// Whether the goal has been met.
  bool get goalReached => (goalProgress ?? 0) >= 1;

  /// Pauses or resumes. Pausing stops the clock and the distance together, so
  /// a coffee stop costs neither.
  void togglePause() {
    if (!isActive) return;
    if (_pausedAt == null) {
      _pausedAt = clock();
      tracker.isPaused = true;
    } else {
      _pausedTotal += clock().difference(_pausedAt!);
      _pausedAt = null;
      tracker.isPaused = false;
    }
    _publish();
    _save();
  }

  /// Ends the workout and hands back what it measured. The session is cleared,
  /// so the caller must save the summary it is given.
  Future<LiveSessionSummary?> finish() async {
    if (!isActive) return null;

    final summary = LiveSessionSummary(
      mode: _mode,
      sessionId: _sessionId,
      activityType: _activityType,
      title: _title,
      elapsed: elapsed,
      distanceMetres: distanceMetres,
      calories: state.calories,
      route: tracker.routeAsJson(),
    );

    _lastFinishedSessionId = _sessionId;
    _lastFinishedAt = clock();
    await _stopEverything();
    return summary;
  }

  /// Drops the workout without saving it, for a session that was abandoned.
  Future<void> discard() => _stopEverything();

  Future<void> _stopEverything() async {
    _ticker?.cancel();
    _ticker = null;
    _telemetry?.cancel();
    _telemetry = null;
    tracker.stop();

    _startedAt = null;
    _pausedAt = null;
    _pausedTotal = Duration.zero;
    _baseDistanceMetres = 0;
    _sessionId = null;
    _locationWarning = null;
    _goalType = null;
    _goalTarget = null;

    notifier.value = const LiveSessionState();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('LiveSession clear error: $e');
    }
  }

  /// Picks a workout back up after the app was killed mid-session.
  ///
  /// The clock continues from the stored start time. Distance measured before
  /// the restart is kept as a baseline; the route from that leg is gone, since
  /// holding every point on disk is not worth the writes.
  Future<void> restore() async {
    if (isActive) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final startedAt = DateTime.tryParse('${data['startedAt']}');
      if (startedAt == null) {
        await prefs.remove(_key);
        return;
      }

      // A workout nobody ever finished is not resumed days later.
      if (clock().difference(startedAt) > staleAfter) {
        await prefs.remove(_key);
        return;
      }

      final mode = '${data['mode']}' == 'clique' ? LiveMode.clique : LiveMode.solo;
      final storedSessionId = data['sessionId'] as String?;

      // A Clique that has since been finished, cancelled or deleted leaves
      // nothing to record against, so the stored session goes with it. An
      // unanswerable check leaves the session alone.
      if (mode == LiveMode.clique && storedSessionId != null) {
        final stillRunning = await ApiService.cliqueStillRunning(storedSessionId);
        if (stillRunning == false) {
          await prefs.remove(_key);
          return;
        }
      }

      _mode = mode;
      _sessionId = storedSessionId;
      _activityType = '${data['activityType'] ?? 'Running'}';
      _title = '${data['title'] ?? 'Workout'}';
      _startedAt = startedAt;
      _pausedTotal = Duration(milliseconds: (data['pausedMs'] as num?)?.toInt() ?? 0);
      final pausedAt = DateTime.tryParse('${data['pausedAt']}');
      _pausedAt = pausedAt;
      _baseDistanceMetres = (data['distance'] as num?)?.toDouble() ?? 0;
      _goalType = data['goalType'] as String?;
      _goalTarget = (data['goalTarget'] as num?)?.toDouble();

      tracker.reset();
      tracker.isPaused = _pausedAt != null;

      _publish();
      _startTicker();
      await _beginTracking();
      _startTelemetry();
    } catch (e) {
      debugPrint('LiveSession restore error: $e');
    }
  }

  // ── internals ────────────────────────────────────────────────────────────

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _publish());
  }

  void _startTelemetry() {
    _telemetry?.cancel();
    if (_mode != LiveMode.clique || _sessionId == null) return;
    _telemetry = Timer.periodic(telemetryInterval, (_) => _broadcast());
  }

  Future<void> _beginTracking() async {
    try {
      await tracker.start(onUpdate: () {
        _publish();
        _save();
      });
    } on LocationDeniedException catch (e) {
      _locationWarning = e.message;
      _publish();
    } catch (e) {
      debugPrint('LiveSession GPS error: $e');
      _locationWarning = 'Distance is unavailable — GPS could not start.';
      _publish();
    }
  }

  void _broadcast() {
    final id = _sessionId;
    if (id == null || !isActive || isPaused) return;
    final position = tracker.lastPosition;
    SocketService().emit('clique:telemetry', {
      'sessionId': id,
      if (position != null) 'lat': position.latitude,
      if (position != null) 'lng': position.longitude,
      'distance': distanceMetres,
      'calories': state.calories,
      'pace': paceMinPerKm ?? 0,
    });
  }

  /// Minutes per kilometre so far, or null before anything has been covered.
  double? get paceMinPerKm {
    final km = distanceMetres / 1000;
    if (km <= 0) return null;
    return (elapsed.inSeconds / 60) / km;
  }

  void _publish() {
    final km = distanceMetres / 1000;
    notifier.value = LiveSessionState(
      isActive: _startedAt != null,
      isPaused: _pausedAt != null,
      mode: _mode,
      sessionId: _sessionId,
      activityType: _activityType,
      title: _title,
      elapsed: elapsed,
      distanceKm: km,
      calories: CalorieEstimator.fromDistance(
        activity: _activityType,
        distanceKm: km,
      ),
      heartRate: HealthService().healthNotifier.value.heartRate,
      locationWarning: _locationWarning,
      goalType: _goalType,
      goalProgress: goalProgress,
    );
  }

  Future<void> _save() async {
    final start = _startedAt;
    if (start == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'mode': _mode == LiveMode.clique ? 'clique' : 'solo',
          'sessionId': _sessionId,
          'activityType': _activityType,
          'title': _title,
          'startedAt': start.toIso8601String(),
          'pausedAt': _pausedAt?.toIso8601String(),
          'pausedMs': _pausedTotal.inMilliseconds,
          'distance': distanceMetres,
          'goalType': _goalType,
          'goalTarget': _goalTarget,
        }),
      );
    } catch (e) {
      debugPrint('LiveSession save error: $e');
    }
  }
}
