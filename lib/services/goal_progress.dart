/// Turns logged activities into the day sets the analytics screen draws from.
///
/// Everything works in the athlete's local calendar days: a run at 1am belongs
/// to that day where they live, not wherever the server happens to be.
class GoalProgress {
  const GoalProgress._();

  static const double _kmPerMile = 1.60934;

  /// Local days on which anything at all was logged.
  ///
  /// This is what the calendar marks and what the streak counts. It is
  /// deliberately independent of goals — a goal has its own period, and one
  /// user can hold several with different periods, so there is no single
  /// per-day pass/fail that a calendar could show.
  static Set<DateTime> activeDays(List<dynamic> activities) {
    final days = <DateTime>{};
    for (final raw in activities) {
      if (raw is! Map) continue;
      final when = DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toLocal();
      if (when == null) continue;
      days.add(DateTime(when.year, when.month, when.day));
    }
    return days;
  }

  /// How many activities were logged on each local calendar day.
  ///
  /// The calendar shades a day by this count rather than just marking it, so
  /// a day with one short walk reads differently from a day with five sessions.
  static Map<DateTime, int> activityCountsByDay(List<dynamic> activities) {
    final counts = <DateTime, int>{};
    for (final raw in activities) {
      if (raw is! Map) continue;
      final when = DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toLocal();
      if (when == null) continue;
      final day = DateTime(when.year, when.month, when.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  /// The calendar's shade for a day: 0 for nothing logged, 1 for a single
  /// activity, 2 for two to four, 3 for five or more.
  static int activityDensityLevel(int count) {
    if (count <= 0) return 0;
    if (count == 1) return 1;
    if (count <= 4) return 2;
    return 3;
  }

  /// Consecutive days ending today, or yesterday.
  ///
  /// Today is allowed to be empty without breaking the run — the day is not
  /// over yet, and a streak that reset every midnight would be unusable.
  static int currentStreak(Set<DateTime> days, {DateTime? now}) {
    if (days.isEmpty) return 0;
    final today = now ?? DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);

    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// The longest run of consecutive days anywhere in the data.
  static int longestStreak(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final sorted = days.toList()..sort();

    var longest = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      run = sorted[i].difference(sorted[i - 1]).inDays == 1 ? run + 1 : 1;
      if (run > longest) longest = run;
    }
    return longest;
  }

  /// Whether an activity counts toward a goal set for [goalActivity].
  ///
  /// An exact, case-insensitive match on the activity name. A Running goal is
  /// satisfied by a Running session and nothing else — not a Trail Run, not a
  /// walk. An empty goal activity counts everything.
  static bool countsToward(String goalActivity, String activityType) {
    final goal = goalActivity.trim().toLowerCase();
    if (goal.isEmpty) return true;
    return activityType.trim().toLowerCase() == goal;
  }

  /// Total achieved toward a goal over the period the goal is set for.
  ///
  /// The target is evaluated whole, over its own window — a 50 km weekly goal
  /// is measured against the week, never split into a daily share. Splitting
  /// it is what made "4 sessions weekly" collapse into the nonsense of
  /// "0.57 sessions a day".
  ///
  /// Returns the value reached in the canonical unit for the goal's metric:
  /// kilometres, minutes, kilocalories, or a session count.
  static double achievedInPeriod(
    Map<String, dynamic> goal,
    List<dynamic> activities, {
    DateTime? now,
  }) {
    final metric = '${goal['metric'] ?? 'Distance'}';
    final activity = '${goal['activity'] ?? ''}';
    final start = periodStart(goal, now: now);

    var total = 0.0;
    for (final raw in activities) {
      if (raw is! Map) continue;
      final act = Map<String, dynamic>.from(raw);
      if (!countsToward(activity, '${act['type'] ?? ''}')) continue;

      final when = DateTime.tryParse('${act['createdAt'] ?? ''}')?.toLocal();
      if (when == null || when.isBefore(start)) continue;

      total += switch (metric) {
        'Distance' => ((act['distance'] as num?)?.toDouble() ?? 0) / 1000,
        'Duration' => ((act['duration'] as num?)?.toDouble() ?? 0) / 60,
        'Calories' => (act['calories'] as num?)?.toDouble() ?? 0,
        _ => 1.0,
      };
    }
    return total;
  }

  /// Midnight on the Monday of the week containing [day].
  ///
  /// Weeks run Monday to Sunday, matching HealthService, so every "this week"
  /// figure in the app covers the same seven days.
  static DateTime weekStart(DateTime day) {
    final midnight = DateTime(day.year, day.month, day.day);
    return midnight.subtract(Duration(days: (day.weekday + 6) % 7));
  }

  /// Midnight at the start of the goal's current period.
  static DateTime periodStart(Map<String, dynamic> goal, {DateTime? now}) {
    final today = now ?? DateTime.now();
    final midnight = DateTime(today.year, today.month, today.day);
    final frequency =
        '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}'.toLowerCase();

    return switch (frequency) {
      'daily' => midnight,
      'monthly' => DateTime(today.year, today.month, 1),
      _ => weekStart(today),
    };
  }

  /// What has been logged since Monday: sessions, kilometres and kilocalories.
  ///
  /// The server also reports a weekly block, but it covers a rolling seven days
  /// from right now — a different week from the Monday-to-Sunday one the goal
  /// rings and the health service use. Two "this week" numbers that disagree on
  /// screen is worse than one worked out on the only side that knows the
  /// athlete's timezone.
  static ({int workouts, double distanceKm, int calories}) weekToDateTotals(
    List<dynamic> activities, {
    DateTime? now,
  }) {
    final start = weekStart(now ?? DateTime.now());

    var workouts = 0;
    var meters = 0.0;
    var calories = 0;
    for (final raw in activities) {
      if (raw is! Map) continue;
      final when = DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toLocal();
      if (when == null || when.isBefore(start)) continue;
      workouts++;
      meters += (raw['distance'] as num?)?.toDouble() ?? 0;
      calories += ((raw['calories'] as num?) ?? 0).toInt();
    }

    return (
      workouts: workouts,
      distanceKm: meters / 1000,
      calories: calories,
    );
  }

  /// How many consecutive periods, ending with the current one, met the goal.
  ///
  /// The unit is the goal's own: a daily goal streaks in days, a weekly goal in
  /// weeks, a monthly goal in months. There is no common per-day pass/fail
  /// across goals of different periods, which is exactly why each carries its
  /// own count.
  ///
  /// The period in progress does not break the run — a week is not a failure
  /// until it is over.
  static int periodStreak(
    Map<String, dynamic> goal,
    List<dynamic> activities, {
    DateTime? now,
    int maxLookBack = 260,
  }) {
    final target = targetOf(goal);
    if (target == null) return 0;

    final today = now ?? DateTime.now();
    var streak = 0;

    for (var back = 0; back < maxLookBack; back++) {
      final reference = _shiftPeriods(goal, today, -back);
      final start = periodStart(goal, now: reference);
      final end = _nextPeriodStart(goal, start);
      final achieved = _sumBetween(goal, activities, start, end);

      if (achieved + 1e-9 >= target) {
        streak++;
        continue;
      }
      // The current period is still open, so falling short of it so far is not
      // a broken streak — only a finished period counts against you.
      if (back == 0) continue;
      break;
    }
    return streak;
  }

  /// Total achieved over the whole period that contains [date].
  ///
  /// Unlike [achievedInPeriod], which runs from the period's start to now, this
  /// is bounded at both ends — so tapping a day last month reports what that
  /// month came to, not everything since.
  static double achievedInPeriodContaining(
    Map<String, dynamic> goal,
    List<dynamic> activities,
    DateTime date,
  ) {
    final start = periodStart(goal, now: date);
    return _sumBetween(goal, activities, start, _nextPeriodStart(goal, start));
  }

  /// Names the period containing [date] — "Mon 31 Aug – Sun 6 Sep", "September",
  /// or the day itself — so a bar on a day sheet says what it is measuring.
  static String periodLabelFor(Map<String, dynamic> goal, DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const shortMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    final frequency =
        '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}'.toLowerCase();
    final start = periodStart(goal, now: date);

    switch (frequency) {
      case 'daily':
        return 'This day';
      case 'monthly':
        return months[start.month - 1];
      default:
        final end = start.add(const Duration(days: 6));
        return '${start.day} ${shortMonths[start.month - 1]} – '
            '${end.day} ${shortMonths[end.month - 1]}';
    }
  }

  /// Every activity logged on one local calendar day, newest first.
  static List<Map<String, dynamic>> activitiesOn(
    List<dynamic> activities,
    DateTime date,
  ) {
    final matches = <Map<String, dynamic>>[];
    for (final raw in activities) {
      if (raw is! Map) continue;
      final act = Map<String, dynamic>.from(raw);
      final when = DateTime.tryParse('${act['createdAt'] ?? ''}')?.toLocal();
      if (when == null) continue;
      if (when.year == date.year &&
          when.month == date.month &&
          when.day == date.day) {
        matches.add(act);
      }
    }
    matches.sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));
    return matches;
  }

