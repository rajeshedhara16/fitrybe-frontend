import 'session_service.dart';

/// Estimates the active calories burned by a workout.
///
/// Where the workout covers ground, the estimate comes from the distance
/// actually travelled. A flat per-second figure — which is what this replaced —
/// ticks up at the same rate whether the athlete is sprinting or standing
/// still, so a phone left on a table reported a burn.
///
/// Activities with no distance to measure (a gym session, yoga, boxing) fall
/// back to a MET model, where elapsed time genuinely is the best available
/// signal for effort.
///
/// Every figure here is an estimate. Without a heart-rate strap or a power
/// meter, no phone can do better.
class CalorieEstimator {
  /// Used when the athlete has not recorded a weight. Their real weight makes
  /// a large difference, so the profile value is preferred wherever set.
  static const double _fallbackWeightKg = 70;

  static double get _weightKg {
    final weight = (SessionService().user?['weight'] as num?)?.toDouble();
    // Guard against nonsense values from a mis-typed profile.
    if (weight != null && weight >= 25 && weight <= 350) return weight;
    return _fallbackWeightKg;
  }

  /// Kilocalories per kilogram of body weight per kilometre travelled.
  ///
  /// Running costs roughly 1 kcal/kg/km; walking about half that for the same
  /// ground, because it is a far more efficient gait. Cycling is lower again
  /// since the machine carries the weight.
  static const Map<String, double> _kcalPerKgPerKm = {
    'running': 1.036,
    'walking': 0.53,
    'hiking': 0.75,
    'cycling': 0.28,
    'swimming': 2.20,
    'rowing': 0.90,
    'kayaking': 0.85,
    'skiing': 0.90,
    'snowboarding': 0.75,
    'roller skating': 0.60,
    'skateboarding': 0.55,
  };

  /// Metabolic equivalents for activities that do not cover measurable ground.
  /// 1 MET is resting; the value is a multiple of that.
  static const Map<String, double> _mets = {
    'gym workout': 5.0,
    'football': 7.0,
    'basketball': 6.5,
    'tennis': 7.3,
    'badminton': 5.5,
    'cricket': 4.8,
    'boxing': 7.8,
    'yoga': 2.5,
    'martial arts': 10.3,
    'rock climbing': 8.0,
    'golf': 4.8,
    'volleyball': 4.0,
  };

  static const double _defaultKcalPerKgPerKm = 0.8;
  static const double _defaultMet = 5.0;

  /// Active calories for a workout measured by distance.
  ///
  /// Returns 0 when nothing has been covered — standing still burns resting
  /// calories, not active ones, and reporting otherwise is what made a
  /// stationary phone look like a workout.
  static int fromDistance({
    required String activity,
    required double distanceKm,
  }) {
    if (distanceKm <= 0) return 0;
    final rate = _kcalPerKgPerKm[activity.toLowerCase()] ??
        _defaultKcalPerKgPerKm;
    return (rate * _weightKg * distanceKm).round();
  }

  /// Active calories for a workout measured by time, net of the resting burn
  /// the athlete would have had anyway.
  static int fromDuration({
    required String activity,
    required int elapsedSeconds,
  }) {
    if (elapsedSeconds <= 0) return 0;
    final met = _mets[activity.toLowerCase()] ?? _defaultMet;
    final hours = elapsedSeconds / 3600;
    // The classic MET formula gives total burn; subtracting one MET leaves
    // what the activity itself added.
    return ((met - 1) * _weightKg * hours).round();
  }

  /// Picks whichever model suits the activity.
  ///
  /// [tracksDistance] says whether this workout is one the app measures with
  /// GPS. When it is but nothing has been covered yet, the answer is zero
  /// rather than a time-based guess — the athlete has not moved.
  static int estimate({
    required String activity,
    required int elapsedSeconds,
    required double distanceKm,
    required bool tracksDistance,
  }) {
    if (tracksDistance) {
      return fromDistance(activity: activity, distanceKm: distanceKm);
    }
    return fromDuration(activity: activity, elapsedSeconds: elapsedSeconds);
  }
}
