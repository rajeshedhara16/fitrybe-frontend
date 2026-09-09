import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'subscription_screen.dart';
import 'edit_profile_screen.dart';
import 'welcome_screen.dart';
import '../services/api_client.dart';
import '../services/session_service.dart';
import '../widgets/user_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _pageBg = const Color(0xFF131316);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Card Header
              _buildUserCard(),

              const SizedBox(height: 24),

              // Pro Membership Banner
              _buildProBanner(),

              const SizedBox(height: 24),

              // Section 1: Account
              _buildSectionHeader('ACCOUNT'),
              const SizedBox(height: 10),
              _buildSettingsGroup([
                _buildSettingsTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Edit Profile',
                  subtitle: 'Update your photo, bio, and personal details',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                    );
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.security_rounded,
                  title: 'Account & Security',
                  subtitle: 'Password, email, and connected accounts',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('Account & Security settings coming soon.');
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Sharing',
                  subtitle: 'Control who can see your workout activities',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('Privacy settings coming soon.');
                  },
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 24),

              // Section 2: Preferences
              _buildSectionHeader('PREFERENCES'),
              const SizedBox(height: 10),
              _buildSettingsGroup([
                _buildSettingsTile(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notifications',
                  subtitle: 'Push alerts, trybe invites, and kudos',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('Notification preferences coming soon.');
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.straighten_rounded,
                  title: 'Units of Measure',
                  subtitle: 'Kilometers (km), Kilograms (kg)',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('Unit preferences coming soon.');
                  },
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 24),

              // Section 3: Support & About
              _buildSectionHeader('SUPPORT'),
              const SizedBox(height: 10),
              _buildSettingsGroup([
                _buildSettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help & Support',
                  subtitle: 'FAQ, contact team, or report an issue',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('Support page coming soon.');
                  },
                ),
                _buildSettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About FiTrybe',
                  subtitle: 'Version 1.0.0 · Terms & Privacy Policy',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showComingSoon('FiTrybe v1.0.0');
                  },
                  showDivider: false,
                ),
              ]),

              const SizedBox(height: 28),

              // Log Out Button
              _buildLogOutButton(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    final avatar = SessionService().avatarUrl;
    final name = SessionService().displayName;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          UserAvatar(
            url: avatar,
            fallbackName: name,
            radius: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Fitrybe Athlete' : name,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  SessionService().userId != null
                      ? 'ID: ${SessionService().userId!.substring(0, (SessionService().userId!.length).clamp(0, 12))}...'
                      : 'Athlete',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Edit',
              style: GoogleFonts.hankenGrotesk(
                color: _accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProBanner() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _accent.withValues(alpha: 0.25),
              const Color(0xFFFF9800).withValues(alpha: 0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded, color: _accent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'FiTrybe PRO',
                        style: GoogleFonts.anybody(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'PREMIUM',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock advanced analytics, custom routes & pro badges.',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _accent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white70, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 56,
            endIndent: 16,
            color: Colors.white.withValues(alpha: 0.04),
          ),
      ],
    );
  }

  Widget _buildLogOutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade400.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade400.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 20),
        ),
        title: Text(
          'Log Out',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.red.shade400,
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Sign out of your FiTrybe account',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 12,
          ),
        ),
        onTap: () async {
          HapticFeedback.heavyImpact();
          final nav = Navigator.of(context);
          await ApiClient().clearTokens();
          nav.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1F1F22),
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(color: Colors.white70),
        ),
      ),
    );
  }
}
