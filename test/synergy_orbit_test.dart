import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/screens/synergy_orbit.dart';

/// The orbit runs continuous animations, so these check the screen builds,
/// settles into a real state rather than spinning forever, and shuts its
/// animations down cleanly when it leaves the tree.
void main() {
  Future<void> pumpOrbit(WidgetTester tester, {bool reduceMotion = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(child: SynergyOrbit()),
        ),
      ),
    ));
    // A few frames, not pumpAndSettle: the orbit's pulse repeats forever.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('with nobody to show, it settles on the empty orbit message',
      (tester) async {
    await pumpOrbit(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Synergy Orbit'), findsOneWidget);
    expect(find.text('Your orbit is empty'), findsOneWidget);
  });

  testWidgets('leaving the screen disposes its animations without errors',
      (tester) async {
    await pumpOrbit(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('builds with reduced motion switched on', (tester) async {
    await pumpOrbit(tester, reduceMotion: true);
    expect(tester.takeException(), isNull);
    expect(find.text('Synergy Orbit'), findsOneWidget);
  });
}
