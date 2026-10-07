import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/wearable_brands.dart';
import '../services/brand_logos.dart';

/// A watch brand's logo, or its initial while no logo file has been added.
///
/// A supplied logo is drawn unaltered on a light tile, which is what most
/// brand guidelines ask for and what keeps a coloured mark legible against the
/// app's dark background.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    required this.brand,
    this.size = 36,
    this.radius = 11,
  });

  final WearableBrand brand;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final asset = BrandLogos.assetFor(brand.slug);

    if (asset == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand.colour.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: brand.colour.withValues(alpha: 0.35)),
        ),
        child: Text(
          brand.monogram,
          style: GoogleFonts.anybody(
            color: brand.colour,
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.17),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: BrandLogos.isVector(asset)
          ? SvgPicture.asset(asset, fit: BoxFit.contain)
          : Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
