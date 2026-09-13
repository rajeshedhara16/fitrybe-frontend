import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';

/// Who sees what.
///
/// Workout visibility covers the whole profile: switching it off hides every
/// workout ever logged, not just future ones, and switching it back on restores
/// exactly what was visible before. The server enforces it whenever anyone else
/// reads a workout, so nothing stored is rewritten. The post audience is
/// different and applies to new posts only.
class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  static const Color _bg = Color(0xFF131316);
  static const Color _cardBg = Color(0xFF1F1F22);
  static const Color _accent = Color(0xFFFF5722);

  late bool _activityPublic;
  late bool _postToEveryone;
  late bool _discoverable;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = SessionService().user;
    _activityPublic = user?['activitiesVisible'] != false;
    _postToEveryone = user?['defaultPostAudience'] != 'TRYBES';
    _discoverable = user?['discoverable'] != false;
  }

  /// Applies a change optimistically and puts it back if the server refuses.
  Future<void> _save(String field, Object value, VoidCallback revert) async {
    HapticFeedback.selectionClick();
    setState(() => _isSaving = true);

    final updated = await ApiService.updateProfile({field: value});
    if (!mounted) return;

    if (updated == null || updated[field] != value) {
      setState(() {
        revert();
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Text(
            'Could not save that. Your setting has not changed.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    SessionService().update(updated);
    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Privacy & Sharing',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionHeader('YOUR WORKOUTS'),
              const SizedBox(height: 10),
              _card(
                child: _toggle(
                  icon: Icons.visibility_outlined,
                  title: 'Visible to others',
                  subtitle: _activityPublic
                      ? 'All your workouts, past and future, appear on your profile and in Trybe leaderboards.'
                      : 'Every workout you have logged, including older ones, is hidden from everyone else.',
                  value: _activityPublic,
                  onChanged: (v) {
                    final previous = _activityPublic;
                    setState(() => _activityPublic = v);
                    _save('activitiesVisible', v,
                        () => _activityPublic = previous);
                  },
                ),
              ),
              const SizedBox(height: 8),
              _note(
                'Turning this back on shows your workouts again exactly as before.',
              ),
              const SizedBox(height: 24),
              _sectionHeader('NEW POSTS'),
              const SizedBox(height: 10),
              _card(
                child: _toggle(
                  icon: Icons.public_rounded,
                  title: 'Post to everyone',
                  subtitle: _postToEveryone
                      ? 'Posts go out to everyone on Fitrybe by default.'
                      : 'Posts go only to people in your Trybes by default.',
                  value: _postToEveryone,
                  onChanged: (v) {
                    final previous = _postToEveryone;
                    setState(() => _postToEveryone = v);
                    _save('defaultPostAudience', v ? 'EVERYONE' : 'TRYBES',
                        () => _postToEveryone = previous);
                  },
                ),
              ),
              const SizedBox(height: 8),
              _note('The composer still lets you pick per post.'),
              const SizedBox(height: 24),
              _sectionHeader('FINDING YOU'),
              const SizedBox(height: 10),
              _card(
                child: _toggle(
                  icon: Icons.person_search_outlined,
                  title: 'Appear in search',
                  subtitle: _discoverable
                      ? 'Other athletes can find you by name and see you in suggestions.'
                      : 'You will not appear in search results or suggestions.',
                  value: _discoverable,
                  onChanged: (v) {
                    final previous = _discoverable;
                    setState(() => _discoverable = v);
                    _save('discoverable', v, () => _discoverable = previous);
                  },
                ),
              ),
              const SizedBox(height: 8),
              _note(
                'This controls search only. Someone who already follows you, or '
                'who opens a link to your profile, can still see it.',
              ),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Workout visibility covers your whole history. The post audience '
                        'applies to new posts; ones already shared keep their audience.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white54,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isSaving
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged(!value);
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: value
                      ? _accent.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: value ? _accent : Colors.white70,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              _buildCustomSwitch(
                value: value,
                onChanged: _isSaving ? null : onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return GestureDetector(
      onTap: onChanged != null
          ? () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: value ? _accent : const Color(0xFF2C2C32),
          border: Border.all(
            color: value
                ? _accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white24,
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }

  static Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white38,
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}
