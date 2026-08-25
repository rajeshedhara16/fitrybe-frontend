import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen>
    with SingleTickerProviderStateMixin {
  // ── Theme ──────────────────────────────────────────────────────────────────
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _bg = const Color(0xFF131316);

  // ── Caption ────────────────────────────────────────────────────────────────
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();

  // ── Post Types ─────────────────────────────────────────────────────────────
  String _selectedPostType = 'Update';
  final List<Map<String, dynamic>> _postTypes = [
    {'label': 'Update', 'icon': Icons.edit_note_rounded},
    {'label': 'Activity', 'icon': Icons.directions_run_rounded},
    {'label': 'Milestone', 'icon': Icons.emoji_events_rounded},
    {'label': 'Challenge', 'icon': Icons.local_fire_department_rounded},
  ];

  // ── Audience ───────────────────────────────────────────────────────────────
  String _selectedAudience = 'Everyone';
  final List<Map<String, dynamic>> _audiences = [
    {'label': 'Everyone', 'icon': Icons.public_rounded},
    {'label': 'Trybes', 'icon': Icons.group_rounded},
  ];

  // ── Media & Location ───────────────────────────────────────────────────────
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  String? _locationTag;
  bool _isFetchingLocation = false;
  bool _isPosting = false;

  String? get _avatarUrl => SessionService().avatarUrl;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _postTypes.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _captionFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Pick Images ────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    HapticFeedback.lightImpact();
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        limit: 5,
      );
      if (images.isNotEmpty) {
        setState(() {
          // Merge but cap at 5
          final combined = [..._selectedImages, ...images];
          _selectedImages.clear();
          _selectedImages.addAll(combined.take(5));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _cardBg,
            content: Text(
              'Could not access photos. Please allow photo library access in Settings.',
              style: GoogleFonts.hankenGrotesk(color: Colors.white70),
            ),
          ),
        );
      }
    }
  }

  // ── Fetch Location ─────────────────────────────────────────────────────────
  Future<void> _fetchLocation() async {
    HapticFeedback.lightImpact();

    // If location is already tagged → remove it
    if (_locationTag != null) {
      setState(() => _locationTag = null);
      return;
    }

    setState(() => _isFetchingLocation = true);

    try {
      // 1 ── Check service enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationError('Please enable Location Services on your device.');
        return;
      }

      // 2 ── Check / request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationError(
          'Location permission is required. Please allow it in app settings.',
        );
        return;
      }

      // 3 ── Get position (no timeLimit — avoids crashes on some Android versions)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      // 4 ── Reverse-geocode (isolated — falls back to coordinates on failure)
      String locationLabel;
      try {
        final geocodingService = Geocoding();
        final placemarks = await geocodingService.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = <String>[
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
            if (p.administrativeArea != null &&
                p.administrativeArea!.isNotEmpty)
              p.administrativeArea!,
          ];
          locationLabel = parts.isNotEmpty
              ? parts.join(', ')
              : '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        } else {
          locationLabel =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
        }
      } catch (_) {
        // Reverse geocoding failed — show raw coordinates instead
        locationLabel =
            '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}';
      }

      if (mounted) setState(() => _locationTag = locationLabel);
    } catch (e) {
      _showLocationError('Could not fetch location. Please try again.');
    } finally {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _cardBg,
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(color: Colors.white70),
        ),
      ),
    );
  }

  // ── Post ───────────────────────────────────────────────────────────────────
  Future<void> _handlePost() async {
    HapticFeedback.mediumImpact();
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            'Please write something or add a photo to post.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }

    if (_isPosting) return;
    setState(() => _isPosting = true);

    // The post lives on the server only — the feed re-reads it from the API so
    // there is no second, local copy to keep in sync.
    try {
      await ApiService.createPost(
        caption: caption,
        type: _selectedPostType,
        audience: _selectedAudience == 'Everyone' ? 'EVERYONE' : 'TRYBES',
        locationTag: _locationTag,
        images: _selectedImages.map((x) => File(x.path)).toList(),
      );

      if (!mounted) return;
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _accent,
          content: Text(
            'Post shared successfully!',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not share your post. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ),
        leadingWidth: 80,
        title: Text(
          'New Post',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: _isPosting ? null : _handlePost,
                child: _isPosting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _accent,
                        ),
                      )
                    : Text(
                        'Post',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(height: 1, color: Colors.white.withValues(alpha: 0.04)),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Post Type Chips ─────────────────────────────────────
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _postTypes.map((type) {
                        final isSelected = _selectedPostType == type['label'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedPostType = type['label']);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? _accent : _cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _accent
                                    : Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  type['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white38,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  type['label'] as String,
                                  style: GoogleFonts.hankenGrotesk(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white54,
                                    fontSize: 12.5,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Author + Caption ────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      UserAvatar(
                        url: _avatarUrl,
                        fallbackName: SessionService().displayName,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              SessionService().displayName,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Location tag below name
                            if (_locationTag != null) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: _accent,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _locationTag!,
                                    style: GoogleFonts.hankenGrotesk(
                                      color: _accent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _locationTag = null),
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: Colors.white38,
                                      size: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 6),
                            TextField(
                              controller: _captionController,
                              focusNode: _captionFocusNode,
                              maxLines: null,
                              maxLength: 300,
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    "What's on your mind? Share your progress...",
                                hintStyle: GoogleFonts.hankenGrotesk(
                                  color: Colors.white30,
                                  fontSize: 15,
                                ),
                                border: InputBorder.none,
                                counterStyle: GoogleFonts.hankenGrotesk(
                                  color: Colors.white24,
                                  fontSize: 11,
                                ),
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Photo Grid ─────────────────────────────────────────
                  if (_selectedImages.isNotEmpty) ...[
                    _buildPhotoGrid(),
                    const SizedBox(height: 20),
                  ],

                  // ── Audience Selector ──────────────────────────────────
                  Text(
                    'VISIBLE TO',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: _audiences.map((aud) {
                      final isSelected = _selectedAudience == aud['label'];
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedAudience = aud['label']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _accent.withValues(alpha: 0.12)
                                : _cardBg.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _accent.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                aud['icon'] as IconData,
                                color: isSelected ? _accent : Colors.white38,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                aud['label'] as String,
                                style: GoogleFonts.hankenGrotesk(
                                  color: isSelected ? _accent : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Bottom Action Bar ────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom > 0
                  ? 12
                  : 20 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: _bg,
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              children: [
                // Photo
                _buildActionChip(
                  icon: Icons.photo_library_rounded,
                  label: _selectedImages.isEmpty
                      ? 'Photo'
                      : '${_selectedImages.length} Photo${_selectedImages.length > 1 ? 's' : ''}',
                  active: _selectedImages.isNotEmpty,
                  onTap: _pickImages,
                ),
                const SizedBox(width: 10),
                // Location
                _buildActionChip(
                  icon: _isFetchingLocation
                      ? Icons.hourglass_top_rounded
                      : Icons.location_on_outlined,
                  label: _isFetchingLocation
                      ? 'Locating…'
                      : (_locationTag ?? 'Location'),
                  active: _locationTag != null,
                  onTap: _fetchLocation,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo Grid Widget ─────────────────────────────────────────────────────
  Widget _buildPhotoGrid() {
    if (_selectedImages.length == 1) {
      return _buildSinglePhoto(_selectedImages[0], 0);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: _selectedImages.length < 5 ? _selectedImages.length : 5,
      itemBuilder: (context, index) {
        if (index == 4 && _selectedImages.length > 5) {
          // overflow indicator
          return _buildOverflowTile(index);
        }
        return _buildGridPhoto(_selectedImages[index], index);
      },
    );
  }

  Widget _buildSinglePhoto(XFile image, int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              File(image.path),
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          Positioned(top: 8, right: 8, child: _buildRemoveButton(index)),
        ],
      ),
    );
  }

  Widget _buildGridPhoto(XFile image, int index) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(image.path), fit: BoxFit.cover),
        ),
        Positioned(top: 4, right: 4, child: _buildRemoveButton(index)),
      ],
    );
  }

  Widget _buildOverflowTile(int index) {
    final extra = _selectedImages.length - 4;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(_selectedImages[index].path),
            fit: BoxFit.cover,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '+$extra',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRemoveButton(int index) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedImages.removeAt(index));
      },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 13),
      ),
    );
  }

  // ── Action Chip ────────────────────────────────────────────────────────────
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _accent.withValues(alpha: 0.12) : _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? _accent.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? _accent : Colors.white54, size: 15),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  color: active ? _accent : Colors.white54,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
