import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'clique_live_activity_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/user_avatar.dart';

class CreateCliqueActivityScreen extends StatefulWidget {
  const CreateCliqueActivityScreen({super.key});

  @override
  State<CreateCliqueActivityScreen> createState() =>
      _CreateCliqueActivityScreenState();
}

class _CreateCliqueActivityScreenState
    extends State<CreateCliqueActivityScreen> {
  // ─── Theme ───────────────────────────────────────────────────────────────
  static const Color _bg = Color(0xFF131316);
  static const Color _surface = Color(0xFF1F1F22);
  static const Color _surfaceHigh = Color(0xFF2A2A2D);
  static const Color _surfaceHighest = Color(0xFF353438);
  static const Color _accent = Color(0xFFFF5722);

  // ─── State ────────────────────────────────────────────────────────────────
  final TextEditingController _nameController =
      TextEditingController(text: 'Morning Trail Run');
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _goalController =
      TextEditingController(text: '5.0');
  final FocusNode _goalFocusNode = FocusNode();

  int _selectedActivityType = 0;
  int _selectedGoalType = 0; // 0: Distance, 1: Duration, 2: Calories, 3: Steps

  bool _isScheduled = false;
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(
      DateTime.now().add(const Duration(hours: 2)));

  final List<Map<String, dynamic>> _activityTypes = [
    {'label': 'Running', 'icon': Icons.directions_run_rounded},
    {'label': 'Cycling', 'icon': Icons.directions_bike_rounded},
    {'label': 'Hiking', 'icon': Icons.terrain_rounded},
    {'label': 'Swimming', 'icon': Icons.pool_rounded},
    {'label': 'Lifting', 'icon': Icons.fitness_center_rounded},
    {'label': 'Walking', 'icon': Icons.directions_walk_rounded},
    {'label': 'Rowing', 'icon': Icons.rowing_rounded},
    {'label': 'Yoga', 'icon': Icons.self_improvement_rounded},
    {'label': 'Boxing', 'icon': Icons.sports_mma_rounded},
    {'label': 'Tennis', 'icon': Icons.sports_tennis_rounded},
    {'label': 'Basketball', 'icon': Icons.sports_basketball_rounded},
  ];

  final List<String> _goalTypes = ['Distance', 'Duration', 'Calories', 'Steps'];
  final List<String> _goalUnits = ['km', 'min', 'kcal', 'steps'];

  /// Athletes chosen to invite when the session is created.
  final List<Map<String, dynamic>> _selectedMembers = [];

  @override
  void initState() {
    super.initState();
    _goalFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {});
  }

  @override
  void dispose() {
    _goalFocusNode.removeListener(_onFocusChange);
    _goalFocusNode.dispose();
    _nameController.dispose();
    _searchController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  bool _isCreating = false;

  /// Creates the session on the server, invites the selected friends, then
  /// opens its live screen.
  Future<void> _createSession() async {
    if (_isCreating) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCreating = true);

    final goalType = _goalTypes[_selectedGoalType];
    final goalValue = double.tryParse(_goalController.text) ?? 5.0;
    final goalUnit = _goalUnits[_selectedGoalType];
    final activityType =
        _activityTypes[_selectedActivityType]['label'] as String;
    final scheduledAt = _isScheduled
        ? DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            _selectedTime.hour,
            _selectedTime.minute,
          )
        : DateTime.now();

    try {
      final session = await ApiService.createClique({
        'title': _previewName,
        'activityType': activityType,
        'scheduledAt': scheduledAt.toIso8601String(),
        // The API tracks distance targets in kilometres.
        if (goalType == 'Distance') 'targetDistance': goalValue,
        if (goalType == 'Duration') 'targetDuration': (goalValue * 60).round(),
      });

      final sessionId = session?['id'] as String?;
      if (sessionId != null) {
        for (final member in _selectedMembers) {
          final userId = member['id'] as String?;
          if (userId != null) {
            await ApiService.inviteToClique(sessionId, userId);
          }
        }
      }

      if (!mounted) return;
      setState(() => _isCreating = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CliqueLiveActivityScreen(
            sessionId: sessionId,
            isUpcoming: _isScheduled,
            scheduledTime: _isScheduled
                ? '${_formatDate(_selectedDate)}, ${_selectedTime.format(context)}'
                : 'Today',
            activityName: _previewName,
            activityType: activityType,
            activityIcon:
                _activityTypes[_selectedActivityType]['icon'] as IconData,
            goalType: goalType,
            goalValue: goalValue,
            goalUnit: goalUnit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F1F22),
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not create this session. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  String get _previewName =>
      _nameController.text.isEmpty ? 'Untitled Activity' : _nameController.text;

  String get _previewGoal {
    final baseGoal =
        '${_goalController.text} ${_goalUnits[_selectedGoalType]} • ${_selectedMembers.length} participant${_selectedMembers.length == 1 ? '' : 's'}';
    if (_isScheduled) {
      final formattedTime = _selectedTime.format(context);
      return '$formattedTime • $baseGoal';
    }
    return baseGoal;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: _bg,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                leadingWidth: 80,
                leading: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                centerTitle: true,
                title: Text(
                  'Create Activity',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: _isCreating ? null : _createSession,
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 180),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Activity Name ───────────────────────────────
                    _buildLabel('Activity Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Morning Trail Run',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 24),

                    // ── Activity Type ───────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Activity Type'),
                        GestureDetector(
                          onTap: _showAllActivitiesSheet,
                          child: Text(
                            'See All >',
                            style: GoogleFonts.hankenGrotesk(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildActivityTypeScroll(),
                    const SizedBox(height: 24),

                    // ── Goal Type ───────────────────────────────────
                    _buildLabel('Goal Type'),
                    const SizedBox(height: 12),
                    _buildGoalTypeSegment(),
                    const SizedBox(height: 24),

                    // ── Goal Value ──────────────────────────────────
                    _buildGoalValueInput(),
                    const SizedBox(height: 28),

                    // ── Schedule ────────────────────────────────────
                    _buildScheduleSection(),
                    const SizedBox(height: 28),

                    // ── Invite Members ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel('Invite Members'),
                        GestureDetector(
                          onTap: _showInviteFriendsSheet,
                          child: Text(
                            'See All >',
                            style: GoogleFonts.hankenGrotesk(
                              color: _accent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSearchField(),
                    if (_selectedMembers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(
                        '${_selectedMembers.length} member${_selectedMembers.length == 1 ? '' : 's'} selected',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMemberAvatarRow(),
                    ],
                  ]),
                ),
              ),
            ],
          ),

          // ── Fixed bottom bar ─────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  // ─── Widgets ─────────────────────────────────────────────────────────────

  Widget _buildLabel(String text) => Text(
        text.toUpperCase(),
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    void Function(String)? onChanged,
  }) =>
      TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 15),
          filled: true,
          fillColor: _surfaceHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  BorderSide(color: _accent.withValues(alpha: 0.5), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      );

  Widget _buildActivityTypeScroll() => SizedBox(
        height: 96,
        child: ListView.separated(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          itemCount: _activityTypes.length,
          separatorBuilder: (_, _) => const SizedBox(width: 18),
          itemBuilder: (context, i) {
            final isSelected = _selectedActivityType == i;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedActivityType = i);
              },
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _accent.withValues(alpha: 0.15)
                          : _surfaceHighest.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? _accent.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.04),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.15),
                                blurRadius: 15,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _activityTypes[i]['icon'] as IconData,
                      color: isSelected ? _accent : Colors.white60,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activityTypes[i]['label'] as String,
                    style: GoogleFonts.hankenGrotesk(
                      color: isSelected ? Colors.white : Colors.white38,
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

  void _showAllActivitiesSheet() {
    HapticFeedback.mediumImpact();
    final TextEditingController searchController = TextEditingController();
    final List<Map<String, dynamic>> allOptions = [
      // Distance-Based Activities
      {'name': 'Walking', 'icon': Icons.directions_walk_rounded, 'type': 'distance'},
      {'name': 'Running', 'icon': Icons.directions_run_rounded, 'type': 'distance'},
      {'name': 'Hiking', 'icon': Icons.hiking_rounded, 'type': 'distance'},
      {'name': 'Cycling', 'icon': Icons.pedal_bike_rounded, 'type': 'distance'},
      {'name': 'Roller Skating', 'icon': Icons.roller_skating_rounded, 'type': 'distance'},
      {'name': 'Skateboarding', 'icon': Icons.skateboarding_rounded, 'type': 'distance'},
      {'name': 'Wheelchair Activity', 'icon': Icons.accessible_rounded, 'type': 'distance'},
      {'name': 'Dog Walking', 'icon': Icons.pets_rounded, 'type': 'distance'},
      {'name': 'Open Water Swimming', 'icon': Icons.pool_rounded, 'type': 'distance'},
      {'name': 'Kayaking', 'icon': Icons.kayaking_rounded, 'type': 'distance'},
      {'name': 'Canoeing', 'icon': Icons.rowing_rounded, 'type': 'distance'},
      {'name': 'Paddleboarding', 'icon': Icons.surfing_rounded, 'type': 'distance'},
      {'name': 'Skiing', 'icon': Icons.downhill_skiing_rounded, 'type': 'distance'},
      {'name': 'Snowboarding', 'icon': Icons.snowboarding_rounded, 'type': 'distance'},
      {'name': 'Trail Running', 'icon': Icons.terrain_rounded, 'type': 'distance'},
      {'name': 'Nature Walk', 'icon': Icons.park_rounded, 'type': 'distance'},
      {'name': 'Commute Walk', 'icon': Icons.directions_walk_rounded, 'type': 'distance'},
      {'name': 'Commute Ride', 'icon': Icons.pedal_bike_rounded, 'type': 'distance'},

      // Location-Based Activities
      {'name': 'Gym Workout', 'icon': Icons.fitness_center_rounded, 'type': 'location'},
      {'name': 'Football/Soccer', 'icon': Icons.sports_soccer_rounded, 'type': 'location'},
      {'name': 'Basketball', 'icon': Icons.sports_basketball_rounded, 'type': 'location'},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball_rounded, 'type': 'location'},
      {'name': 'Tennis', 'icon': Icons.sports_tennis_rounded, 'type': 'location'},
      {'name': 'Badminton', 'icon': Icons.sports_tennis_rounded, 'type': 'location'},
      {'name': 'Cricket', 'icon': Icons.sports_cricket_rounded, 'type': 'location'},
      {'name': 'Rugby', 'icon': Icons.sports_rugby_rounded, 'type': 'location'},
      {'name': 'Boxing', 'icon': Icons.sports_mma_rounded, 'type': 'location'},
      {'name': 'Martial Arts', 'icon': Icons.sports_martial_arts_rounded, 'type': 'location'},
      {'name': 'Yoga (Outdoor)', 'icon': Icons.self_improvement_rounded, 'type': 'location'},
      {'name': 'Calisthenics (Park)', 'icon': Icons.sports_gymnastics_rounded, 'type': 'location'},
      {'name': 'Rock Climbing', 'icon': Icons.hiking_rounded, 'type': 'location'},
      {'name': 'Golf', 'icon': Icons.sports_golf_rounded, 'type': 'location'},
      {'name': 'Disc Golf', 'icon': Icons.sports_golf_rounded, 'type': 'location'},
      {'name': 'Frisbee', 'icon': Icons.album_rounded, 'type': 'location'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final String query = searchController.text.toLowerCase();
            final filteredOptions = allOptions.where((opt) {
              return (opt['name'] as String).toLowerCase().contains(query);
            }).toList();

            final distanceOpts =
                filteredOptions.where((opt) => opt['type'] == 'distance').toList();
            final locationOpts =
                filteredOptions.where((opt) => opt['type'] == 'location').toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Activity',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2C2C30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white38, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: GoogleFonts.hankenGrotesk(
                                color: Colors.white, fontSize: 14),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search activities...',
                              hintStyle: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        if (distanceOpts.isNotEmpty) ...[
                          _buildModalSectionHeader('Distance-Based Activities'),
                          ...distanceOpts
                              .map((opt) => _buildModalOptionRow(opt)),
                          const SizedBox(height: 20),
                        ],
                        if (locationOpts.isNotEmpty) ...[
                          _buildModalSectionHeader('Location-Based Activities'),
                          ...locationOpts
                              .map((opt) => _buildModalOptionRow(opt)),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildModalOptionRow(Map<String, dynamic> opt) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(opt['icon'] as IconData, color: _accent, size: 22),
      title: Text(
        opt['name'] as String,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
      onTap: () {
        HapticFeedback.lightImpact();
        final String name = opt['name'] as String;
        final IconData icon = opt['icon'] as IconData;

        setState(() {
          final int existingIdx = _activityTypes
              .indexWhere((element) => element['label'] == name);
          if (existingIdx != -1) {
            _selectedActivityType = existingIdx;
          } else {
            _activityTypes.add({'label': name, 'icon': icon});
            _selectedActivityType = _activityTypes.length - 1;
          }
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGoalTypeSegment() => Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _surfaceHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: List.generate(_goalTypes.length, (i) {
            final isActive = _selectedGoalType == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedGoalType = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isActive ? _surfaceHigh : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _goalTypes[i],
                    style: GoogleFonts.hankenGrotesk(
                      color: isActive ? Colors.white : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );

  Widget _buildGoalValueInput() => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 130,
                child: TextField(
                  controller: _goalController,
                  focusNode: _goalFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                _goalUnits[_selectedGoalType],
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Target ${_goalTypes[_selectedGoalType].toLowerCase()} for all participants',
            style:
                GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
          ),
        ],
      );

  Widget _buildScheduleSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'SCHEDULE ACTIVITY',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Switch.adaptive(
                value: _isScheduled,
                activeThumbColor: _accent,
                onChanged: (val) {
                  HapticFeedback.lightImpact();
                  setState(() => _isScheduled = val);
                },
              ),
            ],
          ),
          if (_isScheduled) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _surfaceHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              color: _accent, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            _formatDate(_selectedDate),
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _surfaceHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              color: _accent, size: 16),
                          const SizedBox(width: 10),
                          Text(
                            _selectedTime.format(context),
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 13.5,
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
          ],
        ],
      );

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.lightImpact();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: _accent,
            onPrimary: Colors.white,
            surface: _surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day) {
      return 'Tomorrow';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  Widget _buildSearchField() => TextField(
        controller: _searchController,
        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search clique members...',
          hintStyle:
              GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded,
              color: Colors.white38, size: 20),
          filled: true,
          fillColor: _surfaceHighest,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  BorderSide(color: _accent.withValues(alpha: 0.5), width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      );

  Widget _buildMemberAvatarRow() => SizedBox(
        height: 64,
        child: ListView(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          children: [
            ..._selectedMembers.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      url: m['avatar'] as String?,
                      fallbackName: m['name'] as String?,
                      radius: 28,
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selectedMembers.removeAt(i));
                        },
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _surfaceHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white12, width: 1),
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Add more button
            GestureDetector(
              onTap: _showInviteFriendsSheet,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _surfaceHighest,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(Icons.add_rounded,
                    color: Colors.white38, size: 22),
              ),
            ),
          ],
        ),
      );

  void _showInviteFriendsSheet() {
    HapticFeedback.mediumImpact();
    final TextEditingController friendSearchController =
        TextEditingController();

    List<Map<String, dynamic>> allFriends = [];
    bool friendsLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Load the athletes this user follows the first time the sheet
            // is laid out.
            if (friendsLoading) {
              final myId = SessionService().userId;
              if (myId == null) {
                friendsLoading = false;
              } else {
                ApiService.getFollowing(myId).then((following) {
                  allFriends = following;
                  friendsLoading = false;
                  setModalState(() {});
                }).catchError((_) {
                  friendsLoading = false;
                  setModalState(() {});
                });
              }
            }

            final String query = friendSearchController.text.toLowerCase();
            final filteredFriends = allFriends.where((f) {
              final name =
                  '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}'.toLowerCase();
              final location = '${f['location'] ?? ''}'.toLowerCase();
              return name.contains(query) || location.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Invite Friends',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2C2C30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white70, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white38, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: friendSearchController,
                            style: GoogleFonts.hankenGrotesk(
                                color: Colors.white, fontSize: 14),
                            onChanged: (_) => setModalState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Search friends...',
                              hintStyle: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredFriends.length,
                      separatorBuilder: (_, _) => Divider(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.05)),
                      itemBuilder: (context, i) {
                        final friend = filteredFriends[i];
                        final friendId = friend['id'] as String?;
                        final rawName =
                            '${friend['firstName'] ?? ''} ${friend['lastName'] ?? ''}'
                                .trim();
                        final friendName =
                            rawName.isEmpty ? 'Athlete' : rawName;
                        final friendAvatar =
                            ApiService.media(friend['avatarUrl'] as String?);
                        final bool isSelected =
                            _selectedMembers.any((m) => m['id'] == friendId);

                        return ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          leading: UserAvatar(
                            url: friendAvatar,
                            fallbackName: friendName,
                            radius: 22,
                          ),
                          title: Text(
                            friendName,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${friend['location'] ?? 'Fitrybe athlete'}',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (isSelected) {
                                  _selectedMembers
                                      .removeWhere((m) => m['id'] == friendId);
                                } else {
                                  _selectedMembers.add({
                                    'id': friendId,
                                    'name': friendName,
                                    'avatar': friendAvatar,
                                  });
                                }
                              });
                              setModalState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _accent.withValues(alpha: 0.2)
                                    : _surfaceHighest,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? _accent
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Text(
                                isSelected ? 'Selected' : 'Invite',
                                style: GoogleFonts.hankenGrotesk(
                                  color: isSelected ? _accent : Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar() {
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (isKeyboardVisible) {
      return const SizedBox.shrink();
    }

    return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              _bg,
              _bg.withValues(alpha: 0.95),
              Colors.transparent,
            ],
            stops: const [0.0, 0.7, 1.0],
          ),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _activityTypes[_selectedActivityType]['icon'] as IconData,
                  color: _accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _previewName,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _previewGoal,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}
