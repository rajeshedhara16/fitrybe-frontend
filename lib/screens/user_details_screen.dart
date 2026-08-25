import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screens.dart';
import 'health_permission_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// A single selectable preference (an activity or a sport).
class _PrefItem {
  final String label;
  final IconData icon;
  const _PrefItem(this.label, this.icon);
}

/// A named group of preferences, e.g. "Cardio" or "Team Sports".
class _PrefGroup {
  final String title;
  final IconData icon;
  final List<_PrefItem> items;
  const _PrefGroup(this.title, this.icon, this.items);
}

class UserDetailsScreen extends StatefulWidget {
  static const routeName = '/UserDetailsScreen';
  const UserDetailsScreen({super.key});

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _page1FormKey = GlobalKey<FormState>();

  static const int _totalSteps = 3;
  static const Color _accent = Color(0xFFFF5722);
  static const Color _accentLight = Color(0xFFFF7043);
  static const Color _card = Color(0xFF1C1C1E);

  int _currentPageIndex = 0;

  final FocusNode f1 = FocusNode();
  final FocusNode f2 = FocusNode();
  final FocusNode fDob = FocusNode();

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();

  String selectedGender = '';

  /// The picked date itself — `dobController` only holds its display text.
  DateTime? _selectedDob;
  bool _isSaving = false;

  final Set<String> selectedActivities = {};
  final Set<String> selectedSports = {};

  // ---- Preference page state -------------------------------------------
  final ScrollController _prefScrollController = ScrollController();
  bool _expandDistance = false;
  bool _expandLocation = false;

  // ---- Preference data --------------------------------------------------

  static const List<_PrefGroup> _activityGroups = [
    _PrefGroup('Distance-Based Activities', Icons.route_rounded, [
      _PrefItem('Walking', Icons.directions_walk_rounded),
      _PrefItem('Running', Icons.directions_run_rounded),
      _PrefItem('Hiking', Icons.hiking_rounded),
      _PrefItem('Cycling', Icons.pedal_bike_rounded),
      _PrefItem('Roller Skating', Icons.roller_skating_rounded),
      _PrefItem('Skateboarding', Icons.skateboarding_rounded),
      _PrefItem('Wheelchair Activity', Icons.accessible_forward_rounded),
      _PrefItem('Dog Walking', Icons.pets_rounded),
      _PrefItem('Open Water Swimming', Icons.pool_rounded),
      _PrefItem('Kayaking', Icons.kayaking_rounded),
      _PrefItem('Canoeing', Icons.rowing_rounded),
      _PrefItem('Paddleboarding', Icons.waves_rounded),
      _PrefItem('Skiing', Icons.downhill_skiing_rounded),
      _PrefItem('Snowboarding', Icons.snowboarding_rounded),
      _PrefItem('Trail Running', Icons.terrain_rounded),
      _PrefItem('Nature Walk', Icons.nature_people_rounded),
      _PrefItem('Commute Walk', Icons.transfer_within_a_station_rounded),
      _PrefItem('Commute Ride', Icons.directions_bike_rounded),
    ]),
    _PrefGroup('Location-Based Activities', Icons.place_rounded, [
      _PrefItem('Gym Workout', Icons.fitness_center_rounded),
      _PrefItem('Football/Soccer', Icons.sports_soccer_rounded),
      _PrefItem('Basketball', Icons.sports_basketball_rounded),
      _PrefItem('Volleyball', Icons.sports_volleyball_rounded),
      _PrefItem('Tennis', Icons.sports_tennis_rounded),
      _PrefItem('Badminton', Icons.sports_tennis_rounded),
      _PrefItem('Cricket', Icons.sports_cricket_rounded),
      _PrefItem('Rugby', Icons.sports_rugby_rounded),
      _PrefItem('Boxing', Icons.sports_mma_rounded),
      _PrefItem('Martial Arts', Icons.sports_martial_arts_rounded),
      _PrefItem('Yoga (Outdoor)', Icons.self_improvement_rounded),
      _PrefItem('Calisthenics (Park)', Icons.accessibility_new_rounded),
      _PrefItem('Rock Climbing', Icons.terrain_rounded),
      _PrefItem('Golf', Icons.sports_golf_rounded),
      _PrefItem('Disc Golf', Icons.adjust_rounded),
      _PrefItem('Frisbee', Icons.album_rounded),
    ]),
  ];

