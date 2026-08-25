import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class CustomizeGoalScreen extends StatefulWidget {
  static const routeName = '/CustomizeGoalScreen';
  const CustomizeGoalScreen({super.key});

  @override
  State<CustomizeGoalScreen> createState() => _CustomizeGoalScreenState();
}

class _CustomizeGoalScreenState extends State<CustomizeGoalScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _bg = const Color(0xFF131316);

  // Activity models
  late List<Map<String, dynamic>> _carouselActivities;

  int _selectedActivityIndex = 0; // Default: Running

  // Metric models
  final List<String> _metrics = ['Distance', 'Duration', 'Calories', 'Sessions'];
  int _selectedMetricIndex = 0; // Default: Distance

  // Frequency models
  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly'];
  int _selectedFrequencyIndex = 1; // Default: Weekly

  // Target value states (mapped by Metric index)
  late List<int> _metricTargets;

  late TextEditingController _targetTextCtrl;

  @override
  void initState() {
    super.initState();
    _carouselActivities = [
      {'name': 'Running', 'icon': Icons.directions_run_rounded},
      {'name': 'Cycling', 'icon': Icons.pedal_bike_rounded},
      {'name': 'Walking', 'icon': Icons.directions_walk_rounded},
      {'name': 'Strength', 'icon': Icons.fitness_center_rounded},
      {'name': 'Yoga', 'icon': Icons.self_improvement_rounded},
      {'name': 'Swimming', 'icon': Icons.pool_rounded},
    ];
    // Default values for [Distance, Duration, Calories, Sessions]
    _metricTargets = [50, 45, 500, 4];
    _targetTextCtrl = TextEditingController(text: '${_metricTargets[_selectedMetricIndex]}');
  }

  @override
  void dispose() {
    _targetTextCtrl.dispose();
    super.dispose();
  }

  // Get metric unit label
  String _getMetricUnit() {
    switch (_selectedMetricIndex) {
      case 0:
        return 'Miles';
      case 1:
        return 'Minutes';
      case 2:
        return 'Kcal';
      case 3:
        return 'Sessions';
      default:
        return '';
    }
  }

  // Get increment step
  int _getIncrementStep() {
    switch (_selectedMetricIndex) {
      case 0:
        return 5; // Distance +/- 5 miles
      case 1:
        return 5; // Duration +/- 5 mins
      case 2:
        return 50; // Calories +/- 50 Kcal
      case 3:
        return 1; // Sessions +/- 1
      default:
        return 1;
    }
  }

  // Get minimum value
  int _getMinValue() {
    switch (_selectedMetricIndex) {
      case 0:
      case 1:
        return 5;
      case 2:
        return 50;
      case 3:
        return 1;
      default:
        return 1;
    }
  }

  void _incrementTarget() {
    HapticFeedback.selectionClick();
    setState(() {
      _metricTargets[_selectedMetricIndex] += _getIncrementStep();
      _targetTextCtrl.text = '${_metricTargets[_selectedMetricIndex]}';
    });
  }

  void _decrementTarget() {
    final int minVal = _getMinValue();
    if (_metricTargets[_selectedMetricIndex] > minVal) {
      HapticFeedback.selectionClick();
      setState(() {
        _metricTargets[_selectedMetricIndex] -= _getIncrementStep();
        _targetTextCtrl.text = '${_metricTargets[_selectedMetricIndex]}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedActivity = _carouselActivities[_selectedActivityIndex];
    final selectedMetric = _metrics[_selectedMetricIndex];
    final selectedFrequency = _frequencies[_selectedFrequencyIndex];
    final currentTarget = _metricTargets[_selectedMetricIndex];
    final currentUnit = _getMetricUnit();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg.withValues(alpha: 0.8),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ),
        centerTitle: true,
        title: Text(
          'Customize Goal',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Activity Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ACTIVITY SELECTION',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                GestureDetector(
                  onTap: _showAllActivitiesPickerSheet,
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
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _carouselActivities.length,
                itemBuilder: (context, index) {
                  final act = _carouselActivities[index];
                  final bool isActive = index == _selectedActivityIndex;
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _selectedActivityIndex = index;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 18.0),
                      child: Column(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _accent.withValues(alpha: 0.15)
                                  : _cardBg.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? _accent.withValues(alpha: 0.3)
                                    : Colors.white.withValues(alpha: 0.03),
                                width: 1.5,
                              ),
                              boxShadow: isActive
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
                              act['icon'] as IconData,
                              color: isActive ? _accent : Colors.white60,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            act['name'] as String,
                            style: GoogleFonts.hankenGrotesk(
                              color: isActive ? Colors.white : Colors.white38,
                              fontSize: 11.5,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Goal Builder Subtitle
            Center(
              child: Text(
                'Set Your ${selectedActivity['name']} Goal',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Metric Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: List.generate(_metrics.length, (index) {
                  final metric = _metrics[index];
                  final bool isActive = index == _selectedMetricIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedMetricIndex = index;
                          _targetTextCtrl.text = '${_metricTargets[_selectedMetricIndex]}';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? _accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            metric,
                            style: GoogleFonts.hankenGrotesk(
                              color: isActive ? Colors.white : Colors.white38,
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Section 4: Target Input Card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36),
              decoration: BoxDecoration(
                color: _cardBg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus Button
                  GestureDetector(
                    onTap: _decrementTarget,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                      ),
                      child: const Icon(Icons.remove, color: Colors.white70, size: 26),
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Display Number (Inline Editable TextField)
                  Column(
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _targetTextCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 68,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              setState(() {
                                _metricTargets[_selectedMetricIndex] = parsed;
                              });
                            }
                          },
                        ),
                      ),
                      Text(
                        currentUnit,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 32),
                  // Plus Button
                  GestureDetector(
                    onTap: _incrementTarget,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                      ),
                      child: const Icon(Icons.add, color: Colors.white70, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Section 5: Frequency Selection
            Text(
              'COMPLETE THIS GOAL:',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: List.generate(_frequencies.length, (index) {
                  final freq = _frequencies[index];
                  final bool isActive = index == _selectedFrequencyIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedFrequencyIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive ? _accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            freq,
                            style: GoogleFonts.hankenGrotesk(
                              color: isActive ? Colors.white : Colors.white38,
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),

            // Section 6: Live Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREVIEW',
                            style: GoogleFonts.hankenGrotesk(
                              color: _accent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${selectedActivity['name']} Goal',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.stars_rounded,
                        color: _accent,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Target',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currentTarget $currentUnit',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Frequency',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                selectedFrequency,
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.query_stats, color: Colors.white38, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Tracking: ',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        selectedMetric,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Spacing for bottom footer
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          color: _bg.withValues(alpha: 0.95),
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final int targetVal = _metricTargets[_selectedMetricIndex];
                try {
                  await ApiService.updateGoals({
                    'activity': selectedActivity['name'],
                    'metric': selectedMetric,
                    'targetValue': targetVal,
                    'unit': currentUnit,
                    'frequency': selectedFrequency,
                    'period': selectedFrequency.toUpperCase(),
                  });
                } catch (_) {}

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: _accent,
                    content: Text(
                      '${selectedActivity['name']} Goal Saved!',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                'Save Goal',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAllActivitiesPickerSheet() {
    HapticFeedback.mediumImpact();
    final TextEditingController searchController = TextEditingController();
    List<Map<String, dynamic>> allOptions = [
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

            final distanceOpts = filteredOptions.where((opt) => opt['type'] == 'distance').toList();
            final locationOpts = filteredOptions.where((opt) => opt['type'] == 'location').toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
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
                          child: const Icon(Icons.close, color: Colors.white70, size: 18),
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
                            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                            onChanged: (val) {
                              setModalState(() {});
                            },
                            decoration: InputDecoration(
                              hintText: 'Search activities...',
                              hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 14),
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
                          ...distanceOpts.map((opt) => _buildModalOptionRow(opt)),
                          const SizedBox(height: 20),
                        ],
                        if (locationOpts.isNotEmpty) ...[
                          _buildModalSectionHeader('Location-Based Activities'),
                          ...locationOpts.map((opt) => _buildModalOptionRow(opt)),
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
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
      onTap: () {
        HapticFeedback.lightImpact();
        final String name = opt['name'] as String;
        final IconData icon = opt['icon'] as IconData;
        
        setState(() {
          // Check if activity is already in the carousel list
          final int existingIdx = _carouselActivities.indexWhere((element) => element['name'] == name);
          if (existingIdx != -1) {
            _selectedActivityIndex = existingIdx;
          } else {
            _carouselActivities.add({'name': name, 'icon': icon});
            _selectedActivityIndex = _carouselActivities.length - 1;
          }
        });
        Navigator.pop(context);
      },
    );
  }
}
