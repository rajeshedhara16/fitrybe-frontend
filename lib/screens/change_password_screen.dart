import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

/// Changes the password of an account that already has one.
///
/// Setting a *first* password is not this screen. That has no current password
/// to prove ownership with, so it goes through the emailed-code flow instead.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  static const Color _bg = Color(0xFF0B0B0D);
  static const Color _cardBg = Color(0xFF1C1C1E);
  static const Color _accent = Color(0xFFFF5722);

  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSaving = false;
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    try {
      // The server issues this device a fresh token pair, so changing the
      // password does not sign the person doing it out along with everyone else.
      await ApiService.changePassword(
        _currentController.text,
        _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Password changed. Other devices have been signed out.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          behavior: SnackBarBehavior.floating,
          content: Text(
            '$e'.replaceFirst('Exception: ', ''),
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text(
          'Change Password',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _currentController,
                  hint: 'Current password',
                  icon: Icons.lock_outline_rounded,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Enter your current password'
                      : null,
                  withToggle: true,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _newController,
                  hint: 'New password',
                  icon: Icons.lock_rounded,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a new password';
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (v == _currentController.text) {
                      return 'That is the password you already have';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _confirmController,
                  hint: 'Confirm new password',
                  icon: Icons.lock_reset_rounded,
                  validator: (v) =>
                      v == _newController.text ? null : 'Passwords do not match',
                ),
                const SizedBox(height: 14),
                Text(
                  'Changing your password signs you out on every other device. '
                  'This one stays signed in.',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Text(
                          'Update password',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool withToggle = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: _obscure,
      enabled: !_isSaving,
      style: GoogleFonts.hankenGrotesk(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            GoogleFonts.hankenGrotesk(color: Colors.white24, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white70, size: 21),
        // One toggle for all three: they are typed in one sitting and hiding
        // some while showing others helps nobody.
        suffixIcon: withToggle
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
        filled: true,
        fillColor: _cardBg,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
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
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
