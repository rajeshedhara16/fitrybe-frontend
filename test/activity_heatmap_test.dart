import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/widgets/activity_heatmap.dart';

/// The heatmap's two views: a year of day blocks, and a month that steps
/// backwards and forwards without running past today or the data window.
void main() {
  // Sunday 13 September 2026, mid-morning.
  final now = DateTime(2026, 9, 13, 10);
  const accent = Color(0xFFFF5722);

  Map<String, dynamic> act(DateTime at, int minutes) => {
        'createdAt': at.toUtc().toIso8601String(),
        'duration': minutes * 60,
      };

  final activities = [
    act(DateTime(2026, 9, 13, 7), 45), // today
    act(DateTime(2026, 9, 1, 18), 10),
    act(DateTime(2026, 2, 3, 6), 90),
    act(DateTime(2025, 9, 13, 8), 30), // 365 days ago: outside the year
  ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivityHeatmap(
            activities: activities,
            title: 'Heatmap',
            accent: accent,
            cardColor: Colors.black,
            now: now,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  Finder dayCells() => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith('heat-'));

  Color? colorOf(WidgetTester tester, String ymd) {
    final box = tester.widget<Container>(find.byKey(ValueKey('heat-$ymd')));
    return (box.decoration as BoxDecoration?)?.color;
  }

  String monthLabel(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const ValueKey('heatmap-month-label'))).data!;

  bool enabled(WidgetTester tester, String key) =>
      tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed != null;

  test('shade levels follow total minutes', () {
    expect(ActivityHeatmap.levelFor(null), 0);
    expect(ActivityHeatmap.levelFor(0), 0);
    expect(ActivityHeatmap.levelFor(10), 1);
    expect(ActivityHeatmap.levelFor(25), 2);
    expect(ActivityHeatmap.levelFor(45), 3);
    expect(ActivityHeatmap.levelFor(90), 4);
  });

  testWidgets('the year view shows exactly 365 day blocks', (tester) async {
    await pump(tester);
    expect(dayCells(), findsNWidgets(365));
  });

  testWidgets('the year runs from 364 days ago up to today', (tester) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('heat-2026-09-13')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-2025-09-14')), findsOneWidget);
    expect(find.byKey(const ValueKey('heat-2025-09-13')), findsNothing);
    expect(find.byKey(const ValueKey('heat-2026-09-14')), findsNothing);
  });

  testWidgets('a day is shaded by how long was trained', (tester) async {
    await pump(tester);
    expect(colorOf(tester, '2026-09-13'), accent.withValues(alpha: 0.7));
    expect(colorOf(tester, '2026-02-03'), accent);
    expect(colorOf(tester, '2026-09-01'), accent.withValues(alpha: 0.2));
    expect(colorOf(tester, '2026-09-02'), const Color(0x4D353438));
    expect(find.text('3 active days in the last year'), findsOneWidget);
  });

  testWidgets('month view opens on the current month, with next disabled',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();

    expect(monthLabel(tester), 'September 2026');
    expect(dayCells(), findsNWidgets(30));
    expect(enabled(tester, 'heatmap-next'), isFalse);
    expect(enabled(tester, 'heatmap-prev'), isTrue);
    expect(find.text('2 active days · 55m'), findsOneWidget);
  });

  testWidgets('back and next step through months', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('heatmap-prev')));
    await tester.pump();
    expect(monthLabel(tester), 'August 2026');
    expect(dayCells(), findsNWidgets(31));
    expect(enabled(tester, 'heatmap-next'), isTrue);
    expect(find.text('No workouts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('heatmap-next')));
    await tester.pump();
    expect(monthLabel(tester), 'September 2026');
  });

  testWidgets('stepping back stops at the edge of the data window',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 23; i++) {
      await tester.tap(find.byKey(const ValueKey('heatmap-prev')));
      await tester.pump();
    }
    expect(monthLabel(tester), 'October 2024');
    expect(enabled(tester, 'heatmap-prev'), isFalse);
  });

  testWidgets('a month crossing years steps correctly', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();

    for (var i = 0; i < 9; i++) {
      await tester.tap(find.byKey(const ValueKey('heatmap-prev')));
      await tester.pump();
    }
    expect(monthLabel(tester), 'December 2025');
    expect(dayCells(), findsNWidgets(31));
  });

  testWidgets('switching back to year restores the full year', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('heatmap-range-year')));
    await tester.pumpAndSettle();
    expect(dayCells(), findsNWidgets(365));
  });

  testWidgets('fits a phone-width screen in both views without overflowing',
      (tester) async {
    // A small phone. The year view has to fit 53 week columns into what is
    // left after the card's padding, which is where rounding could overflow.
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ActivityHeatmap(
            activities: activities,
            title: 'Training Consistency',
            accent: accent,
            cardColor: Colors.black,
            now: now,
          ),
        ),
      ),
    ));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(dayCells(), findsNWidgets(365));
    final cellSize = tester.getSize(find.byKey(const ValueKey('heat-2026-09-13')));
    expect(cellSize.width, greaterThanOrEqualTo(2.0));

    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(dayCells(), findsNWidgets(30));
  });

  testWidgets('month view shows small plain blocks with no day numbers',
      (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('heatmap-range-month')));
    await tester.pumpAndSettle();

    // No date is written on any block, even on a wide screen.
    for (final n in ['1', '13', '30']) {
      expect(find.text(n), findsNothing, reason: 'day $n should not be written');
    }
    final size = tester.getSize(find.byKey(const ValueKey('heat-2026-09-13')));
    expect(size.width, lessThanOrEqualTo(22));
    expect(size.width, size.height);
  });
}