  /// Flat lists, kept so the rest of the app can still read plain names.
  List<String> get activityOptions =>
      _activityGroups.expand((g) => g.items).map((i) => i.label).toList();

  List<String> get sportsOption => [];

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      final index = _pageController.page?.round() ?? 0;
      if (index != _currentPageIndex) {
        setState(() {
          _currentPageIndex = index;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _prefScrollController.dispose();
    f1.dispose();
    f2.dispose();
    fDob.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    dobController.dispose();
    super.dispose();
  }

  double get _pageValue {
    if (_pageController.hasClients && _pageController.position.haveDimensions) {
      return _pageController.page ?? _currentPageIndex.toDouble();
    }
    return _currentPageIndex.toDouble();
  }

  void _handleBack() {
    if (_currentPageIndex == 0) {
      Navigator.of(context).pop();
    } else {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _goToGenderStep() {
    FocusScope.of(context).unfocus();
    if (!(_page1FormKey.currentState?.validate() ?? false)) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
    );
  }

  /// Maps the gender card labels onto the backend's `Gender` enum.
  String? get _genderEnum => switch (selectedGender.toLowerCase()) {
        'male' => 'MALE',
        'female' => 'FEMALE',
        'other' => 'OTHER',
        '' => null,
        _ => 'PREFER_NOT_TO_SAY',
      };

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final updated = await ApiService.updateProfile({
        if (firstNameController.text.trim().isNotEmpty)
          'firstName': firstNameController.text.trim(),
        if (lastNameController.text.trim().isNotEmpty)
          'lastName': lastNameController.text.trim(),
        if (_selectedDob != null) 'dob': _selectedDob!.toIso8601String(),
        if (_genderEnum != null) 'gender': _genderEnum,
        'activityInterests': selectedActivities.toList(),
        'sportInterests': selectedSports.toList(),
        'onboardingCompleted': true,
      });
      SessionService().update(updated);

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const HealthPermissionScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not save your profile. Check your connection.',
            style: GoogleFonts.hankenGrotesk(),
          ),
          backgroundColor: const Color(0xFF2D2D2D),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _accent,
              onPrimary: Colors.white,
              surface: _card,
              onSurface: Colors.white,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _accent),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      const monthNames = [
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
        'Dec',
      ];
      setState(() {
        _selectedDob = picked;
        dobController.text =
            "${picked.day} ${monthNames[picked.month - 1]} ${picked.year}";
      });
    }
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${_currentPageIndex + 1} OF $_totalSteps',
                style: GoogleFonts.hankenGrotesk(
                  color: _accent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                _currentPageIndex == 0
                    ? 'About you'
                    : _currentPageIndex == 1
                    ? 'Gender'
                    : 'Preferences',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFFA0A0A0),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              final page = _pageValue;
              return Row(
                children: List.generate(_totalSteps, (i) {
                  final fraction = ((page + 1) - i).clamp(0.0, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == _totalSteps - 1 ? 0 : 8,
                      ),
                      child: _ProgressSegment(fraction: fraction),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGenderCard(
    String genderName,
    String subtitle,
    String value,
    IconData icon,
  ) {
    final isSel = selectedGender == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          selectedGender = value;
        });
        Future.delayed(const Duration(milliseconds: 260), () {
          if (!mounted) return;
          _pageController.nextPage(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
          );
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSel ? _accent : Colors.white.withValues(alpha: 0.06),
            width: 2.0,
          ),
          boxShadow: isSel
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.25),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSel
                    ? _accent.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isSel ? _accent : Colors.white70,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    genderName,
                    style: GoogleFonts.hankenGrotesk(
                      color: isSel ? _accent : Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.hankenGrotesk(
                      color: const Color(0xFFA0A0A0),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSel ? _accent : Colors.transparent,
                border: Border.all(
                  color: isSel ? _accent : Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: isSel
                  ? const Icon(Icons.check, size: 15, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameStep() {
    return Form(
      key: _page1FormKey,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(
                "LET'S GET STARTED",
                style: GoogleFonts.anybody(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _accent,
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
                      text: 'HEY, ',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text: 'TRYBER',
                      style: TextStyle(color: _accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "Tell us a little about you.",
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFFA0A0A0),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 30),
              TextFormField(
                controller: firstNameController,
                style: GoogleFonts.hankenGrotesk(color: Colors.white),
                decoration: _buildInputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icons.person_rounded,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: lastNameController,
                style: GoogleFonts.hankenGrotesk(color: Colors.white),
                decoration: _buildInputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icons.person_rounded,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(16),
                child: IgnorePointer(
                  child: TextFormField(
                    controller: dobController,
                    style: GoogleFonts.hankenGrotesk(color: Colors.white),
                    decoration: _buildInputDecoration(
                      labelText: 'Date of Birth',
                      prefixIcon: Icons.cake_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your date of birth';
                      }
                      return null;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: _goToGenderStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: const StadiumBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next',
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildGenderStep() {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Text(
              "TAILOR THE EXPERIENCE",
              style: GoogleFonts.anybody(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _accent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                style: GoogleFonts.anybody(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1.0,
                  height: 1.2,
                ),
                children: const [
                  TextSpan(
                    text: 'HELP US ',
                    style: TextStyle(color: Colors.white),
                  ),
                  TextSpan(
                    text: 'TAILOR IT',
                    style: TextStyle(color: _accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              "Pick what best describes you — we'll tune your plan around it.",
              style: GoogleFonts.hankenGrotesk(
                color: const Color(0xFFA0A0A0),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 34),
            _buildGenderCard(
              'Male',
              'Optimized for men',
              'Male',
              Icons.male_rounded,
            ),
            _buildGenderCard(
              'Female',
              'Optimized for women',
              'Female',
              Icons.female_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
    );
  }

  // =======================================================================
  // STEP 3 — PREFERENCES
  // =======================================================================

  int get _totalPicks => selectedActivities.length;
  void _togglePref(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      final set = selectedActivities;
      if (!set.remove(label)) set.add(label);
    });
  }

  void _removePick(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedActivities.remove(label);
      selectedSports.remove(label);
    });
  }

  Widget _buildPreferenceStep() {
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: _prefScrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildPrefHero()),
              SliverToBoxAdapter(child: _buildPicksTray()),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPrefSection(_activityGroups[index]),
                  childCount: _activityGroups.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ),
        ),
        _buildPrefBottomBar(),
      ],
    );
  }

  Widget _buildPrefHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "BUILD YOUR MIX",
            style: GoogleFonts.anybody(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _accent,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
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
                  text: 'WHAT ',
                  style: TextStyle(color: Colors.white),
                ),
                TextSpan(
                  text: 'MOVES YOU',
                  style: TextStyle(color: _accent),
                ),
                TextSpan(
                  text: '?',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Choose the activities you love to connect with people sharing similar interests.',
            style: GoogleFonts.hankenGrotesk(
              color: const Color(0xFFA0A0A0),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Live tray of everything picked so far — the anchor of the whole screen.
  Widget _buildPicksTray() {
    final picks = [...selectedActivities, ...selectedSports];
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: picks.isEmpty
          ? const SizedBox.shrink()
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _accent.withValues(alpha: 0.28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt, size: 16, color: _accent),
                      const SizedBox(width: 6),
                      Text(
                        'YOUR MIX · ${picks.length}',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selectedActivities.clear();
                            selectedSports.clear();
                          });
                        },
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.hankenGrotesk(
                            color: const Color(0xFFA0A0A0),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: picks
                        .map(
                          (p) => GestureDetector(
                            onTap: () => _removePick(p),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: _accent.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    p,
                                    style: GoogleFonts.hankenGrotesk(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.close_rounded,
                                    size: 14,
                                    color: Color(0xFFA0A0A0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleTriggerChip({
    required bool isExpanded,
    required int remainingCount,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isExpanded ? Colors.white24 : _accent.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
              size: 16,
              color: isExpanded ? Colors.white54 : _accent,
            ),
            const SizedBox(width: 8),
            Text(
              isExpanded ? 'Show Less' : '+$remainingCount More...',
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isExpanded ? Colors.white70 : _accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrefSection(_PrefGroup group) {
    final count = group.items.where((i) => selectedActivities.contains(i.label)).length;
    final isDistance = group.title.contains('Distance-Based');
    final isExpanded = isDistance ? _expandDistance : _expandLocation;

    final visibleItems = isExpanded ? group.items : group.items.take(5).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header Row
          Row(
            children: [
              Icon(group.icon, size: 17, color: _accent),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.title.toUpperCase(),
                    style: GoogleFonts.anybody(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDistance ? 'GPS Required' : 'GPS Used for Presence',
                    style: GoogleFonts.hankenGrotesk(
                      color: const Color(0xFFFF5722).withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                count > 0 ? '$count picked' : '${group.items.length}',
                style: GoogleFonts.hankenGrotesk(
                  color: count > 0 ? _accent : Colors.white24,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Chips Wrap
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ...visibleItems.map(
                (item) => _buildPrefChip(
                  item,
                  selectedActivities.contains(item.label),
                  () => _togglePref(item.label),
                ),
              ),
              // More/Less trigger chip
              _buildToggleTriggerChip(
                isExpanded: isExpanded,
                remainingCount: group.items.length - 5,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isDistance) {
                      _expandDistance = !_expandDistance;
                    } else {
                      _expandLocation = !_expandLocation;
                    }
                  });
                },
              ),
            ],
          ),
          if (!isExpanded) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: Colors.white30,
                ),
                const SizedBox(width: 6),
                Text(
                  "We offer more activities — tap '+${group.items.length - 5} More' to explore them.",
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white30,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrefChip(_PrefItem item, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_accentLight, _accent])
              : null,
          color: selected ? null : const Color(0xFF161618),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? const Color(0xFFFF8A65)
                : Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.34),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 16,
              color: selected ? Colors.black : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              item.label,
              style: GoogleFonts.hankenGrotesk(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildPrefBottomBar() {
    final total = _totalPicks;
    final ready = total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.0),
            Colors.black.withValues(alpha: 0.92),
            Colors.black,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    total == 0
                        ? 'Select interests to connect with others'
                        : '$total interests selected',
                    style: GoogleFonts.hankenGrotesk(
                      color: total > 0 ? _accent : const Color(0xFFA0A0A0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (ready && !_isSaving) ? _submitForm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF232326),
                  disabledForegroundColor: Colors.white38,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  shape: const StadiumBorder(),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Submit',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 16.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 60,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
            ),
            onPressed: _handleBack,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: FitrybeBackground()),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: _buildProgressHeader(),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildNameStep(),
                    _buildGenderStep(),
                    _buildPreferenceStep(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
      fillColor: _card,
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
        borderSide: const BorderSide(color: _accent, width: 1.5),
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
}



class _ProgressSegment extends StatelessWidget {
  final double fraction;
  const _ProgressSegment({required this.fraction});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 6,
        color: Colors.white.withValues(alpha: 0.08),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5722), Color(0xCCFF5722)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
