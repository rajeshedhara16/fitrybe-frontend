import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../widgets/user_avatar.dart';

class CreateTrybeScreen extends StatefulWidget {
  static const routeName = '/CreateTrybeScreen';

  const CreateTrybeScreen({super.key});

  @override
  State<CreateTrybeScreen> createState() => _CreateTrybeScreenState();
}

class _CreateTrybeScreenState extends State<CreateTrybeScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF131316);
  final Color _cardBg = const Color(0xFF1E1E22);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _memberSearchController = TextEditingController();

  File? _trybeImageFile;
  final ImagePicker _picker = ImagePicker();

  // Trybe Type: 'Public' or 'Private'
  String _trybeType = 'Public';

  // Selected Activity Interests
  final Set<String> _selectedActivities = {'Running', 'Gym Workout'};

  bool _isExpandedActivities = false;

  final List<Map<String, dynamic>> _allActivityOptions = [
    {'name': 'Walking', 'icon': Icons.directions_walk_rounded},
    {'name': 'Running', 'icon': Icons.directions_run_rounded},
    {'name': 'Hiking', 'icon': Icons.hiking_rounded},
    {'name': 'Cycling', 'icon': Icons.directions_bike_rounded},
    {'name': 'Roller Skating', 'icon': Icons.roller_skating_rounded},
    {'name': 'Skateboarding', 'icon': Icons.skateboarding_rounded},
    {'name': 'Scooter Riding', 'icon': Icons.electric_scooter_rounded},
    {'name': 'Wheelchair Activity', 'icon': Icons.accessible_rounded},
    {'name': 'Dog Walking', 'icon': Icons.pets_rounded},
    {'name': 'Open Water Swimming', 'icon': Icons.pool_rounded},
    {'name': 'Kayaking', 'icon': Icons.kayaking_rounded},
    {'name': 'Canoeing', 'icon': Icons.rowing_rounded},
    {'name': 'Paddleboarding', 'icon': Icons.surfing_rounded},
    {'name': 'Skiing', 'icon': Icons.downhill_skiing_rounded},
    {'name': 'Snowboarding', 'icon': Icons.snowboarding_rounded},
    {'name': 'Trail Running', 'icon': Icons.terrain_rounded},
    {'name': 'Nature Walk', 'icon': Icons.forest_rounded},
    {'name': 'Commute Walk', 'icon': Icons.directions_walk_rounded},
    {'name': 'Commute Ride', 'icon': Icons.directions_bike_rounded},
    {'name': 'Gym Workout', 'icon': Icons.fitness_center_rounded},
    {'name': 'Football/Soccer', 'icon': Icons.sports_soccer_rounded},
    {'name': 'Basketball', 'icon': Icons.sports_basketball_rounded},
    {'name': 'Volleyball', 'icon': Icons.sports_volleyball_rounded},
    {'name': 'Tennis', 'icon': Icons.sports_tennis_rounded},
    {'name': 'Badminton', 'icon': Icons.sports_tennis_rounded},
    {'name': 'Cricket', 'icon': Icons.sports_cricket_rounded},
    {'name': 'Rugby', 'icon': Icons.sports_rugby_rounded},
    {'name': 'Boxing', 'icon': Icons.sports_mma_rounded},
    {'name': 'Martial Arts', 'icon': Icons.sports_kabaddi_rounded},
    {'name': 'Yoga (Outdoor)', 'icon': Icons.self_improvement_rounded},
    {'name': 'Calisthenics (Park)', 'icon': Icons.accessibility_new_rounded},
    {'name': 'Rock Climbing', 'icon': Icons.filter_hdr_rounded},
    {'name': 'Golf', 'icon': Icons.sports_golf_rounded},
    {'name': 'Disc Golf', 'icon': Icons.track_changes_rounded},
    {'name': 'Frisbee', 'icon': Icons.sports_handball_rounded},
  ];

  // Athletes suggested for invitation, loaded from the API.
  List<Map<String, dynamic>> _suggestedMembers = [];
  bool _isCreating = false;

  final Set<String> _invitedMemberIds = {};
  String _memberSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSuggestedMembers();
  }

  Future<void> _loadSuggestedMembers() async {
    final users = await ApiService.searchUsers('', limit: 20);
    if (!mounted) return;
    setState(() => _suggestedMembers = users);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _trybeImageFile = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking trybe image: $e');
    }
  }

  Future<void> _createTrybe() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(
            'Please enter a Trybe name',
            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      return;
    }

    if (_isCreating) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    try {
      final trybe = await ApiService.createTrybe(
        name: name,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        category:
            _selectedActivities.isNotEmpty ? _selectedActivities.first : null,
        isPublic: _trybeType == 'Public',
        activityInterests: _selectedActivities.toList(),
        image: _trybeImageFile,
      );

      // Notify everyone the creator picked.
      final trybeId = trybe?['id'] as String?;
      if (trybeId != null) {
        for (final userId in _invitedMemberIds) {
          await ApiService.inviteToTrybe(trybeId, userId);
        }
      }

      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _accent,
          content: Text(
            'Trybe "$name" created successfully! 🎉',
            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not create this Trybe. Check your connection.',
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Trybe',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton(
              onPressed: _isCreating ? null : _createTrybe,
              child: _isCreating
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _accent),
                    )
                  : Text(
                      'Create',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 3. Trybe Profile Picture
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent.withValues(alpha: 0.5), width: 2),
                        image: _trybeImageFile != null
                            ? DecorationImage(
                                image: FileImage(_trybeImageFile!),
                                fit: BoxFit.cover,
                              )
                            : const DecorationImage(
                                image: NetworkImage(
                                  'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=400',
                                ),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bg, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to change Trybe photo',
                style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
              ),
            ),
            const SizedBox(height: 28),

            // 1. Trybe Name
            _buildSectionTitle('TRYBE NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Patna Striders, Bay Area Cyclists',
                hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30),
                filled: true,
                fillColor: _cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 2. Trybe Description
            _buildSectionTitle('TRYBE DESCRIPTION'),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 3,
              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Short description or purpose of this community...',
                hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30),
                filled: true,
                fillColor: _cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: _accent),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 4. Trybe Type (Public / Private)
            _buildSectionTitle('TRYBE TYPE'),
            const SizedBox(height: 10),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildTypeCard(
                      title: 'Public',
                      desc: 'Anyone can find and join',
                      icon: Icons.public_rounded,
                      isSelected: _trybeType == 'Public',
                      onTap: () {
                        setState(() {
                          _trybeType = 'Public';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeCard(
                      title: 'Private',
                      desc: 'Invitation or approval required',
                      icon: Icons.lock_outline_rounded,
                      isSelected: _trybeType == 'Private',
                      onTap: () {
                        setState(() {
                          _trybeType = 'Private';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Activity Interests
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle('ACTIVITY INTERESTS'),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isExpandedActivities = !_isExpandedActivities;
                    });
                  },
                  child: Text(
                    _isExpandedActivities ? 'See Less' : 'See More',
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Select activities this Trybe is focused on',
              style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: (_isExpandedActivities
                      ? _getOrderedActivityOptions()
                      : _getOrderedActivityOptions().take(6).toList())
                  .map((act) {
                final isSelected = _selectedActivities.contains(act['name']);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      if (isSelected) {
                        if (_selectedActivities.length > 1) {
                          _selectedActivities.remove(act['name']);
                        }
                      } else {
                        _selectedActivities.add(act['name']!);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _accent.withValues(alpha: 0.15) : _cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          act['icon'] as IconData,
                          size: 16,
                          color: isSelected ? _accent : Colors.white60,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          act['name']!,
                          style: GoogleFonts.hankenGrotesk(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            // 6. Members (Add / Invite)
            _buildSectionTitle('ADD / INVITE MEMBERS'),
            const SizedBox(height: 4),
            Text(
              'Invite friends while creating or skip to invite later',
              style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),

            // Member Search Bar
            TextField(
              controller: _memberSearchController,
              onChanged: (val) {
                setState(() {
                  _memberSearchQuery = val.trim().toLowerCase();
                });
              },
              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                hintText: 'Search friends to invite...',
                hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13),
                filled: true,
                fillColor: _cardBg,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Suggested list
            if (_suggestedMembers.isEmpty)
              Text(
                'No other athletes on Fitrybe yet — you can invite people once they join.',
                style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38, fontSize: 12.5),
              ),
            ..._suggestedMembers.where((m) {
              if (_memberSearchQuery.isEmpty) return true;
              final name =
                  '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.toLowerCase();
              return name.contains(_memberSearchQuery);
            }).map((m) {
              final memberId = m['id'] as String?;
              final rawName =
                  '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
              final memberName = rawName.isEmpty ? 'Fitrybe Athlete' : rawName;
              final isInvited = _invitedMemberIds.contains(memberId);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Row(
                  children: [
                    UserAvatar(
                      url: ApiService.media(m['avatarUrl'] as String?),
                      fallbackName: memberName,
                      radius: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            memberName,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '${m['location'] ?? 'Fitrybe community'}',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: memberId == null
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isInvited) {
                                  _invitedMemberIds.remove(memberId);
                                } else {
                                  _invitedMemberIds.add(memberId);
                                }
                              });
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInvited ? Colors.white10 : _accent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        minimumSize: const Size(60, 30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        isInvited ? 'Invited ✓' : 'Invite',
                        style: GoogleFonts.hankenGrotesk(
                          color: isInvited ? Colors.white54 : Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getOrderedActivityOptions() {
    final selectedList = _allActivityOptions
        .where((act) => _selectedActivities.contains(act['name']))
        .toList();
    final unselectedList = _allActivityOptions
        .where((act) => !_selectedActivities.contains(act['name']))
        .toList();
    return [...selectedList, ...unselectedList];
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white60,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTypeCard({
    required String title,
    required String desc,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.1) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _accent : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon,
                  color: isSelected ? _accent : Colors.white54,
                  size: 20,
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: _accent, size: 18),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white38,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
