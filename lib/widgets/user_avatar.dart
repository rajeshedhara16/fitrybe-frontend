import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Avatar that tolerates the API returning a null/empty `avatarUrl`.
///
/// `NetworkImage('')` throws at paint time, and most seeded accounts have no
/// photo yet, so fall back to the user's initials on the brand tint.
class UserAvatar extends StatelessWidget {
  final String? url;
  final String? fallbackName;
  final double radius;

  const UserAvatar({
    super.key,
    required this.url,
    this.fallbackName,
    this.radius = 20,
  });

  String get _initials {
    final name = (fallbackName ?? '').trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = url != null && url!.trim().isNotEmpty;

    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primaryOrange.withValues(alpha: 0.18),
      foregroundImage: hasImage ? NetworkImage(url!) : null,
      // Shown while the image loads and if it fails to resolve.
      child: Text(
        _initials,
        style: GoogleFonts.hankenGrotesk(
          color: AppTheme.primaryOrange,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}
