import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'user_details_screen.dart';
import '../services/api_service.dart';
import '../services/apple_auth.dart';
import '../services/google_auth.dart';
import '../services/session_service.dart';

/// Surfaces backend auth failures (bad credentials, duplicate email,
/// unreachable server) instead of leaving the button silently idle.
void _showAuthError(BuildContext context, Object error) {
  debugPrint('AUTH ERROR DETAILS: $error');
  final String message;
  if (error is ApiException) {
    message = error.message;
  } else if (error is Exception) {
    final str = error.toString();
    message = str.startsWith('Exception: ') ? str.substring(11) : str;
  } else {
    message = error.toString();
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: const Color(0xFF252528),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
      ),
    ),
  );
}

/// Sends the athlete to the feed, or back into the profile wizard if they never
/// finished it. Clears the auth screens behind them either way.
void _landAfterAuth(BuildContext context, Map<String, dynamic>? user) {
  final completedOnboarding = user?['onboardingCompleted'] == true;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) =>
          completedOnboarding ? const HomeScreen() : const UserDetailsScreen(),
    ),
    (route) => false,
  );
}

/// Signs in with Google, from either the sign-in or the sign-up screen.
///
/// There is no separate Google "sign up": the server attaches the identity to
/// the account that already holds the address, or makes one, so the same call
/// serves both buttons.
///
/// Returns true if the screen should stay in its loading state because a route
/// change is under way. Backing out of the Google sheet returns false with
/// nothing shown, since cancelling is not an error.
Future<bool> _signInWithGoogle(BuildContext context) async {
  try {
    final idToken = await GoogleAuth.idToken();
    if (idToken == null) return false;

    await ApiService.socialLogin('GOOGLE', idToken);
    final user = await SessionService().load();
    if (!context.mounted) return false;

    _landAfterAuth(context, user);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    _showAuthError(context, e);
    return false;
  }
}

/// Signs in with Apple, from either the sign-in or the sign-up screen.
///
/// Apple hands over a name only on the very first authorization for this app,
/// so it is passed along here. The server treats it as a hint and uses it only
/// to fill a blank on a brand new account; the identity itself comes out of the
/// token it verified.
Future<bool> _signInWithApple(BuildContext context) async {
  try {
    final credential = await AppleAuth.authorize();
    if (credential == null) return false;

    await ApiService.socialLogin(
      'APPLE',
      credential.identityToken,
      firstName: credential.firstName,
      lastName: credential.lastName,
    );
    final user = await SessionService().load();
    if (!context.mounted) return false;

    _landAfterAuth(context, user);
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    _showAuthError(context, e);
    return false;
  }
}

