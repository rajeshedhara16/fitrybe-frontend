import 'package:flutter/foundation.dart';

/// Which system an athlete reads their numbers in.
enum UnitSystem { metric, imperial }

/// Formats every measurement the app shows.
///
/// Nothing stored is ever converted. Distances stay in metres, weights in
/// kilograms, pace in minutes per kilometre, whatever this is set to. Switching
/// changes only what is drawn, so it can never corrupt a logged workout and a
/// goal set in one system still measures correctly in the other.
///
/// The consequence, and the reason this class exists rather than a scattering
/// of `toStringAsFixed(1)} km` across eighteen files, is that a conversion done
/// in one place is a conversion done everywhere.
class Units {
  const Units._();

  static const double _kmPerMile = 1.60934;
  static const double _feetPerMetre = 3.28084;
  static const double _poundsPerKg = 2.20462;
  static const double _inchesPerCm = 0.393701;

  /// The current preference, and a way to rebuild on a change.
  ///
  /// Screens that are already on-screen when it flips can listen; everything
  /// else picks it up on its next build.
  static final ValueNotifier<UnitSystem> notifier =
      ValueNotifier<UnitSystem>(UnitSystem.metric);

  static UnitSystem get system => notifier.value;

  static bool get isImperial => notifier.value == UnitSystem.imperial;

  /// Adopts whatever the server says this account uses. Anything unrecognised
  /// falls back to metric rather than throwing, since a display preference is
  /// never worth an exception.
  static void adopt(Object? raw) {
    notifier.value =
        '$raw'.toUpperCase() == 'IMPERIAL' ? UnitSystem.imperial : UnitSystem.metric;
  }

  static String get systemName => isImperial ? 'IMPERIAL' : 'METRIC';

  // ── Distance ──────────────────────────────────────────────────────────────

  /// The bare unit label, for a value shown separately.
  static String get distanceUnit => isImperial ? 'mi' : 'km';

  /// Metres converted to the displayed unit, as a number with no label.
  static double distanceFrom(num metres) {
    final km = metres / 1000;
    return isImperial ? km / _kmPerMile : km;
  }

  /// Kilometres converted to the displayed unit, for the many API fields that
  /// already arrive in kilometres.
  static double fromKm(num km) => isImperial ? km / _kmPerMile : km.toDouble();

  /// Explicit conversions, independent of the current preference.
  ///
  /// A goal saved in one unit has to be redrawn in the other, and that has to
  /// work regardless of which way round the athlete is reading today.
  static double toKmFromMiles(num miles) => miles * _kmPerMile;

  static double kmToMiles(num km) => km / _kmPerMile;

  /// Back the other way, for a value the athlete typed.
  static double toKm(num entered) =>
      isImperial ? entered * _kmPerMile : entered.toDouble();

  /// "12.4 km" or "7.7 mi".
  static String distance(num metres, {int decimals = 2}) =>
      '${distanceFrom(metres).toStringAsFixed(decimals)} $distanceUnit';

  /// Same, for a value already in kilometres.
  static String distanceKm(num km, {int decimals = 2}) =>
      '${fromKm(km).toStringAsFixed(decimals)} $distanceUnit';

  // ── Pace ──────────────────────────────────────────────────────────────────

  static String get paceUnit => isImperial ? '/mi' : '/km';

  /// Minutes per kilometre converted to minutes per displayed unit, unformatted.
  ///
  /// For callers with their own layout, such as the recorder's 5'30" styling.
  /// Formatting differs between screens; the arithmetic must not.
  static double paceFrom(num minutesPerKm) =>
      isImperial ? minutesPerKm * _kmPerMile : minutesPerKm.toDouble();

  /// Minutes per kilometre rendered as "5:42 /km" or "9:11 /mi".
  ///
  /// Pace inverts distance: covering a longer unit takes more time, so minutes
  /// per mile is the per-kilometre figure multiplied, not divided.
  static String pace(num? minutesPerKm) {
    if (minutesPerKm == null || minutesPerKm <= 0) return '--';
    final value = paceFrom(minutesPerKm);
    final mins = value.floor();
    final secs = ((value - mins) * 60).round();
    // 59.6 seconds rounds to 60, which must read as the next minute rather
    // than "5:60".
    if (secs == 60) return '${mins + 1}:00 $paceUnit';
    return '$mins:${secs.toString().padLeft(2, '0')} $paceUnit';
  }

  // ── Speed ─────────────────────────────────────────────────────────────────

  static String get speedUnit => isImperial ? 'mph' : 'km/h';

  static String speed(num? kmh, {int decimals = 1}) {
    if (kmh == null) return '--';
    final value = isImperial ? kmh / _kmPerMile : kmh.toDouble();
    return '${value.toStringAsFixed(decimals)} $speedUnit';
  }

  // ── Elevation ─────────────────────────────────────────────────────────────

  static String get elevationUnit => isImperial ? 'ft' : 'm';

  static String elevation(num? metres) {
    if (metres == null) return '--';
    final value = isImperial ? metres * _feetPerMetre : metres.toDouble();
    return '${value.round()} $elevationUnit';
  }

  // ── Body measurements ─────────────────────────────────────────────────────

  static String get weightUnit => isImperial ? 'lb' : 'kg';

  static double weightFrom(num kg) =>
      isImperial ? kg * _poundsPerKg : kg.toDouble();

  static double weightToKg(num entered) =>
      isImperial ? entered / _poundsPerKg : entered.toDouble();

  static String weight(num? kg, {int decimals = 1}) {
    if (kg == null) return '--';
    return '${weightFrom(kg).toStringAsFixed(decimals)} $weightUnit';
  }

  static String get heightUnit => isImperial ? 'ft/in' : 'cm';

  /// Centimetres as "178 cm" or "5'10"".
  ///
  /// Feet and inches are two numbers rather than a decimal, because nobody
  /// reads their own height as 5.83 feet.
  static String height(num? cm) {
    if (cm == null) return '--';
    if (!isImperial) return '${cm.round()} cm';

    final totalInches = (cm * _inchesPerCm).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$feet'$inches\"";
  }
}
