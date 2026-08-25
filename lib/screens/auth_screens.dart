import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'user_details_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// Surfaces backend auth failures (bad credentials, duplicate email,
/// unreachable server) instead of leaving the button silently idle.
void _showAuthError(BuildContext context, Object error) {
  final message = error is ApiException
      ? error.message
      : 'Could not reach Fitrybe. Check your connection and try again.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, style: GoogleFonts.hankenGrotesk()),
      backgroundColor: const Color(0xFF2D2D2D),
      behavior: SnackBarBehavior.floating,
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
      final completedOnboarding = user?['onboardingCompleted'] == true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => completedOnboarding
              ? const HomeScreen()
              : const UserDetailsScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showAuthError(context, e);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
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
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.0,
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
                      const SizedBox(height: 12),
                      Text(
                        "Sign in to connect with your tribe and track your daily targets.",
                        style: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFFA0A0A0),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Email',
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
                      const SizedBox(height: 20),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Password',
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
                      const SizedBox(height: 12),

                      // Forgot Password link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text(
                            'Forgot Password?',
                            style: GoogleFonts.hankenGrotesk(
                              color: const Color(0xFFFF5722),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Login Button (Solid Orange Capsule)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5722),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
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
                      const SizedBox(height: 32),

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
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Google Button (Wide Center Outlined Stadium Button)
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const UserDetailsScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E2E32), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          backgroundColor: const Color(0x1AFFFFFF),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/google.png', width: 22, height: 22),
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
                      const SizedBox(height: 40),

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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
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
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.0,
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
                      const SizedBox(height: 12),
                      Text(
                        "Thank you for joining our fitrybe community — let's get you set up.",
                        style: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFFA0A0A0),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Email Input
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Email',
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
                      const SizedBox(height: 20),

                      // Password Input
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Password',
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
                      const SizedBox(height: 20),

                      // Confirm Password Input
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                        decoration: _buildInputDecoration(
                          labelText: 'Confirm Password',
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
                      const SizedBox(height: 36),

                      // Create Account Button (Solid Orange Capsule)
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF5722),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
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
                      const SizedBox(height: 32),

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
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFF2D2D2D))),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Google Button (Wide Center Outlined Stadium Button)
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E2E32), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const StadiumBorder(),
                          backgroundColor: const Color(0x1AFFFFFF),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/images/google.png', width: 22, height: 22),
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
                      const SizedBox(height: 40),

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
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

InputDecoration _buildInputDecoration({
  required String labelText,
  required IconData prefixIcon,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: labelText,
    labelStyle: GoogleFonts.hankenGrotesk(
      color: const Color(0x99FFFFFF),
      fontSize: 15,
    ),
    prefixIcon: Icon(prefixIcon, color: Colors.white, size: 22),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFF1C1C1E),
    contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
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
  const FitrybeBackground({super.key});

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

        // 3. Randomized Radial Glow
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
                  const Color(0xFFFF5722).withValues(alpha: _alpha),
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
