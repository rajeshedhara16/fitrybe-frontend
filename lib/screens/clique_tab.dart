import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'clique_live_activity_screen.dart';
import 'synergy_orbit.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/socket_service.dart';
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

  @override
  void initState() {
    super.initState();
    _liveBlinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _loadSessions();
    _listenForLobbyChanges();
  }

  /// Refreshes the session list when a lobby changes or a host starts one, so
  /// participant counts and LIVE/UPCOMING placement stay current.
  void _listenForLobbyChanges() {
    final socket = SocketService();
    socket.connect();
    socket.on('clique:lobby_updated', _onRemoteCliqueChange);
    socket.on('clique:started', _onRemoteCliqueChange);
  }

  void _onRemoteCliqueChange(dynamic _) {
    if (mounted) _loadSessions();
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
    final counts = (session['counts'] is Map)
        ? Map<String, dynamic>.from(session['counts'])
        : const <String, dynamic>{};

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
      // Server-computed so every device agrees on the figures.
      'participantsCount': (counts['joinedCount'] as num?)?.toInt() ??
          participants.length,
      'maxParticipants': (counts['participantCount'] as num?)?.toInt() ??
          participants.length,
      'readyCount': (counts['readyCount'] as num?)?.toInt() ?? 0,
      'invitedCount': (counts['invitedCount'] as num?)?.toInt() ?? 0,
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
    SocketService()
      ..off('clique:lobby_updated')
      ..off('clique:started');
    _liveBlinkController.dispose();
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

  /// The Synergy tab lives in its own widget, which owns its animations and
  /// only runs them while this tab is showing.
  Widget _buildSynergyTabSection() => const SynergyOrbit();
}
