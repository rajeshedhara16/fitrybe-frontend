import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/calorie_estimator.dart';

void main() {
  group('distance-based activities', () {
    test('a stationary athlete burns no active calories', () {
      // The bug this replaced: a flat per-second rate meant a phone left on a
      // table reported a workout.
      expect(
        CalorieEstimator.estimate(
          activity: 'Running',
          elapsedSeconds: 1800,
          distanceKm: 0,
          tracksDistance: true,
        ),
        0,
      );
    });

    test('elapsed time alone does not change the estimate', () {
      final quick = CalorieEstimator.estimate(
        activity: 'Running',
        elapsedSeconds: 600,
        distanceKm: 2,
        tracksDistance: true,
      );
      final slow = CalorieEstimator.estimate(
        activity: 'Running',
        elapsedSeconds: 3600,
        distanceKm: 2,
        tracksDistance: true,
      );
      expect(quick, slow);
    });

    test('calories scale with ground covered', () {
      final one = CalorieEstimator.fromDistance(activity: 'Running', distanceKm: 1);
      final five = CalorieEstimator.fromDistance(activity: 'Running', distanceKm: 5);
      expect(five, closeTo(one * 5, 2));
    });

    test('a 5km run lands in a believable range for a 70kg default', () {
      // ~1 kcal per kg per km, so roughly 350 for 70kg over 5km.
      final kcal =
          CalorieEstimator.fromDistance(activity: 'Running', distanceKm: 5);
      expect(kcal, greaterThan(300));
      expect(kcal, lessThan(420));
    });

    test('walking the same distance costs less than running it', () {
      expect(
        CalorieEstimator.fromDistance(activity: 'Walking', distanceKm: 5),
        lessThan(CalorieEstimator.fromDistance(activity: 'Running', distanceKm: 5)),
      );
    });

    test('an unknown activity still returns something sensible', () {
      final kcal =
          CalorieEstimator.fromDistance(activity: 'Unicycling', distanceKm: 5);
      expect(kcal, greaterThan(0));
    });

    test('activity matching ignores case', () {
      expect(
        CalorieEstimator.fromDistance(activity: 'running', distanceKm: 3),
        CalorieEstimator.fromDistance(activity: 'Running', distanceKm: 3),
      );
    });
  });

  group('time-based activities', () {
    test('a gym session accrues calories from elapsed time', () {
      final kcal = CalorieEstimator.estimate(
        activity: 'Gym Workout',
        elapsedSeconds: 3600,
        distanceKm: 0,
        tracksDistance: false,
      );
      expect(kcal, greaterThan(0));
    });

    test('a harder activity burns more over the same hour', () {
      expect(
        CalorieEstimator.fromDuration(activity: 'Boxing', elapsedSeconds: 3600),
        greaterThan(
          CalorieEstimator.fromDuration(activity: 'Yoga', elapsedSeconds: 3600),
        ),
      );
    });

    test('an hour of yoga lands in a believable range', () {
      final kcal =
          CalorieEstimator.fromDuration(activity: 'Yoga', elapsedSeconds: 3600);
      expect(kcal, greaterThan(50));
      expect(kcal, lessThan(200));
    });

    test('zero elapsed time is zero calories', () {
      expect(
        CalorieEstimator.fromDuration(activity: 'Gym Workout', elapsedSeconds: 0),
        0,
      );
    });
  });
}
