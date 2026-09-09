import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/goal_progress.dart';

/// Checks the two halves of the app against each other rather than each
/// against its own assumptions.
///
/// The fixture is a real capture from the API — three goals set through the
/// goal endpoint and six workouts logged through the activity endpoint, then
/// the exact `/goals` and `/activities/analytics` responses the analytics
/// screen receives. Regenerate it with:
///
///     node scripts/dump_contract_fixture.js   (in fitrybe-backend)
///
/// The scenario, all logged on the capture date:
///   goals      Daily Running 5 km · Weekly Cycling 50 km · Monthly Swimming 8 sessions
///   workouts   6 km Running, 20 km Walking, 60 km Cycling,
///              3 × Swimming (no pace sent), 1 × Gym Workout (no distance)
void main() {
  late Map<String, dynamic> fixture;
  late DateTime capturedAt;
  late List<dynamic> activities;
  late List<Map<String, dynamic>> goals;

  setUpAll(() {
    final file = File('test/fixtures/api_contract.json');
    expect(file.existsSync(), isTrue,
        reason: 'Run scripts/dump_contract_fixture.js in fitrybe-backend');
    fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

    // The capture date is the reference "now", so the fixture stays valid
    // however long after it was recorded the suite runs.
    capturedAt = DateTime.parse('${fixture['generatedAt']}').toLocal();
    activities = fixture['analytics']['recentActivities'] as List<dynamic>;
    goals = (fixture['goals']['goals'] as List<dynamic>)
        .map((g) => Map<String, dynamic>.from(g as Map))
        .toList();
  });

  Map<String, dynamic> goalFor(String period) =>
      goals.firstWhere((g) => '${g['period']}' == period);

  group('the shape both sides agreed on', () {
    test('/goals carries the list the picker and analytics screen read', () {
      expect(fixture['goals'], contains('goals'));
      expect(goals, hasLength(3));
      expect(
        goals.map((g) => '${g['period']}').toSet(),
        {'DAILY', 'WEEKLY', 'MONTHLY'},
      );
    });

    test('/analytics carries the keys the screen reads', () {
      final analytics = fixture['analytics'] as Map<String, dynamic>;
      for (final key in ['summary', 'recentActivities', 'records']) {
        expect(analytics, contains(key), reason: 'missing $key');
      }
    });

    test('each goal carries the fields the progress maths needs', () {
      for (final goal in goals) {
        for (final key in ['activity', 'metric', 'targetValue', 'unit', 'frequency']) {
          expect(goal, contains(key), reason: '${goal['period']} missing $key');
        }
      }
    });

    test('each activity carries the fields the screen reads', () {
      for (final raw in activities) {
        final act = raw as Map<String, dynamic>;
        for (final key in ['createdAt', 'type', 'duration', 'distance', 'calories']) {
          expect(act, contains(key), reason: 'activity missing $key');
        }
      }
    });

    test('no GPS traces are shipped to the analytics screen', () {
      for (final raw in activities) {
        expect((raw as Map).containsKey('routeData'), isFalse);
      }
    });
  });

  group('goal progress, end to end', () {
    test('the daily running goal is met by the 6 km run', () {
      final goal = goalFor('DAILY');
      final achieved =
          GoalProgress.achievedInPeriod(goal, activities, now: capturedAt);
      final target = GoalProgress.targetOf(goal);

      expect(target, 5);
      // 6 km run only. The 20 km walk is a different activity.
      expect(achieved, closeTo(6, 0.001));
      expect(achieved >= target!, isTrue);
    });

    test('a walk does not inflate the running goal', () {
      final achieved = GoalProgress.achievedInPeriod(
        goalFor('DAILY'),
        activities,
        now: capturedAt,
      );
      expect(achieved, lessThan(26),
          reason: 'the 20 km walk must not count toward Running');
    });

    test('the weekly cycling goal is met by the 60 km ride', () {
      final goal = goalFor('WEEKLY');
      final achieved =
          GoalProgress.achievedInPeriod(goal, activities, now: capturedAt);
      expect(GoalProgress.targetOf(goal), 50);
      expect(achieved, closeTo(60, 0.001));
    });

    test('the monthly swimming goal counts 3 of 8 sessions', () {
      final goal = goalFor('MONTHLY');
      final achieved =
          GoalProgress.achievedInPeriod(goal, activities, now: capturedAt);
      expect(GoalProgress.targetOf(goal), 8);
      expect(achieved, 3);
      expect(achieved / GoalProgress.targetOf(goal)!, closeTo(0.375, 0.001));
    });
  });

  group('streaks, end to end', () {
    test('each goal streaks in its own unit', () {
      expect(
        GoalProgress.periodStreak(goalFor('DAILY'), activities, now: capturedAt),
        1,
      );
      expect(GoalProgress.streakLabel(goalFor('DAILY'), 1), '1 day');
      expect(GoalProgress.streakLabel(goalFor('WEEKLY'), 1), '1 week');
      expect(GoalProgress.streakLabel(goalFor('MONTHLY'), 1), '1 month');
    });

    test('a goal that was met streaks, one that was not does not', () {
      // Cycling hit 60 of 50 this week.
      expect(
        GoalProgress.periodStreak(goalFor('WEEKLY'), activities, now: capturedAt),
        greaterThanOrEqualTo(1),
      );
      // Swimming reached 3 of 8 this month, and the month is still open, so
      // the run is not broken — it simply has not started.
      expect(
        GoalProgress.periodStreak(goalFor('MONTHLY'), activities, now: capturedAt),
        0,
      );
    });
  });

  group('the calendar, end to end', () {
    test('the capture day is an active day', () {
      final days = GoalProgress.activeDays(activities);
      final today =
          DateTime(capturedAt.year, capturedAt.month, capturedAt.day);
      expect(days, contains(today));
    });

    test('the calendar streak counts it', () {
      final days = GoalProgress.activeDays(activities);
      expect(GoalProgress.currentStreak(days, now: capturedAt), 1);
    });

    test('tapping that day lists every session logged on it', () {
      final found = GoalProgress.activitiesOn(activities, capturedAt);
      expect(found, hasLength(7));
    });

    test('the day sheet bars agree with the goal cards', () {
      for (final goal in goals) {
        final onDay = GoalProgress.achievedInPeriodContaining(
            goal, activities, capturedAt);
        final inPeriod =
            GoalProgress.achievedInPeriod(goal, activities, now: capturedAt);
        expect(onDay, closeTo(inPeriod, 0.001),
            reason: 'the ${goal['period']} bar disagrees with its card');
      }
    });
  });

  group('records, end to end', () {
    Map<String, dynamic> recordFor(String type) =>
        (fixture['analytics']['records'] as List<dynamic>)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .firstWhere((r) => '${r['type']}' == type);

    test('records are held per activity type', () {
      final types = (fixture['analytics']['records'] as List<dynamic>)
          .map((r) => '${(r as Map)['type']}')
          .toSet();
      expect(types,
          {'Running', 'Walking', 'Cycling', 'Swimming', 'Gym Workout'});
    });

    test('the running record is the run, not the longer walk', () {
      expect(recordFor('Running')['longestDistanceKm'], 6);
      expect(recordFor('Walking')['longestDistanceKm'], 20);
    });

    test('session counts are per type', () {
      expect(recordFor('Swimming')['sessions'], 3);
      expect(recordFor('Cycling')['sessions'], 1);
    });

    test('the server derives a pace when the recorder does not send one', () {
      // Swimming went up without avgPace: 1.5 km in 30 min is 20 min/km.
      expect(recordFor('Swimming')['bestPace'], 20);
      // Running sent its own, which is kept as given.
      expect(recordFor('Running')['bestPace'], 5);
    });

    test('an activity with no distance has no pace to report', () {
      // The gym session covers no ground, so Best Pace must skip it rather
      // than divide by zero or record a nonsense figure.
      expect(recordFor('Gym Workout')['bestPace'], isNull);
      expect(recordFor('Gym Workout')['longestDurationSecs'], 2700);
    });
  });

  group('summary totals', () {
    test('all-time distance matches what was logged', () {
      // 6 + 20 + 60 + 1.5 + 1.2 + 1.0 = 89.7 km
      expect(
        fixture['analytics']['summary']['totalDistanceKm'],
        closeTo(89.7, 0.01),
      );
    });

    test('the session count matches', () {
      expect(fixture['analytics']['summary']['totalWorkouts'], 7);
    });
  });
}
