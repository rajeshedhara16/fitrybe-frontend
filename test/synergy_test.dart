import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/synergy.dart';

void main() {
  // Monday 14 September 2026, midday.
  final now = DateTime(2026, 9, 14, 12);

  Map<String, dynamic> act(
    int daysAgo, {
    int hour = 9,
    String type = 'Running',
    double meters = 5000,
  }) {
    final at = DateTime(now.year, now.month, now.day - daysAgo, hour);
    return {
      'createdAt': at.toUtc().toIso8601String(),
      'type': type,
      'distance': meters,
      'duration': 1800,
    };
  }

  SynergyReport report(List<dynamic> mine, List<dynamic> theirs) =>
      SynergyReport.compute(mine: mine, theirs: theirs, now: now);

  group('score', () {
    test('training on exactly the same days is perfect sync', () {
      final days = [act(0), act(3), act(7)];
      final r = report(days, days);
      expect(r.score, 100);
      expect(r.sharedDays, 3);
      expect(r.tier, SynergyTier.perfect);
    });

    test('is shared days out of days either trained', () {
      // Mine: 0-3. Theirs: 2-5. Shared 2 of 6.
      final r = report(
        [act(0), act(1), act(2), act(3)],
        [act(2), act(3), act(4), act(5)],
      );
      expect(r.sharedDays, 2);
      expect(r.eitherActiveDays, 6);
      expect(r.score, 33);
      expect(r.tier, SynergyTier.warming);
    });

    test('is the same whichever side is looking', () {
      final a = [act(0), act(1), act(9), act(12)];
      final b = [act(1), act(2), act(12)];
      expect(report(a, b).score, report(b, a).score);
    });

    test('both active but never together scores zero', () {
      final r = report([act(0), act(2)], [act(1), act(3)]);
      expect(r.score, 0);
      expect(r.tier, SynergyTier.starting);
      expect(r.summary, contains('never on the same day'));
    });

    test('nobody training is its own state, not a low score', () {
      final r = report(const [], const []);
      expect(r.score, 0);
      expect(r.tier, SynergyTier.none);
      expect(r.summary, contains('Neither of you'));
    });

    test('only them training explains how to start', () {
      final r = report(const [], [act(1), act(4)]);
      expect(r.yourActiveDays, 0);
      expect(r.theirActiveDays, 2);
      expect(r.summary, contains('2 days'));
      expect(r.summary, contains('same days as them'));
    });

    test('only you training says they have not logged anything', () {
      final r = report([act(1)], const []);
      expect(r.summary, contains('1 day'));
      expect(r.summary, contains('have not logged'));
    });
  });

  group('window', () {
    test('covers the last 30 days including today, nothing older', () {
      final r = report([act(29), act(30)], [act(29), act(30)]);
      expect(r.sharedDays, 1);
      expect(r.eitherActiveDays, 1);
    });

    test('several workouts on one day count as one day but each workout counts',
        () {
      final r = report(const [], [
        act(2, hour: 7, meters: 3000),
        act(2, hour: 18, meters: 2000),
        act(40, meters: 9000),
      ]);
      expect(r.theirActiveDays, 1);
      expect(r.theirWorkouts, 2);
      expect(r.theirDistanceKm, closeTo(5.0, 1e-9));
    });

    test('days are local calendar days, so a late workout stays on its day', () {
      final r = report([act(1, hour: 6)], [act(1, hour: 23)]);
      expect(r.sharedDays, 1);
    });

    test('malformed entries are ignored', () {
      final r = report(
        ['junk', <String, dynamic>{'createdAt': 'not a date'}, act(0)],
        [null, act(0)],
      );
      expect(r.sharedDays, 1);
    });
  });

  group('their stats', () {
    test('favourite is the most frequent activity', () {
      final r = report(const [], [
        act(1, type: 'Cycling'),
        act(2, type: 'Running'),
        act(3, type: 'Cycling'),
      ]);
      expect(r.theirFavourite, 'Cycling');
    });

    test('a tie goes to the most recent', () {
      final r = report(const [], [
        act(5, type: 'Cycling'),
        act(1, type: 'Swimming'),
      ]);
      expect(r.theirFavourite, 'Swimming');
    });

    test('no workouts means no favourite', () {
      expect(report(const [], const []).theirFavourite, isNull);
    });

    test('streak counts consecutive days up to today', () {
      final r = report(const [], [act(0), act(1), act(2), act(4)]);
      expect(r.theirStreak, 3);
    });
  });

  group('timeline', () {
    test('is 14 days, oldest first, ending today', () {
      final r = report(const [], const []);
      expect(r.timeline, hasLength(14));
      expect(r.timelineDates.last, DateTime(2026, 9, 14));
      expect(r.timelineDates.first, DateTime(2026, 9, 1));
    });

    test('marks who trained on each day', () {
      final r = report([act(0), act(1)], [act(0), act(2)]);
      expect(r.timeline[13], DayOverlap.both);
      expect(r.timeline[12], DayOverlap.you);
      expect(r.timeline[11], DayOverlap.them);
      expect(r.timeline[10], DayOverlap.none);
    });
  });
}
