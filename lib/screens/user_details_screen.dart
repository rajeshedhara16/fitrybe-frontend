import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_screens.dart';
import 'health_permission_screen.dart';
import '../models/trybe_activity_options.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';

/// A single selectable preference (an activity or a sport).
class _PrefItem {
  final String label;
  final IconData icon;
  const _PrefItem(this.label, this.icon);
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

  /// Flat list of all activity names available across the platform.
  List<String> get activityOptions =>
      trybeActivityOptions.map((a) => a.name).toList();

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

  void _handleContinue() {
    FocusScope.of(context).unfocus();
    if (_currentPageIndex == 0) {
      _goToGenderStep();
    } else if (_currentPageIndex == 1) {
      if (selectedGender.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please select an option to continue',
              style: GoogleFonts.hankenGrotesk(),
            ),
            backgroundColor: const Color(0xFF2D2D2D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        );
      }
    } else {
      if (_totalPicks < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please pick at least 3 activities to finish setup',
              style: GoogleFonts.hankenGrotesk(),
            ),
            backgroundColor: const Color(0xFF2D2D2D),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        _submitForm();
      }
    }
  }

  Widget _buildNavigationFooter() {
    final isLast = _currentPageIndex == _totalSteps - 1;
    final ready = _totalPicks >= 3;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131317),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom + 4
            : 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          InkWell(
            onTap: _handleBack,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Previous',
                    style: GoogleFonts.hankenGrotesk(
                      color: const Color(0xFFD0D0D0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Pagination Dots (matches screenshot)
          AnimatedBuilder(
            animation: _pageController,
            builder: (context, _) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_totalSteps, (i) {
                  final isActive = _currentPageIndex == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? _accent : const Color(0xFF4A4A4E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            },
          ),

          // Continue / Submit button
          InkWell(
            onTap: _handleContinue,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: _accent,
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: (isLast && !ready) ? Colors.white38 : Colors.white,
                      size: 26,
                    ),
                  const SizedBox(height: 2),
                  Text(
                    isLast ? 'Submit' : 'Continue',
                    style: GoogleFonts.hankenGrotesk(
                      color: (isLast && !ready)
                          ? Colors.white38
                          : const Color(0xFFD0D0D0),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

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
                              text: 'HEY,\n',
                              style: TextStyle(color: Colors.white),
                            ),
                            TextSpan(
                              text: 'TRYBER',
                              style: TextStyle(color: _accent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "Tell us a little about you.",
                        style: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFFA0A0A0),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Text boxes together with the header
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
                        borderRadius: BorderRadius.circular(32),
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

                      const Spacer(flex: 3),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGenderStep() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(flex: 2),

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
                    const SizedBox(height: 32),

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

                    const Spacer(flex: 3),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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


  static List<_PrefItem> get _gridActivities => trybeActivityOptions
      .where((a) => a.name != 'Running')
      .map((a) => _PrefItem(a.name, a.icon))
      .toList();

  Widget _buildFeaturedRunningCard() {
    final isSel = selectedActivities.contains('Running');
    return GestureDetector(
      onTap: () => _togglePref('Running'),
      child: Container(
        height: 92,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSel
                ? [
                    _accent.withValues(alpha: 0.28),
                    const Color(0xFF221614),
                  ]
                : [
                    const Color(0xFF222228),
                    const Color(0xFF141418),
                  ],
          ),
          border: Border.all(
            color: isSel ? _accent : Colors.white.withValues(alpha: 0.08),
            width: isSel ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background subtle athletic runner pattern
            Positioned(
              right: -10,
              top: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.12,
                child: const Icon(
                  Icons.directions_run_rounded,
                  size: 130,
                  color: Colors.white,
                ),
              ),
            ),
            // Foreground Badge & Title matching screenshot
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSel
                          ? _accent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_run_rounded,
                      color: isSel ? _accent : const Color(0xFFFF7A50),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'RUNNING',
                    style: GoogleFonts.anybody(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (isSel)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header (exact title texts kept)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "BUILD YOUR MIX",
                style: GoogleFonts.anybody(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: _accent,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.anybody(
                    fontSize: 26,
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
              const SizedBox(height: 4),
              Text(
                'Choose the activities you love to connect with others.',
                style: GoogleFonts.hankenGrotesk(
                  color: const Color(0xFFA0A0A0),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // 2. Featured Top Banner Card (Running)
        _buildFeaturedRunningCard(),

        // 3. Grid of Activities with Horizontal Scroller (8 boxes visible on one screen: 4 rows x 2 columns)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const int rows = 4;
              const int colsOnScreen = 2; // 4 rows x 2 columns = 8 boxes visible on screen
              const double mainAxisSpacing = 10;
              const double crossAxisSpacing = 10;
              const double hPadding = 20;
              const double vPadding = 4;

              final availableHeight = constraints.maxHeight - (vPadding * 2) - ((rows - 1) * crossAxisSpacing);
              final rowHeight = (availableHeight / rows).clamp(50.0, 120.0);

              final availableWidth = constraints.maxWidth - (hPadding * 2) - ((colsOnScreen - 1) * mainAxisSpacing);
              final colWidth = (availableWidth / colsOnScreen).clamp(120.0, 260.0);

              final childAspectRatio = rowHeight / colWidth;

              return GridView.builder(
                controller: _prefScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: hPadding, vertical: vPadding),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: rows,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                  childAspectRatio: childAspectRatio,
                ),
                itemCount: _gridActivities.length,
                itemBuilder: (context, index) {
                  final item = _gridActivities[index];
                  final isSel = selectedActivities.contains(item.label);
                  return GestureDetector(
                    onTap: () => _togglePref(item.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel
                            ? _accent.withValues(alpha: 0.12)
                            : const Color(0xFF19191D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSel
                              ? _accent
                              : Colors.white.withValues(alpha: 0.05),
                          width: isSel ? 1.8 : 1.0,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isSel ? _accent : const Color(0xFFFF7A50),
                                  size: 28,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.label,
                                  textAlign: TextAlign.left,
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    height: 1.15,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSel)
                            const Positioned(
                              top: 0,
                              right: 0,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: _accent,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // 4. Fancy Glowing Scrollbar Indicator (replaces selected counter)
        _buildFancyScrollbar(),
      ],
    );
  }

  Widget _buildFancyScrollbar() {
    return AnimatedBuilder(
      animation: _prefScrollController,
      builder: (context, child) {
        double progress = 0.0;
        if (_prefScrollController.hasClients &&
            _prefScrollController.position.hasContentDimensions &&
            _prefScrollController.position.maxScrollExtent > 0) {
          progress = (_prefScrollController.offset /
                  _prefScrollController.position.maxScrollExtent)
              .clamp(0.0, 1.0);
        }

        const double trackWidth = 88.0;
        const double trackHeight = 4.0;
        const double thumbWidth = 28.0;
        final double maxThumbOffset = trackWidth - thumbWidth;
        final double currentThumbOffset = maxThumbOffset * progress;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Container(
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(trackHeight / 2),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: currentThumbOffset,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: thumbWidth,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            _accent,
                            Color(0xFFFF8A65),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(trackHeight / 2),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.55),
                            blurRadius: 6,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =======================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: FitrybeBackground(isSubtle: true)),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
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
                _buildNavigationFooter(),
              ],
            ),
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
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: _accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(32),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }
}
