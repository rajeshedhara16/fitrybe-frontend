import 'package:flutter/material.dart';

/// How a brand's workouts can reach Fitrybe on one platform.
enum WearableLink {
  /// The brand's own app shares into Apple Health or Health Connect, and
  /// Fitrybe reads them from there.
  viaHealthStore,

  /// The brand's app does not write to this platform's health store, so its
  /// workouts need a bridging app in between.
  bridgeNeeded,

  /// Not usable on this platform at all, such as an Apple Watch on Android.
  notOnPlatform,
}

/// A watch or band someone might already own.
///
/// Fitrybe has no direct link to any of them. Each brand's own app writes into
/// Apple Health or Health Connect, and Fitrybe reads the workouts there, which
/// is why every row describes the route rather than offering a sign-in.
class WearableBrand {
  const WearableBrand({
    required this.name,
    required this.slug,
    required this.colour,
    required this.ios,
    required this.android,
    this.note,
    this.customSteps,
  });

  final String name;

  /// File name for this brand's logo, looked for at `assets/brands/<slug>.svg`
  /// and `.png`. Until one is added the row shows a monogram instead.
  final String slug;

  /// Roughly the brand's own colour, used only for the monogram shown before a
  /// real logo is added.
  final Color colour;

  final WearableLink ios;
  final WearableLink android;

  /// Anything true of this brand that the generic steps do not cover.
  final String? note;

  /// Replaces the generic "turn on sharing" steps where they would be wrong.
  final String? customSteps;

  WearableLink linkFor({required bool isIOS}) => isIOS ? ios : android;

  /// The letter shown while this brand has no logo file.
  String get monogram => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
}

const List<WearableBrand> wearableBrands = [
  WearableBrand(
    name: 'Apple Watch',
    slug: 'apple-watch',
    // Apple's guidelines are the strictest of the set, so this stays a neutral
    // grey rather than anything resembling their mark.
    colour: Color(0xFFD7DBE0),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.notOnPlatform,
    customSteps:
        'Nothing to switch on. Workouts from an Apple Watch are written to Apple Health by watchOS itself, so they arrive as soon as Fitrybe has access.',
  ),
  WearableBrand(
    name: 'Garmin',
    slug: 'garmin',
    colour: Color(0xFF007CC3),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
    note:
        'Garmin has paused its own developer programme, so no app can link to Garmin directly at the moment. Garmin Connect still shares your workouts with the health store, which is how they reach Fitrybe.',
  ),
  WearableBrand(
    name: 'Whoop',
    slug: 'whoop',
    colour: Color(0xFFE32636),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Oura',
    slug: 'oura',
    colour: Color(0xFFB9BDC9),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Polar',
    slug: 'polar',
    colour: Color(0xFFE4002B),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Fitbit',
    slug: 'fitbit',
    colour: Color(0xFF00B0B9),
    ios: WearableLink.bridgeNeeded,
    android: WearableLink.viaHealthStore,
    note:
        'On Android, Fitbit shares with Health Connect and everything works normally. On iPhone, the Fitbit app does not write to Apple Health, so its workouts only arrive if another app copies them across.',
  ),
  WearableBrand(
    name: 'Samsung Galaxy Watch',
    slug: 'samsung',
    colour: Color(0xFF1428A0),
    ios: WearableLink.notOnPlatform,
    android: WearableLink.viaHealthStore,
    customSteps:
        'Open Samsung Health, go to Settings, then Health Connect, and allow it to share Exercise. Then come back here and press Sync now.',
  ),
  WearableBrand(
    name: 'Wear OS and Pixel Watch',
    slug: 'wear-os',
    colour: Color(0xFF4285F4),
    ios: WearableLink.notOnPlatform,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Suunto',
    slug: 'suunto',
    colour: Color(0xFFE1251B),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Coros',
    slug: 'coros',
    colour: Color(0xFFFF6B00),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
  WearableBrand(
    name: 'Amazfit and Zepp',
    slug: 'amazfit',
    colour: Color(0xFFFF6A00),
    ios: WearableLink.viaHealthStore,
    android: WearableLink.viaHealthStore,
  ),
];

/// The brands worth listing on this platform, in the order they are shown.
List<WearableBrand> brandsFor({required bool isIOS}) => wearableBrands
    .where((b) => b.linkFor(isIOS: isIOS) != WearableLink.notOnPlatform)
    .toList();

/// The line under a brand's name in the list.
String brandStatus(
  WearableBrand brand, {
  required bool isIOS,
  required bool storeConnected,
  required String storeName,
}) {
  switch (brand.linkFor(isIOS: isIOS)) {
    case WearableLink.viaHealthStore:
      return storeConnected ? 'Arrives through $storeName' : 'Connect $storeName first';
    case WearableLink.bridgeNeeded:
      return 'Needs a bridging app';
    case WearableLink.notOnPlatform:
      return 'Not available on this phone';
  }
}

/// What to do to make this brand's workouts show up.
String brandSteps(
  WearableBrand brand, {
  required bool isIOS,
  required String storeName,
}) {
  if (brand.customSteps != null) return brand.customSteps!;

  if (brand.linkFor(isIOS: isIOS) == WearableLink.bridgeNeeded) {
    return 'The ${brand.name} app does not write to $storeName, so Fitrybe cannot see those workouts on its own. '
        'An app that copies ${brand.name} sessions into $storeName will make them appear here.';
  }

  return 'Open the ${brand.name} app, find its settings, and turn on sharing with $storeName, including workouts or exercise. '
      'Then come back here and press Sync now. If you cannot find the setting, update the ${brand.name} app first.';
}
