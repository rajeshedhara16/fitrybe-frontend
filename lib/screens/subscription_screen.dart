import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  static const routeName = '/SubscriptionScreen';
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = Colors.black;

  int _selectedPlanIndex = 0; // 0: Yearly (Best Value), 1: Monthly
  bool _isSubscribing = false;
  bool _isPro = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await ApiService.getSubscriptionStatus();
    if (!mounted) return;
    setState(() => _isPro = status['isPro'] == true);
  }

  Future<void> _onSubscribePressed() async {
    if (_isSubscribing) return;
    HapticFeedback.heavyImpact();
    final plan = _selectedPlanIndex == 0 ? 'ANNUAL' : 'MONTHLY';
    setState(() => _isSubscribing = true);

    try {
      await ApiService.subscribe(plan);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubscribing = false);
      // Never claim the upgrade worked when the server rejected it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F1F22),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not start your subscription. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubscribing = false;
      _isPro = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🎉 Welcome to Trybe Pro! All Premium features unlocked.',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
    Navigator.pop(context, true); // return true indicating subscription success
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle White Ambient Gradient & Background Blur
            Positioned.fill(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      gradient: RadialGradient(
                        center: Alignment(0.0, -0.6),
                        radius: 1.2,
                        colors: [
                          Color(0x1CFFFFFF), // Subtle white ambient glow
                          Color(0x08FFFFFF),
                          Colors.black,
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Scrollable Content
            Column(
              children: [
                // Top Header Row
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E22),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context, false);
                        },
                        child: Text(
                          'No thanks',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),

                        // Hero Pill Tag
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _accent,
                                  const Color(0xFFFF8A65),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.4),
                                  blurRadius: 12,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  'TRYBE PRO PREMIUM',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Headline
                        Center(
                          child: Text(
                            'Elevate Every Activity',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Center(
                          child: Text(
                            'Get real-time GPS route mapping, live clique synergy, and pro analytics built for athletes.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white60,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Feature Checklist
                        _buildFeatureRow(
                          Icons.map_rounded,
                          'Live GPS Route Mapping',
                          'Interactive dark vector map polyline & live location tracing',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          Icons.insights_rounded,
                          'Pro Performance Analytics',
                          'Heart rate zones, elevation profiles, and pace breakdowns',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          Icons.groups_rounded,
                          'Unlimited Cliques & Live Squads',
                          'Host unlimited real-time squad activities and leaderboard battles',
                        ),
                        const SizedBox(height: 14),
                        _buildFeatureRow(
                          Icons.spatial_audio_off_rounded,
                          'Live Audio Cue Milestones',
                          'Audio pace alerts and live squad motivation cheers',
                        ),

                        const SizedBox(height: 32),

                        // Pricing Plans Title
                        Text(
                          'CHOOSE YOUR PLAN',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Plan Card 1: Yearly (Recommended)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPlanIndex = 0);
                          },
                          child: _buildPlanCard(
                            index: 0,
                            title: 'ANNUAL PLAN',
                            price: '\$49.99',
                            period: '/ year',
                            subText: '\$4.16/month · Billed annually',
                            badgeText: 'SAVE 40% · 7-DAY FREE TRIAL',
                            isPopular: true,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Plan Card 2: Monthly
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPlanIndex = 1);
                          },
                          child: _buildPlanCard(
                            index: 1,
                            title: 'MONTHLY PLAN',
                            price: '\$8.99',
                            period: '/ month',
                            subText: 'Billed monthly · Cancel anytime',
                            badgeText: null,
                            isPopular: false,
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // Bottom Fixed CTA Button Area
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              (_isSubscribing || _isPro) ? null : _onSubscribePressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _accent.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white70,
                            elevation: 8,
                            shadowColor: _accent.withValues(alpha: 0.5),
                            shape: const StadiumBorder(),
                          ),
                          child: _isSubscribing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isPro
                                      ? "YOU'RE ON TRYBE PRO"
                                      : _selectedPlanIndex == 0
                                          ? 'START 7-DAY FREE TRIAL'
                                          : 'SUBSCRIBE NOW',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedPlanIndex == 0
                            ? '7 days free, then \$49.99/year. Cancel anytime in App Store settings.'
                            : 'Billed monthly at \$8.99. Cancel anytime in App Store settings.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _accent, size: 20),
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required int index,
    required String title,
    required String price,
    required String period,
    required String subText,
    required String? badgeText,
    required bool isPopular,
  }) {
    final bool isSelected = _selectedPlanIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF25252B)
            : const Color(0xFF18181C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
          width: isSelected ? 2.0 : 1.0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.25),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _accent : Colors.white38,
                        width: isSelected ? 6.0 : 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: GoogleFonts.hankenGrotesk(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: _accent.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: GoogleFonts.anybody(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                period,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white54,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}