  /// Label for a streak in the goal's own unit, e.g. "3 weeks".
  static String streakLabel(Map<String, dynamic> goal, int streak) {
    final frequency =
        '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}'.toLowerCase();
    final unit = switch (frequency) {
      'daily' => 'day',
      'monthly' => 'month',
      _ => 'week',
    };
    return '$streak $unit${streak == 1 ? '' : 's'}';
  }

  /// Moves a date [count] whole periods, used to walk a streak backwards.
  static DateTime _shiftPeriods(
      Map<String, dynamic> goal, DateTime from, int count) {
    final frequency =
        '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}'.toLowerCase();
    return switch (frequency) {
      'daily' => from.add(Duration(days: count)),
      // Day 15 keeps the arithmetic clear of month-length edges: stepping back
      // from the 31st must not skip a 30-day month.
      'monthly' => DateTime(from.year, from.month + count, 15),
      _ => from.add(Duration(days: count * 7)),
    };
  }

  static DateTime _nextPeriodStart(Map<String, dynamic> goal, DateTime start) {
    final frequency =
        '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}'.toLowerCase();
    return switch (frequency) {
      'daily' => start.add(const Duration(days: 1)),
      'monthly' => DateTime(start.year, start.month + 1, 1),
      _ => start.add(const Duration(days: 7)),
    };
  }