/// The Apple button, matching the Google one beside it.
///
/// Returns nothing at all off Apple platforms: the Android flow is a browser
/// redirect that is not wired up, and a button that cannot work is worse than
/// no button. Apple's own guidelines want its logo and wording left alone, so
/// the label is fixed rather than themed per screen.
Widget _appleSignInButton({
  required bool isLoading,
  required VoidCallback onPressed,
}) {
  if (!AppleAuth.isSupported) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF2E2E32), width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: const StadiumBorder(),
        backgroundColor: const Color(0x1AFFFFFF),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.apple, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Text(
            'Continue with Apple',
            style: GoogleFonts.hankenGrotesk(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await ApiService.login(email, password);
      final user = await SessionService().load();
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Users who never finished the profile wizard resume it on next sign-in.
      _landAfterAuth(context, user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showAuthError(context, e);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    final navigated = await _signInWithGoogle(context);
    // Leave the spinner up while the route change runs, so the button cannot be
    // pressed a second time on the way out.
    if (!navigated && mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleApple() async {
    setState(() => _isLoading = true);
    final navigated = await _signInWithApple(context);
    if (!navigated && mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
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
                                'WELCOME BACK',
                                style: GoogleFonts.anybody(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF5722),
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
                                  children: const [
                                    TextSpan(
                                      text: 'SIGN ',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: 'IN',
                                      style: TextStyle(color: Color(0xFFFF5722)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Sign in to connect with your tribe and track your daily targets.",
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFFA0A0A0),
                                  fontSize: 14.5,
                                  height: 1.35,
                                ),
                              ),

                              const Spacer(flex: 1),

                              // Glassmorphism Container Card
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
                                    child: Column(
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
                                          style: GoogleFonts.hankenGrotesk(color: Colors.white),
                                          decoration: _buildInputDecoration(
                                            hintText: 'Enter your email',
                                            prefixIcon: Icons.mail_rounded,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                              return 'Please enter a valid email address';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Password Label & Input
                                        Text(
                                          'Password',
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
                                          decoration: _buildInputDecoration(
                                            hintText: 'Enter your password',
                                            prefixIcon: Icons.lock_rounded,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                color: const Color(0xFFA0A0A0),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            if (value.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 6),

                                        // Forgot Password link
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () {},
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text(
                                              'Forgot Password?',
                                              style: GoogleFonts.hankenGrotesk(
                                                color: const Color(0xFFFF5722),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),

                                        // Login Button (Solid Orange Capsule)
                                        ElevatedButton(
                                          onPressed: _isLoading ? null : _handleLogin,
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
                                                  'Login',
                                                  style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 18),

                                        // Divider: Or continue with
                                        Row(
                                          children: [
                                            const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Text(
                                                'Or continue with',
                                                style: GoogleFonts.hankenGrotesk(
                                                  color: const Color(0x66FFFFFF),
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        // Google Button (Wide Center Outlined Stadium Button)
                                        OutlinedButton(
                                          onPressed:
                                              _isLoading ? null : _handleGoogle,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF2E2E32), width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 15),
                                            shape: const StadiumBorder(),
                                            backgroundColor: const Color(0x1AFFFFFF),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Image.asset('assets/images/google.png', width: 20, height: 20),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Login with google',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Apple. Required by App Review
                                        // guideline 4.8 wherever another
                                        // third-party sign-in is offered.
                                        _appleSignInButton(
                                          isLoading: _isLoading,
                                          onPressed: _handleApple,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(flex: 1),

                              // Don't have an account Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    "Don't have an account? ",
                                    style: GoogleFonts.hankenGrotesk(
                                      color: const Color(0x80FFFFFF),
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Register',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: const Color(0xFFFF5722),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
      ),
    );
  }

}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      await ApiService.register(email, password);
      await SessionService().load();
      if (!mounted) return;
      setState(() => _isLoading = false);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UserDetailsScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showAuthError(context, e);
    }
  }

  /// Google has no separate sign-up. Someone who already has an account here
  /// gets signed in to it rather than blocked, which is what they meant.
  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    final navigated = await _signInWithGoogle(context);
    if (!navigated && mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleApple() async {
    setState(() => _isLoading = true);
    final navigated = await _signInWithApple(context);
    if (!navigated && mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Stack(
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
                                'JOIN THE TRYBE',
                                style: GoogleFonts.anybody(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFF5722),
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
                                  children: const [
                                    TextSpan(
                                      text: 'CREATE ',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    TextSpan(
                                      text: 'ACCOUNT',
                                      style: TextStyle(color: Color(0xFFFF5722)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Thank you for joining our fitrybe community — let's get you set up.",
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFFA0A0A0),
                                  fontSize: 14.5,
                                  height: 1.35,
                                ),
                              ),

                              const Spacer(flex: 1),

                              // Glassmorphism Container Card
                              ClipRRect(
                                borderRadius: BorderRadius.circular(26),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                                    child: Column(
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
                                          style: GoogleFonts.hankenGrotesk(color: Colors.white),
                                          decoration: _buildInputDecoration(
                                            hintText: 'Enter your email',
                                            prefixIcon: Icons.mail_rounded,
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                              return 'Please enter a valid email address';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 14),

                                        // Password Label & Input
                                        Text(
                                          'Password',
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
                                          decoration: _buildInputDecoration(
                                            hintText: 'Create a password',
                                            prefixIcon: Icons.lock_rounded,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                                color: const Color(0xFFA0A0A0),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword = !_obscurePassword;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            if (value.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 14),

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
                                          controller: _confirmPasswordController,
                                          obscureText: _obscureConfirmPassword,
                                          style: GoogleFonts.hankenGrotesk(color: Colors.white),
                                          decoration: _buildInputDecoration(
                                            hintText: 'Confirm your password',
                                            prefixIcon: Icons.lock_rounded,
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                                color: const Color(0xFFA0A0A0),
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                                });
                                              },
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null || value.isEmpty) {
                                              return 'Please confirm your password';
                                            }
                                            if (value != _passwordController.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 18),

                                        // Create Account Button (Solid Orange Capsule)
                                        ElevatedButton(
                                          onPressed: _isLoading ? null : _handleRegister,
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
                                                  'Create Account',
                                                  style: GoogleFonts.hankenGrotesk(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 16),

                                        // Divider: Or continue with
                                        Row(
                                          children: [
                                            const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                              child: Text(
                                                'Or continue with',
                                                style: GoogleFonts.hankenGrotesk(
                                                  color: const Color(0x66FFFFFF),
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                            ),
                                            const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                                          ],
                                        ),
                                        const SizedBox(height: 14),

                                        // Google Button (Wide Center Outlined Stadium Button)
                                        OutlinedButton(
                                          onPressed:
                                              _isLoading ? null : _handleGoogle,
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFF2E2E32), width: 1.5),
                                            padding: const EdgeInsets.symmetric(vertical: 15),
                                            shape: const StadiumBorder(),
                                            backgroundColor: const Color(0x1AFFFFFF),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Image.asset('assets/images/google.png', width: 20, height: 20),
                                              const SizedBox(width: 12),
                                              Text(
                                                'Join with google',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Apple. Required by App Review
                                        // guideline 4.8 wherever another
                                        // third-party sign-in is offered.
                                        _appleSignInButton(
                                          isLoading: _isLoading,
                                          onPressed: _handleApple,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const Spacer(flex: 1),

                              // Already have an account Link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.hankenGrotesk(
                                      color: const Color(0x80FFFFFF),
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                                      );
                                    },
                                    child: Text(
                                      'Log in',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: const Color(0xFFFF5722),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
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
      ),
    );
  }
}

InputDecoration _buildInputDecoration({
  String? hintText,
  String? labelText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: GoogleFonts.hankenGrotesk(
      color: const Color(0x66FFFFFF),
      fontSize: 14,
    ),
    labelText: labelText,
    labelStyle: GoogleFonts.hankenGrotesk(
      color: const Color(0x99FFFFFF),
      fontSize: 14.5,
    ),
    prefixIcon: Icon(prefixIcon, color: Colors.white70, size: 21),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF131317).withValues(alpha: 0.65),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFFF5722), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

class FitrybeBackground extends StatefulWidget {
  final bool isSubtle;
  const FitrybeBackground({super.key, this.isSubtle = false});

  @override
  State<FitrybeBackground> createState() => _FitrybeBackgroundState();
}

class _FitrybeBackgroundState extends State<FitrybeBackground> {
  late final double _glowWidth;
  late final double _glowHeight;

  double? _top;
  double? _bottom;
  double? _left;
  double? _right;

  late final double _alpha;
  late final double _radialStop;

  @override
  void initState() {
    super.initState();
    final random = Random();

    // 1. Random size & aspect ratio (creates distinct shapes of elliptical fog)
    _glowWidth = 350.0 + random.nextDouble() * 250.0; // 350 to 600
    _glowHeight = 300.0 + random.nextDouble() * 250.0; // 300 to 550

    // 2. Random opacity / stop density
    _alpha = 0.25 + random.nextDouble() * 0.15; // 0.25 to 0.40
    _radialStop = 0.65 + random.nextDouble() * 0.15; // 0.65 to 0.80

    // 3. Random location positioning (placed off-screen or on edges to bleed inward)
    final positionType = random.nextInt(4);
    switch (positionType) {
      case 0: // Bottom edge area
        _bottom = -120.0 + random.nextDouble() * 90.0; // -120 to -30
        _left = -100.0 + random.nextDouble() * 200.0;
        break;
      case 1: // Top edge area
        _top = -120.0 + random.nextDouble() * 90.0; // -120 to -30
        _right = -100.0 + random.nextDouble() * 200.0;
        break;
      case 2: // Left edge area
        _top = 100.0 + random.nextDouble() * 300.0;
        _left = -160.0 + random.nextDouble() * 90.0;
        break;
      case 3: // Right edge area
        _top = 100.0 + random.nextDouble() * 300.0;
        _right = -160.0 + random.nextDouble() * 90.0;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryAlpha = widget.isSubtle ? 0.10 : 0.35;
    final secondaryAlpha = widget.isSubtle ? 0.08 : 0.28;
    final randomAlpha = widget.isSubtle ? _alpha * 0.35 : _alpha;

    return Stack(
      children: [
        // 1. Deep custom color background fill (pure black)
        Positioned.fill(
          child: Container(color: Colors.black),
        ),

        // 2. Grain pattern overlay (custom textured noise overlay)
        Positioned.fill(
          child: CustomPaint(
            painter: _GrainPainter(),
          ),
        ),

        // 3. Dynamic ambient glow orb behind the glass card (primary warm FitRybe tone)
        Positioned(
          top: size.height * 0.26,
          right: -50,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFF5722).withValues(alpha: primaryAlpha),
                  const Color(0xFFFF5722).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // 4. Secondary ambient glow orb behind the glass card (vibrant amber / coral)
        Positioned(
          bottom: size.height * 0.18,
          left: -50,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFE6A2B).withValues(alpha: secondaryAlpha),
                  const Color(0xFFFE6A2B).withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.75],
              ),
            ),
          ),
        ),

        // 5. Randomized Atmospheric Radial Glow
        Positioned(
          top: _top,
          bottom: _bottom,
          left: _left,
          right: _right,
          child: Container(
            width: _glowWidth,
            height: _glowHeight,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  Color(0xFFFF5722).withValues(alpha: randomAlpha),
                  const Color(0xFFFF5722).withValues(alpha: 0.0),
                ],
                stops: [0.0, _radialStop],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1.0;

    const grid = 6.0;
    for (double y = 0; y < size.height; y += grid) {
      for (double x = 0; x < size.width; x += grid) {
        canvas.drawRect(Rect.fromLTWH(x, y, 1, 1), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
