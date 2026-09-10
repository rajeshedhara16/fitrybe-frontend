import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'welcome_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Permanently deletes the account.
///
/// Deliberately unhurried. Everything that is about to be destroyed is listed
/// before the button, the word DELETE has to be typed, and an account with a
/// password has to give it. There is no undo behind this, so the screen's job
/// is to make sure nobody arrives at the end of it by accident.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  static const Color _bg = Color(0xFF0B0B0D);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _danger = Color(0xFFE53935);

  final _confirmController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isDeleting = false;
  bool _obscurePassword = true;

  /// Provider-only accounts have no password to ask for. The server knows this
  /// too and will not accept one from them.
  bool get _hasPassword => SessionService().user?['hasPassword'] == true;

  bool get _canSubmit {
    if (_confirmController.text.trim().toUpperCase() != 'DELETE') return false;
    if (_hasPassword && _passwordController.text.isEmpty) return false;
    return true;
  }

  @override
  void dispose() {
    _confirmController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    HapticFeedback.heavyImpact();
    setState(() => _isDeleting = true);

    try {
      await ApiService.deleteAccount(
        password: _hasPassword ? _passwordController.text : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '$e'.replaceFirst('Exception: ', ''),
            style: GoogleFonts.hankenGrotesk(color: Colors.white),
          ),
        ),
      );
      return;
    }

    // The account is gone, so the session cannot be revoked server-side any
    // more. Clearing locally is all that is left, and it must happen even if
    // that call fails, or the app would sit on tokens for a dead account.
    await SessionService().logout();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
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
          'Delete Account',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _danger.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: _danger, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This cannot be undone. There is no grace period and no '
                        'way to recover the account afterwards.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 13.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'WHAT GETS DELETED',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              ...const [
                'Every workout you have recorded, with its route and stats',
                'Your posts, photos, comments and kudos',
                'Your messages and conversations',
                'Your goals, streaks and achievements',
                'Your Trybe and Clique memberships',
                'Your followers and everyone you follow',
              ].map(_bullet),
              const SizedBox(height: 24),
              Text(
                _hasPassword
                    ? 'Type DELETE and enter your password to confirm.'
                    : 'Type DELETE to confirm.',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                enabled: !_isDeleting,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
                decoration: _fieldDecoration('DELETE'),
              ),
              if (_hasPassword) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  enabled: !_isDeleting,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.hankenGrotesk(color: Colors.white),
                  decoration: _fieldDecoration('Your password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.white38,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: (!_canSubmit || _isDeleting) ? null : _delete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  disabledBackgroundColor: _danger.withValues(alpha: 0.25),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                  elevation: 0,
                ),
                child: _isDeleting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Text(
                        'Delete my account permanently',
                        style: GoogleFonts.hankenGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isDeleting ? null : () => Navigator.pop(context),
                child: Text(
                  'Keep my account',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, color: Colors.white24, size: 5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white60,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.hankenGrotesk(
        color: Colors.white24,
        fontSize: 14,
        letterSpacing: 0,
      ),
      filled: true,
      fillColor: _cardBg,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
    );
  }
}
