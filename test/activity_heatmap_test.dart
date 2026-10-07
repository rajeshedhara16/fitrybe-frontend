import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/widgets/activity_heatmap.dart';

/// The heatmap's two views: a year of small day blocks that opens scrolled to
/// today, and a month of blocks that fill the card and step back and forth
/// without going past the current month.
void main() {
  // Sunday 13 September 2026, mid-morning.
  final now = DateTime(2026, 9, 13, 10);
  const accent = Color(0xFFFF5722);
  const empty = Color(0xFF1E1E22);
  const future = Color(0xFF141416);

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

  Future<void> pump(WidgetTester tester, {Size size = const Size(1200, 2400)}) async {
    tester.view.physicalSize = size;
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
    // The year view scrolls to today after its first frame.
    await tester.pump();
  }

  Finder cellsWithPrefix(String prefix) => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      (w.key as ValueKey<String>).value.startsWith(prefix));

  // Year blocks are keyed heat-<date>, month blocks heat-m-<date>.
  Finder yearCells() => find.byWidgetPredicate((w) =>
      w.key is ValueKey<String> &&
      RegExp(r'^heat-\d').hasMatch((w.key as ValueKey<String>).value));
  Finder monthCells() => cellsWithPrefix('heat-m-');

  Color? colorOf(WidgetTester tester, String key) {
    final box = tester.widget<Container>(find.byKey(ValueKey(key)));
    return (box.decoration as BoxDecoration?)?.color;
  }

  Future<void> openMonth(WidgetTester tester) async {
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
  }

  test('shade levels follow total minutes', () {
    expect(ActivityHeatmap.levelFor(null), 0);
    expect(ActivityHeatmap.levelFor(0), 0);
    expect(ActivityHeatmap.levelFor(10), 1);
    expect(ActivityHeatmap.levelFor(25), 2);
    expect(ActivityHeatmap.levelFor(45), 3);
    expect(ActivityHeatmap.levelFor(90), 4);
  });

  testWidgets('opens on the year view with exactly 365 day blocks', (tester) async {
    await pump(tester);
    expect(yearCells(), findsNWidgets(365));
    expect(monthCells(), findsNothing);
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
    expect(colorOf(tester, 'heat-2026-09-01'), accent.withValues(alpha: 0.25)); // 10 min
    expect(colorOf(tester, 'heat-2026-09-13'), accent.withValues(alpha: 0.75)); // 45 min
    expect(colorOf(tester, 'heat-2026-02-03'), accent); // 90 min
    expect(colorOf(tester, 'heat-2026-09-02'), empty); // nothing
    expect(find.text('3 active days in the last year'), findsOneWidget);
  });

  testWidgets('the legend runs from Less to More', (tester) async {
    await pump(tester);
    expect(find.text('Less'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  testWidgets('month view opens on the current month', (tester) async {
    await pump(tester);
    await openMonth(tester);

    expect(find.text('September 2026'), findsOneWidget);
    expect(monthCells(), findsNWidgets(30));
    expect(yearCells(), findsNothing);
    expect(find.text('2 / 30 active days'), findsOneWidget);
  });

  testWidgets('month view shades past days and darkens days still to come',
      (tester) async {
    await pump(tester);
    await openMonth(tester);

    expect(colorOf(tester, 'heat-m-2026-09-01'), accent.withValues(alpha: 0.25));
    expect(colorOf(tester, 'heat-m-2026-09-13'), accent.withValues(alpha: 0.75));
    expect(colorOf(tester, 'heat-m-2026-09-02'), empty);
    expect(colorOf(tester, 'heat-m-2026-09-14'), future);
    expect(colorOf(tester, 'heat-m-2026-09-30'), future);
  });

  testWidgets('next does nothing on the current month', (tester) async {
    await pump(tester);
    await openMonth(tester);

    await next(tester);
    expect(find.text('September 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsNothing);
  });

  testWidgets('back and next step through months', (tester) async {
    await pump(tester);
    await openMonth(tester);

    await back(tester);
    expect(find.text('August 2026'), findsOneWidget);
    expect(monthCells(), findsNWidgets(31));
    expect(find.text('0 / 31 active days'), findsOneWidget);

    await next(tester);
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('stepping back crosses into the previous year', (tester) async {
    await pump(tester);
    await openMonth(tester);

    for (var i = 0; i < 9; i++) {
      await back(tester);
    }
    expect(find.text('December 2025'), findsOneWidget);
    expect(monthCells(), findsNWidgets(31));

    for (var i = 0; i < 2; i++) {
      await back(tester);
    }
    expect(find.text('October 2025'), findsOneWidget);
    expect(find.text('0 / 31 active days'), findsOneWidget);
  });

  testWidgets('switching back to year restores the full year', (tester) async {
    await pump(tester);
    await openMonth(tester);
    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();

    expect(yearCells(), findsNWidgets(365));
    expect(monthCells(), findsNothing);
    expect(find.text('3 active days in the last year'), findsOneWidget);
  });

  testWidgets('month view shows square blocks with no day numbers',
      (tester) async {
    await pump(tester);
    await openMonth(tester);

    for (final n in ['1', '13', '30']) {
      expect(find.text(n), findsNothing, reason: 'day $n should not be written');
    }
    final size = tester.getSize(find.byKey(const ValueKey('heat-m-2026-09-13')));
    expect(size.width, size.height);
  });

  testWidgets('month blocks stretch to fill the card width', (tester) async {
    await pump(tester, size: const Size(360, 780));
    await openMonth(tester);

    // Seven blocks and six gaps across the inside of the card: the screen less
    // the page padding (40), the card padding (32) and its 1px border on each
    // side, so 360 - 40 - 32 - 2 = 286 wide.
    final size = tester.getSize(find.byKey(const ValueKey('heat-m-2026-09-13')));
    expect(size.width, ((286 - 6 * 6.0) / 7).floorToDouble());
  });

  testWidgets('fits a phone-width screen in both views without overflowing',
      (tester) async {
    await pump(tester, size: const Size(360, 780));
    expect(tester.takeException(), isNull);
    expect(yearCells(), findsNWidgets(365));

    await openMonth(tester);
    expect(tester.takeException(), isNull);
    expect(monthCells(), findsNWidgets(30));
  });

  testWidgets('on a phone the year opens scrolled to today', (tester) async {
    await pump(tester, size: const Size(360, 780));
    await tester.pump();

    final today = tester.getRect(find.byKey(const ValueKey('heat-2026-09-13')));
    expect(today.left, greaterThanOrEqualTo(0));
    expect(today.right, lessThanOrEqualTo(360));

    // A year ago is off to the left, reachable by scrolling back.
    final yearAgo = tester.getRect(find.byKey(const ValueKey('heat-2025-09-14')));
    expect(yearAgo.right, lessThan(0));
  });
}
