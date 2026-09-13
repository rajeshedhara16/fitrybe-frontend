import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

enum HeatmapMode { month, year }

/// GitHub-style activity contribution heatmap.
///
/// Displays activity intensity in a minimal contribution grid (Month or Year mode)
/// with no calendar day/month text labels inside the grid, and a sleek intensity legend.
class ActivityHeatmap extends StatefulWidget {
  const ActivityHeatmap({
    super.key,
    required this.activities,
    required this.title,
    required this.accent,
    required this.cardColor,
    this.titleStyle,
    this.now,
    this.monthsBack = 23,
    this.initialMode = HeatmapMode.year,
  });

  final List<dynamic> activities;
  final String title;
  final TextStyle? titleStyle;
  final Color accent;
  final Color cardColor;
  final DateTime? now;
  final int monthsBack;
  final HeatmapMode initialMode;

  /// Shade level for a day's total minutes: 0 for nothing, up to 4.
  static int levelFor(double? minutes) {
    if (minutes == null || minutes <= 0) return 0;
    if (minutes < 20) return 1;
    if (minutes < 40) return 2;
    if (minutes < 70) return 3;
    return 4;
  }

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  static const _months = [
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
    'December'
  ];

  static const _monthsShort = [
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

  final ScrollController _scrollController = ScrollController();
  late HeatmapMode _mode;
  late DateTime _selectedMonth;

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    final today = _today;
    _selectedMonth = DateTime(today.year, today.month, 1);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _mode == HeatmapMode.year) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<DateTime, double> _minutesByDay() {
    final minutes = <DateTime, double>{};
    for (final raw in widget.activities) {
      if (raw is! Map) continue;
      final at = DateTime.tryParse('${raw['createdAt'] ?? ''}')?.toLocal();
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day);
      minutes[day] =
          (minutes[day] ?? 0) + ((raw['duration'] as num?) ?? 0) / 60;
    }
    return minutes;
  }

  Color _colorFor(int level) => switch (level) {
        1 => widget.accent.withValues(alpha: 0.25),
        2 => widget.accent.withValues(alpha: 0.50),
        3 => widget.accent.withValues(alpha: 0.75),
        4 => widget.accent,
        _ => const Color(0xFF1E1E22),
      };

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _prevMonth() {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    final today = _today;
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (next.isAfter(DateTime(today.year, today.month, 1))) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMonth = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _minutesByDay();
    final today = _today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title and Month / Year toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.title,
              style: widget.titleStyle ??
                  GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            _buildModeToggle(),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_mode == HeatmapMode.month)
                _buildMonthSubheader(minutes)
              else
                _buildYearSubheader(minutes, today),
              const SizedBox(height: 14),
              if (_mode == HeatmapMode.month)
                _buildMonthGrid(minutes, today)
              else
                _buildYearGrid(minutes, today),
              const SizedBox(height: 14),
              // Footer: intensity legend
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Less',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 5),
                    for (var l = 0; l <= 4; l++)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                          color: _colorFor(l),
                          borderRadius: BorderRadius.circular(2.5),
                          border: l == 0
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: 0.05))
                              : null,
                        ),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      'More',
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
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 30,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleOption('Month', HeatmapMode.month),
          _buildToggleOption('Year', HeatmapMode.year),
        ],
      ),
    );
  }

  Widget _buildToggleOption(String label, HeatmapMode mode) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () {
        if (_mode == mode) return;
        HapticFeedback.selectionClick();
        setState(() {
          _mode = mode;
        });
        if (mode == HeatmapMode.year) {
          _scrollToEnd();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? widget.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: widget.accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildYearSubheader(Map<DateTime, double> minutes, DateTime today) {
    final start = DateTime(today.year, today.month, today.day - 364);
    final totalActive = minutes.entries
        .where((e) =>
            e.value > 0 && !e.key.isBefore(start) && !e.key.isAfter(today))
        .length;

    return Text(
      '$totalActive active ${totalActive == 1 ? 'day' : 'days'} in the last year',
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildMonthSubheader(Map<DateTime, double> minutes) {
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final totalActive = minutes.entries.where((e) {
      return e.key.year == _selectedMonth.year &&
          e.key.month == _selectedMonth.month &&
          e.value > 0;
    }).length;

    final isCurrentMonth = _selectedMonth.year == _today.year &&
        _selectedMonth.month == _today.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _prevMonth,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white70,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_months[_selectedMonth.month - 1]} ${_selectedMonth.year}',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isCurrentMonth ? null : _nextMonth,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isCurrentMonth
                      ? Colors.transparent
                      : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: isCurrentMonth ? Colors.white12 : Colors.white70,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        Text(
          '$totalActive / $daysInMonth active ${totalActive == 1 ? 'day' : 'days'}',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildYearGrid(Map<DateTime, double> minutes, DateTime today) {
    final start = DateTime(today.year, today.month, today.day - 364);
    final gridStart = DateTime(
      start.year,
      start.month,
      start.day - (start.weekday - 1),
    );
    final totalDays = DateTime.utc(today.year, today.month, today.day)
            .difference(
                DateTime.utc(gridStart.year, gridStart.month, gridStart.day))
            .inDays +
        1;
    final columns = (totalDays / 7).ceil();

    DateTime dayAt(int col, int row) => DateTime(
          gridStart.year,
          gridStart.month,
          gridStart.day + col * 7 + row,
        );

    const cellSize = 12.0;
    const gap = 3.0;
    final gridWidth = columns * (cellSize + gap) - gap;

    final monthLabels = <int, String>{};
    int? lastMonth;
    for (var c = 0; c < columns; c++) {
      final monday = dayAt(c, 0);
      if (monday.month != lastMonth) {
        monthLabels[c] = _monthsShort[monday.month - 1];
        lastMonth = monday.month;
      }
    }

    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: SizedBox(
        width: gridWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final entry in monthLabels.entries)
                    Positioned(
                      left: entry.key * (cellSize + gap),
                      top: 0,
                      child: Text(
                        entry.value,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: EdgeInsets.only(
                      right: c == columns - 1 ? 0 : gap,
                    ),
                    child: Column(
                      children: [
                        for (var r = 0; r < 7; r++)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: r == 6 ? 0 : gap,
                            ),
                            child: _buildCell(
                              dayAt(c, r),
                              start,
                              today,
                              cellSize,
                              minutes,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGrid(Map<DateTime, double> minutes, DateTime today) {
    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, daysInMonth);

    // Align to Monday start
    final gridStart = DateTime(
      firstDayOfMonth.year,
      firstDayOfMonth.month,
      firstDayOfMonth.day - (firstDayOfMonth.weekday - 1),
    );

    final totalGridDays = DateTime.utc(
              lastDayOfMonth.year,
              lastDayOfMonth.month,
              lastDayOfMonth.day + (7 - lastDayOfMonth.weekday),
            )
            .difference(
                DateTime.utc(gridStart.year, gridStart.month, gridStart.day))
            .inDays +
        1;
    final numWeeks = (totalGridDays / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive cell size based on width (7 columns)
        const gap = 6.0;
        final availableWidth = constraints.maxWidth;
        final cellSize = ((availableWidth - (6 * gap)) / 7).floorToDouble();

        return Column(
          children: [
            for (var w = 0; w < numWeeks; w++)
              Padding(
                padding: EdgeInsets.only(bottom: w == numWeeks - 1 ? 0 : gap),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var d = 0; d < 7; d++)
                      _buildMonthCell(
                        DateTime(
                          gridStart.year,
                          gridStart.month,
                          gridStart.day + w * 7 + d,
                        ),
                        firstDayOfMonth,
                        lastDayOfMonth,
                        today,
                        cellSize,
                        minutes,
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildMonthCell(
    DateTime day,
    DateTime firstOfMonth,
    DateTime lastOfMonth,
    DateTime today,
    double size,
    Map<DateTime, double> minutes,
  ) {
    final isCurrentMonth =
        !day.isBefore(firstOfMonth) && !day.isAfter(lastOfMonth);

    if (!isCurrentMonth) {
      return SizedBox(
        width: size,
        height: size,
      );
    }

    final isFuture = day.isAfter(today);
    final isToday = day == today;
    final mins = minutes[day];
    final level = isFuture ? 0 : ActivityHeatmap.levelFor(mins);

    return Container(
      key: ValueKey('heat-m-${_ymd(day)}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFuture ? const Color(0xFF141416) : _colorFor(level),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
    );
  }

  Widget _buildCell(
    DateTime day,
    DateTime start,
    DateTime today,
    double size,
    Map<DateTime, double> minutes,
  ) {
    final isWithinRange = !day.isBefore(start) && !day.isAfter(today);

    if (!isWithinRange) {
      return SizedBox(width: size, height: size);
    }

    final mins = minutes[day];
    final level = ActivityHeatmap.levelFor(mins);

    return Container(
      key: ValueKey('heat-${_ymd(day)}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFor(level),
        borderRadius: BorderRadius.circular(2.5),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 0.5,
        ),
      ),
    );
  }
}
