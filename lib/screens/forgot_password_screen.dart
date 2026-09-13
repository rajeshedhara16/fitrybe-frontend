import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auth_screens.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Resetting a forgotten password with a code emailed to the account address.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.initialEmail,
    this.isSettingFirstPassword = false,
  });

  /// Carried over from the sign-in form, so nobody types their address twice.
  final String? initialEmail;

  /// True when reached from Account & Security by someone whose account has no
  /// password, because they signed up with Google or Apple.
  ///
  /// The mechanics are identical, a code to the address on file and then a new
  /// password, but the words are not. Someone who never had a password has not
  /// forgotten one, and reassuring them about a problem they do not have reads
  /// as a wrong turn.
  final bool isSettingFirstPassword;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

enum _Stage { email, code }

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _accent = Color(0xFFFF5722);

  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  _Stage _stage = _Stage.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _sentMessage = '';

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail?.trim() ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _email => _emailController.text.trim();

  Future<void> _requestCode() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final message = await ApiService.requestPasswordReset(_email);
      if (!mounted) return;
      setState(() {
        _sentMessage = message;
        _stage = _Stage.code;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showAuthError(context, e);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!(_codeFormKey.currentState?.validate() ?? false)) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await ApiService.resetPassword(
        email: _email,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      final user = await SessionService().load();
      if (!mounted) return;

      landAfterAuth(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _codeController.clear();
      });
      showAuthError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStage = _stage == _Stage.code;
    final isFirstPassword = widget.isSettingFirstPassword;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () {
            if (onCodeStage && !_isLoading) {
              setState(() => _stage = _Stage.email);
              return;
            }
            Navigator.pop(context);
          },
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FitrybeBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: isKeyboardOpen
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              onCodeStage
                                  ? 'SECURITY CODE'
                                  : (isFirstPassword
                                      ? 'ACCOUNT SECURITY'
                                      : 'ACCOUNT RECOVERY'),
                              style: GoogleFonts.anybody(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _accent,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: GoogleFonts.anybody(
                                  fontSize: 38,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                  height: 1.1,
                                ),
                                children: onCodeStage
                                    ? const [
                                        TextSpan(
                                          text: 'VERIFY ',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                        TextSpan(
                                          text: 'CODE',
                                          style: TextStyle(color: _accent),
                                        ),
                                      ]
                                    : (isFirstPassword
                                        ? const [
                                            TextSpan(
                                              text: 'SET A ',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            TextSpan(
                                              text: 'PASSWORD',
                                              style: TextStyle(color: _accent),
                                            ),
                                          ]
                                        : const [
                                            TextSpan(
                                              text: 'FORGOT ',
                                              style: TextStyle(
                                                  color: Colors.white),
                                            ),
                                            TextSpan(
                                              text: 'PASSWORD?',
                                              style: TextStyle(color: _accent),
                                            ),
                                          ]),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              onCodeStage
                                  ? (_sentMessage.isNotEmpty
                                      ? _sentMessage
                                      : 'We sent a 6-digit verification code to $_email. Enter it below along with your new password.')
                                  : (isFirstPassword
                                      ? 'You sign in with a connected account, so you don\'t have a password yet. Adding one gives you a second way in. We\'ll email you a code to confirm it\'s you.'
                                      : 'Don\'t worry! Enter your registered email address and we\'ll send you a code to reset your password.'),
                              style: GoogleFonts.hankenGrotesk(
                                color: const Color(0xFFA0A0A0),
                                fontSize: 14.5,
                                height: 1.35,
                              ),
                            ),

                            const Spacer(flex: 1),

                            // Glassmorphism Container Card (Identical to Login Screen)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withValues(alpha: 0.12),
                                        const Color(0xFF14141A).withValues(alpha: 0.45),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.45),
                                        blurRadius: 30,
                                        offset: const Offset(0, 12),
                                      ),
                                    ],
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 300),
                                    child: onCodeStage
                                        ? _buildCodeStage()
                                        : _buildEmailStage(),
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(flex: 1),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailStage() {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email_stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Email Label & Input
          Text(
            'Email',
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFFE2E2E2),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _requestCode();
            },
            style: GoogleFonts.hankenGrotesk(color: Colors.white),
            decoration: buildAuthInputDecoration(
              hintText: 'Enter your email',
              prefixIcon: Icons.mail_rounded,
            ),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _primaryButton(
            widget.isSettingFirstPassword ? 'Send Code' : 'Send Reset Code',
            _requestCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStage() {
    return Form(
      key: _codeFormKey,
      child: Column(
        key: const ValueKey('code_stage'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Code Label & Input
          Text(
            '6-digit Code',
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFFE2E2E2),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 3,
            ),
            decoration: buildAuthInputDecoration(
              hintText: 'Enter 6-digit code',
              prefixIcon: Icons.pin_rounded,
            ).copyWith(counterText: ''),
            validator: (value) {
              if ((value?.trim().length ?? 0) != 6) {
                return 'Enter the 6-digit code from your email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // New Password Label & Input
          Text(
            'New Password',
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFFE2E2E2),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: GoogleFonts.hankenGrotesk(color: Colors.white),
            decoration: buildAuthInputDecoration(
              hintText: 'Enter new password',
              prefixIcon: Icons.lock_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFA0A0A0),
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Confirm Password Label & Input
          Text(
            'Confirm Password',
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFFE2E2E2),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirmPassword,
            style: GoogleFonts.hankenGrotesk(color: Colors.white),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _submitNewPassword();
            },
            decoration: buildAuthInputDecoration(
              hintText: 'Confirm new password',
              prefixIcon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: const Color(0xFFA0A0A0),
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Primary Reset Password Button
          _primaryButton(
            widget.isSettingFirstPassword
                ? 'Set Password'
                : 'Reset Password',
            _submitNewPassword,
          ),
          const SizedBox(height: 10),

          // Resend Code Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _stage = _Stage.email;
                        _codeController.clear();
                      });
                    },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Didn\'t receive code? Resend',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFFFF5722),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFFF5722),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: const StadiumBorder(),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }
}
