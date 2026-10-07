import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'health_service.dart';

/// What one sync did, for the screen to report.
class HealthImportResult {
  const HealthImportResult({
    this.found = 0,
    this.imported = 0,
    this.duplicates = 0,
    this.error,
  });

  /// Workouts the health store returned that were worth sending.
  final int found;

  /// Workouts that were new and are now in the athlete's history.
  final int imported;

  /// Workouts already filed, or matching a session recorded in the app.
  final int duplicates;

  final String? error;

  bool get failed => error != null;
}

/// Brings workouts from Apple Health and Health Connect into Fitrybe.
///
/// Watches from Garmin, Fitbit, Whoop, Polar, Samsung and Apple all write into
/// one of those two stores through their own apps, so reading the store covers
/// every brand at once without a deal with any of them.
///
/// The health store lives on the phone, so there is no server-side sync: this
/// runs when the app opens and when the athlete asks for it.
class HealthImport {
  HealthImport._();
  static final HealthImport _instance = HealthImport._();
  factory HealthImport() => _instance;

  static const _enabledKey = 'fitrybe_health_import_enabled';
  static const _lastSyncKey = 'fitrybe_health_last_sync';

  /// How far back a first sync looks. Far enough to feel populated, short
  /// enough that nobody's whole training history lands at once.
  static const firstRunWindow = Duration(days: 30);

  /// Anything shorter than this is a stray tap on a watch, not a session.
  static const minimumDuration = Duration(seconds: 60);

  /// Workouts are re-read no more than this often while the app is used.
  static const syncInterval = Duration(hours: 1);

  /// One request carries at most this many, matching the server's limit.
  static const maxPerSync = 200;

  final ValueNotifier<bool> enabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier<DateTime?>(null);

  bool _loaded = false;
  bool _syncing = false;

  bool get isEnabled => enabledNotifier.value;
  bool get isSyncing => _syncing;

