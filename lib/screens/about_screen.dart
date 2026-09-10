import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// About, with the legal links App Review expects to find inside the app.
///
/// A privacy policy is not optional for anything that collects an account, and
/// a reviewer looks for it here as well as in App Store Connect. Health and
/// location data raise the bar further: both are declared in the manifests, so
/// the policy has to say what happens to them.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const Color _bg = Color(0xFF0B0B0D);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _accent = Color(0xFFFF5722);

  // ── Fill these in ─────────────────────────────────────────────────────────
  //
  // Both must be live, publicly reachable pages before submission. A 404 here
  // is a rejection, and the same privacy URL has to go in App Store Connect.

  static const String privacyPolicyUrl = 'https://fitrybe.app/privacy';
  static const String termsUrl = 'https://fitrybe.app/terms';
  static const String supportEmail = 'support@fitrybe.app';

  // ──────────────────────────────────────────────────────────────────────────

  /// Kept in step with `version` in pubspec.yaml by hand. Reading it at runtime
  /// would mean another plugin for one string.
  static const String appVersion = '1.0.0';

  Future<void> _open(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(url);

    // Returns false rather than throwing when nothing can handle the link, so
    // a missing browser shows a message instead of doing nothing at all.
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened) return;

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: _cardBg,
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Could not open $url',
          style: GoogleFonts.hankenGrotesk(color: Colors.white70),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'About FiTrybe',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.directions_run_rounded,
                          color: _accent, size: 34),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'FiTrybe',
                      style: GoogleFonts.anybody(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $appVersion',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _sectionHeader('LEGAL'),
              const SizedBox(height: 10),
              _group([
                _row(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy Policy',
                  onTap: () => _open(context, privacyPolicyUrl),
                ),
                _row(
                  context,
                  icon: Icons.description_outlined,
                  label: 'Terms of Service',
                  onTap: () => _open(context, termsUrl),
                  showDivider: false,
                ),
              ]),
              const SizedBox(height: 24),
              _sectionHeader('SUPPORT'),
              const SizedBox(height: 10),
              _group([
                _row(
                  context,
                  icon: Icons.mail_outline_rounded,
                  label: 'Contact support',
                  trailingText: supportEmail,
                  onTap: () => _open(context, 'mailto:$supportEmail'),
                  showDivider: false,
                ),
              ]),
              const SizedBox(height: 28),
              Text(
                'Made for people who train together.',
                textAlign: TextAlign.center,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white24,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white38,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  static Widget _group(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  static Widget _row(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? trailingText,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Colors.white70, size: 21),
          title: Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: trailingText == null
              ? null
              : Text(
                  trailingText,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
          trailing: const Icon(Icons.open_in_new_rounded,
              color: Colors.white24, size: 17),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 56,
            color: Colors.white.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}
