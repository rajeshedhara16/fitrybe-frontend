import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitrybe/services/live_session.dart';

/// A workout in progress has to survive leaving the screen and the app being
/// killed. The clock is derived from timestamps rather than counted by a
/// ticker, which is what these check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DateTime now;

  setUp(() async {
    now = DateTime(2026, 10, 6, 7, 0);
    LiveSession.clock = () => now;
    SharedPreferences.setMockInitialValues({});
    await LiveSession().discard();
  });

  tearDown(() async {
    await LiveSession().discard();
    LiveSession.clock = DateTime.now;
  });

  void tick(Duration by) => now = now.add(by);

  group('the clock', () {
    test('counts from the moment the workout started', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.solo, activityType: 'Running');

      expect(session.elapsed, Duration.zero);
      tick(const Duration(minutes: 12, seconds: 30));
      expect(session.elapsed, const Duration(minutes: 12, seconds: 30));
    });

    test('a pause stops it, and resuming carries on from where it stopped', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.solo, activityType: 'Running');

      tick(const Duration(minutes: 5));
      session.togglePause();
      expect(session.isPaused, isTrue);

      tick(const Duration(minutes: 3));
      expect(session.elapsed, const Duration(minutes: 5), reason: 'paused time does not count');

      session.togglePause();
      tick(const Duration(minutes: 2));
      expect(session.elapsed, const Duration(minutes: 7));
    });

    test('is not thrown off by the app being asleep, since nothing is counted', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.solo, activityType: 'Running');

      // No ticks ran while the phone was locked; the clock is still right.
      tick(const Duration(hours: 1, minutes: 4));
      expect(session.elapsed, const Duration(hours: 1, minutes: 4));
    });
  });

  group('surviving the app being killed', () {
    test('a stored session is picked back up with its clock intact', () async {
      SharedPreferences.setMockInitialValues({
        'fitrybe_live_session': jsonEncode({
          'mode': 'clique',
          'sessionId': 'session-1',
          'activityType': 'Cycling',
          'title': 'Evening ride',
          'startedAt': now.subtract(const Duration(minutes: 20)).toIso8601String(),
          'pausedAt': null,
          'pausedMs': const Duration(minutes: 2).inMilliseconds,
          'distance': 4200.0,
        }),
      });

      final session = LiveSession();
      await session.restore();

      expect(session.isActive, isTrue);
      expect(session.mode, LiveMode.clique);
      expect(session.sessionId, 'session-1');
      // 20 minutes ago, less the 2 minutes spent paused.
      expect(session.elapsed, const Duration(minutes: 18));
      expect(session.distanceMetres, 4200.0, reason: 'distance already covered is kept');
      expect(session.state.activityType, 'Cycling');
    });

    test('a session paused before the restart stays paused', () async {
      SharedPreferences.setMockInitialValues({
        'fitrybe_live_session': jsonEncode({
          'mode': 'solo',
          'activityType': 'Running',
          'startedAt': now.subtract(const Duration(minutes: 10)).toIso8601String(),
          'pausedAt': now.subtract(const Duration(minutes: 4)).toIso8601String(),
          'pausedMs': 0,
          'distance': 0.0,
        }),
      });

      final session = LiveSession();
      await session.restore();

      expect(session.isPaused, isTrue);
      expect(session.elapsed, const Duration(minutes: 6));
      tick(const Duration(minutes: 5));
      expect(session.elapsed, const Duration(minutes: 6), reason: 'still paused');
    });

    test('nothing stored means nothing is resumed', () async {
      await LiveSession().restore();
      expect(LiveSession().isActive, isFalse);
    });
  });

  group('finishing', () {
    test('hands back what was measured and clears the session', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'session-2',
        activityType: 'Running',
        title: 'Sunset run',
      );
      tick(const Duration(minutes: 31));

      final summary = await session.finish();

      expect(summary, isNotNull);
      expect(summary!.elapsed, const Duration(minutes: 31));
      expect(summary.sessionId, 'session-2');
      expect(summary.activityType, 'Running');
      expect(summary.title, 'Sunset run');
      expect(session.isActive, isFalse, reason: 'the session is over');
      expect(session.elapsed, Duration.zero);
    });

    test('finishing when nothing is running gives nothing back', () async {
      expect(await LiveSession().finish(), isNull);
    });

    test('a second start cannot wipe a workout already in progress', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.solo, activityType: 'Running');
      tick(const Duration(minutes: 9));

      await session.start(mode: LiveMode.solo, activityType: 'Cycling');

      expect(session.elapsed, const Duration(minutes: 9));
      expect(session.state.activityType, 'Running');
    });
  });

  group('sessions that should not come back', () {
    test('one left running overnight is given up on', () async {
      SharedPreferences.setMockInitialValues({
        'fitrybe_live_session': jsonEncode({
          'mode': 'solo',
          'activityType': 'Running',
          'startedAt': now.subtract(const Duration(hours: 13)).toIso8601String(),
          'pausedMs': 0,
          'distance': 1200.0,
        }),
      });

      await LiveSession().restore();

      expect(LiveSession().isActive, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fitrybe_live_session'), isNull,
          reason: 'the stale session is forgotten, not left to come back');
    });

    test('one just inside the limit is still resumed', () async {
      SharedPreferences.setMockInitialValues({
        'fitrybe_live_session': jsonEncode({
          'mode': 'solo',
          'activityType': 'Running',
          'startedAt': now.subtract(const Duration(hours: 11)).toIso8601String(),
          'pausedMs': 0,
          'distance': 0.0,
        }),
      });

      await LiveSession().restore();

      expect(LiveSession().isActive, isTrue);
      expect(LiveSession().elapsed, const Duration(hours: 11));
    });

    test('rubbish in storage is discarded rather than crashing the app', () async {
      SharedPreferences.setMockInitialValues({'fitrybe_live_session': 'not json'});
      await LiveSession().restore();
      expect(LiveSession().isActive, isFalse);
    });
  });

  group('goals', () {
    test('a session without a goal never claims one is reached', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.solo, activityType: 'Running');
      tick(const Duration(hours: 2));

      expect(session.goalProgress, isNull);
      expect(session.goalReached, isFalse);
      expect(session.state.goalReached, isFalse);
    });

    test('a duration goal fills up and then reads as reached', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'session-goal',
        activityType: 'Cycling',
        goalType: 'Duration',
        goalTarget: 2,
      );

      expect(session.goalProgress, 0);
      tick(const Duration(minutes: 1));
      expect(session.goalProgress, 0.5);
      expect(session.goalReached, isFalse);

      tick(const Duration(minutes: 1));
      expect(session.goalReached, isTrue, reason: 'two minutes of a two minute goal');
      expect(session.state.goalType, 'Duration');
    });

    test('time spent paused does not count towards a duration goal', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.solo,
        activityType: 'Running',
        goalType: 'Duration',
        goalTarget: 10,
      );

      tick(const Duration(minutes: 4));
      session.togglePause();
      tick(const Duration(minutes: 30));

      expect(session.goalReached, isFalse);
      expect(session.goalProgress, 0.4);
    });

    test('a goal that arrives after the start is still applied', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.clique, sessionId: 's', activityType: 'Running');
      tick(const Duration(minutes: 3));
      expect(session.goalReached, isFalse);

      session.updateGoal(type: 'Duration', target: 2);
      expect(session.goalReached, isTrue);
    });

    test('the goal survives the app being killed', () async {
      SharedPreferences.setMockInitialValues({
        'fitrybe_live_session': jsonEncode({
          'mode': 'clique',
          'sessionId': 'session-2',
          'activityType': 'Running',
          'startedAt': now.subtract(const Duration(minutes: 1)).toIso8601String(),
          'pausedMs': 0,
          'distance': 0.0,
          'goalType': 'Duration',
          'goalTarget': 5.0,
        }),
      });

      await LiveSession().restore();

      expect(LiveSession().state.goalType, 'Duration');
      expect(LiveSession().goalProgress, 0.2);
    });
  });

  group('after finishing', () {
    test('the same session cannot restart straight away', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'session-9',
        activityType: 'Running',
      );
      tick(const Duration(minutes: 4));
      await session.finish();
      expect(session.isActive, isFalse);

      // A screen rebuild or a lobby broadcast still in flight tries again.
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'session-9',
        activityType: 'Running',
      );
      expect(session.isActive, isFalse, reason: 'the finished session stays finished');
    });

    test('a different session may start immediately', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.clique, sessionId: 'session-a', activityType: 'Running');
      await session.finish();

      await session.start(mode: LiveMode.clique, sessionId: 'session-b', activityType: 'Running');
      expect(session.isActive, isTrue);
      expect(session.sessionId, 'session-b');
    });

    test('the same session may be run again later', () async {
      final session = LiveSession();
      await session.start(mode: LiveMode.clique, sessionId: 'session-c', activityType: 'Running');
      await session.finish();

      tick(LiveSession.restartGuard + const Duration(seconds: 1));
      await session.start(mode: LiveMode.clique, sessionId: 'session-c', activityType: 'Running');
      expect(session.isActive, isTrue);
    });
  });

  group('remembering what was finished', () {
    test('a finished Clique is still known after the app restarts', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'session-remembered',
        activityType: 'Running',
      );
      tick(const Duration(minutes: 5));
      await session.finish();

      expect(session.hasFinished('session-remembered'), isTrue);

      // What a fresh launch would read back off disk.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('fitrybe_finished_sessions'),
          contains('session-remembered'));
    });

    test('a session never finished is not claimed as done', () async {
      expect(LiveSession().hasFinished('never-run'), isFalse);
      expect(LiveSession().hasFinished(null), isFalse);
    });
  });

  group('sessions without a goal', () {
    test('never finish themselves', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'no-goal',
        activityType: 'Running',
      );
      tick(const Duration(hours: 3));

      expect(session.goalProgress, isNull);
      expect(session.goalReached, isFalse);
      expect(session.isActive, isTrue, reason: 'nothing to reach, so it runs on');
    });

    test('a goal cleared by the server stops counting towards one', () async {
      final session = LiveSession();
      await session.start(
        mode: LiveMode.clique,
        sessionId: 'cleared-goal',
        activityType: 'Running',
        goalType: 'Duration',
        goalTarget: 5,
      );
      tick(const Duration(minutes: 2));
      expect(session.goalProgress, 0.4);

      session.updateGoal(type: null, target: null);
      expect(session.goalProgress, isNull);
      expect(session.goalReached, isFalse);
    });
  });
}
