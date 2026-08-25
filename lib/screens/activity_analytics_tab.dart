import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'subscription_screen.dart';
import 'customize_goal_screen.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';

class ActivityAnalyticsTab extends StatefulWidget {
  const ActivityAnalyticsTab({super.key});

  @override
  State<ActivityAnalyticsTab> createState() => _ActivityAnalyticsTabState();
}

class _ActivityAnalyticsTabState extends State<ActivityAnalyticsTab> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);

  // Month navigation state
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  Map<String, dynamic>? _analyticsData;
  Map<String, dynamic>? _goalsData;

  @override
  void initState() {
    super.initState();
    _fetchBackendAnalytics();
    HealthService().fetchTodayHealthData();
  }

  Future<void> _fetchBackendAnalytics() async {
    try {
      final analytics = await ApiService.getAnalytics();
      final goals = await ApiService.getGoals();
      if (mounted) {
        setState(() {
          _analyticsData = analytics;
          _goalsData = goals;
        });
      }
    } catch (_) {}
  }

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header title
          Text(
            'Activity Analytics',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),

          // Summary Metrics Grid
          _buildSummaryGrid(),
          const SizedBox(height: 24),

          // Section 1: Activity Calendar & Sidebar Stats
          _buildCalendarSection(),
          const SizedBox(height: 24),

          // Section 2: Personal Goals
          _buildPersonalGoalsSection(),
          const SizedBox(height: 24),

          // Section 3: Activity Breakdown
          _buildBreakdownSection(),
          const SizedBox(height: 24),

          // Section 4: Trends (Bar Chart & Donut Chart)
          _buildTrendsSection(),
          const SizedBox(height: 24),

          // Section 5: Intensity Heatmap
          _buildIntensityHeatmap(),
          const SizedBox(height: 24),

          // Section 6: Personal Records
          _buildPersonalRecordsGrid(),
          const SizedBox(height: 24),

          // Section 7: AI Fitness Insights
          _buildAIInsights(),
          const SizedBox(height: 24),

          // Section 8: Locked Premium Overlay
          _buildLockedAdvancedAnalytics(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return ValueListenableBuilder<HealthDataSummary>(
      valueListenable: HealthService().healthNotifier,
      builder: (context, health, _) {
        final summary = _analyticsData?['summary'] as Map<String, dynamic>?;
        final int backendWorkouts = summary?['totalWorkouts'] ?? 0;

        final String durationStr = health.activeMinutes >= 60
            ? '${(health.activeMinutes / 60).toStringAsFixed(1)}h'
            : '${health.activeMinutes}m';

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildSummaryCard('Daily Steps', '${health.steps}', ''),
            _buildSummaryCard('Active Workouts', '$backendWorkouts', ''),
            _buildSummaryCard('Active Time', durationStr, ''),
            _buildSummaryCard('Calories', '${health.calories}', ' kcal'),
            _buildSummaryCard('Distance', '${health.distanceKm}', ' km'),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, String unit) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.hankenGrotesk(
                  color: _accent,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
                children: [
                  TextSpan(text: value),
                  if (unit.isNotEmpty)
                    TextSpan(
                      text: unit,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.normal,
                        color: Colors.white60,
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

  void _showDayDetailModal(BuildContext context, int day, int month, int year) {
    HapticFeedback.lightImpact();
    final String monthName = _months[month - 1];
    final String dateStr = '$monthName $day, $year';
    final now = DateTime.now();
    final bool isToday = (day == now.day && month == now.month && year == now.year);

    final goalMap = _goalsData?['goal'] as Map<String, dynamic>?;
    final bool hasGoal = goalMap != null;
    final String goalActivity = goalMap?['activity']?.toString() ?? 'Fitness';
    final String goalMetric = goalMap?['metric']?.toString() ?? 'Distance';
    final dynamic targetVal = goalMap?['targetValue'] ?? 0;
    final String unit = goalMap?['unit']?.toString() ?? '';
    final String frequency = goalMap?['frequency']?.toString() ?? 'Weekly';

    // Find activities logged on this specific date
    final List<dynamic> allActivities = _analyticsData?['recentActivities'] ?? [];
    final List<dynamic> dayActivities = allActivities.where((act) {
      if (act['createdAt'] == null) return false;
      final dt = DateTime.tryParse(act['createdAt'].toString())?.toLocal();
      return dt != null && dt.year == year && dt.month == month && dt.day == day;
    }).toList();

    double totalDistMeters = 0;
    int totalCalories = 0;
    for (final act in dayActivities) {
      totalDistMeters += (act['distance'] as num?)?.toDouble() ?? 0.0;
      totalCalories += (act['calories'] as num?)?.toInt() ?? 0;
    }

    final int workoutsCount = dayActivities.length;
    final String distStr = '${(totalDistMeters / 1000).toStringAsFixed(1)} km';

    final bool isGoalAchieved = hasGoal && dayActivities.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr.toUpperCase(),
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasGoal
                          ? (isToday ? 'Today\'s Goal Summary' : 'Goal Completion Status')
                          : 'Daily Activity Breakdown',
                      style: GoogleFonts.anybody(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isGoalAchieved ? _accent : const Color(0xFF353438),
                  child: Icon(
                    isGoalAchieved
                        ? Icons.check_circle_rounded
                        : (hasGoal ? Icons.pie_chart_outline_rounded : Icons.outlined_flag_rounded),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131316),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDayModalStat('WORKOUTS', '$workoutsCount'),
                  _buildDayModalStat('DISTANCE', distStr),
                  _buildDayModalStat('CALORIES', '$totalCalories kcal'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (hasGoal)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isGoalAchieved ? _accent.withValues(alpha: 0.15) : const Color(0xFF1B1B1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isGoalAchieved ? _accent : Colors.white10,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isGoalAchieved ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                      color: isGoalAchieved ? _accent : Colors.white54,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isGoalAchieved ? '$goalActivity Goal Active' : '$goalActivity Goal ($frequency)',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Target: $targetVal $unit ($goalMetric)',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set a custom goal (Distance, Duration, Calories, Sessions) to start tracking completion.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
                        );
                        if (res == true) {
                          _fetchBackendAnalytics();
                        }
                      },
                      child: Text(
                        '+ Set Goal',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDayModalStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCalendarSection() {
    final int daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final int startWeekday = DateTime(_selectedYear, _selectedMonth, 1).weekday; // 1 = Mon, 7 = Sun
    final int leadingSpaces = startWeekday - 1;
    final int totalGridItems = leadingSpaces + daysInMonth;

    final now = DateTime.now();
    final goalMap = _goalsData?['goal'] as Map<String, dynamic>?;
    final bool hasGoal = goalMap != null;

    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];
    final Set<String> activeDates = {};
    for (final act in activities) {
      if (act['createdAt'] != null) {
        final dt = DateTime.tryParse(act['createdAt'].toString())?.toLocal();
        if (dt != null) {
          final key = '${dt.year}-${dt.month}-${dt.day}';
          activeDates.add(key);
        }
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_months[_selectedMonth - 1]} $_selectedYear',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _prevMonth,
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: _nextMonth,
                        child: const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Day initials
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map(
                      (day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              // Grid for days
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.0,
                ),
                itemCount: totalGridItems,
                itemBuilder: (context, index) {
                  if (index < leadingSpaces) {
                    return const SizedBox.shrink();
                  }

                  final int dayNumber = index - leadingSpaces + 1;
                  final bool isToday = (dayNumber == now.day && _selectedMonth == now.month && _selectedYear == now.year);
                  final String dateKey = '$_selectedYear-$_selectedMonth-$dayNumber';
                  final bool isActivityLogged = activeDates.contains(dateKey);

                  Color tileBgColor;
                  Color borderColor;
                  if (isActivityLogged) {
                    tileBgColor = _accent;
                    borderColor = _accent;
                  } else {
                    tileBgColor = const Color(0xFF353438).withValues(alpha: 0.3);
                    borderColor = Colors.transparent;
                  }

                  if (isToday) {
                    borderColor = Colors.white;
                  }

                  return GestureDetector(
                    onTap: () => _showDayDetailModal(
                      context,
                      dayNumber,
                      _selectedMonth,
                      _selectedYear,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tileBgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: borderColor,
                          width: isToday ? 2.0 : 1.0,
                        ),
                        boxShadow: isActivityLogged
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: GoogleFonts.hankenGrotesk(
                              color: isActivityLogged
                                  ? Colors.white
                                  : (isToday ? Colors.white : Colors.white70),
                              fontSize: 11,
                              fontWeight: (isActivityLogged || isToday) ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isActivityLogged) ...[
                            const SizedBox(height: 2),
                            const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 11,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
              // Goal Status Legend / Empty State Prompt
              if (hasGoal)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLegendDot(_accent, 'Activity Logged'),
                    _buildLegendDot(const Color(0xFF353438), 'Rest Day'),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'No fitness goal set yet',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
                          );
                          if (res == true) {
                            _fetchBackendAnalytics();
                          }
                        },
                        child: Text(
                          '+ Set Goal',
                          style: GoogleFonts.hankenGrotesk(
                            color: _accent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sidebar Stats Grid Below Calendar (App Backend Data)
        Builder(
          builder: (context) {
            final List<dynamic> recentActivities = _analyticsData?['recentActivities'] ?? [];
            final int totalWorkouts = _analyticsData?['summary']?['totalWorkouts'] ?? 0;

            // Count unique active days in selected month from backend activities
            final Set<int> activeDaysSet = {};
            for (final act in recentActivities) {
              if (act['createdAt'] != null) {
                final dt = DateTime.tryParse(act['createdAt'].toString());
                if (dt != null && dt.month == _selectedMonth && dt.year == _selectedYear) {
                  activeDaysSet.add(dt.day);
                }
              }
            }

            final int activeDaysCount = activeDaysSet.length;
            final double activePct = daysInMonth > 0 ? (activeDaysCount / daysInMonth) : 0.0;
            final int activePctInt = (activePct * 100).round();

            // Calculate current streak from backend logged workouts
            int currentStreak = 0;
            if (totalWorkouts > 0) {
              int streakCounter = 0;
              for (int d = now.day; d >= 1; d--) {
                if (activeDaysSet.contains(d)) {
                  streakCounter++;
                  currentStreak = streakCounter;
                } else if (d < now.day) {
                  break;
                }
              }
            }

            final progressMap = _goalsData?['progress'] as Map<String, dynamic>?;
            final int overallGoalCompletionPct = hasGoal
                ? ((((progressMap?['distancePercentage'] as num?)?.toInt() ?? 0) +
                   ((progressMap?['caloriesPercentage'] as num?)?.toInt() ?? 0) +
                   ((progressMap?['workoutsPercentage'] as num?)?.toInt() ?? 0)) ~/ 3).clamp(0, 100)
                : 0;

            return Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _cardBg.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'CURRENT STREAK',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$currentStreak',
                          style: GoogleFonts.anybody(
                            color: _accent,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          currentStreak == 1 ? 'Day in a row' : 'Days in a row',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ACTIVE DAYS',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$activeDaysCount/$daysInMonth',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 38,
                                  height: 38,
                                  child: CircularProgressIndicator(
                                    value: activePct.clamp(0.0, 1.0),
                                    strokeWidth: 3.5,
                                    backgroundColor: const Color(0xFF353438),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _accent,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$activePctInt%',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GOAL COMPLETION',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasGoal ? '$overallGoalCompletionPct%' : '0%',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: hasGoal ? Colors.white : Colors.white54,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              Icons.military_tech_rounded,
                              color: _accent,
                              size: 30,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPersonalGoalsSection() {
    final goalMap = _goalsData?['goal'] as Map<String, dynamic>?;
    final progressMap = _goalsData?['progress'] as Map<String, dynamic>?;
    final bool hasGoal = goalMap != null;

    final double distRatio = hasGoal
        ? (((progressMap?['distancePercentage'] as num?)?.toDouble() ?? 0.0) / 100.0)
        : 0.0;
    final double calRatio = hasGoal
        ? (((progressMap?['caloriesPercentage'] as num?)?.toDouble() ?? 0.0) / 100.0)
        : 0.0;
    final double workRatio = hasGoal
        ? (((progressMap?['workoutsPercentage'] as num?)?.toDouble() ?? 0.0) / 100.0)
        : 0.0;

    final String customActivity = goalMap?['activity'] ?? 'Running';
    final String customMetric = goalMap?['metric'] ?? 'Distance';
    final dynamic customTarget = goalMap?['targetValue'] ?? goalMap?['targetDistance'] ?? 25;
    final String customUnit = goalMap?['unit'] ?? 'Miles';

    final targetDist = goalMap?['targetDistance'] ?? 25.0;
    final targetCal = goalMap?['targetCalories'] ?? 500;
    final targetWork = goalMap?['targetWorkouts'] ?? 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Personal Goals',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (hasGoal)
              GestureDetector(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
                  );
                  if (res == true) {
                    _fetchBackendAnalytics();
                  }
                },
                child: Text(
                  'Customize Goal >',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!hasGoal)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: Icon(Icons.track_changes_rounded, color: _accent, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Active Goal',
                        style: GoogleFonts.anybody(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Set target distance, duration, or calories to track progress.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
                          );
                          if (res == true) {
                            _fetchBackendAnalytics();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+ Set Custom Goal',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildGoalCard(
                  Icons.flag_rounded,
                  '$customActivity ($customMetric)',
                  'Target: $customTarget $customUnit',
                  distRatio.clamp(0.0, 1.0),
                ),
                const SizedBox(width: 12),
                _buildGoalCard(
                  Icons.directions_run_rounded,
                  'Weekly Distance',
                  '${(progressMap?['distanceKm'] ?? 0)} / $targetDist km',
                  distRatio.clamp(0.0, 1.0),
                ),
                const SizedBox(width: 12),
                _buildGoalCard(
                  Icons.local_fire_department_rounded,
                  'Active Calories',
                  '${(progressMap?['calories'] ?? 0)} / $targetCal kcal',
                  calRatio.clamp(0.0, 1.0),
                ),
                const SizedBox(width: 12),
                _buildGoalCard(
                  Icons.fitness_center_rounded,
                  'Weekly Workouts',
                  '${(progressMap?['workouts'] ?? 0)} / $targetWork Sessions',
                  workRatio.clamp(0.0, 1.0),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildGoalCard(
    IconData icon,
    String title,
    String progressText,
    double progress,
  ) {
    final bool isCompleted = progress >= 1.0;
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final res = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
        );
        if (res == true) {
          _fetchBackendAnalytics();
        }
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? _accent.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: _accent, size: 18),
                Text(
                  progressText,
                  style: GoogleFonts.hankenGrotesk(
                    color: isCompleted ? _accent : Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: const Color(0xFF353438),
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownSection() {
    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];

    if (activities.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Breakdown',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _cardBg.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _accent.withValues(alpha: 0.15),
                  child: Icon(Icons.fitness_center_rounded, color: _accent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Activities Recorded Yet',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Log your runs, workouts, or rides in FitRybe to see your activity breakdown here.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Group activities by type
    final Map<String, List<dynamic>> grouped = {};
    for (final act in activities) {
      final String rawType = act['type']?.toString() ?? 'Workout';
      grouped.putIfAbsent(rawType, () => []).add(act);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Breakdown',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: grouped.entries.map((entry) {
            final String typeName = entry.key;
            final List<dynamic> typeActs = entry.value;
            final int sessionCount = typeActs.length;

            double totalMeters = 0;
            int totalSecs = 0;
            for (final a in typeActs) {
              totalMeters += (a['distance'] as num?)?.toDouble() ?? 0.0;
              totalSecs += (a['duration'] as num?)?.toInt() ?? 0;
            }

            final String distStr = totalMeters > 0
                ? '${(totalMeters / 1000).toStringAsFixed(1)} km'
                : '0 km';

            final int hours = totalSecs ~/ 3600;
            final int mins = (totalSecs % 3600) ~/ 60;
            final String timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

            IconData icon = Icons.bolt_rounded;
            final String lowerType = typeName.toLowerCase();
            if (lowerType.contains('run')) {
              icon = Icons.directions_run;
            } else if (lowerType.contains('cycle') || lowerType.contains('bike')) {
              icon = Icons.pedal_bike;
            } else if (lowerType.contains('strength') || lowerType.contains('gym')) {
              icon = Icons.fitness_center;
            } else if (lowerType.contains('walk')) {
              icon = Icons.directions_walk;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: _buildBreakdownCard(
                icon,
                typeName,
                '$sessionCount ${sessionCount == 1 ? 'Session' : 'Sessions'}',
                distStr,
                timeStr,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBreakdownCard(
    IconData icon,
    String title,
    String countText,
    String distText,
    String timeText,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: _accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      countText,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      distText,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      timeText,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];
    final now = DateTime.now();

    // 1. Calculate Activity Frequency for the last 7 days
    final List<int> dailyCounts = List.filled(7, 0);
    final List<String> dayLabels = [];

    for (int i = 6; i >= 0; i--) {
      final dayDate = now.subtract(Duration(days: i));
      final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      dayLabels.add(dayNames[dayDate.weekday - 1]);

      int count = 0;
      for (final act in activities) {
        if (act['createdAt'] != null) {
          final dt = DateTime.tryParse(act['createdAt'].toString())?.toLocal();
          if (dt != null && dt.year == dayDate.year && dt.month == dayDate.month && dt.day == dayDate.day) {
            count++;
          }
        }
      }
      dailyCounts[6 - i] = count;
    }

    final int maxCount = dailyCounts.reduce((a, b) => a > b ? a : b);

    // 2. Calculate Activity Distribution
    final Map<String, int> typeCounts = {};
    for (final act in activities) {
      final String rawType = act['type']?.toString() ?? 'Workout';
      typeCounts[rawType] = (typeCounts[rawType] ?? 0) + 1;
    }

    final int totalCount = activities.length;
    String topType = 'Workout';
    int topCount = 0;
    typeCounts.forEach((key, val) {
      if (val > topCount) {
        topCount = val;
        topType = key;
      }
    });

    final double topPctRatio = totalCount > 0 ? (topCount / totalCount) : 0.0;
    final int topPctInt = (topPctRatio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Performance Trends',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Bar Chart (Activity Frequency - Last 7 Days)
            Expanded(
              child: Container(
                height: 185,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVITY FREQUENCY',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 105,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (index) {
                          final int cnt = dailyCounts[index];
                          final double hFactor = maxCount > 0
                              ? ((cnt / maxCount).clamp(0.08, 1.0))
                              : 0.05;
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final double maxH = constraints.maxHeight;
                                      final double barH = (maxH * hFactor).clamp(4.0, maxH);
                                      return Align(
                                        alignment: Alignment.bottomCenter,
                                        child: Container(
                                          width: 12,
                                          height: barH,
                                          decoration: BoxDecoration(
                                            color: cnt > 0
                                                ? _accent.withValues(alpha: hFactor.clamp(0.4, 1.0))
                                                : const Color(0xFF353438),
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(4),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  dayLabels[index],
                                  style: GoogleFonts.hankenGrotesk(
                                    color: cnt > 0 ? Colors.white : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: cnt > 0 ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Donut Chart (Activity Distribution)
            Expanded(
              child: Container(
                height: 185,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _cardBg.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DISTRIBUTION',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: topPctRatio.clamp(0.0, 1.0),
                              strokeWidth: 9,
                              backgroundColor: const Color(0xFF2C2C30),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _accent,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$topPctInt%',
                                style: GoogleFonts.anybody(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                topType,
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white54,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: typeCounts.isEmpty
                          ? [
                              _buildLegendItem(const Color(0xFF353438), 'No Data'),
                            ]
                          : typeCounts.entries.take(3).map((e) {
                              final String l = e.key;
                              Color c = _accent;
                              if (l.toLowerCase().contains('cycle')) c = const Color(0xFFFFB5A0);
                              if (l.toLowerCase().contains('strength')) c = const Color(0xFFC8C5CB);
                              return _buildLegendItem(c, l);
                            }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildIntensityHeatmap() {
    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];
    final now = DateTime.now();

    // Build intensity map "YYYY-MM-DD" -> intensity level (1 to 4)
    final Map<String, int> dateIntensityMap = {};
    for (final act in activities) {
      if (act['createdAt'] != null) {
        final dt = DateTime.tryParse(act['createdAt'].toString())?.toLocal();
        if (dt != null) {
          final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final int durationSecs = (act['duration'] as num?)?.toInt() ?? 0;
          int lvl = 1;
          if (durationSecs > 3600) {
            lvl = 4;
          } else if (durationSecs > 1800) {
            lvl = 3;
          } else if (durationSecs > 600) {
            lvl = 2;
          }
          dateIntensityMap[key] = (dateIntensityMap[key] ?? 0) > lvl ? dateIntensityMap[key]! : lvl;
        }
      }
    }

    final int todayWeekday = now.weekday; // 1 = Mon, 7 = Sun
    final DateTime startDate = now.subtract(Duration(days: 15 * 7 + (todayWeekday - 1)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity Intensity Heatmap',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 16, // 16 weeks
                  itemBuilder: (context, weekIdx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (dayIdx) {
                          final cellDate = startDate.add(Duration(days: weekIdx * 7 + dayIdx));
                          if (cellDate.isAfter(now)) {
                            return const SizedBox(width: 11, height: 11);
                          }
                          final key = '${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}';
                          final int level = dateIntensityMap[key] ?? 0;

                          Color cellColor = const Color(0xFF353438).withValues(alpha: 0.3);
                          if (level == 1) {
                            cellColor = _accent.withValues(alpha: 0.25);
                          } else if (level == 2) {
                            cellColor = _accent.withValues(alpha: 0.5);
                          } else if (level == 3) {
                            cellColor = _accent.withValues(alpha: 0.75);
                          } else if (level == 4) {
                            cellColor = _accent;
                          }

                          return Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Less Intense',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                  Row(
                    children: [
                      _buildHeatmapLegendCell(
                        const Color(0xFF353438).withValues(alpha: 0.3),
                      ),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.25)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.5)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.75)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent),
                    ],
                  ),
                  Text(
                    'More Intense',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapLegendCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPersonalRecordsGrid() {
    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];

    dynamic longestAct;
    double maxDistMeters = 0;
    dynamic maxDistAct;
    int maxCalories = 0;
    dynamic maxCalAct;
    final Map<String, int> typeCounts = {};

    for (final act in activities) {
      // Longest duration
      final int dur = (act['duration'] as num?)?.toInt() ?? 0;
      if (longestAct == null || dur > ((longestAct['duration'] as num?)?.toInt() ?? 0)) {
        longestAct = act;
      }

      // Max distance
      final double dist = (act['distance'] as num?)?.toDouble() ?? 0.0;
      if (dist > maxDistMeters) {
        maxDistMeters = dist;
        maxDistAct = act;
      }

      // Max calories
      final int cal = (act['calories'] as num?)?.toInt() ?? 0;
      if (cal > maxCalories) {
        maxCalories = cal;
        maxCalAct = act;
      }

      // Activity frequency
      final String rawType = act['type']?.toString() ?? 'Workout';
      typeCounts[rawType] = (typeCounts[rawType] ?? 0) + 1;
    }

    // Format Longest
    final int longestSecs = (longestAct?['duration'] as num?)?.toInt() ?? 0;
    final int lHours = longestSecs ~/ 3600;
    final int lMins = (longestSecs % 3600) ~/ 60;
    final String longestStr = longestSecs == 0
        ? '0m'
        : (lHours > 0 ? '${lHours}h ${lMins}m' : '${lMins}m');
    final String longestTitle = longestAct?['title'] ?? longestAct?['type'] ?? 'No Workouts';

    // Format Distance
    final String distStr = maxDistMeters > 0
        ? '${(maxDistMeters / 1000).toStringAsFixed(1)} km'
        : '0 km';
    final String distTitle = maxDistAct?['title'] ?? maxDistAct?['type'] ?? 'Top Distance';

    // Format Calories
    final String calStr = maxCalories > 0 ? '$maxCalories kcal' : '0 kcal';
    final String calTitle = maxCalAct?['title'] ?? maxCalAct?['type'] ?? 'Max Calories';

    // Format Top Activity
    String topTypeName = 'None';
    int topTypeCount = 0;
    typeCounts.forEach((k, v) {
      if (v > topTypeCount) {
        topTypeCount = v;
        topTypeName = k;
      }
    });
    final String topActSub = topTypeCount > 0 ? '$topTypeCount Sessions' : 'Top Activity';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Records',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildRecordCard('Longest', longestStr, longestTitle),
            _buildRecordCard('Top Distance', distStr, distTitle),
            _buildRecordCard('Max Calories', calStr, calTitle),
            _buildRecordCard('Top Activity', topTypeName, topActSub),
          ],
        ),
      ],
    );
  }

  Widget _buildRecordCard(String label, String value, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: _accent),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: 18,
                top: 12,
                bottom: 12,
                right: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.anybody(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
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

  Widget _buildAIInsights() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: _accent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Fitness Insights',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'COMING SOON',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Personalized AI Coach on the Horizon',
            style: GoogleFonts.anybody(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'We\'re developing a custom AI engine to analyze your logged workouts, recovery trends, and exertion data to deliver actionable, data-driven training guidance.',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white60,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAIComingSoonPill('Adaptive Coaching'),
              _buildAIComingSoonPill('Recovery Metrics'),
              _buildAIComingSoonPill('Smart Milestone Predictor'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIComingSoonPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildLockedAdvancedAnalytics() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          // Background preview cards with mock graphs
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: _cardBg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRAINING LOAD',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Optimal',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        SizedBox(
                          height: 90,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildMockBar(35, _accent),
                              _buildMockBar(55, _accent),
                              _buildMockBar(45, Colors.white24),
                              _buildMockBar(80, _accent),
                              _buildMockBar(65, _accent),
                              _buildMockBar(95, _accent),
                              _buildMockBar(50, Colors.white24),
                              _buildMockBar(75, _accent),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: _cardBg.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RECOVERY SCORE',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '84% Good',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 80,
                                child: CircularProgressIndicator(
                                  value: 0.84,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.white10,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _accent.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                              Text(
                                '84%',
                                style: GoogleFonts.anybody(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                color: Colors.white.withValues(alpha: 0.18),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: _accent, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      'Unlock Advanced Insights',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get Training Load, Recovery Score, and VO2 Max projections with Fitrybe Premium.',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          elevation: 4,
                        ),
                        child: Text(
                          'Upgrade to Premium',
                          style: GoogleFonts.hankenGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockBar(double height, Color color) {
    return Container(
      width: 8,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
