import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/models/wearable_brands.dart';
import 'package:fitrybe/services/brand_logos.dart';

/// What the Apps and Devices list promises about each watch, which has to stay
/// true on both platforms: Fitrybe reads the health store, it does not link to
/// any brand directly.
void main() {
  WearableBrand brand(String name) =>
      wearableBrands.firstWhere((b) => b.name == name);

  group('what is listed on each platform', () {
    test('an iPhone does not list Android-only watches', () {
      final names = brandsFor(isIOS: true).map((b) => b.name);
      expect(names, contains('Apple Watch'));
      expect(names, isNot(contains('Samsung Galaxy Watch')));
      expect(names, isNot(contains('Wear OS and Pixel Watch')));
    });

    test('an Android phone does not list the Apple Watch', () {
      final names = brandsFor(isIOS: false).map((b) => b.name);
      expect(names, isNot(contains('Apple Watch')));
      expect(names, contains('Samsung Galaxy Watch'));
      expect(names, contains('Garmin'));
    });

    test('the big names are all there', () {
      final names = brandsFor(isIOS: true).map((b) => b.name).toList();
      for (final expected in ['Garmin', 'Whoop', 'Oura', 'Polar', 'Fitbit', 'Suunto']) {
        expect(names, contains(expected));
      }
    });
  });

  group('status under the name', () {
    test('tells you to connect the store before anything can arrive', () {
      expect(
        brandStatus(brand('Garmin'),
            isIOS: true, storeConnected: false, storeName: 'Apple Health'),
        'Connect Apple Health first',
      );
    });

    test('says where workouts come from once it is connected', () {
      expect(
        brandStatus(brand('Polar'),
            isIOS: false, storeConnected: true, storeName: 'Health Connect'),
        'Arrives through Health Connect',
      );
    });

    test('Fitbit on an iPhone is honest about needing a bridge', () {
      expect(
        brandStatus(brand('Fitbit'),
            isIOS: true, storeConnected: true, storeName: 'Apple Health'),
        'Needs a bridging app',
      );
    });

    test('Fitbit on Android is a normal connection', () {
      expect(
        brandStatus(brand('Fitbit'),
            isIOS: false, storeConnected: true, storeName: 'Health Connect'),
        'Arrives through Health Connect',
      );
    });
  });

  group('steps', () {
    test('name the brand and the store the athlete actually has', () {
      final steps = brandSteps(brand('Whoop'), isIOS: false, storeName: 'Health Connect');
      expect(steps, contains('Whoop'));
      expect(steps, contains('Health Connect'));
      expect(steps, contains('Sync now'));
    });

    test('an Apple Watch is told it needs no setup', () {
      final steps = brandSteps(brand('Apple Watch'), isIOS: true, storeName: 'Apple Health');
      expect(steps, contains('Nothing to switch on'));
    });

    test('a bridge case explains the gap rather than giving useless steps', () {
      final steps = brandSteps(brand('Fitbit'), isIOS: true, storeName: 'Apple Health');
      expect(steps, contains('does not write to Apple Health'));
      expect(steps, isNot(contains('turn on sharing')));
    });

    test('Garmin says why there is no direct link', () {
      expect(brand('Garmin').note, contains('paused its own developer programme'));
    });
  });

  group('logos', () {
    setUp(() => BrandLogos.overrideBundled(const {}));

    test('a brand with no logo file falls back to its initial', () {
      expect(BrandLogos.assetFor('garmin'), isNull);
      expect(brand('Garmin').monogram, 'G');
      expect(brand('Wear OS and Pixel Watch').monogram, 'W');
    });

    test('a bundled logo is used, preferring the vector', () {
      BrandLogos.overrideBundled({
        'assets/brands/garmin.png',
        'assets/brands/garmin.svg',
      });
      expect(BrandLogos.assetFor('garmin'), 'assets/brands/garmin.svg');
      expect(BrandLogos.isVector('assets/brands/garmin.svg'), isTrue);
      expect(BrandLogos.isVector('assets/brands/garmin.png'), isFalse);
    });

    test('a png on its own is still used', () {
      BrandLogos.overrideBundled({'assets/brands/polar.png'});
      expect(BrandLogos.assetFor('polar'), 'assets/brands/polar.png');
      expect(BrandLogos.assetFor('whoop'), isNull);
    });

    test('every brand has its own file-safe slug', () {
      final slugs = wearableBrands.map((b) => b.slug).toList();
      expect(slugs.toSet().length, slugs.length, reason: 'slugs must be unique');
      for (final slug in slugs) {
        expect(slug, matches(RegExp(r'^[a-z0-9-]+$')));
      }
    });

    test('the file names match what the README asks for', () {
      expect(BrandLogos.candidatesFor('whoop').first, 'assets/brands/whoop.svg');
      expect(brand('Samsung Galaxy Watch').slug, 'samsung');
    });
  });
}
