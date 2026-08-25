import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'record_map_screen.dart';
import '../services/health_service.dart';

class RecordScreen extends StatefulWidget {
  static const routeName = '/RecordScreen';
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with TickerProviderStateMixin {
  // ── Colors ──────────────────────────────────────────────────────────────────
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1A1A1E);
  final Color _bg = const Color(0xFF0F0F12);

  // ── Activity selection ───────────────────────────────────────────────────────
  String _selectedActivityName = 'Walking';
  IconData _selectedActivityIcon = Icons.directions_walk_rounded;

  bool get _isGpsActivity {
    const gpsActivities = {
      'Running',
      'Cycling',
      'Walking',
      'Hiking',
      'Trail Running',
      'Roller Skating',
      'Skateboarding',
      'Swimming',
      'Kayaking',
      'Rowing',
      'Skiing',
      'Snowboarding',
    };
    return gpsActivities.contains(_selectedActivityName);
  }

  // ── Tracking state ──────────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;

  // ── Stopwatch ────────────────────────────────────────────────────────────────
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;

  // ── Live metrics (simulated) ─────────────────────────────────────────────────
  double _activeDistance = 0.0;
  int _activeCalories = 0;
  int _activeHeartRate = 0;

  // ── Activity Log ─────────────────────────────────────────────────────────────
  final List<_ActivityLog> _activityLogs = [];

