import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/goal_progress.dart';

/// An activity as the API returns it.
Map<String, dynamic> act({
  required DateTime on,
  String type = 'Running',
  double distanceM = 0,
  int durationS = 0,
  int calories = 0,
}) =>
    {
      'createdAt': on.toUtc().toIso8601String(),
      'type': type,
      'distance': distanceM,
      'duration': durationS,
      'calories': calories,
    };

Map<String, dynamic> goal({
  String metric = 'Distance',
  String activity = 'Running',
  num target = 50,
  String unit = 'Km',
  String frequency = 'Weekly',
}) =>
    {
      'metric': metric,
      'activity': activity,
      'targetValue': target,
      'unit': unit,
      'frequency': frequency,
    };

DateTime day(int daysAgo) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: daysAgo))
      .add(const Duration(hours: 9));
}

void main() {
  group('active days', () {
    test('a logged day is active whatever was done', () {
      final days = GoalProgress.activeDays([
        act(on: day(1), type: 'Yoga', durationS: 600),
      ]);
      expect(days, hasLength(1));
    });

    test('several sessions on one day count as one day', () {
      final days = GoalProgress.activeDays([
        act(on: day(1), distanceM: 3000),
        act(on: day(1), distanceM: 4000),
      ]);
      expect(days, hasLength(1));
    });

    test('a day with nothing logged is not active', () {
      final days = GoalProgress.activeDays([act(on: day(3))]);
      expect(days.contains(DateTime(day(1).year, day(1).month, day(1).day)),
          isFalse);
    });

    test('malformed rows are skipped rather than throwing', () {
      final days = GoalProgress.activeDays([
        {'createdAt': null},
        'not a map',
        act(on: day(1)),
      ]);
      expect(days, hasLength(1));
    });
  });

  group('streaks', () {
    Set<DateTime> daysMeeting(List<int> daysAgo) =>
        GoalProgress.activeDays([for (final d in daysAgo) act(on: day(d))]);

    test('consecutive days count', () {
      expect(GoalProgress.currentStreak(daysMeeting([0, 1, 2])), 3);
    });

    test('today being empty does not break the run', () {
      expect(GoalProgress.currentStreak(daysMeeting([1, 2, 3])), 3);
    });

    test('a gap ends the streak', () {
      expect(GoalProgress.currentStreak(daysMeeting([0, 1, 3, 4])), 2);
    });

    test('an old run that has lapsed counts for nothing today', () {
      expect(GoalProgress.currentStreak(daysMeeting([5, 6, 7])), 0);
    });

    test('no activity means no streak', () {
      expect(GoalProgress.currentStreak({}), 0);
    });

    test('the longest run is found anywhere in the history', () {
      expect(GoalProgress.longestStreak(daysMeeting([0, 2, 3, 4, 5, 8])), 4);
    });

    test('a streak spanning a month boundary is not cut short', () {
      expect(
        GoalProgress.longestStreak({
          DateTime(2026, 1, 30),
          DateTime(2026, 1, 31),
          DateTime(2026, 2, 1),
          DateTime(2026, 2, 2),
        }),
        4,
      );
    });
  });

  group('activity matching is exact', () {
    test('the same activity matches', () {
      expect(GoalProgress.countsToward('Running', 'Running'), isTrue);
    });

    test('a near-miss name does not satisfy a goal', () {
      // Matching is on the whole name, not a substring, so a goal cannot be
      // met by something that merely contains or is contained by its name.
      expect(GoalProgress.countsToward('Swimming', 'Swim'), isFalse);
      expect(GoalProgress.countsToward('Gym', 'Gym Workout'), isFalse);
    });

    test('a gym workout does not satisfy a running goal', () {
      expect(GoalProgress.countsToward('Running', 'Gym Workout'), isFalse);
    });

    test('only case and surrounding space are forgiven', () {
      expect(GoalProgress.countsToward('running', ' Running '), isTrue);
    });

    test('a goal with no activity counts everything', () {
      expect(GoalProgress.countsToward('', 'Kayaking'), isTrue);
    });
  });

  group('a goal is measured over its own period, never split', () {
    test('a weekly goal counts the whole week', () {
      // Four runs across one week. A weekly target is met by their sum, not by
      // any single day reaching a seventh of it.
      //
      // The reference date is pinned: relative days would drift in and out of
      // the Monday-start week depending on which weekday the suite runs.
      final thursday = DateTime(2026, 9, 3, 12);
      final total = GoalProgress.achievedInPeriod(
        goal(target: 40, frequency: 'Weekly'),
        [
          act(on: DateTime(2026, 9, 3, 7), distanceM: 12000),
          act(on: DateTime(2026, 9, 2, 7), distanceM: 10000),
          act(on: DateTime(2026, 9, 1, 7), distanceM: 11000),
          act(on: DateTime(2026, 8, 31, 7), distanceM: 9000), // that Monday
        ],
        now: thursday,
      );
      expect(total, closeTo(42, 0.001));
    });

    test('a weekly goal excludes the week before', () {
      final thursday = DateTime(2026, 9, 3, 12);
      final total = GoalProgress.achievedInPeriod(
        goal(target: 40, frequency: 'Weekly'),
        [
          act(on: DateTime(2026, 9, 1, 7), distanceM: 10000),
          act(on: DateTime(2026, 8, 30, 7), distanceM: 30000), // Sunday before
        ],
        now: thursday,
      );
      expect(total, closeTo(10, 0.001));
    });

    test('a daily goal counts only today', () {
      final total = GoalProgress.achievedInPeriod(
        goal(target: 5, frequency: 'Daily'),
        [
          act(on: day(0), distanceM: 6000),
          act(on: day(1), distanceM: 20000),
        ],
      );
      expect(total, closeTo(6, 0.001));
    });

    test('a sessions goal counts sessions, with no rounding needed', () {
      // Four sessions a week is four sessions a week. It is never restated as
      // a fraction of a day, which is what forced the old round-up.
      final thursday = DateTime(2026, 9, 3, 12);
      final total = GoalProgress.achievedInPeriod(
        goal(metric: 'Sessions', target: 4, frequency: 'Weekly'),
        [
          act(on: DateTime(2026, 9, 3, 7)),
          act(on: DateTime(2026, 9, 2, 7)),
          act(on: DateTime(2026, 9, 1, 7)),
        ],
        now: thursday,
      );
      expect(total, 3);
    });

    test('a duration goal counts minutes', () {
      final total = GoalProgress.achievedInPeriod(
        goal(metric: 'Duration', target: 45, frequency: 'Daily'),
        [act(on: day(0), durationS: 2700)],
      );
      expect(total, closeTo(45, 0.001));
    });

    test('activities of another type contribute nothing', () {
      final total = GoalProgress.achievedInPeriod(
        goal(activity: 'Running', frequency: 'Weekly'),
        [act(on: day(0), type: 'Cycling', distanceM: 40000)],
      );
      expect(total, 0);
    });

    test('activity before the period start is excluded', () {
      final total = GoalProgress.achievedInPeriod(
        goal(frequency: 'Daily'),
        [act(on: day(2), distanceM: 30000)],
      );
      expect(total, 0);
    });
  });

  group('targets', () {
    test('a kilometre target is taken as typed', () {
      expect(GoalProgress.targetOf(goal(target: 50, unit: 'Km')), 50);
    });

    test('a mile target converts to kilometres', () {
      expect(
        GoalProgress.targetOf(goal(target: 10, unit: 'Miles')),
        closeTo(16.09, 0.01),
      );
    });

    test('only distance goals are converted', () {
      expect(
        GoalProgress.targetOf(
          goal(metric: 'Calories', target: 500, unit: 'Kcal'),
        ),
        500,
      );
    });

    test('no goal, or an empty target, gives nothing', () {
      expect(GoalProgress.targetOf(null), isNull);
      expect(GoalProgress.targetOf(goal(target: 0)), isNull);
    });
  });

  group('period boundaries', () {
    test('a daily period starts at midnight today', () {
      final start = GoalProgress.periodStart(
        goal(frequency: 'Daily'),
        now: DateTime(2026, 9, 3, 14, 30),
      );
      expect(start, DateTime(2026, 9, 3));
    });

    test('a weekly period starts on Monday', () {
      // 3 September 2026 is a Thursday.
      final start = GoalProgress.periodStart(
        goal(frequency: 'Weekly'),
        now: DateTime(2026, 9, 3, 14, 30),
      );
      expect(start, DateTime(2026, 8, 31));
    });

    test('a weekly period on a Monday starts that same day', () {
      final start = GoalProgress.periodStart(
        goal(frequency: 'Weekly'),
        now: DateTime(2026, 8, 31, 6, 0),
      );
      expect(start, DateTime(2026, 8, 31));
    });

    test('a monthly period starts on the first', () {
      final start = GoalProgress.periodStart(
        goal(frequency: 'Monthly'),
        now: DateTime(2026, 9, 17, 23, 0),
      );
      expect(start, DateTime(2026, 9, 1));
    });
  });

  group('this week on the home card', () {
    // Thursday 3 September 2026, so the week began Monday 31 August.
    final thursday = DateTime(2026, 9, 3, 18, 0);

    test('counts everything logged since Monday', () {
      final totals = GoalProgress.weekToDateTotals([
        act(on: DateTime(2026, 8, 31, 7), distanceM: 5000, calories: 300),
        act(on: DateTime(2026, 9, 2, 19), distanceM: 8000, calories: 500),
        act(on: DateTime(2026, 9, 3, 6), distanceM: 2000, calories: 120),
      ], now: thursday);

      expect(totals.workouts, 3);
      expect(totals.distanceKm, closeTo(15, 1e-9));
      expect(totals.calories, 920);
    });

    test('the week before does not count', () {
      final totals = GoalProgress.weekToDateTotals([
        act(on: DateTime(2026, 8, 30, 10), distanceM: 20000, calories: 900),
        act(on: DateTime(2026, 9, 1, 10), distanceM: 4000, calories: 200),
      ], now: thursday);

      expect(totals.workouts, 1);
      expect(totals.distanceKm, closeTo(4, 1e-9));
      expect(totals.calories, 200);
    });

    test('every activity counts, whatever the type', () {
      final totals = GoalProgress.weekToDateTotals([
        act(on: DateTime(2026, 9, 1, 8), type: 'Yoga', durationS: 3600),
        act(on: DateTime(2026, 9, 2, 8), type: 'Cycling', distanceM: 30000),
      ], now: thursday);

      expect(totals.workouts, 2);
      expect(totals.distanceKm, closeTo(30, 1e-9));
    });

    test('nothing logged reads as zero, not as missing', () {
      final totals = GoalProgress.weekToDateTotals(const [], now: thursday);

      expect(totals.workouts, 0);
      expect(totals.distanceKm, 0);
      expect(totals.calories, 0);
    });

    test('a Monday counts that same day', () {
      final totals = GoalProgress.weekToDateTotals([
        act(on: DateTime(2026, 8, 31, 5), distanceM: 3000),
      ], now: DateTime(2026, 8, 31, 9));

      expect(totals.workouts, 1);
    });
  });

  group('per-period streaks', () {
    // Sunday 6 September 2026, so "this week" is Mon 31 Aug - Sun 6 Sep.
    final sunday = DateTime(2026, 9, 6, 12);

    List<Map<String, dynamic>> runsOn(List<DateTime> days, {double km = 10}) =>
        [for (final d in days) act(on: d, distanceM: km * 1000)];

    test('a daily goal streaks in days', () {
      final g = goal(target: 5, frequency: 'Daily');
      final activities = runsOn([
        sunday,
        sunday.subtract(const Duration(days: 1)),
        sunday.subtract(const Duration(days: 2)),
      ]);
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 3);
      expect(GoalProgress.streakLabel(g, 3), '3 days');
    });

    test('a weekly goal streaks in weeks, not days', () {
      final g = goal(target: 20, frequency: 'Weekly');
      // One 25km run in each of three consecutive weeks. Three weeks, not
      // three days, and the empty days between do not break it.
      final activities = runsOn([
        sunday,
        sunday.subtract(const Duration(days: 7)),
        sunday.subtract(const Duration(days: 14)),
      ], km: 25);
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 3);
      expect(GoalProgress.streakLabel(g, 3), '3 weeks');
    });

    test('a missed week ends a weekly streak', () {
      final g = goal(target: 20, frequency: 'Weekly');
      final activities = runsOn([
        sunday,
        // nothing in the previous week
        sunday.subtract(const Duration(days: 14)),
      ], km: 25);
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 1);
    });

    test('a monthly goal streaks in months', () {
      final g = goal(target: 30, frequency: 'Monthly');
      final activities = runsOn([
        DateTime(2026, 9, 4, 10),
        DateTime(2026, 8, 12, 10),
        DateTime(2026, 7, 20, 10),
      ], km: 40);
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 3);
      expect(GoalProgress.streakLabel(g, 1), '1 month');
    });

    test('the period in progress does not break the streak', () {
      final g = goal(target: 20, frequency: 'Weekly');
      // Nothing yet this week, but the two before were met. The week is not
      // over, so it is not yet a failure.
      final activities = runsOn([
        sunday.subtract(const Duration(days: 7)),
        sunday.subtract(const Duration(days: 14)),
      ], km: 25);
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 2);
    });

    test('goals of different periods streak independently', () {
      final daily = goal(activity: 'Running', target: 5, frequency: 'Daily');
      final weekly = goal(activity: 'Cycling', target: 50, frequency: 'Weekly');

      final activities = [
        // Running every day for four days.
        for (var d = 0; d < 4; d++)
          act(
            on: sunday.subtract(Duration(days: d)),
            type: 'Running',
            distanceM: 6000,
          ),
        // One long ride in each of the last two weeks.
        act(on: sunday, type: 'Cycling', distanceM: 60000),
        act(
          on: sunday.subtract(const Duration(days: 7)),
          type: 'Cycling',
          distanceM: 60000,
        ),
      ];

      expect(GoalProgress.periodStreak(daily, activities, now: sunday), 4);
      expect(GoalProgress.periodStreak(weekly, activities, now: sunday), 2);
    });

    test('activities of the wrong type never feed a streak', () {
      final g = goal(activity: 'Running', target: 5, frequency: 'Daily');
      final activities = runsOn([sunday], km: 20)
          .map((a) => {...a, 'type': 'Cycling'})
          .toList();
      expect(GoalProgress.periodStreak(g, activities, now: sunday), 0);
    });

    test('a goal with no target has no streak', () {
      final g = goal(target: 0, frequency: 'Daily');
      expect(GoalProgress.periodStreak(g, runsOn([sunday]), now: sunday), 0);
    });
  });

  group('a tapped day', () {
    // Thursday 3 September 2026. Week runs Mon 31 Aug - Sun 6 Sep.
    final thursday = DateTime(2026, 9, 3);

    test('lists only the sessions from that day, newest first', () {
      final found = GoalProgress.activitiesOn(
        [
          act(on: DateTime(2026, 9, 3, 7), distanceM: 5000),
          act(on: DateTime(2026, 9, 3, 18), distanceM: 8000),
          act(on: DateTime(2026, 9, 2, 18), distanceM: 9000),
        ],
        thursday,
      );
      expect(found, hasLength(2));
      expect((found.first['distance'] as num), 8000); // the 18:00 one
    });

    test('a day with nothing logged lists nothing', () {
      expect(
        GoalProgress.activitiesOn([act(on: DateTime(2026, 9, 2, 7))], thursday),
        isEmpty,
      );
    });

    test('a weekly bar covers the whole week containing that day', () {
      final total = GoalProgress.achievedInPeriodContaining(
        goal(target: 40, frequency: 'Weekly'),
        [
          act(on: DateTime(2026, 8, 31, 7), distanceM: 10000), // Mon, in
          act(on: DateTime(2026, 9, 6, 20), distanceM: 15000), // Sun, in
          act(on: DateTime(2026, 9, 7, 7), distanceM: 99000), // next Mon, out
          act(on: DateTime(2026, 8, 30, 7), distanceM: 99000), // prev Sun, out
        ],
        thursday,
      );
      expect(total, closeTo(25, 0.001));
    });

    test('a daily bar covers only that day', () {
      final total = GoalProgress.achievedInPeriodContaining(
        goal(target: 5, frequency: 'Daily'),
        [
          act(on: DateTime(2026, 9, 3, 7), distanceM: 6000),
          act(on: DateTime(2026, 9, 2, 7), distanceM: 40000),
        ],
        thursday,
      );
      expect(total, closeTo(6, 0.001));
    });

    test('a monthly bar stops at the month boundary', () {
      final total = GoalProgress.achievedInPeriodContaining(
        goal(target: 100, frequency: 'Monthly'),
        [
          act(on: DateTime(2026, 9, 1, 7), distanceM: 20000),
          act(on: DateTime(2026, 9, 30, 7), distanceM: 20000),
          act(on: DateTime(2026, 8, 31, 7), distanceM: 99000), // August, out
          act(on: DateTime(2026, 10, 1, 7), distanceM: 99000), // October, out
        ],
        thursday,
      );
      expect(total, closeTo(40, 0.001));
    });

    test('a past period reports what it came to, not everything since', () {
      final july = DateTime(2026, 7, 15);
      final total = GoalProgress.achievedInPeriodContaining(
        goal(target: 100, frequency: 'Monthly'),
        [
          act(on: DateTime(2026, 7, 10, 7), distanceM: 30000),
          act(on: DateTime(2026, 9, 3, 7), distanceM: 99000), // later, excluded
        ],
        july,
      );
      expect(total, closeTo(30, 0.001));
    });

    test('period labels name what the bar measures', () {
      expect(
        GoalProgress.periodLabelFor(goal(frequency: 'Daily'), thursday),
        'This day',
      );
      expect(
        GoalProgress.periodLabelFor(goal(frequency: 'Weekly'), thursday),
        '31 Aug – 6 Sep',
      );
      expect(
        GoalProgress.periodLabelFor(goal(frequency: 'Monthly'), thursday),
        'September',
      );
    });
  });
}
