import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'subscription_screen.dart';
import 'customize_goal_screen.dart';
import '../services/api_service.dart';
import '../widgets/activity_heatmap.dart';
import '../services/goal_progress.dart';
import '../services/units.dart';
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
            _buildSummaryCard('Distance',
                Units.fromKm(health.distanceKm).toStringAsFixed(1),
                ' ${Units.distanceUnit}'),
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

    final date = DateTime(year, month, day);
    final now = DateTime.now();
    final bool isToday =
        day == now.day && month == now.month && year == now.year;
    final bool isFuture = date.isAfter(DateTime(now.year, now.month, now.day));

    final List<dynamic> allActivities =
        _analyticsData?['recentActivities'] ?? const [];
    final dayActivities = GoalProgress.activitiesOn(allActivities, date);

    // Goals ordered daily, weekly, monthly. Each bar covers the period that
    // contains this day, named so it is clear what is being measured.
    final goals = (_goalsData?['goals'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList()
      ..sort((a, b) => _periodRank('${a['frequency'] ?? a['period']}')
          .compareTo(_periodRank('${b['frequency'] ?? b['period']}')));

    double totalDistMeters = 0;
    int totalCalories = 0;
    int totalSeconds = 0;
    for (final act in dayActivities) {
      totalDistMeters += (act['distance'] as num?)?.toDouble() ?? 0;
      totalCalories += (act['calories'] as num?)?.toInt() ?? 0;
      totalSeconds += (act['duration'] as num?)?.toInt() ?? 0;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_months[month - 1]} $day, $year',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'TODAY',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Day totals ───────────────────────────────────────
                    if (dayActivities.isNotEmpty) ...[
                      // Expanded so four stats share the width evenly rather
                      // than overflowing on a narrow phone.
                      Row(
                        children: [
                          Expanded(
                            child: _buildDayModalStat(
                                'SESSIONS', '${dayActivities.length}'),
                          ),
                          if (totalDistMeters > 0)
                            Expanded(
                              child: _buildDayModalStat('DISTANCE',
                                  Units.distance(totalDistMeters)),
                            ),
                          Expanded(
                            child: _buildDayModalStat(
                                'TIME', _shortDuration(totalSeconds)),
                          ),
                          if (totalCalories > 0)
                            Expanded(
                              child: _buildDayModalStat(
                                  'KCAL', '$totalCalories'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                    ],

                    // ── Goal completion ──────────────────────────────────
                    Text(
                      'GOAL COMPLETION',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (goals.isEmpty)
                      Text(
                        'No goals set yet.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      )
                    else
                      for (final goal in goals) ...[
                        _buildDayGoalBar(goal, allActivities, date),
                        const SizedBox(height: 14),
                      ],

                    const SizedBox(height: 8),

                    // ── Activities that day ──────────────────────────────
                    Text(
                      'ACTIVITIES',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (dayActivities.isEmpty)
                      Text(
                        isFuture
                            ? 'Nothing logged yet.'
                            : isToday
                                ? 'Nothing logged yet today.'
                                : 'Rest day — nothing logged.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      )
                    else
                      for (final act in dayActivities) ...[
                        _buildDayActivityRow(act),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One goal's progress across the period containing the tapped day.
  Widget _buildDayGoalBar(
    Map<String, dynamic> goal,
    List<dynamic> activities,
    DateTime date,
  ) {
    final metric = '${goal['metric'] ?? 'Distance'}';
    final activity = '${goal['activity'] ?? ''}';
    final frequency = '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}';
    final unit = '${goal['unit'] ?? ''}';

    final target = GoalProgress.targetOf(goal) ?? 0;
    final achieved =
        GoalProgress.achievedInPeriodContaining(goal, activities, date);
    final progress = target <= 0 ? 0.0 : (achieved / target).clamp(0.0, 1.0);
    final bool met = progress >= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$frequency · ${activity.isEmpty ? metric : activity}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (met)
              Icon(Icons.check_circle_rounded, color: _accent, size: 15),
            if (met) const SizedBox(width: 5),
            Text(
              '${(progress * 100).round()}%',
              style: GoogleFonts.anybody(
                color: met ? _accent : Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(_accent),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${_goalValueLabel(metric, achieved, target, unit)}'
          '  ·  ${GoalProgress.periodLabelFor(goal, date)}',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 11.5,
          ),
        ),
      ],
    );
  }

  /// One logged session on the tapped day.
  Widget _buildDayActivityRow(Map<String, dynamic> act) {
    final type = '${act['type'] ?? act['title'] ?? 'Workout'}';
    final distanceKm = ((act['distance'] as num?)?.toDouble() ?? 0) / 1000;
    final seconds = (act['duration'] as num?)?.toInt() ?? 0;
    final calories = (act['calories'] as num?)?.toInt() ?? 0;
    final when = DateTime.tryParse('${act['createdAt'] ?? ''}')?.toLocal();

    final parts = <String>[
      if (distanceKm > 0) Units.distanceKm(distanceKm),
      if (seconds > 0) _shortDuration(seconds),
      if (calories > 0) '$calories kcal',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_metricIcon('Distance'), color: _accent, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (parts.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    parts.join('  ·  '),
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (when != null)
            Text(
              _clockTime(when),
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white30,
                fontSize: 11,
              ),
            ),
        ],
      ),
    );
  }

  static String _shortDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${mins}m';
    if (mins > 0) return '${mins}m';
    return '${seconds}s';
  }

  static String _clockTime(DateTime when) {
    final hour12 = when.hour % 12 == 0 ? 12 : when.hour % 12;
    final minute = when.minute.toString().padLeft(2, '0');
    return '$hour12:$minute ${when.hour < 12 ? 'am' : 'pm'}';
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
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.anybody(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// The fill for a calendar day at a given density level, from a light tint
  /// for a single activity to near-solid for five or more.
  Color _calendarShade(int density) => switch (density) {
        1 => _accent.withValues(alpha: 0.22),
        2 => _accent.withValues(alpha: 0.5),
        3 => _accent.withValues(alpha: 0.88),
        _ => const Color(0xFF353438).withValues(alpha: 0.3),
      };

  double _calendarBorderAlpha(int density) => switch (density) {
        1 => 0.35,
        2 => 0.6,
        _ => 1.0,
      };

  Widget _buildCalendarSection() {
    final int daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final int startWeekday = DateTime(_selectedYear, _selectedMonth, 1).weekday; // 1 = Mon, 7 = Sun
    final int leadingSpaces = startWeekday - 1;
    final int totalGridItems = leadingSpaces + daysInMonth;

    final now = DateTime.now();
    final bool hasGoal =
        (_goalsData?['goals'] as List<dynamic>? ?? const []).isNotEmpty;

    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];

    // Days with anything logged. Deliberately independent of goals: a goal has
    // its own period, and one athlete can hold several with different periods,
    // so there is no single per-day pass/fail a calendar could show.
    final Set<DateTime> loggedDays = GoalProgress.activeDays(activities);

    // How many activities each day had, which sets how strongly it is shaded.
    final Map<DateTime, int> countsByDay =
        GoalProgress.activityCountsByDay(activities);

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
                  final DateTime cellDate =
                      DateTime(_selectedYear, _selectedMonth, dayNumber);
                  final int activityCount = countsByDay[cellDate] ?? 0;
                  final bool isActivityLogged = activityCount > 0;
                  // One activity is a light tint, two to four darker, five or
                  // more darkest, so a busy day stands out from a single walk.
                  final int density =
                      GoalProgress.activityDensityLevel(activityCount);

                  Color tileBgColor;
                  Color borderColor;
                  if (isActivityLogged) {
                    tileBgColor = _calendarShade(density);
                    borderColor = _accent.withValues(alpha: _calendarBorderAlpha(density));
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
                        // The glow deepens with the shade, so a busier day
                        // reads as brighter rather than merely a darker fill.
                        boxShadow: isActivityLogged
                            ? [
                                BoxShadow(
                                  color: _accent.withValues(
                                      alpha: 0.12 + 0.12 * density),
                                  blurRadius: 3.0 + 3.0 * density,
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
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sidebar Stats Grid Below Calendar (App Backend Data)
        Builder(
          builder: (context) {
            // Days in the selected month that met the goal. `.toLocal()` matters:
            // a late-night session belongs to the athlete's day, not the
            // server's.
            final Set<int> activeDaysSet = loggedDays
                .where((d) => d.month == _selectedMonth && d.year == _selectedYear)
                .map((d) => d.day)
                .toSet();

            final int activeDaysCount = activeDaysSet.length;
            final double activePct = daysInMonth > 0 ? (activeDaysCount / daysInMonth) : 0.0;
            final int activePctInt = (activePct * 100).round();

            // The streak counts consecutive days that met the goal, and runs
            // across month boundaries — the old version restarted the count at
            // Counts consecutive days with training, and runs across month
            // boundaries — the old version restarted at the first of the month.
            final int currentStreak = GoalProgress.currentStreak(loggedDays);
            final int longestStreak = GoalProgress.longestStreak(loggedDays);

            // Average progress across the goals the athlete holds, each
            // measured over its own period. Computed here rather than on the
            // server, which cannot know the athlete's timezone and so cannot
            // say which day, week or month a session belongs to.
            final List<Map<String, dynamic>> goals = (_goalsData?['goals']
                        as List<dynamic>? ??
                    const [])
                .whereType<Map>()
                .map((g) => Map<String, dynamic>.from(g))
                .toList();

            var completionSum = 0.0;
            var counted = 0;
            for (final goal in goals) {
              final target = GoalProgress.targetOf(goal);
              if (target == null || target <= 0) continue;
              final achieved = GoalProgress.achievedInPeriod(goal, activities);
              completionSum += (achieved / target).clamp(0.0, 1.0);
              counted++;
            }
            final int overallGoalCompletionPct =
                counted == 0 ? 0 : ((completionSum / counted) * 100).round();

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
                        if (longestStreak > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Best $longestStreak',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
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
    // One goal per period — daily, weekly, monthly — each with its own
    // activity, metric and target. They are measured and streaked separately
    // because a day and a week share no common pass/fail.
    final List<dynamic> rawGoals = _goalsData?['goals'] ?? const [];
    final goals = rawGoals
        .whereType<Map>()
        .map((g) => Map<String, dynamic>.from(g))
        .toList()
      ..sort((a, b) => _periodRank('${a['frequency'] ?? a['period']}')
          .compareTo(_periodRank('${b['frequency'] ?? b['period']}')));

    final List<dynamic> activities = _analyticsData?['recentActivities'] ?? [];
    final bool hasGoal = goals.isNotEmpty;

    Future<void> openPicker() async {
      HapticFeedback.mediumImpact();
      final res = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
      );
      if (res == true) _fetchBackendAnalytics();
    }

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
            GestureDetector(
              onTap: openPicker,
              child: Text(
                hasGoal ? 'Customize Goal >' : 'Set a Goal >',
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
          GestureDetector(
            onTap: openPicker,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardBg.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.flag_rounded, color: _accent, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Set a daily, weekly or monthly goal to start a streak.',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                ],
              ),
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < goals.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  _buildGoalCard(goals[i], activities),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// Daily first, then weekly, then monthly — shortest horizon leads.
  static int _periodRank(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'daily':
        return 0;
      case 'weekly':
        return 1;
      default:
        return 2;
    }
  }

  static IconData _metricIcon(String metric) {
    switch (metric) {
      case 'Calories':
        return Icons.local_fire_department_rounded;
      case 'Duration':
        return Icons.timer_rounded;
      case 'Sessions':
        return Icons.fitness_center_rounded;
      default:
        return Icons.route_rounded;
    }
  }

  /// Formats an achieved/target pair in the goal's own unit.
  static String _goalValueLabel(
      String metric, double achieved, double target, String unit) {
    switch (metric) {
      case 'Sessions':
        return '${achieved.round()} / ${target.round()} sessions';
      case 'Calories':
        return '${achieved.round()} / ${target.round()} kcal';
      case 'Duration':
        return '${achieved.round()} / ${target.round()} min';
      default:
        // Both figures are kilometres by the time they reach here — the
        // goal's own unit was already folded in when its target was read — so
        // the only conversion left is to whatever the athlete reads in.
        return '${Units.fromKm(achieved).toStringAsFixed(1)} / '
            '${Units.fromKm(target).toStringAsFixed(1)} ${Units.distanceUnit}';
    }
  }

  /// One goal, showing progress through its current period and how many
  /// consecutive periods have been completed.
  Widget _buildGoalCard(Map<String, dynamic> goal, List<dynamic> activities) {
    final metric = '${goal['metric'] ?? 'Distance'}';
    final activity = '${goal['activity'] ?? ''}';
    final frequency = '${goal['frequency'] ?? goal['period'] ?? 'Weekly'}';
    final unit = '${goal['unit'] ?? ''}';

    final target = GoalProgress.targetOf(goal) ?? 0;
    final achieved = GoalProgress.achievedInPeriod(goal, activities);
    final progress = target <= 0 ? 0.0 : (achieved / target).clamp(0.0, 1.0);
    final streak = GoalProgress.periodStreak(goal, activities);
    final bool isCompleted = progress >= 1.0;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final res = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CustomizeGoalScreen()),
        );
        if (res == true) _fetchBackendAnalytics();
      },
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? _accent.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.05),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _metricIcon(metric),
                  color: isCompleted ? _accent : Colors.white60,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    frequency.toUpperCase(),
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (isCompleted)
                  Icon(Icons.check_circle_rounded, color: _accent, size: 16),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              activity.isEmpty ? metric : '$activity · $metric',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _goalValueLabel(metric, achieved, target, unit),
              style: GoogleFonts.anybody(
                color: Colors.white70,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.bolt_rounded,
                  color: streak > 0 ? _accent : Colors.white24,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  streak > 0
                      ? '${GoalProgress.streakLabel(goal, streak)} in a row'
                      : 'No streak yet',
                  style: GoogleFonts.hankenGrotesk(
                    color: streak > 0 ? Colors.white70 : Colors.white38,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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

            final String distStr = Units.distance(totalMeters, decimals: 1);

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
    return ActivityHeatmap(
      activities: (_analyticsData?['recentActivities'] as List?) ?? const [],
      title: 'Activity Intensity Heatmap',
      titleStyle: GoogleFonts.hankenGrotesk(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      accent: _accent,
      cardColor: _cardBg.withValues(alpha: 0.7),
    );
  }

  Widget _buildPersonalRecordsGrid() {
    // All-time bests, held separately per activity type, straight from the
    // server. Deriving these on the client meant they were computed over a
    // truncated list — so a genuine record disappeared once it aged out — and
    // that a yoga session and a run competed for a single "longest" slot.
    final List<dynamic> records = _analyticsData?['records'] ?? [];

    Map<String, dynamic>? bestBy(
      String field, {
      bool lowestWins = false,
      bool Function(Map<String, dynamic>)? where,
    }) {
      Map<String, dynamic>? winner;
      num? best;
      for (final raw in records) {
        if (raw is! Map) continue;
        final row = Map<String, dynamic>.from(raw);
        if (where != null && !where(row)) continue;
        final value = row[field] as num?;
        if (value == null || value <= 0) continue;
        if (best == null ||
            (lowestWins ? value < best : value > best)) {
          best = value;
          winner = row;
        }
      }
      return winner;
    }

    String formatDuration(int seconds) {
      if (seconds <= 0) return '—';
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    }

    // Pace inverts distance, so the conversion is not the same one distance
    // uses. Units owns that; doing it here again is how the two drift apart.
    String formatPace(num? minutesPerKm) => Units.pace(minutesPerKm);

    final longest = bestBy('longestDurationSecs');
    final furthest = bestBy('longestDistanceKm');
    final hardest = bestBy('mostCalories');
    // Pace only means anything for a type that actually covers ground.
    final fastest = bestBy('bestPace', lowestWins: true);
    final mostUsed = bestBy('sessions');

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
        const SizedBox(height: 4),
        Text(
          'All time, best per activity',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 12,
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
            _buildRecordCard(
              'Longest',
              formatDuration(
                  (longest?['longestDurationSecs'] as num?)?.toInt() ?? 0),
              longest == null ? 'No workouts yet' : '${longest['type']}',
            ),
            _buildRecordCard(
              'Furthest',
              furthest == null
                  ? '—'
                  : Units.distanceKm(furthest['longestDistanceKm'] as num, decimals: 1),
              furthest == null ? 'No distance logged' : '${furthest['type']}',
            ),
            _buildRecordCard(
              'Best Pace',
              formatPace(fastest?['bestPace'] as num?),
              fastest == null ? 'No paced activity' : '${fastest['type']}',
            ),
            _buildRecordCard(
              'Most Calories',
              hardest == null ? '—' : '${hardest['mostCalories']} kcal',
              hardest == null ? 'No workouts yet' : '${hardest['type']}',
            ),
          ],
        ),
        if (mostUsed != null) ...[
          const SizedBox(height: 12),
          _buildRecordCard(
            'Most Logged',
            '${mostUsed['type']}',
            '${mostUsed['sessions']} sessions'
            '${(mostUsed['totalDistanceKm'] as num? ?? 0) > 0 ? ' · ${Units.distanceKm(mostUsed['totalDistanceKm'] as num, decimals: 0)} total' : ''}',
          ),
        ],
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
