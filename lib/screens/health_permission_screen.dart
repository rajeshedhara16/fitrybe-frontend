import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screens.dart'; // for FitrybeBackground
import 'home_screen.dart';
import '../services/api_client.dart';
import '../services/health_service.dart';

class HealthPermissionScreen extends StatefulWidget {
  static const routeName = '/HealthPermissionScreen';
  const HealthPermissionScreen({super.key});

  @override
  State<HealthPermissionScreen> createState() => _HealthPermissionScreenState();
}

class _HealthPermissionScreenState extends State<HealthPermissionScreen> {
  bool activeEnergy = true;
  bool cardioFitness = true;
  bool steps = true;

  bool _isConnecting = false;

  void _handleConnect() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _isConnecting = true;
    });

    try {
      await HealthService().requestPermissions();
      if (!ApiClient().isAuthenticated) {
        await ApiClient().saveTokens('fitrybe_active_user_token', 'fitrybe_refresh_token');
      }
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildPermissionRow({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
            activeThumbColor: const Color(0xFFFF5722),
            activeTrackColor: const Color(0xFFFF5722).withValues(alpha: 0.3),
            inactiveThumbColor: const Color(0xFF757575),
            inactiveTrackColor: const Color(0xFF303030),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.95),
            Colors.black,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: const StadiumBorder(),
              elevation: 0,
            ),
            child: Text(
              'Connect to Health',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allOn = activeEnergy && cardioFitness && steps;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Deep grid noise random orange gradient background
          const Positioned.fill(child: FitrybeBackground()),

          // 2. Main Page Layout
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subheader tag
                      Text(
                        "HEALTH ACCESS",
                        style: GoogleFonts.anybody(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFF5722),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Large Header
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.anybody(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -1.0,
                            height: 1.15,
                          ),
                          children: const [
                            TextSpan(
                              text: 'ALLOW ACCESS\nTO ',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'HEALTH.',
                              style: TextStyle(color: Color(0xFFFF5722)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Paragraph description
                      Text(
                        'Health breathes life into fitrybe, enabling you to get personalized Activity Path, log workouts, receive fitness and well-being summaries - all while being guided towards a healthier you.',
                        style: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFFA0A0A0),
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Matte card container
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131315),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                        child: Column(
                          children: [
                            // White icon box representing Health app
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.redAccent,
                                  size: 42,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Health',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Interactive Turn On All button
                            OutlinedButton(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  final target = !allOn;
                                  activeEnergy = target;
                                  cardioFitness = target;
                                  steps = target;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                allOn ? 'Turn Off All' : 'Turn On All',
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFF448AFF),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Divider(color: Colors.white10, height: 1),
                            const SizedBox(height: 12),
                            // Active Energy Permission
                            _buildPermissionRow(
                              icon: Icons.bolt_rounded,
                              iconBg: const Color(0xFFFFB300).withValues(alpha: 0.1),
                              iconColor: const Color(0xFFFFB300),
                              label: 'Active Energy',
                              value: activeEnergy,
                              onChanged: (val) {
                                setState(() => activeEnergy = val);
                              },
                            ),
                            // Cardio Fitness Permission
                            _buildPermissionRow(
                              icon: Icons.favorite_rounded,
                              iconBg: const Color(0xFFE57373).withValues(alpha: 0.1),
                              iconColor: const Color(0xFFE57373),
                              label: 'Cardio Fitness',
                              value: cardioFitness,
                              onChanged: (val) {
                                setState(() => cardioFitness = val);
                              },
                            ),
                            // Steps Permission
                            _buildPermissionRow(
                              icon: Icons.directions_run_rounded,
                              iconBg: const Color(0xFF81C784).withValues(alpha: 0.1),
                              iconColor: const Color(0xFF81C784),
                              label: 'Steps',
                              value: steps,
                              onChanged: (val) {
                                setState(() => steps = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Connected orange button overlay
              _buildBottomBar(),
            ],
          ),

          // 3. Immersive Overlay Loader
          if (_isConnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.8),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5722)),
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Connecting with Health app...',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
