import 'goal_progress.dart';

/// Who trained on one day of the shared timeline.
enum DayOverlap { none, you, them, both }

enum SynergyTier { none, starting, warming, buddies, inSync, perfect }

/// How in step two athletes' training has been over the last 30 days.
///
/// The score is the share of active days the two of you had in common: days
/// you both trained, out of days either of you trained. It is symmetric, so
/// both people see the same number about each other, and it rewards training
/// on the same days rather than simply training a lot.
///
/// Built from each athlete's own workout history as the server sends it, which
/// covers two years, so nothing here depends on a capped page of results.
class SynergyReport {
  const SynergyReport({
    required this.score,
    required this.sharedDays,
    required this.eitherActiveDays,
    required this.yourActiveDays,
    required this.theirActiveDays,
    required this.theirWorkouts,
    required this.theirDistanceKm,
    required this.theirStreak,
    required this.theirFavourite,
    required this.timelineDates,
    required this.timeline,
  });

  /// The comparison window, today included.
  static const int windowDays = 30;

  /// Days shown on the shared timeline, oldest first and ending today.
  static const int timelineDays = 14;

  /// 0 to 100.
  final int score;
  final int sharedDays;
  final int eitherActiveDays;
  final int yourActiveDays;
  final int theirActiveDays;

  /// Their workouts in the window, counted individually rather than by day.
  final int theirWorkouts;
  final double theirDistanceKm;

  /// Their current run of consecutive training days, from their full history.
  final int theirStreak;

  /// Their most frequent activity in the window, the most recent on a tie.
  final String? theirFavourite;

  final List<DateTime> timelineDates;
  final List<DayOverlap> timeline;

  factory SynergyReport.compute({
    required List<dynamic> mine,
    required List<dynamic> theirs,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final windowStart =
        DateTime(today.year, today.month, today.day - (windowDays - 1));

    bool inWindow(DateTime day) =>
        !day.isBefore(windowStart) && !day.isAfter(today);

    final myDays = GoalProgress.activeDays(mine).where(inWindow).toSet();
    final theirDays = GoalProgress.activeDays(theirs).where(inWindow).toSet();
    final shared = myDays.intersection(theirDays);
    final either = myDays.union(theirDays);

    var workouts = 0;
    var meters = 0.0;
    final typeCounts = <String, int>{};
    final typeLatest = <String, DateTime>{};
    for (final raw in theirs) {
      if (raw is! Map) continue;
      final at = DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toLocal();
      if (at == null || !inWindow(DateTime(at.year, at.month, at.day))) {
        continue;
      }
      workouts++;
      meters += (raw['distance'] as num?)?.toDouble() ?? 0;

      final type = '${raw['type'] ?? ''}'.trim();
      if (type.isEmpty) continue;
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      final previous = typeLatest[type];
      if (previous == null || at.isAfter(previous)) typeLatest[type] = at;
    }

    String? favourite;
    for (final type in typeCounts.keys) {
      if (favourite == null) {
        favourite = type;
        continue;
      }
      final count = typeCounts[type]!;
      final best = typeCounts[favourite]!;
      if (count > best ||
          (count == best && typeLatest[type]!.isAfter(typeLatest[favourite]!))) {
        favourite = type;
      }
    }

    final dates = [
      for (var back = timelineDays - 1; back >= 0; back--)
        DateTime(today.year, today.month, today.day - back),
    ];

    return SynergyReport(
      score: either.isEmpty ? 0 : (shared.length * 100 / either.length).round(),
      sharedDays: shared.length,
      eitherActiveDays: either.length,
      yourActiveDays: myDays.length,
      theirActiveDays: theirDays.length,
      theirWorkouts: workouts,
      theirDistanceKm: meters / 1000,
      theirStreak:
          GoalProgress.currentStreak(GoalProgress.activeDays(theirs), now: clock),
      theirFavourite: favourite,
      timelineDates: dates,
      timeline: [
        for (final day in dates)
          switch ((myDays.contains(day), theirDays.contains(day))) {
            (true, true) => DayOverlap.both,
            (true, false) => DayOverlap.you,
            (false, true) => DayOverlap.them,
            (false, false) => DayOverlap.none,
          },
      ],
    );
  }

  SynergyTier get tier {
    if (eitherActiveDays == 0) return SynergyTier.none;
    if (score >= 80) return SynergyTier.perfect;
    if (score >= 60) return SynergyTier.inSync;
    if (score >= 40) return SynergyTier.buddies;
    if (score >= 20) return SynergyTier.warming;
    return SynergyTier.starting;
  }

  String get tierLabel => switch (tier) {
        SynergyTier.none => 'No workouts yet',
        SynergyTier.starting => 'Just getting started',
        SynergyTier.warming => 'Warming up',
        SynergyTier.buddies => 'Training buddies',
        SynergyTier.inSync => 'In sync',
        SynergyTier.perfect => 'Perfect sync',
      };

  /// One plain sentence explaining the score.
  String get summary {
    String days(int n) => n == 1 ? '1 day' : '$n days';

    if (eitherActiveDays == 0) {
      return 'Neither of you has logged a workout in the last 30 days.';
    }
    if (yourActiveDays == 0) {
      return 'They trained on ${days(theirActiveDays)} in the last 30 days. '
          'Train on the same days as them to start syncing.';
    }
    if (theirActiveDays == 0) {
      return 'You trained on ${days(yourActiveDays)} in the last 30 days. '
          'They have not logged a workout yet.';
    }
    if (sharedDays == 0) {
      return 'You were both active, but never on the same day in the last 30 days.';
    }
    final times = sharedDays == 1 ? 'once' : '$sharedDays times';
    return 'You trained on the same day $times out of the '
        '${days(eitherActiveDays)} either of you was active.';
  }
}
