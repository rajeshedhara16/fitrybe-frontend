import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _bg = const Color(0xFF131316);

  // Profile fields controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;

  final ImagePicker _picker = ImagePicker();
  bool _isSaving = false;
  bool _isUploading = false;

  String? get _bannerUrl => SessionService().bannerUrl;
  String? get _avatarUrl => SessionService().avatarUrl;

  @override
  void initState() {
    super.initState();
    final user = SessionService().user;
    final first = (user?['firstName'] as String?)?.trim() ?? '';
    final last = (user?['lastName'] as String?)?.trim() ?? '';
    _nameController = TextEditingController(text: '$first $last'.trim());
    _bioController =
        TextEditingController(text: (user?['bio'] as String?) ?? '');
    _locationController =
        TextEditingController(text: (user?['location'] as String?) ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload({required bool isAvatar}) async {
    if (_isUploading) return;
    HapticFeedback.lightImpact();
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);
      final updated = isAvatar
          ? await ApiService.uploadAvatar(File(picked.path))
          : await ApiService.uploadBanner(File(picked.path));
      SessionService().update(updated);
      if (!mounted) return;
      setState(() => _isUploading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      _toast(e is ApiException ? e.message : 'Could not upload that image.');
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    // The API stores first/last separately; split on the first space.
    final fullName = _nameController.text.trim();
    final spaceIndex = fullName.indexOf(' ');
    final firstName =
        spaceIndex == -1 ? fullName : fullName.substring(0, spaceIndex);
    final lastName =
        spaceIndex == -1 ? '' : fullName.substring(spaceIndex + 1).trim();

    try {
      final updated = await ApiService.updateProfile({
        if (firstName.isNotEmpty) 'firstName': firstName,
        if (lastName.isNotEmpty) 'lastName': lastName,
        'bio': _bioController.text.trim(),
        'location': _locationController.text.trim(),
      });
      SessionService().update(updated);
      if (!mounted) return;
      setState(() => _isSaving = false);
      _toast('Profile updated successfully!', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _toast(e is ApiException ? e.message : 'Could not save your profile.');
    }
  }

  void _toast(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? _accent : _cardBg,
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: success ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _accent),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner & Avatar stack with Edit buttons
            SizedBox(
              height: 220,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Banner background
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 160,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Opacity(
                          opacity: 0.4,
                          child: _bannerUrl == null
                              ? Container(
                                  color: _accent.withValues(alpha: 0.35))
                              : Image.network(
                                  _bannerUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                      color: _accent.withValues(alpha: 0.35)),
                                ),
                        ),
                        // Black overlay gradient
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                _bg.withValues(alpha: 0.8),
                                _bg,
                              ],
                            ),
                          ),
                        ),
                        // Camera overlay button for cover photo
                        Center(
                          child: GestureDetector(
                            onTap: () => _pickAndUpload(isAvatar: false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Change Cover',
                                    style: GoogleFonts.hankenGrotesk(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Avatar
                  Positioned(
                    bottom: 0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _bg, width: 4),
                          ),
                          child: UserAvatar(
                            url: _avatarUrl,
                            fallbackName: SessionService().displayName,
                            radius: 46,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _pickAndUpload(isAvatar: true),
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                              border: Border.all(color: _bg, width: 4),
                            ),
                            alignment: Alignment.center,
                            child: _isUploading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Input Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Display Name'),
                  _buildTextField(_nameController, Icons.person_outline_rounded, 'Enter display name'),
                  const SizedBox(height: 20),

                  _buildLabel('Bio'),
                  _buildTextField(
                    _bioController,
                    Icons.text_fields_rounded,
                    'Tell us about yourself...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),

                  _buildLabel('Location'),
                  _buildTextField(
                    _locationController,
                    Icons.location_on_outlined,
                    'City, Country',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white54,
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    IconData icon,
    String hint, {
    int maxLines = 1,
    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      style: GoogleFonts.hankenGrotesk(
        color: readOnly ? Colors.white38 : Colors.white,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30),
        prefixIcon: Icon(icon, color: readOnly ? Colors.white24 : Colors.white38, size: 20),
        suffixIcon: readOnly
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed_rounded, color: Colors.white24, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Auto',
                      style: GoogleFonts.hankenGrotesk(color: Colors.white24, fontSize: 11),
                    ),
                  ],
                ),
              )
            : null,
        filled: true,
        fillColor: readOnly ? _cardBg.withValues(alpha: 0.3) : _cardBg.withValues(alpha: 0.6),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.03)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: _accent.withValues(alpha: 0.5)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
