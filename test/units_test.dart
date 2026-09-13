import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/units.dart';

/// A conversion bug here is silent and everywhere at once, which is exactly the
/// kind that ships. These pin the arithmetic rather than the wording.
void main() {
  setUp(() => Units.adopt('METRIC'));

  group('adopting a preference', () {
    test('reads the server value', () {
      Units.adopt('IMPERIAL');
      expect(Units.isImperial, isTrue);
      Units.adopt('METRIC');
      expect(Units.isImperial, isFalse);
    });

    test('anything unrecognised is metric, never an exception', () {
      for (final junk in [null, '', 'furlongs', 42, 'imperial ']) {
        Units.adopt(junk);
        expect(Units.isImperial, isFalse, reason: 'for $junk');
      }
    });

    test('is case-insensitive, since the server shouts and Dart does not', () {
      Units.adopt('imperial');
      expect(Units.isImperial, isTrue);
    });
  });

  group('distance', () {
    test('metric passes metres straight through as kilometres', () {
      expect(Units.distance(5000), '5.00 km');
      expect(Units.distance(21097, decimals: 1), '21.1 km');
    });

    test('imperial converts, and a marathon is the famous number', () {
      Units.adopt('IMPERIAL');
      // 42.195 km is 26.2 miles.
      expect(Units.distance(42195, decimals: 1), '26.2 mi');
      expect(Units.distance(1609.34, decimals: 2), '1.00 mi');
    });

    test('a kilometre value converts the same as a metre one', () {
      Units.adopt('IMPERIAL');
      expect(Units.distanceKm(42.195, decimals: 1),
          Units.distance(42195, decimals: 1));
    });

    test('a typed value round-trips back to kilometres', () {
      Units.adopt('IMPERIAL');
      expect(Units.toKm(26.2), closeTo(42.17, 0.02));
      expect(Units.fromKm(Units.toKm(10)), closeTo(10, 1e-9));
    });

    test('zero stays zero in both systems', () {
      expect(Units.distance(0), '0.00 km');
      Units.adopt('IMPERIAL');
      expect(Units.distance(0), '0.00 mi');
    });
  });

  group('pace', () {
    test('minutes per kilometre render as minutes and seconds', () {
      expect(Units.pace(5.5), '5:30 /km');
      expect(Units.pace(4), '4:00 /km');
    });

    test('pace inverts distance: a mile takes longer than a kilometre', () {
      Units.adopt('IMPERIAL');
      // 5:00 per km is a little over 8:03 per mile. Slower, not faster.
      expect(Units.pace(5), '8:03 /mi');
    });

    test('59.6 seconds reads as the next minute, not 5:60', () {
      // 5.994 minutes is 5 minutes 59.64 seconds.
      expect(Units.pace(5.994), '6:00 /km');
    });

    test('no pace is a dash, never zero', () {
      expect(Units.pace(null), '--');
      expect(Units.pace(0), '--');
      expect(Units.pace(-3), '--');
    });
  });

  group('speed', () {
    test('converts and labels', () {
      expect(Units.speed(16.1), '16.1 km/h');
      Units.adopt('IMPERIAL');
      expect(Units.speed(16.1), '10.0 mph');
    });
  });

  group('elevation', () {
    test('metres become feet', () {
      expect(Units.elevation(100), '100 m');
      Units.adopt('IMPERIAL');
      expect(Units.elevation(100), '328 ft');
    });
  });

  group('body measurements', () {
    test('weight converts both ways', () {
      expect(Units.weight(70), '70.0 kg');
      Units.adopt('IMPERIAL');
      expect(Units.weight(70), '154.3 lb');
      // Round-trip the exact value, not the string's rounded one: 154.3 is
      // already a display figure and reads back a hundredth of a kilo light.
      expect(Units.weightToKg(Units.weightFrom(70)), closeTo(70, 1e-9));
      expect(Units.weightToKg(154.3), closeTo(70, 0.02));
    });

    test('height is feet and inches, not a decimal', () {
      expect(Units.height(178), '178 cm');
      Units.adopt('IMPERIAL');
      expect(Units.height(178), "5'10\"");
    });

    test('twelve inches rolls into a foot rather than reading 5\'12', () {
      Units.adopt('IMPERIAL');
      // 182.9 cm is 71.99 inches, which rounds to 72 and must be 6'0".
      expect(Units.height(182.9), "6'0\"");
    });
  });

  group('preference-independent conversion', () {
    test('a goal saved in miles reads correctly to someone on metric', () {
      Units.adopt('METRIC');
      // A 30 mile weekly goal is a little under 48.3 km.
      expect(Units.toKmFromMiles(30), closeTo(48.28, 0.01));
    });

    test('and the other way round', () {
      Units.adopt('IMPERIAL');
      expect(Units.kmToMiles(50), closeTo(31.07, 0.01));
    });

    test('they invert each other whichever system is active', () {
      for (final s in ['METRIC', 'IMPERIAL']) {
        Units.adopt(s);
        expect(Units.kmToMiles(Units.toKmFromMiles(26.2)), closeTo(26.2, 1e-9),
            reason: 'under $s');
      }
    });
  });
}
