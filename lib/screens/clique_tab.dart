import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'clique_live_activity_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

class CliqueTab extends StatefulWidget {
  final ValueChanged<int>? onSubTabChanged;
  const CliqueTab({super.key, this.onSubTabChanged});

  @override
  State<CliqueTab> createState() => _CliqueTabState();
}

class _CliqueTabState extends State<CliqueTab>
    with TickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1E1E22);

  int _activeSegmentTab = 0; // 0: Activity, 1: Challenges, 2: Synergy
  final String _selectedCategory = 'All';

  final Set<String> _joinedUpcomingIds = {};

  List<Map<String, dynamic>> _liveActivities = [];
  List<Map<String, dynamic>> _upcomingActivities = [];
  bool _isActivitiesLoading = true;
  String? _activitiesError;

  late AnimationController _liveBlinkController;

  // Synergy Orbit States
  double _orbitRotation = math.pi / 2; // Start with first member at bottom center
  Map<String, dynamic>? _selectedOrbitMember;
  late AnimationController _orbitFloatController;

  List<Map<String, dynamic>> _orbitMembers = [];

  @override
  void initState() {
    super.initState();
    _liveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _orbitFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _loadSessions();
    _loadOrbit();
  }

  Future<void> _loadSessions() async {
    if (mounted) setState(() => _activitiesError = null);
    try {
      final sessions = await ApiService.getCliques();
      if (!mounted) return;
      setState(() {
        _liveActivities = sessions
            .where((s) => '${s['status']}'.toUpperCase() == 'LIVE')
            .map(_toActivityCard)
            .toList();
        _upcomingActivities = sessions
            .where((s) => '${s['status']}'.toUpperCase() == 'UPCOMING')
            .map(_toActivityCard)
            .toList();
        _isActivitiesLoading = false;
      });
    } catch (e) {
      debugPrint('CliqueTab load error: $e');
      if (!mounted) return;
      setState(() {
        _isActivitiesLoading = false;
        _activitiesError = 'We could not load group activities.';
      });
    }
  }

  /// The Synergy orbit shows the athletes you follow.
  Future<void> _loadOrbit() async {
    final userId = SessionService().userId;
    if (userId == null) return;
    final following = await ApiService.getFollowing(userId);
    if (!mounted) return;
    setState(() {
      _orbitMembers = following.take(8).map((user) {
        final name = '${user['firstName'] ?? ''}'.trim();
        return {
          'id': user['id'],
          'name': name.isEmpty ? 'Athlete' : name,
          'avatar': ApiService.media(user['avatarUrl'] as String?),
          'location': user['location'],
          'bio': user['bio'],
        };
      }).toList();
    });
  }

  /// Loads a followed athlete's real training numbers for the detail sheet.
  ///
  /// "Synergy" is the share of your own training days in the last 30 that they
  /// also trained on — a measurable overlap rather than an invented score.
  Future<void> _loadOrbitMemberStats(Map<String, dynamic> member) async {
    final memberId = member['id'] as String?;
    final myId = SessionService().userId;
    if (memberId == null || member['statsLoaded'] == true) return;

    final results = await Future.wait([
      ApiService.getActivities(userId: memberId, limit: 100),
      if (myId != null)
        ApiService.getActivities(userId: myId, limit: 100)
      else
        Future.value(<Map<String, dynamic>>[]),
    ]);
    if (!mounted) return;

    final theirs = results[0];
    final mine = results[1];

    double totalMeters = 0;
    int totalSeconds = 0;
    for (final a in theirs) {
      totalMeters += (a['distance'] as num?)?.toDouble() ?? 0;
      totalSeconds += ((a['duration'] as num?) ?? 0).toInt();
    }

    final theirDays = _activeDays(theirs);
    final myDays = _activeDays(mine);
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final myRecent = myDays.where((d) => d.isAfter(cutoff)).toSet();
    final shared = myRecent.intersection(theirDays).length;
    final synergy =
        myRecent.isEmpty ? 0 : ((shared / myRecent.length) * 100).round();

    setState(() {
      member['activities'] = '${theirs.length}';
      member['dist'] = '${(totalMeters / 1000).toStringAsFixed(1)}k';
      member['time'] = '${(totalSeconds / 3600).toStringAsFixed(1)}h';
      member['streak'] = '${_streakFrom(theirDays)}d';
      member['synergy'] = '$synergy%';
      member['fav'] = theirs.isEmpty ? '—' : '${theirs.first['type'] ?? '—'}';
      member['statsLoaded'] = true;
    });
  }

  static Set<DateTime> _activeDays(List<Map<String, dynamic>> activities) =>
      activities
          .map((a) => DateTime.tryParse('${a['createdAt'] ?? ''}')?.toLocal())
          .whereType<DateTime>()
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet();

  static int _streakFrom(Set<DateTime> days) {
    if (days.isEmpty) return 0;
    final now = DateTime.now();
    var cursor = DateTime(now.year, now.month, now.day);
    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static const Map<String, IconData> _activityIcons = {
    'run': Icons.directions_run_rounded,
    'running': Icons.directions_run_rounded,
    'cycling': Icons.directions_bike_rounded,
    'ride': Icons.directions_bike_rounded,
    'walking': Icons.directions_walk_rounded,
    'walk': Icons.directions_walk_rounded,
    'swimming': Icons.pool_rounded,
    'hike': Icons.hiking_rounded,
  };

  static const List<String> _monthLabels = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  /// Maps an API clique session onto the card shape the tab renders.
  Map<String, dynamic> _toActivityCard(Map<String, dynamic> session) {
    final type = '${session['activityType'] ?? 'Running'}';
    final participants = (session['participants'] as List?) ?? const [];
    final scheduled =
        DateTime.tryParse('${session['scheduledAt'] ?? ''}')?.toLocal() ??
            DateTime.now();
    final targetKm = (session['targetDistance'] as num?)?.toDouble() ?? 0;

    // Live progress = furthest participant against the session target.
    double bestMeters = 0;
    for (final p in participants.whereType<Map>()) {
      final d = (p['currentDistance'] as num?)?.toDouble() ?? 0;
      if (d > bestMeters) bestMeters = d;
    }
    final coveredKm = bestMeters / 1000;
    final hour12 = scheduled.hour % 12 == 0 ? 12 : scheduled.hour % 12;

    return {
      'id': '${session['id']}',
      'title': '${session['title'] ?? 'Group activity'}',
      'clique': '${session['meetingLocation'] ?? 'Fitrybe Clique'}',
      'category': type,
      'type': type,
      'icon': _activityIcons[type.toLowerCase()] ?? Icons.fitness_center_rounded,
      'progress': targetKm > 0 ? (coveredKm / targetKm).clamp(0.0, 1.0) : 0.0,
      'progressText': targetKm > 0
          ? '${coveredKm.toStringAsFixed(1)} / ${targetKm.toStringAsFixed(1)} KM'
          : '${coveredKm.toStringAsFixed(1)} KM',
      'participantsCount': participants.length,
      'maxParticipants': participants.length,
      'dateDay': '${scheduled.day}',
      'dateMonth': _monthLabels[scheduled.month - 1],
      'time':
          '$hour12:${scheduled.minute.toString().padLeft(2, '0')} ${scheduled.hour < 12 ? 'AM' : 'PM'}',
      'target': targetKm > 0
          ? '${targetKm.toStringAsFixed(1)} KM Distance'
          : '$type session',
      'isParticipant': participants.whereType<Map>().any(
          (p) => '${p['userId']}' == SessionService().userId),
      'participants': participants
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList(),
    };
  }

  @override
  void dispose() {
    _liveBlinkController.dispose();
    _orbitFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _activeSegmentTab == 2 ? Colors.black : Colors.transparent,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-Tab Selector (Flat under-line style)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSegmentItem(0, 'Activity')),
                      Expanded(child: _buildSegmentItem(1, 'Challenges')),
                      Expanded(child: _buildSegmentItem(2, 'Synergy')),
                    ],
                  ),
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ],
              ),
            ),

            // Conditional Content
            _activeSegmentTab == 0
                ? _buildActivityTab()
                : _activeSegmentTab == 1
                    ? _buildChallengesTab()
                    : _buildSynergyTabSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentItem(int index, String label) {
    final bool isActive = _activeSegmentTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeSegmentTab = index;
        });
        widget.onSubTabChanged?.call(index);
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: isActive ? _accent : Colors.white38,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // --- ACTIVITY TAB ---
  Widget _buildActivityTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Clique Activity',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Move together. Stay motivated.',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Render No Activity State directly
          if (_isActivitiesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: LoadingStateView(),
            )
          else if (_activitiesError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: ErrorStateView(
                message: _activitiesError!,
                onRetry: _loadSessions,
              ),
            )
          else if (_liveActivities.isEmpty && _upcomingActivities.isEmpty)
            _buildEmptyActivityState()
          else ...[
            if (_getFilteredLiveActivities().isNotEmpty) ...[
              // Live Activities Section
              Text(
                'LIVE NOW',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Render filtered Live Activities
              ..._getFilteredLiveActivities().map((act) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _buildLiveActivityCardDynamic(act),
                  )),
            ],
            if (_getFilteredUpcomingActivities().isNotEmpty) ...[
              // Upcoming Section
              Text(
                'UPCOMING',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Render filtered Upcoming Activities
              ..._getFilteredUpcomingActivities().map((act) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildUpcomingActivityCardDynamic(act),
                  )),
            ],
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredLiveActivities() {
    if (_selectedCategory == 'All') return _liveActivities;
    return _liveActivities
        .where((a) => a['category'] == _selectedCategory)
        .toList();
  }

  List<Map<String, dynamic>> _getFilteredUpcomingActivities() {
    if (_selectedCategory == 'All') return _upcomingActivities;
    return _upcomingActivities
        .where((a) => a['category'] == _selectedCategory)
        .toList();
  }

  Widget _buildEmptyActivityState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Glowing Icon Badge
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: _accent.withValues(alpha: 0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              Icons.directions_run_rounded,
              color: _accent,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'No Clique Activities Yet',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Join a group workout with your friends or schedule your first Clique activity to track live together.',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white54,
              fontSize: 13.5,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

        ],
      ),
    );
  }

  Widget _buildLiveActivityCardDynamic(Map<String, dynamic> act) {
    final String title = act['title'] as String;
    final String clique = act['clique'] as String;
    final String actType = act['type'] as String? ?? 'Running';
    final IconData icon = act['icon'] as IconData;
    final double progress = (act['progress'] as num).toDouble();
    final String progressText = act['progressText'] as String;
    final int pCount = act['participantsCount'] as int;
    final int maxP = act['maxParticipants'] as int;

    return Container(
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Live indicator header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    FadeTransition(
                      opacity: _liveBlinkController,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE NOW',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Active Session',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Title Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: _accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      clique,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toInt()}% Goal Met',
                style: GoogleFonts.hankenGrotesk(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                progressText,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white54,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  for (final p in ((act['participants'] as List?) ?? const [])
                      .whereType<Map>()
                      .take(4)) ...[
                    _buildStackedAvatar(p),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
              Text(
                '$pCount/$maxP Participants',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.heavyImpact();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CliqueLiveActivityScreen(
                      sessionId: act['id'] as String?,
                      activityName: title,
                      activityType: actType,
                      activityIcon: icon,
                    ),
                  ),
                );
                _loadSessions();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Open Live Session',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedAvatar(Map participant) {
    final user = (participant['user'] is Map)
        ? Map<String, dynamic>.from(participant['user'])
        : const <String, dynamic>{};
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF1E1E22), width: 1.5),
      ),
      child: UserAvatar(
        url: ApiService.media(user['avatarUrl'] as String?),
        fallbackName: name.isEmpty ? 'Athlete' : name,
        radius: 14,
      ),
    );
  }

  Widget _buildUpcomingActivityCardDynamic(Map<String, dynamic> act) {
    final String id = act['id'] as String;
    final String title = act['title'] as String;
    final String actType = act['type'] as String? ?? 'Walking';
    final IconData icon = act['icon'] as IconData;
    final String dateDay = act['dateDay'] as String;
    final String dateMonth = act['dateMonth'] as String;
    final String time = act['time'] as String;
    final int pCount = act['participantsCount'] as int;
    // Membership comes from the server; the local set only covers joins made
    // in this session before the list refreshes.
    final bool isJoined =
        act['isParticipant'] == true || _joinedUpcomingIds.contains(id);
    final int displayPCount =
        (act['isParticipant'] != true && _joinedUpcomingIds.contains(id))
            ? pCount + 1
            : pCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isJoined ? _accent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        children: [
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2D),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dateDay,
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  dateMonth,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.white38, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white54,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $displayPCount joined',
                      style: GoogleFonts.hankenGrotesk(
                        color: isJoined ? Colors.greenAccent : Colors.white38,
                        fontSize: 11.5,
                        fontWeight: isJoined ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // View Lobby / Join CTA
          GestureDetector(
            onTap: () async {
              HapticFeedback.lightImpact();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CliqueLiveActivityScreen(
                    sessionId: id,
                    isUpcoming: true,
                    scheduledTime: '$dateMonth $dateDay, $time',
                    activityName: title,
                    activityType: actType,
                    activityIcon: icon,
                  ),
                ),
              );
              _loadSessions();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isJoined ? _accent.withValues(alpha: 0.2) : const Color(0xFF2A2A2D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isJoined ? _accent : Colors.transparent,
                ),
              ),
              child: Text(
                isJoined ? 'LOBBY ✓' : 'LOBBY',
                style: GoogleFonts.hankenGrotesk(
                  color: isJoined ? _accent : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CHALLENGES TAB ---
  Widget _buildChallengesTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Challenges',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Compete. Complete. Achieve.',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),

          // Challenges are not part of the backend yet, so this stays an
          // honest empty state instead of showing invented competitions.
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            icon: Icons.emoji_events_rounded,
            title: 'No challenges yet',
            message:
                'Group challenges are coming soon. In the meantime, start a live Clique activity or chase your weekly goal.',
            actionLabel: 'See live activities',
            onAction: () {
              HapticFeedback.selectionClick();
              setState(() => _activeSegmentTab = 0);
              widget.onSubTabChanged?.call(0);
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSynergyTabSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Synergy Orbit',
            style: GoogleFonts.anybody(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Explore your closest connections.',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 32),

          if (_orbitMembers.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              icon: Icons.hub_rounded,
              title: 'Your orbit is empty',
              message:
                  'Follow athletes from the Trybes tab and they will appear here, along with how often you train on the same days.',
            )
          else ...[
            // Orbit Visualization Container
            _buildOrbitView(),
            const SizedBox(height: 24),

            // Slide-up Details Container
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              firstCurve: Curves.easeInOut,
              secondCurve: Curves.easeInOut,
              crossFadeState: _selectedOrbitMember != null
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(height: 0),
              secondChild: _buildSelectedMemberDetailsSheet(),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildOrbitView() {
    const double orbitSize = 280.0;
    const double radius = 100.0;
    const double centerOffset = orbitSize / 2;

    // Calculate coordinates for connection line
    Offset? lineStart;
    Offset? lineEnd;
    if (_selectedOrbitMember != null) {
      final index = _orbitMembers.indexWhere((m) => m['id'] == _selectedOrbitMember!['id']);
      if (index != -1) {
        final double baseAngle = (index / _orbitMembers.length) * 2 * math.pi;
        final double angle = baseAngle + _orbitRotation;
        lineStart = const Offset(centerOffset, centerOffset);
        lineEnd = Offset(
          centerOffset + radius * math.cos(angle),
          centerOffset + radius * math.sin(angle),
        );
      }
    }

    return Center(
      child: Container(
        width: orbitSize,
        height: orbitSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: GestureDetector(
          onPanUpdate: (details) {
            if (_selectedOrbitMember == null) {
              setState(() {
                _orbitRotation += details.delta.dx * 0.007;
              });
            }
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Floating gradient 1
              AnimatedBuilder(
                animation: _orbitFloatController,
                builder: (context, child) {
                  final double floatVal = _orbitFloatController.value;
                  return Positioned(
                    left: centerOffset - 120 + 20 * math.sin(floatVal * 2 * math.pi),
                    top: centerOffset - 120 + 20 * math.cos(floatVal * 2 * math.pi),
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _accent.withValues(alpha: 0.12),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Floating gradient 2
              AnimatedBuilder(
                animation: _orbitFloatController,
                builder: (context, child) {
                  final double floatVal = _orbitFloatController.value;
                  return Positioned(
                    left: centerOffset - 100 - 25 * math.cos(floatVal * 2 * math.pi),
                    top: centerOffset - 100 - 25 * math.sin(floatVal * 2 * math.pi),
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFF9800).withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Rotating Line Connection (Custom Painter)
              if (lineStart != null && lineEnd != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: OrbitLinePainter(
                      start: lineStart,
                      end: lineEnd,
                      color: _accent,
                    ),
                  ),
                ),

              // Orbit rim dashed border helper
              Positioned(
                left: centerOffset - radius,
                top: centerOffset - radius,
                child: Container(
                  width: radius * 2,
                  height: radius * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      style: BorderStyle.solid,
                    ),
                  ),
                ),
              ),

              // Center User Avatar (wrapped in AnimatedBuilder for float)
              AnimatedBuilder(
                animation: _orbitFloatController,
                builder: (context, child) {
                  final double floatVal = _orbitFloatController.value;
                  final double yOffset = floatVal * -4.0;
                  return Positioned(
                    left: centerOffset - 32,
                    top: centerOffset - 32 + yOffset,
                    child: child!,
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _accent, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.25),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  // The orbit centre is the signed-in athlete.
                  child: UserAvatar(
                    url: SessionService().avatarUrl,
                    fallbackName: SessionService().displayName,
                    radius: 32,
                  ),
                ),
              ),

              // Orbiting Members (wrapped in AnimatedBuilder for wavy phase-shifted floating)
              ...List.generate(_orbitMembers.length, (index) {
                final member = _orbitMembers[index];
                final double baseAngle = (index / _orbitMembers.length) * 2 * math.pi;
                final double angle = baseAngle + _orbitRotation;

                final isSelected = _selectedOrbitMember != null && _selectedOrbitMember!['id'] == member['id'];
                final isAnySelected = _selectedOrbitMember != null;

                // Position math
                final double x = centerOffset + radius * math.cos(angle) - 24;
                final double y = centerOffset + radius * math.sin(angle) - 24;

                return AnimatedBuilder(
                  animation: _orbitFloatController,
                  builder: (context, child) {
                    final double floatVal = _orbitFloatController.value;
                    // Introduce a phase shift so avatars float asynchronously/wavy
                    final double phaseAngle = baseAngle;
                    final double yOffset = math.sin(floatVal * 2 * math.pi + phaseAngle) * -4.0;
                    return Positioned(
                      left: x,
                      top: y + yOffset,
                      child: child!,
                    );
                  },
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (_selectedOrbitMember != null && _selectedOrbitMember!['id'] == member['id']) {
                          _selectedOrbitMember = null;
                        } else {
                          _selectedOrbitMember = member;
                          // Rotate orbit to bring this clicked member to the front (bottom center = 90 deg / math.pi/2)
                          _orbitRotation = (math.pi / 2) - baseAngle;
                        }
                      });
                      if (_selectedOrbitMember != null) {
                        _loadOrbitMemberStats(member);
                      }
                    },
                    child: AnimatedOpacity(
                      opacity: isSelected ? 1.0 : (isAnySelected ? 0.35 : 1.0),
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedScale(
                        scale: isSelected ? 1.25 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? _accent : Colors.white10,
                              width: isSelected ? 2 : 1.5,
                            ),
                          ),
                          child: UserAvatar(
                            url: member['avatar'] as String?,
                            fallbackName: member['name'] as String?,
                            radius: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedMemberDetailsSheet() {
    if (_selectedOrbitMember == null) return const SizedBox(height: 0);

    final member = _selectedOrbitMember!;
    final synergyNum =
        double.tryParse('${member['synergy'] ?? ''}'.replaceAll('%', '')) ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar, Name, Progress ring
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  UserAvatar(
                    url: member['avatar'] as String?,
                    fallbackName: member['name'] as String?,
                    radius: 26,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member['name'] as String,
                        style: GoogleFonts.anybody(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RISING DUO',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Synergy circular progress
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: synergyNum / 100,
                      strokeWidth: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(_accent),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${member['synergy'] ?? '—'}',
                        style: GoogleFonts.anybody(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'MATCH',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grid with stats
          Row(
            children: [
              Expanded(
                child: _buildSynergyStatBox('Activities', '${member['activities'] ?? '—'}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSynergyStatBox('Distance', '${member['dist'] ?? '—'}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSynergyStatBox('Streak', '${member['streak'] ?? '—'}'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Shared Timeline
          Text(
            'SHARED ACTIVITY TIMELINE',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 10,
              itemBuilder: (context, idx) {
                final hasActivity = idx % 3 == 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasActivity ? _accent.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
                          border: Border.all(
                            color: hasActivity ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: hasActivity
                            ? Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: _accent,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${30 - idx}d',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // History CTA
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: _accent,
                  content: Text(
                    'Shared activity history with ${member['name']} coming soon!',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: Text(
                'View Full History',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSynergyStatBox(String label, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161619),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: GoogleFonts.anybody(
              color: _accent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class OrbitLinePainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  OrbitLinePainter({required this.start, required this.end, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    // Gradient shader along the line
    paint.shader = ui.Gradient.linear(
      start,
      end,
      [color.withValues(alpha: 0.1), color],
    );

    canvas.drawLine(start, end, paint);

    // Glowing dot at the end
    final glowPaint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(end, 6, glowPaint);
    
    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(end, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant OrbitLinePainter oldDelegate) {
    return oldDelegate.start != start || oldDelegate.end != end || oldDelegate.color != color;
  }
}
