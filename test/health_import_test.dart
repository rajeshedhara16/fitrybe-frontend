import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/health_import.dart';
import 'package:fitrybe/services/health_service.dart';

/// Turning what a watch wrote into Apple Health or Health Connect into a
/// workout Fitrybe can file.
void main() {
  HealthWorkout workout({
    String id = 'w-1',
    String type = 'RUNNING',
    DateTime? start,
    Duration length = const Duration(minutes: 32),
    double metres = 6100,
    int calories = 381,
    String source = 'Apple Watch',
  }) {
    final from = start ?? DateTime(2026, 9, 28, 7, 15);
    return HealthWorkout(
      id: id,
      typeName: type,
      start: from,
      end: from.add(length),
      distanceMetres: metres,
      calories: calories,
      sourceName: source,
    );
  }

  group('activity types', () {
    test('the common ones map onto names the app already uses', () {
      expect(HealthImport.activityTypeFor('RUNNING'), 'Running');
      expect(HealthImport.activityTypeFor('BIKING'), 'Cycling');
      expect(HealthImport.activityTypeFor('WALKING'), 'Walking');
      expect(HealthImport.activityTypeFor('HIKING'), 'Hiking');
      expect(HealthImport.activityTypeFor('TRADITIONAL_STRENGTH_TRAINING'), 'Gym Workout');
      expect(HealthImport.activityTypeFor('SWIMMING_OPEN_WATER'), 'Open Water Swimming');
    });

    test('a wheelchair session keeps its own name', () {
      expect(HealthImport.activityTypeFor('WHEELCHAIR_RUN_PACE'), 'Wheelchair Activity');
    });

    test('anything unknown is made readable rather than dropped', () {
      expect(HealthImport.activityTypeFor('CROSS_TRAINING'), 'Cross Training');
      expect(HealthImport.activityTypeFor('FENCING'), 'Fencing');
      expect(HealthImport.activityTypeFor(''), 'Workout');
    });

    test('matching is case-insensitive', () {
      expect(HealthImport.activityTypeFor('running'), 'Running');
    });
  });

  group('titles', () {
    test('name the session by the time of day', () {
      expect(HealthImport.titleFor('Run', DateTime(2026, 9, 28, 7)), 'Morning Run');
      expect(HealthImport.titleFor('Ride', DateTime(2026, 9, 28, 13)), 'Afternoon Ride');
      expect(HealthImport.titleFor('Walk', DateTime(2026, 9, 28, 19)), 'Evening Walk');
      expect(HealthImport.titleFor('Swim', DateTime(2026, 9, 28, 22)), 'Night Swim');
    });
  });

  group('what is worth importing', () {
    test('a real session is', () {
      expect(HealthImport.isWorthImporting(workout()), isTrue);
    });

    test('a stray few seconds on a watch is not', () {
      expect(
        HealthImport.isWorthImporting(
          workout(length: const Duration(seconds: 20)),
        ),
        isFalse,
      );
    });

    test('a session with no distance still counts if it burned something', () {
      expect(
        HealthImport.isWorthImporting(workout(metres: 0, calories: 210)),
        isTrue,
      );
    });

    test('a minute of nothing at all does not', () {
      expect(
        HealthImport.isWorthImporting(workout(metres: 0, calories: 0)),
        isFalse,
      );
    });
  });

  group('payload', () {
    test('carries what the server needs to file and de-duplicate it', () {
      final payload = HealthImport.toPayload(workout());

      expect(payload['externalId'], 'w-1');
      expect(payload['type'], 'Running');
      expect(payload['title'], 'Morning Running');
      expect(payload['duration'], 32 * 60);
      expect(payload['distance'], 6100);
      expect(payload['calories'], 381);
      expect(payload['sourceName'], 'Apple Watch');
      // Sent as UTC, so the server files it against the real moment.
      expect(payload['startTime'], DateTime(2026, 9, 28, 7, 15).toUtc().toIso8601String());
      expect(payload['endTime'], DateTime(2026, 9, 28, 7, 47).toUtc().toIso8601String());
    });

    test('leaves out a source the health store did not name', () {
      final payload = HealthImport.toPayload(workout(source: '  '));
      expect(payload.containsKey('sourceName'), isFalse);
    });
  });
}