  /// Reads the stored preference. Safe to call repeatedly.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabledNotifier.value = prefs.getBool(_enabledKey) ?? false;
      final stamp = prefs.getString(_lastSyncKey);
      lastSyncNotifier.value = stamp == null ? null : DateTime.tryParse(stamp);
    } catch (e) {
      debugPrint('HealthImport load error: $e');
    }
  }

  /// Turns importing on or off. Turning it on asks for health access and runs
  /// a first sync; turning it off leaves everything already imported alone.
  Future<HealthImportResult?> setEnabled(bool value) async {
    await load();
    if (value) {
      final granted = await HealthService().ensureAuthorized();
      if (!granted) {
        return const HealthImportResult(
          error: 'Fitrybe was not given access to your health data.',
        );
      }
    }
    enabledNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (e) {
      debugPrint('HealthImport save error: $e');
    }
    return value ? await syncNow() : null;
  }

  /// Runs a sync if importing is on and the last one is old enough. Called
  /// when the app opens, so a watch workout turns up without being asked for.
  Future<HealthImportResult?> syncIfDue() async {
    await load();
    if (!isEnabled || _syncing) return null;
    final last = lastSyncNotifier.value;
    if (last != null && DateTime.now().difference(last) < syncInterval) {
      return null;
    }
    return syncNow();
  }

  /// Reads everything since the last sync and sends what is new.
  Future<HealthImportResult> syncNow() async {
    await load();
    if (_syncing) return const HealthImportResult();
    _syncing = true;

    try {
      final now = DateTime.now();
      final last = lastSyncNotifier.value;
      // A few minutes of overlap, so a workout saved to the store moments
      // after the previous sync is not missed. The server drops repeats.
      final since = last == null
          ? now.subtract(firstRunWindow)
          : last.subtract(const Duration(minutes: 10));

      final workouts = await HealthService().fetchWorkouts(since: since, until: now);
      final worth = workouts.where(isWorthImporting).toList();
      if (worth.isEmpty) {
        await _stamp(now);
        return const HealthImportResult();
      }

      final payload = worth.take(maxPerSync).map(toPayload).toList();
      final response = await ApiService.importActivities(payload);
      await _stamp(now);

      return HealthImportResult(
        found: payload.length,
        imported: (response['imported'] as num?)?.toInt() ?? 0,
        duplicates: (response['duplicates'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('HealthImport sync error: $e');
      return HealthImportResult(
        error: e is ApiException
            ? e.message
            : 'Could not bring in your workouts. Try again in a moment.',
      );
    } finally {
      _syncing = false;
    }
  }

  Future<void> _stamp(DateTime at) async {
    lastSyncNotifier.value = at;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, at.toIso8601String());
    } catch (e) {
      debugPrint('HealthImport stamp error: $e');
    }
  }

  // ── Pure helpers, kept static so they can be tested on their own ────────

  /// A minute of movement that burned something or covered ground. Watches
  /// file plenty of stray seconds-long entries that are not workouts.
  static bool isWorthImporting(HealthWorkout workout) {
    if (workout.duration < minimumDuration) return false;
    return workout.distanceMetres > 0 || workout.calories > 0;
  }

  /// Fitrybe's name for a health-store workout type. Anything unrecognised
  /// keeps its own name in readable form rather than being dropped.
  static String activityTypeFor(String healthType) {
    switch (healthType.toUpperCase()) {
      case 'RUNNING':
      case 'RUNNING_TREADMILL':
        return 'Running';
      case 'WALKING':
      case 'WHEELCHAIR_WALK_PACE':
        return 'Walking';
      case 'BIKING':
      case 'BIKING_STATIONARY':
      case 'HAND_CYCLING':
        return 'Cycling';
      case 'HIKING':
        return 'Hiking';
      case 'SWIMMING':
      case 'SWIMMING_POOL':
      case 'SWIMMING_OPEN_WATER':
        return 'Open Water Swimming';
      case 'ROWING':
        return 'Canoeing';
      case 'YOGA':
        return 'Yoga (Outdoor)';
      case 'STRENGTH_TRAINING':
      case 'TRADITIONAL_STRENGTH_TRAINING':
      case 'FUNCTIONAL_STRENGTH_TRAINING':
      case 'WEIGHTLIFTING':
        return 'Gym Workout';
      case 'CLIMBING':
      case 'ROCK_CLIMBING':
        return 'Rock Climbing';
      case 'SKATING':
        return 'Roller Skating';
      case 'SNOWBOARDING':
        return 'Snowboarding';
      case 'DOWNHILL_SKIING':
      case 'CROSS_COUNTRY_SKIING':
        return 'Skiing';
      case 'GOLF':
        return 'Golf';
      case 'TENNIS':
        return 'Tennis';
      case 'BADMINTON':
        return 'Badminton';
      case 'BASKETBALL':
        return 'Basketball';
      case 'VOLLEYBALL':
        return 'Volleyball';
      case 'CRICKET':
        return 'Cricket';
      case 'RUGBY':
        return 'Rugby';
      case 'SOCCER':
        return 'Football/Soccer';
      case 'BOXING':
      case 'KICKBOXING':
        return 'Boxing';
      case 'MARTIAL_ARTS':
        return 'Martial Arts';
      case 'WHEELCHAIR_RUN_PACE':
        return 'Wheelchair Activity';
      default:
        return _readable(healthType);
    }
  }

  /// RUNNING_TREADMILL becomes Running Treadmill.
  static String _readable(String enumName) {
    final words = enumName
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .toList();
    return words.isEmpty ? 'Workout' : words.join(' ');
  }

  /// "Morning Run", the way somebody would name it themselves.
  static String titleFor(String activityType, DateTime start) {
    final hour = start.hour;
    final partOfDay = hour < 12
        ? 'Morning'
        : hour < 17
            ? 'Afternoon'
            : hour < 21
                ? 'Evening'
                : 'Night';
    return '$partOfDay $activityType';
  }

  /// One workout in the shape the import endpoint expects.
  static Map<String, dynamic> toPayload(HealthWorkout workout) {
    final type = activityTypeFor(workout.typeName);
    return {
      'externalId': workout.id,
      'title': titleFor(type, workout.start),
      'type': type,
      'duration': workout.duration.inSeconds,
      'distance': workout.distanceMetres,
      'calories': workout.calories,
      'startTime': workout.start.toUtc().toIso8601String(),
      'endTime': workout.end.toUtc().toIso8601String(),
      if (workout.sourceName.trim().isNotEmpty) 'sourceName': workout.sourceName.trim(),
    };
  }
}