  // ── Animation ────────────────────────────────────────────────────────────────
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    HealthService().fetchTodayHealthData();
    _activeHeartRate = HealthService().healthNotifier.value.heartRate;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  // ── Timer helpers ────────────────────────────────────────────────────────────
  void _startTimer() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() {
        _elapsedSeconds++;
        if (_isGpsActivity) {
          _activeDistance += 0.003;
        } else {
          _activeDistance = 0.0;
        }
        _activeCalories = (_elapsedSeconds * 0.165).round();
        _activeHeartRate = 130 + (_elapsedSeconds % 15);
      });
    });
  }

  void _stopTimer() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = null;
  }

  String _formatTime(int seconds) {
    if (seconds >= 3600) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getPace() {
    if (_activeDistance < 0.005) return "-'--\"";
    final double minPerKm = (_elapsedSeconds / 60.0) / _activeDistance;
    final int min = minPerKm.toInt();
    final int sec = ((minPerKm - min) * 60).toInt();
    return "$min'${sec.toString().padLeft(2, '0')}\"";
  }

  // ── Actions ──────────────────────────────────────────────────────────────────
  void _onStartPressed() {
    HapticFeedback.heavyImpact();
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _elapsedSeconds = 0;
      _activeDistance = 0.0;
      _activeCalories = 0;
      _activeHeartRate = 0;
    });
    _startTimer();
  }

  void _onPausePressed() {
    HapticFeedback.mediumImpact();
    setState(() => _isPaused = true);
  }

  void _onResumePressed() {
    HapticFeedback.mediumImpact();
    setState(() => _isPaused = false);
  }

  void _onStopPressed() {
    HapticFeedback.heavyImpact();
    // Save log only if there was meaningful activity (at least 3 seconds)
    if (_isRecording && _elapsedSeconds >= 3) {
      _activityLogs.insert(
        0,
        _ActivityLog(
          activityName: _selectedActivityName,
          activityIcon: _selectedActivityIcon,
          duration: _elapsedSeconds,
          distanceKm: _isGpsActivity ? _activeDistance : 0.0,
          calories: _activeCalories,
          avgHeartRate: _activeHeartRate,
          timestamp: DateTime.now(),
        ),
      );
    }
    _stopTimer();
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _elapsedSeconds = 0;
      _activeDistance = 0.0;
      _activeCalories = 0;
      _activeHeartRate = 0;
    });
  }

  // ── Activity picker bottom sheet ─────────────────────────────────────────────
  void _showActivityPickerSheet() {
    if (_isRecording) return; // lock while tracking
    HapticFeedback.mediumImpact();

    final List<Map<String, dynamic>> activities = [
      // Recent
      {'name': 'Running', 'icon': Icons.directions_run_rounded, 'cat': 'recent'},
      {'name': 'Cycling', 'icon': Icons.pedal_bike_rounded, 'cat': 'recent'},
      // Distance-Based
      {'name': 'Walking', 'icon': Icons.directions_walk_rounded, 'cat': 'distance'},
      {'name': 'Running', 'icon': Icons.directions_run_rounded, 'cat': 'distance'},
      {'name': 'Hiking', 'icon': Icons.hiking_rounded, 'cat': 'distance'},
      {'name': 'Cycling', 'icon': Icons.pedal_bike_rounded, 'cat': 'distance'},
      {'name': 'Trail Running', 'icon': Icons.terrain_rounded, 'cat': 'distance'},
      {'name': 'Roller Skating', 'icon': Icons.roller_skating_rounded, 'cat': 'distance'},
      {'name': 'Skateboarding', 'icon': Icons.skateboarding_rounded, 'cat': 'distance'},
      {'name': 'Swimming', 'icon': Icons.pool_rounded, 'cat': 'distance'},
      {'name': 'Kayaking', 'icon': Icons.kayaking_rounded, 'cat': 'distance'},
      {'name': 'Rowing', 'icon': Icons.rowing_rounded, 'cat': 'distance'},
      {'name': 'Skiing', 'icon': Icons.downhill_skiing_rounded, 'cat': 'distance'},
      {'name': 'Snowboarding', 'icon': Icons.snowboarding_rounded, 'cat': 'distance'},
      // Location-Based
      {'name': 'Gym Workout', 'icon': Icons.fitness_center_rounded, 'cat': 'location'},
      {'name': 'Football', 'icon': Icons.sports_soccer_rounded, 'cat': 'location'},
      {'name': 'Basketball', 'icon': Icons.sports_basketball_rounded, 'cat': 'location'},
      {'name': 'Tennis', 'icon': Icons.sports_tennis_rounded, 'cat': 'location'},
      {'name': 'Badminton', 'icon': Icons.sports_tennis_rounded, 'cat': 'location'},
      {'name': 'Cricket', 'icon': Icons.sports_cricket_rounded, 'cat': 'location'},
      {'name': 'Boxing', 'icon': Icons.sports_mma_rounded, 'cat': 'location'},
      {'name': 'Yoga', 'icon': Icons.self_improvement_rounded, 'cat': 'location'},
      {'name': 'Martial Arts', 'icon': Icons.sports_martial_arts_rounded, 'cat': 'location'},
      {'name': 'Rock Climbing', 'icon': Icons.landscape_rounded, 'cat': 'location'},
      {'name': 'Golf', 'icon': Icons.sports_golf_rounded, 'cat': 'location'},
      {'name': 'Volleyball', 'icon': Icons.sports_volleyball_rounded, 'cat': 'location'},
    ];

    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final q = searchCtrl.text.toLowerCase();
          final filtered =
              activities.where((a) => (a['name'] as String).toLowerCase().contains(q)).toList();

          Widget sectionHeader(String label, String? desc) => Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8)),
                    if (desc != null) ...[
                      const SizedBox(height: 3),
                      Text(desc,
                          style: GoogleFonts.hankenGrotesk(
                              color: Colors.white30, fontSize: 10, height: 1.4)),
                    ],
                  ],
                ),
              );

          Widget row(Map<String, dynamic> a) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(a['icon'] as IconData, color: _accent, size: 22),
                title: Text(a['name'] as String,
                    style: GoogleFonts.hankenGrotesk(
                        color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w600)),
                trailing:
                    const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedActivityName = a['name'] as String;
                    _selectedActivityIcon = a['icon'] as IconData;
                  });
                  Navigator.pop(ctx);
                },
              );

          final recent = filtered.where((a) => a['cat'] == 'recent').toList();
          final distance = filtered.where((a) => a['cat'] == 'distance').toList();
          final location = filtered.where((a) => a['cat'] == 'location').toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: Color(0xFF1B1B1E),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                      color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Activity',
                        style: GoogleFonts.hankenGrotesk(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2C2C30), shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white70, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Search
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2D), borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white38, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                          onChanged: (_) => setSheet(() {}),
                          decoration: InputDecoration(
                            hintText: 'Search activities...',
                            hintStyle:
                                GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      if (recent.isNotEmpty) ...[
                        sectionHeader('RECENT', null),
                        ...recent.map(row),
                      ],
                      if (distance.isNotEmpty) ...[
                        sectionHeader('DISTANCE-BASED (GPS)',
                            'Track distance, pace, and route automatically.'),
                        ...distance.map(row),
                      ],
                      if (location.isNotEmpty) ...[
                        sectionHeader('LOCATION-BASED',
                            'GPS used for presence, not distance tracking.'),
                        ...location.map(row),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Activity Logs Sheet ──────────────────────────────────────────────────────
  void _showLogsSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2E).withValues(alpha: 0.55),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.2),
                left: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.2),
                right: BorderSide(
                    color: Colors.white.withValues(alpha: 0.18), width: 1.2),
              ),
            ),
            child: Column(
              children: [
            // Handle
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
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Activity Log',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (_activityLogs.isNotEmpty)
                    Text(
                      '${_activityLogs.length} sessions',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Content
            Expanded(
              child: _activityLogs.isEmpty
                  ? _buildEmptyLogs()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _activityLogs.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, i) =>
                          _buildLogEntry(_activityLogs[i]),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
);
}

  // ── Navigate to Real GPS Map Screen ─────────────────────────────────────────
  void _showMapSheet() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecordMapScreen(),
      ),
    );
  }

  Widget _buildEmptyLogs() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded,
              color: Colors.white12, size: 64),
          const SizedBox(height: 16),
          Text(
            'No sessions yet',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Start recording to see your activity history here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white24,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(_ActivityLog log) {
    final String durationStr = _formatTime(log.duration);
    final String dateStr = _formatLogDate(log.timestamp);
    final String timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: icon + name + timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(log.activityIcon, color: _accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.activityName,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$dateStr · $timeStr',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                durationStr,
                style: GoogleFonts.anybody(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Row 2: distance · calories · heart rate chips
          Row(
            children: [
              if (log.distanceKm > 0) ...[
                _logChip(Icons.map_outlined,
                    '${log.distanceKm.toStringAsFixed(2)} KM'),
                const SizedBox(width: 10),
              ],
              _logChip(Icons.local_fire_department_outlined,
                  '${log.calories} KCAL'),
              const SizedBox(width: 10),
              if (log.avgHeartRate > 0)
                _logChip(Icons.favorite_outline_rounded,
                    '${log.avgHeartRate} BPM'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _logChip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: _accent, size: 13),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatLogDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month]} ${dt.day}';
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: close + animated title
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_isRecording) _onStopPressed();
                          Navigator.pop(context);
                        },
                        child:
                            const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Text(
                          _isRecording ? 'Active Tracking' : 'Record Activity',
                          key: ValueKey(_isRecording),
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Right: map + log buttons
                  Row(
                    children: [
                      // Map Button (Only for GPS Activities)
                      if (_isGpsActivity) ...[
                        _PressButton(
                          onTap: _showMapSheet,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(
                              Symbols.map_rounded,
                              color: Colors.white,
                              size: 24,
                              weight: 800,
                              grade: 200,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      // Log button with count badge
                      _PressButton(
                        onTap: _showLogsSheet,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Symbols.format_list_bulleted_rounded,
                                color: Colors.white,
                                size: 24,
                                weight: 800,
                                grade: 200,
                              ),
                            ),
                            if (_activityLogs.isNotEmpty)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _activityLogs.length > 9
                                          ? '9+'
                                          : '${_activityLogs.length}',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
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

            const SizedBox(height: 8),

            // ── Activity Selector Pill ─────────────────────────────────────
            GestureDetector(
              onTap: _showActivityPickerSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E22),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_selectedActivityIcon, color: _accent, size: 18),
                    const SizedBox(width: 9),
                    Text(
                      _selectedActivityName.toUpperCase(),
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (!_isRecording) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Spacer(),

            // ── Big Timer ─────────────────────────────────────────────────
            Column(
              children: [
                Text(
                  _formatTime(_elapsedSeconds),
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'DURATION',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Metrics Grid ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_isGpsActivity) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _showMapSheet,
                            child: _metricCard(
                              label: 'DISTANCE',
                              icon: Icons.map_outlined,
                              value: _isRecording ? _activeDistance.toStringAsFixed(2) : '0.00',
                              unit: 'KM',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            label: 'PACE',
                            icon: Icons.speed_rounded,
                            value: _isRecording ? _getPace() : "-'--\"",
                            unit: '/KM',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            label: 'HEART RATE',
                            icon: Icons.favorite_outline_rounded,
                            value: _isRecording ? '$_activeHeartRate' : '--',
                            unit: 'BPM',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            label: 'CALORIES',
                            icon: Icons.local_fire_department_outlined,
                            value: _isRecording ? '$_activeCalories' : '0',
                            unit: 'KCAL',
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _metricCard(
                            label: 'CALORIES',
                            icon: Icons.local_fire_department_outlined,
                            value: _isRecording ? '$_activeCalories' : '0',
                            unit: 'KCAL',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _metricCard(
                            label: 'HEART RATE',
                            icon: Icons.favorite_outline_rounded,
                            value: _isRecording ? '$_activeHeartRate' : '--',
                            unit: 'BPM',
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // ── Bottom Action Area ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: animation,
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_isRecording
                      ? (_isPaused ? 'paused' : 'active')
                      : 'idle'),
                  child: _buildBottomActions(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    // Pre-activity → big orange START button
    if (!_isRecording) {
      return _PressButton(
        onTap: _onStartPressed,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.45),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                'START ACTIVITY',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active (not paused) → single pause circle
    if (!_isPaused) {
      return Center(
        child: _PressButton(
          onTap: _onPausePressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2D),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.pause_rounded, color: Colors.white, size: 30),
          ),
        ),
      );
    }

    // Paused → green resume circle + dark-red stop circle
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Resume (green)
        _PressButton(
          onTap: _onResumePressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF1B8A3A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.35),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(width: 32),
        // Stop (dark red)
        _PressButton(
          onTap: _onStopPressed,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFF7A1B1B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.30),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required String label,
    required IconData icon,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, color: _accent, size: 17),
            ],
          ),
          const SizedBox(height: 14),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable press-scale button widget ────────────────────────────────────────
class _PressButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _PressButton({required this.onTap, required this.child});

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(TapDownDetails _) => _ctrl.forward();
  void _onUp(TapUpDetails _) {
    _ctrl.reverse();
    widget.onTap();
  }
  void _onCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onDown,
      onTapUp: _onUp,
      onTapCancel: _onCancel,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

// ── Activity Log Data Model ───────────────────────────────────────────────────
class _ActivityLog {
  final String activityName;
  final IconData activityIcon;
  final int duration; // seconds
  final double distanceKm;
  final int calories;
  final int avgHeartRate;
  final DateTime timestamp;

  const _ActivityLog({
    required this.activityName,
    required this.activityIcon,
    required this.duration,
    required this.distanceKm,
    required this.calories,
    required this.avgHeartRate,
    required this.timestamp,
  });
}
