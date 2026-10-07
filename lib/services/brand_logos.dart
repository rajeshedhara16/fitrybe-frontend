import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

/// Which watch-brand logos are actually bundled with this build.
///
/// Logos are trademarks, so the files are added by hand from each brand's own
/// press or brand-guidelines page rather than shipped with the code. Drop a
/// file at `assets/brands/<slug>.svg` or `.png` and the Apps and Devices list
/// picks it up on the next build; until then the row shows a monogram.
class BrandLogos {
  const BrandLogos._();

  static const _folder = 'assets/brands/';
  static const _extensions = ['svg', 'png', 'webp'];

  static Set<String> _bundled = const {};
  static bool _loaded = false;

  /// Reads the asset manifest once. Safe to call repeatedly.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _bundled = manifest
          .listAssets()
          .where((path) => path.startsWith(_folder))
          .toSet();
    } catch (e) {
      // No manifest, or no brands folder yet: every row falls back to its
      // monogram, which is a perfectly good state.
      debugPrint('BrandLogos load error: $e');
      _bundled = const {};
    }
  }

  /// The bundled logo for a brand, or null when none has been added.
  static String? assetFor(String slug) {
    for (final extension in _extensions) {
      final path = '$_folder$slug.$extension';
      if (_bundled.contains(path)) return path;
    }
    return null;
  }

  static bool isVector(String assetPath) => assetPath.toLowerCase().endsWith('.svg');

  /// Every path this brand's logo could live at, in the order they are tried.
  /// Exposed so the expected file names can be checked without a running app.
  static List<String> candidatesFor(String slug) =>
      [for (final extension in _extensions) '$_folder$slug.$extension'];

  @visibleForTesting
  static void overrideBundled(Set<String> paths) {
    _bundled = paths;
    _loaded = true;
  }
}