  static double _sumBetween(
    Map<String, dynamic> goal,
    List<dynamic> activities,
    DateTime start,
    DateTime end,
  ) {
    final metric = '${goal['metric'] ?? 'Distance'}';
    final activity = '${goal['activity'] ?? ''}';

    var total = 0.0;
    for (final raw in activities) {
      if (raw is! Map) continue;
      final act = Map<String, dynamic>.from(raw);
      if (!countsToward(activity, '${act['type'] ?? ''}')) continue;

      final when = DateTime.tryParse('${act['createdAt'] ?? ''}')?.toLocal();
      if (when == null || when.isBefore(start) || !when.isBefore(end)) continue;

      total += switch (metric) {
        'Distance' => ((act['distance'] as num?)?.toDouble() ?? 0) / 1000,
        'Duration' => ((act['duration'] as num?)?.toDouble() ?? 0) / 60,
        'Calories' => (act['calories'] as num?)?.toDouble() ?? 0,
        _ => 1.0,
      };
    }
    return total;
  }

  /// The goal's target in the canonical unit — kilometres for a distance goal,
  /// whatever was entered otherwise.
  static double? targetOf(Map<String, dynamic>? goal) {
    if (goal == null) return null;
    final raw = (goal['targetValue'] as num?)?.toDouble();
    if (raw == null || raw <= 0) return null;

    final isDistance = '${goal['metric'] ?? ''}' == 'Distance';
    final inMiles = '${goal['unit'] ?? ''}'.toLowerCase().contains('mile');
    return isDistance && inMiles ? raw * _kmPerMile : raw;
  }
}
