import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'profile_tab.dart';
import '../services/session_service.dart';

/// Screen for displaying any user's profile page.
/// If viewing another user's profile, it shows all details identical to
/// our own profile page without the "Edit Profile" option.
class UserProfileScreen extends StatelessWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  static void navigate(BuildContext context, String? userId) {
    if (userId == null || userId.trim().isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(userId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = userId == SessionService().userId;

    return Scaffold(
      backgroundColor: const Color(0xFF141416),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isOwnProfile ? 'My Profile' : 'Profile',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: ProfileTab(userId: userId),
      ),
    );
  }
}
