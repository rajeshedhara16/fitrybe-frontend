import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Why a tracking session could not start.
enum LocationDenial {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationDeniedException implements Exception {
  final LocationDenial reason;
  const LocationDeniedException(this.reason);

  String get message {
    switch (reason) {
      case LocationDenial.serviceDisabled:
        return 'Turn on location services to track distance for this workout.';
      case LocationDenial.permissionDenied:
        return 'Fitrybe needs location access to measure your distance.';
      case LocationDenial.permissionDeniedForever:
        return 'Location access is blocked. Enable it in Settings to track distance.';
    }
  }

  @override
  String toString() => message;
}

/// Measures one workout's distance and route from the device GPS.
///
/// This is the only place distance is produced. Screens read [distanceKm] and
/// [route] instead of deriving movement from elapsed time, so a stationary or
/// paused athlete accumulates nothing — what gets saved to the backend is what
/// the device actually observed.
class LocationTracker {
  /// Fixes less precise than this are dropped. A 100 m-accuracy reading can
  /// otherwise teleport the athlete across a block while they stand still.
  static const double _maxAccuracyMeters = 25;

  /// Movement below this between two fixes is GPS jitter, not progress.
  static const double _minStepMeters = 3;

  StreamSubscription<Position>? _sub;
  final List<LatLng> _route = [];
  Position? _lastFix;
  double _distanceMeters = 0;
  bool _isPaused = false;

  double get distanceMeters => _distanceMeters;
  double get distanceKm => _distanceMeters / 1000;
  List<LatLng> get route => List.unmodifiable(_route);
  LatLng? get lastPosition => _route.isEmpty ? null : _route.last;
  bool get isTracking => _sub != null;

  /// Pausing drops the anchor fix, so ground covered while paused is not
  /// counted as a single huge step when tracking resumes.
  set isPaused(bool value) {
    _isPaused = value;
    if (value) _lastFix = null;
  }

  /// Throws [LocationDeniedException] when location cannot be used.
  static Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationDeniedException(LocationDenial.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationDeniedException(
          LocationDenial.permissionDeniedForever);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationDeniedException(LocationDenial.permissionDenied);
    }
  }

  /// Settings for the live tracking stream.
  ///
  /// A workout outlives the screen being visible, so Android runs the fix
  /// stream inside a foreground service and iOS is allowed to deliver updates
  /// in the background. Without this, locking the phone mid-run silently
  /// stopped the trace and the saved distance came up short.
  static LocationSettings _streamSettings() {
    if (kIsWeb) {
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
      );
    }

    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 0,
        // A foreground service keeps fixes coming while the app is backgrounded
        // without needing the ACCESS_BACKGROUND_LOCATION permission.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Fitrybe is tracking your workout',
          notificationText: 'Distance and route are being recorded.',
          notificationChannelName: 'Workout tracking',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }

    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        activityType: ActivityType.fitness,
        distanceFilter: 0,
        // iOS would otherwise pause updates when it decides the athlete has
        // stopped moving, which truncates the trace on a long rest.
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
    );
  }

  /// Best-effort single fix, used to centre a map before recording starts.
  static Future<LatLng?> currentFix() async {
    try {
      await ensurePermission();
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Starts a fresh session. [onUpdate] fires on every accepted fix.
  Future<void> start({required void Function() onUpdate}) async {
    await ensurePermission();
    await stop();
    reset();

    try {
      final first = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.best),
      );
      _route.add(LatLng(first.latitude, first.longitude));
      _lastFix = first;
      onUpdate();
    } catch (_) {
      // No fix yet — the stream supplies the first point instead.
    }

    _sub = Geolocator.getPositionStream(
      locationSettings: _streamSettings(),
    ).listen((position) {
      if (!isTracking || _isPaused) return;
      if (position.accuracy > _maxAccuracyMeters) return;

      final point = LatLng(position.latitude, position.longitude);
      final previous = _lastFix;

      if (previous == null) {
        _route.add(point);
        _lastFix = position;
        onUpdate();
        return;
      }

      final metres = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      if (metres < _minStepMeters) return;

      _distanceMeters += metres;
      _route.add(point);
      _lastFix = position;
      onUpdate();
    });
  }

  Future<void> stop() async {
    // Cleared first so any fix already in flight is ignored by the listener.
    final sub = _sub;
    _sub = null;
    await sub?.cancel();
  }

  void reset() {
    _route.clear();
    _distanceMeters = 0;
    _lastFix = null;
    _isPaused = false;
  }

  /// Average pace in minutes per kilometre, or null before enough ground is
  /// covered for the figure to mean anything.
  double? paceMinPerKm(int elapsedSeconds) {
    if (_distanceMeters < 50 || elapsedSeconds <= 0) return null;
    return (elapsedSeconds / 60) / distanceKm;
  }

  /// Route in the shape the backend stores in `Activity.routeData`.
  List<Map<String, double>> routeAsJson() =>
      _route.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();
}
