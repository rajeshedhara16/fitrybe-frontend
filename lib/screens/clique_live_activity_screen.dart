import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/units.dart';
import '../services/health_service.dart';
import '../services/session_service.dart';
import '../services/socket_service.dart';
import '../services/achievement_service.dart';
import '../services/calorie_estimator.dart';
import '../services/location_tracker.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

class CliqueLiveActivityScreen extends StatefulWidget {
  static const routeName = '/CliqueLiveActivityScreen';
  /// Server id of the clique session this screen is driving.
  final String? sessionId;
  final bool isUpcoming;
  final String scheduledTime;
  final String activityName;
  final String activityType;
  final IconData? activityIcon;
  final String goalType;
  final double goalValue;
  final String goalUnit;

  const CliqueLiveActivityScreen({
    super.key,
    this.sessionId,
    this.isUpcoming = false,
    this.scheduledTime = 'Today, 7:30 PM',
    this.activityName = 'Morning Trail Run',
    this.activityType = 'Running',
    this.activityIcon,
    this.goalType = 'Distance',
    this.goalValue = 5.0,
    this.goalUnit = 'km',
  });

  @override
  State<CliqueLiveActivityScreen> createState() =>
      _CliqueLiveActivityScreenState();
}

class _CliqueLiveActivityScreenState extends State<CliqueLiveActivityScreen>
    with TickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _surfaceHigh = const Color(0xFF2A2A2D);
  final Color _bg = const Color(0xFF0F0F12);

  // Activity config
  String _selectedActivityName = 'Morning Trail Run';
  String _selectedActivityType = 'Running';
  IconData _selectedActivityIcon = Icons.directions_run_rounded;

  // Goal config
  String _goalType = 'Distance';
  double _goalValue = 5.0;
  String _goalUnit = 'km';

  // Animation controllers
  late AnimationController _pulseController;

  // Active tracking state
  bool _isUpcoming = false;
  String _scheduledTime = 'Today, 7:30 PM';
  bool _isStarting = false;
  String _startButtonText = 'START ACTIVITY';
  bool _isRecording = false;
  bool _isPaused = false;
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;

  /// Kilometres measured by the GPS, never derived from elapsed time. This is
  /// what gets broadcast to the squad and saved as the workout.
  double get _activeDistance => _tracker.distanceKm;
  int _activeCalories = 0;

  /// Zero means "no sensor reading" — the UI shows `--` rather than a number
  /// we made up.
  int _activeHeartRate = 0;
  bool _isSheetMinimized = false;

  /// Sole source of this athlete's distance and route for the session.
  final LocationTracker _tracker = LocationTracker();

  /// Explains an empty distance readout when location is unavailable.
  String? _locationWarning;

  /// True only for the athlete who created the session — they alone can invite
  /// and start. Derived from the server record, never assumed.
  bool _currentUserIsAdmin = false;

  /// Whether the signed-in user has accepted their invite (is in the lobby).
  bool _hasJoined = false;
  bool _isTogglingReady = false;

  // Leaderboard filter
  String _selectedMetricFilter = 'DISTANCE';

  // Squad participants for Leaderboard & Lobby, loaded from the session.
  List<Map<String, dynamic>> _squadMembers = [];
  bool _isSquadLoading = true;

  /// Counts the server computes, so every device shows the same figures.
  int _joinedCount = 0;
  int _readyCount = 0;
  int _invitedCount = 0;

  @override
  void initState() {
    super.initState();
    _isUpcoming = widget.isUpcoming;
    _scheduledTime = widget.scheduledTime;
    _selectedActivityName = widget.activityName;
    _selectedActivityType = widget.activityType;
    if (widget.activityIcon != null) {
      _selectedActivityIcon = widget.activityIcon!;
    }
    _goalType = widget.goalType;
    _goalValue = widget.goalValue;
    _goalUnit = widget.goalUnit;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadSession();
    _joinTelemetryRoom();
  }

  /// Subscribes to the session room so other participants' GPS telemetry
  /// updates the leaderboard live.
  void _joinTelemetryRoom() {
    final id = widget.sessionId;
    if (id == null) return;
    final socket = SocketService();
    socket.connect();
    // joinRoom so the session room survives a reconnect or token refresh.
    socket.joinRoom('clique:join', id);
    socket.on('clique:telemetry_update', _onTelemetry);
    socket.on('clique:status_updated', _onStatusUpdated);
    // The server re-broadcasts the whole roster after any lobby change, so
    // squad membership, ready flags and counts stay identical on every device.
    socket.on('clique:lobby_updated', _onLobbyUpdated);
  }

  void _onLobbyUpdated(dynamic data) {
    if (data is! Map || !mounted) return;
    final session = data['session'];
    if (session is! Map) return;
    if ('${session['id']}' != widget.sessionId) return;
    _applySession(Map<String, dynamic>.from(session));
  }

  void _onTelemetry(dynamic data) {
    if (data is! Map || !mounted) return;
    final payload = Map<String, dynamic>.from(data);
    final userId = '${payload['userId'] ?? ''}';
    final index = _squadMembers.indexWhere((m) => m['id'] == userId);
    if (index == -1) return;

    setState(() {
      _squadMembers[index]['distance'] =
          ((payload['distance'] as num?)?.toDouble() ?? 0) / 1000;
      _squadMembers[index]['calories'] =
          ((payload['calories'] as num?) ?? 0).toInt();
      final pace = (payload['pace'] as num?)?.toDouble();
      if (pace != null) _squadMembers[index]['pace'] = _formatPace(pace);
    });
  }

  void _onStatusUpdated(dynamic data) {
    if (data is! Map || !mounted) return;
    if ('${data['sessionId'] ?? widget.sessionId}' != widget.sessionId) return;
    final status = '${data['status']}'.toUpperCase();

    if (status == 'LIVE') {
      setState(() => _isUpcoming = false);
      // The host pressed Start — everyone in the lobby begins tracking now.
      if (!_isRecording && !_currentUserIsAdmin && _hasJoined) {
        setState(() {
          _isRecording = true;
          _isPaused = false;
        });
        _startTimer();
        _beginTracking();
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: _accent,
            content: Text(
              'The host started the activity — go!',
              style: GoogleFonts.hankenGrotesk(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } else if (status == 'COMPLETED') {
      _stopwatchTimer?.cancel();
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  static String _formatPace(double minutesPerKm) {
    if (minutesPerKm <= 0 || minutesPerKm.isInfinite) return "--'--\"";
    final minutes = minutesPerKm.floor();
    final seconds = ((minutesPerKm - minutes) * 60).round();
    return "$minutes'${seconds.toString().padLeft(2, '0')}\"";
  }

  Future<void> _loadSession() async {
    final id = widget.sessionId;
    if (id == null) {
      if (mounted) setState(() => _isSquadLoading = false);
      return;
    }

    final session = await ApiService.getClique(id);
    if (!mounted || session == null) {
      if (mounted) setState(() => _isSquadLoading = false);
      return;
    }
    _applySession(session);
  }

  /// Single place that maps a server session onto this screen's state, used by
  /// both the initial fetch and every live `clique:lobby_updated` push.
  void _applySession(Map<String, dynamic> session) {
    final myId = SessionService().userId;
    final participants = (session['participants'] as List?) ?? const [];
    final counts = (session['counts'] is Map)
        ? Map<String, dynamic>.from(session['counts'])
        : const <String, dynamic>{};

    final members = participants.whereType<Map>().map((raw) {
      final p = Map<String, dynamic>.from(raw);
      final user = (p['user'] is Map)
          ? Map<String, dynamic>.from(p['user'])
          : const <String, dynamic>{};
      final userId = '${p['userId'] ?? user['id'] ?? ''}';
      final isYou = userId == myId;
      final name =
          '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
      final status = '${p['status'] ?? 'JOINED'}'.toUpperCase();

      return {
        'id': userId,
        'name': isYou ? 'You' : (name.isEmpty ? 'Athlete' : name),
        'isAdmin': '${p['role'] ?? ''}'.toUpperCase() == 'HOST',
        'isYou': isYou,
        'distance': ((p['currentDistance'] as num?)?.toDouble() ?? 0) / 1000,
        'pace': _formatPace((p['currentPace'] as num?)?.toDouble() ?? 0),
        'calories': 0,
        'heartRate': 0,
        // Readiness is its own flag now; INVITED members have not accepted yet.
        'isReady': p['isReady'] == true,
        'hasJoined': status != 'INVITED',
        'status': status,
        'avatar': ApiService.media(user['avatarUrl'] as String?),
      };
    }).toList();

    final me = members.where((m) => m['isYou'] == true).toList();

    setState(() {
      _isUpcoming = '${session['status']}'.toUpperCase() != 'LIVE';
      _selectedActivityName = '${session['title'] ?? _selectedActivityName}';
      _selectedActivityType =
          '${session['activityType'] ?? _selectedActivityType}';
      final target = (session['targetDistance'] as num?)?.toDouble();
      if (target != null && target > 0) _goalValue = target;

      _currentUserIsAdmin = '${session['creatorId'] ?? ''}' == myId;
      _hasJoined = me.isNotEmpty && me.first['hasJoined'] == true;

      _squadMembers = members;
      _joinedCount = (counts['joinedCount'] as num?)?.toInt() ??
          members.where((m) => m['hasJoined'] == true).length;
      _readyCount = (counts['readyCount'] as num?)?.toInt() ??
          members.where((m) => m['isReady'] == true).length;
      _invitedCount = (counts['invitedCount'] as num?)?.toInt() ??
          members.where((m) => m['hasJoined'] != true).length;
      _isSquadLoading = false;
    });

    // Opening a session that is already running — a late join, or coming back
    // after backgrounding the app — has to begin tracking too. Without this
    // the live UI appeared but the clock never started and nothing was
    // recorded for this athlete.
    final isLive = '${session['status']}'.toUpperCase() == 'LIVE';
    if (isLive && _hasJoined && !_isRecording) {
      setState(() {
        _isRecording = true;
        _isPaused = false;
      });
      _startTimer();
      _beginTracking();
    }
  }

  /// Persists the caller's ready flag; the server broadcasts the new roster.
  Future<void> _toggleReady() async {
    final id = widget.sessionId;
    if (id == null || _isTogglingReady) return;

    final me = _squadMembers.where((m) => m['isYou'] == true).toList();
    final next = !(me.isNotEmpty && me.first['isReady'] == true);

    HapticFeedback.heavyImpact();
    setState(() {
      _isTogglingReady = true;
      if (me.isNotEmpty) me.first['isReady'] = next;
    });

    final ok = await ApiService.setCliqueReady(id, next);
    if (!mounted) return;
    setState(() => _isTogglingReady = false);
    if (!ok) {
      // Fall back to the server's view if the toggle was rejected.
      _loadSession();
    }
  }

  @override
  void dispose() {
    SocketService()
      ..off('clique:telemetry_update')
      ..off('clique:status_updated')
      ..off('clique:lobby_updated');
    if (widget.sessionId != null) {
      SocketService()
          .leaveRoom('clique:join', 'clique:leave', widget.sessionId!);
    }
    _tracker.stop();
    _pulseController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  /// Host-only. Warns when part of the lobby has not marked ready, but never
  /// blocks the start — one idle member should not hold up the squad.
  Future<void> _confirmAndStartActivity() async {
    if (_isStarting || !_currentUserIsAdmin) return;

    final notReady = _joinedCount - _readyCount;
    if (notReady > 0) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Start anyway?',
            style: GoogleFonts.anybody(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            notReady == 1
                ? '1 of $_joinedCount in the lobby has not marked ready yet.'
                : '$notReady of $_joinedCount in the lobby have not marked ready yet.',
            style: GoogleFonts.hankenGrotesk(
                color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Wait',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                shape: const StadiumBorder(),
              ),
              child: Text('Start now',
                  style: GoogleFonts.hankenGrotesk(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    _triggerStartActivity();
  }

  void _triggerStartActivity() {
    if (_isStarting) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isStarting = true;
      _startButtonText = 'SYNCING SQUAD...';
    });
    int countdown = 3;
    Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (countdown > 0) {
        setState(() {
          _startButtonText = '$countdown...';
        });
        countdown--;
      } else {
        timer.cancel();
        setState(() {
          _isStarting = false;
          _isRecording = true;
          _isPaused = false;
        });
        // Flip the session to LIVE. The server fans the change out to the
        // squad, so there is no client-side relay to trust.
        if (widget.sessionId != null) {
          ApiService.updateCliqueStatus(widget.sessionId!, 'LIVE');
        }
        _startTimer();
        _beginTracking();
      }
    });
  }

  void _startTimer() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isPaused) {
        setState(() {
          _elapsedSeconds++;
          // Calories follow measured distance, not the clock, so an athlete
          // who has not set off yet shows a burn of zero.
          _activeCalories = CalorieEstimator.fromDistance(
            activity: _selectedActivityType,
            distanceKm: _tracker.distanceKm,
          );
          _activeHeartRate = HealthService().healthNotifier.value.heartRate;
          _refreshMyRow();
        });

        // Broadcast our measured progress to the rest of the squad.
        _broadcastTelemetry();
      }
    });
  }

  /// Starts GPS measurement for this athlete's leg of the session. Tracking
  /// failure downgrades the workout to duration-only rather than falling back
  /// to invented distance.
  Future<void> _beginTracking() async {
    _tracker.reset();
    if (mounted) setState(() => _locationWarning = null);
    try {
      await _tracker.start(onUpdate: () {
        if (!mounted) return;
        setState(_refreshMyRow);
        _broadcastTelemetry();
      });
    } on LocationDeniedException catch (e) {
      if (!mounted) return;
      setState(() => _locationWarning = e.message);
    } catch (e) {
      debugPrint('Clique GPS start error: $e');
      if (!mounted) return;
      setState(() =>
          _locationWarning = 'Distance is unavailable — GPS could not start.');
    }
  }

  /// Mirrors this athlete's live figures onto their leaderboard row. Other
  /// rows move only when their own device sends telemetry over the socket.
  void _refreshMyRow() {
    final myIndex = _squadMembers.indexWhere((m) => m['isYou'] == true);
    if (myIndex != -1) {
      _squadMembers[myIndex]['distance'] = _activeDistance;
      _squadMembers[myIndex]['calories'] = _activeCalories;
      _squadMembers[myIndex]['heartRate'] = _activeHeartRate;
      _squadMembers[myIndex]['pace'] = _getPaceString();
    }
    _sortSquadMembers();
  }

  void _broadcastTelemetry() {
    final id = widget.sessionId;
    if (id == null || !_isRecording) return;
    final position = _tracker.lastPosition;
    SocketService().emit('clique:telemetry', {
      'sessionId': id,
      if (position != null) 'lat': position.latitude,
      if (position != null) 'lng': position.longitude,
      'distance': _tracker.distanceMeters,
      'calories': _activeCalories,
      'pace': _tracker.paceMinPerKm(_elapsedSeconds) ?? 0,
    });
  }

  void _sortSquadMembers() {
    if (_selectedMetricFilter == 'DISTANCE') {
      _squadMembers.sort((a, b) => (b['distance'] as double)
          .compareTo(a['distance'] as double));
    } else if (_selectedMetricFilter == 'CALORIES') {
      _squadMembers.sort((a, b) =>
          (b['calories'] as int).compareTo(a['calories'] as int));
    }
  }

  void _togglePause() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPaused = !_isPaused;
      _tracker.isPaused = _isPaused;
    });
  }

  Future<void> _finishAndSaveActivity() async {
    HapticFeedback.heavyImpact();
    _stopwatchTimer?.cancel();

    final formattedTime = _formatElapsedTime(_elapsedSeconds);
    final statsString =
        "Distance: ${_activeDistance.toStringAsFixed(2)} KM, Duration: $formattedTime, Calories: $_activeCalories KCAL.";

    try {
      // Save the workout itself, then share it to the feed.
      final route = _tracker.routeAsJson();
      final activity = await ApiService.logActivity({
        'title': _selectedActivityName,
        'type': _selectedActivityType,
        'duration': _elapsedSeconds,
        'distance': _tracker.distanceMeters,
        'calories': _activeCalories,
        if (_activeDistance > 0.01)
          'avgPace': (_elapsedSeconds / 60) / _activeDistance,
        if (route.isNotEmpty) 'routeData': route,
        // Marks it as a clique workout, which keeps it out of the solo
        // recorder's history while it still counts towards stats and goals.
        'cliqueSessionId': ?widget.sessionId,
      });

      await ApiService.createPost(
        caption:
            "Just completed a $_selectedActivityType ($_selectedActivityName) workout with my Clique! $statsString",
        type: 'Activity',
        activityId: activity?['id'] as String?,
      );

      // The host closing the session ends it for everyone.
      if (widget.sessionId != null && _currentUserIsAdmin) {
        await ApiService.updateCliqueStatus(widget.sessionId!, 'COMPLETED');
      }
      AchievementService().sync();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _accent,
          content: Text(
            '$_selectedActivityName activity saved successfully!',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            e is ApiException
                ? e.message
                : 'Could not save this activity. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  String _formatElapsedTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getPaceString() {
    if (_activeDistance < 0.01) return "--'--\"";
    final double totalMinutes = (_elapsedSeconds / 60.0);
    final double minutesPerKm = totalMinutes / _activeDistance;
    // Per mile when that is what the athlete reads in; the tracker still
    // measures in kilometres.
    final double perUnit = Units.paceFrom(minutesPerKm);
    final int minPart = perUnit.toInt();
    final int secPart = ((perUnit - minPart) * 60).toInt();
    return "$minPart'${secPart.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ───────────────────────────────────────────────
            _buildTopHeader(),

            // ── Main Content Area: Live Leaderboard + Controls ─────────────
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        _isRecording ? 260 : 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Goal Completion Card
                          _buildGoalCompletionCard(),
                          const SizedBox(height: 20),

                          if (_isRecording) ...[
                            // Leaderboard Title & Filter Row
                            _buildLeaderboardHeader(),
                            const SizedBox(height: 16),

                            // Full Rankings List
                            _buildRankingsList(),
                          ] else ...[
                            // Lobby Controls rendered directly on screen
                            _buildLobbyMainContent(),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ── Active Recording Metrics Modal (Only when live) ────
                  if (_isRecording)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildActiveMetricsSheet(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Header Widget ───────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _selectedActivityName,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_selectedActivityIcon, color: _accent, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        _selectedActivityType.toUpperCase(),
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Live/Recording badge
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.redAccent : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isRecording
                                    ? Colors.redAccent
                                    : Colors.orange)
                                .withValues(
                              alpha: _pulseController.value * 0.8,
                            ),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isRecording ? 'LIVE' : 'LOBBY',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Goal Completion Card ──────────────────────────────────────────────────
  Widget _buildGoalCompletionCard() {
    double currentVal = _activeDistance;
    if (_goalType == 'Duration') {
      currentVal = _elapsedSeconds / 60.0;
    } else if (_goalType == 'Calories') {
      currentVal = _activeCalories.toDouble();
    }

    final double goalVal = _goalValue > 0 ? _goalValue : 5.0;
    final double progress = (currentVal / goalVal).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt();

    String currentStr = currentVal.toStringAsFixed(2);
    String targetStr = goalVal.toStringAsFixed(2);
    if (_goalType == 'Duration' ||
        _goalType == 'Calories' ||
        _goalType == 'Steps') {
      currentStr = currentVal.toInt().toString();
      targetStr = goalVal.toInt().toString();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _accent.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.08),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Goal Title & Target Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _goalType == 'Duration'
                              ? Icons.timer_rounded
                              : _goalType == 'Calories'
                                  ? Icons.local_fire_department_rounded
                                  : Icons.flag_rounded,
                          color: _accent,
                          size: 17,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$_goalType Goal'.toUpperCase(),
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accent.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'TARGET: $targetStr $_goalUnit',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Row 2: Progress Numbers & Percentage
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$currentStr ',
                          style: GoogleFonts.anybody(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: '/ $targetStr $_goalUnit',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: GoogleFonts.anybody(
                      color: progress >= 1.0 ? Colors.greenAccent : _accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Row 3: Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 10,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        color: const Color(0xFF2A2A2D),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFFF5722),
                                Color(0xFFFF8A65),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Row 4: Status text
              Text(
                progress >= 1.0
                    ? '0 $_goalUnit remaining'
                    : '${((1.0 - progress) * goalVal).toStringAsFixed(1)} $_goalUnit remaining',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Leaderboard Header & Metric Filters ─────────────────────────────────
  Widget _buildLeaderboardHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clique Leaderboard',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        // Filter pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip('DISTANCE', Icons.straighten_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('CALORIES', Icons.local_fire_department_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final bool isSelected = _selectedMetricFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedMetricFilter = label;
          _sortSquadMembers();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? _accent
              : const Color(0xFF1E1E22).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _accent
                : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white54,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Full Rankings List ───────────────────────────────────────────────────
  Widget _buildRankingsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ALL PARTICIPANTS',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        if (_isSquadLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: LoadingStateView(),
          )
        else if (_squadMembers.isEmpty)
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            icon: Icons.groups_rounded,
            title: 'No one has joined yet',
            message:
                'Invite friends to this session and their live stats will appear here.',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _squadMembers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = _squadMembers[index];
              return _buildRankTile(member, index + 1);
            },
          ),
      ],
    );
  }

  Widget _buildRankTile(Map<String, dynamic> member, int rank) {
    final bool isYou = member['isYou'] as bool? ?? false;
    final String name = member['name'] as String;
    final double dist = (member['distance'] as num).toDouble();
    final int calories = member['calories'] as int? ?? 0;

    final String metricText = _selectedMetricFilter == 'CALORIES'
        ? '$calories kcal'
        : '${dist.toStringAsFixed(2)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isYou
            ? _accent.withValues(alpha: 0.12)
            : _cardBg.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isYou
              ? _accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.04),
          width: isYou ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Plain Grey Rank Number
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: GoogleFonts.anybody(
                color: Colors.white54,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          UserAvatar(
            url: member['avatar'] as String?,
            fallbackName: member['name'] as String?,
            radius: 19,
          ),
          const SizedBox(width: 12),

          // Details (Name + YOU badge)
          Expanded(
            child: Row(
              children: [
                Text(
                  name,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isYou) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'YOU',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Primary metric value (Distance or Calories)
          Text(
            metricText,
            style: GoogleFonts.anybody(
              color: isYou ? _accent : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Lobby Main Content (Rendered directly on screen) ────────────────────
  Widget _buildLobbyMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Squad Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.group_rounded, color: _accent, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Squad',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                // Live counts, kept in step by `clique:lobby_updated`.
                Text(
                  _invitedCount > 0
                      ? '($_readyCount/$_joinedCount ready · $_invitedCount invited)'
                      : '($_readyCount/$_joinedCount ready)',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (_currentUserIsAdmin)
              GestureDetector(
                onTap: _showInviteSheet,
                child: Row(
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      color: _accent,
                      size: 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Invite',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Squad list
        ..._squadMembers.map(
              (m) => SlidableSquadTile(
                key: ValueKey(m['id']),
                member: m,
                // Only the host can drop someone from the squad.
                canRemove: _currentUserIsAdmin && m['isYou'] != true,
                onRemove: () {
                  setState(() {
                    _squadMembers
                        .removeWhere((item) => item['id'] == m['id']);
                  });
                },
              ),
            ),

        const SizedBox(height: 24),

        // The host starts the activity; everyone else only sets readiness.
        if (_currentUserIsAdmin)
          if (_isUpcoming)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showScheduledOptionsModal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A2A2D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                      side: BorderSide(color: _accent.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule_rounded, color: _accent, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'SCHEDULED FOR $_scheduledTime',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // A scheduled session can still be started early by the host.
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isStarting ? null : _confirmAndStartActivity,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      _startButtonText,
                      style: GoogleFonts.hankenGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _confirmAndStartActivity,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _accent.withValues(alpha: 0.4),
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  _startButtonText,
                  style: GoogleFonts.hankenGrotesk(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            )
        else ...[
          Builder(
            builder: (context) {
              final me = _squadMembers.where((m) => m['isYou'] == true).toList();
              final bool isUserReady =
                  me.isNotEmpty && me.first['isReady'] == true;

              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed:
                          (!_hasJoined || _isTogglingReady) ? null : _toggleReady,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isUserReady ? Colors.redAccent : Colors.green,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2A2A2D),
                        disabledForegroundColor: Colors.white38,
                        elevation: 0,
                        shape: const StadiumBorder(),
                      ),
                      child: _isTogglingReady
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isUserReady
                                      ? Icons.cancel_outlined
                                      : Icons.check_circle_outline_rounded,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isUserReady ? 'CANCEL READY' : "I'M READY",
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Only the host can start, so say so rather than showing a
                  // button that would be rejected.
                  Text(
                    _isUpcoming
                        ? 'Waiting for the host to start the activity'
                        : 'The activity is live — join in when you are ready',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // ─── Active Recording Metrics Sheet ──────────────────────────────────────
  Widget _buildActiveMetricsSheet() {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 100) {
          HapticFeedback.lightImpact();
          setState(() {
            _isSheetMinimized = true;
          });
        } else if (details.primaryVelocity! < -100) {
          HapticFeedback.lightImpact();
          setState(() {
            _isSheetMinimized = false;
          });
        }
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: const Color(0xFF141417).withValues(alpha: 0.45),
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              _isSheetMinimized ? 2 : 12,
              20,
              MediaQuery.of(context).padding.bottom +
                  (_isSheetMinimized ? 4 : 16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Drag Handle Pill
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _isSheetMinimized = !_isSheetMinimized;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                        vertical: _isSheetMinimized ? 2 : 4),
                    color: Colors.transparent,
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: _isSheetMinimized ? 0 : 8),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 320),
                  firstCurve: Curves.easeInOut,
                  secondCurve: Curves.easeInOut,
                  sizeCurve: Curves.easeInOutCubic,
                  crossFadeState: _isSheetMinimized
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary Metrics Grid (Distance & Duration)
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'YOUR DISTANCE',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      Units.fromKm(_activeDistance)
                                          .toStringAsFixed(2),
                                      style: GoogleFonts.anybody(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      Units.distanceUnit,
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white38,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(width: 1, height: 48, color: Colors.white12),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  'DURATION',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatElapsedTime(_elapsedSeconds),
                                  style: GoogleFonts.anybody(
                                    color: Colors.white,
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Secondary Metrics Bento Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildBentoCard(
                              'AVG PACE',
                              _getPaceString(),
                              Units.paceUnit,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoCard(
                              'CALORIES',
                              '$_activeCalories',
                              'kcal',
                              hasAccentBorder: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoCard(
                              'AVG BPM',
                              _activeHeartRate > 0 ? '$_activeHeartRate' : '--',
                              'bpm',
                            ),
                          ),
                        ],
                      ),
                      if (_locationWarning != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_off_rounded,
                                color: _accent, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _locationWarning!,
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Main Action Control Button
                      if (!_isPaused)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _togglePause,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.pause_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'PAUSE',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _togglePause,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    'RESUME',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: SizedBox(
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _finishAndSaveActivity,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Text(
                                    'FINISH & SAVE',
                                    style: GoogleFonts.hankenGrotesk(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  secondChild: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'DISTANCE',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      Units.fromKm(_activeDistance)
                                          .toStringAsFixed(2),
                                      style: GoogleFonts.anybody(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      Units.distanceUnit,
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white38,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TIME',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  _formatElapsedTime(_elapsedSeconds),
                                  style: GoogleFonts.anybody(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: GestureDetector(
                            onTap: _togglePause,
                            child: Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accent.withValues(alpha: 0.35),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                _isPaused
                                    ? Icons.play_arrow_rounded
                                    : Icons.pause_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBentoCard(
    String label,
    String value,
    String unit, {
    bool hasAccentBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: hasAccentBorder
            ? const Border(
                bottom: BorderSide(color: Color(0xFFFF5722), width: 3),
              )
            : Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            unit,
            style: GoogleFonts.hankenGrotesk(
                color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ─── Interactive Helper Sheets ────────────────────────────────────────────
  void _showInviteSheet() {
    HapticFeedback.mediumImpact();
    final sessionId = widget.sessionId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        // Candidates are the athletes you follow who are not already in the
        // squad; invites are sent through the API.
        List<Map<String, dynamic>> candidates = [];
        final invitedIds = <String>{};
        bool inviteLoading = true;

        return StatefulBuilder(builder: (context, setSheetState) {
        if (inviteLoading) {
          final myId = SessionService().userId;
          if (myId == null) {
            inviteLoading = false;
          } else {
            ApiService.getFollowing(myId).then((following) {
              final existing =
                  _squadMembers.map((m) => '${m['id']}').toSet();
              candidates = following
                  .where((u) => !existing.contains('${u['id']}'))
                  .toList();
              inviteLoading = false;
              setSheetState(() {});
            }).catchError((_) {
              inviteLoading = false;
              setSheetState(() {});
            });
          }
        }

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2E).withValues(alpha: 0.60),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Invite to Squad',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (inviteLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: LoadingStateView(),
                    )
                  else if (candidates.isEmpty)
                    EmptyStateView(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      icon: Icons.person_add_alt_1_rounded,
                      title: 'No one to invite yet',
                      message:
                          'Follow athletes from the Trybes tab and you can pull them into your sessions.',
                    )
                  else
                    ...candidates.map((f) {
                      final userId = f['id'] as String?;
                      final name =
                          '${f['firstName'] ?? ''} ${f['lastName'] ?? ''}'.trim();
                      final display = name.isEmpty ? 'Athlete' : name;
                      final invited = invitedIds.contains(userId);

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          url: ApiService.media(f['avatarUrl'] as String?),
                          fallbackName: display,
                          radius: 20,
                        ),
                        title: Text(
                          display,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${f['location'] ?? 'Fitrybe athlete'}',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: (invited || userId == null || sessionId == null)
                              ? null
                              : () async {
                                  HapticFeedback.lightImpact();
                                  final ok = await ApiService.inviteToClique(
                                      sessionId, userId);
                                  if (ok) {
                                    invitedIds.add(userId);
                                    setSheetState(() {});
                                    _loadSession();
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            disabledBackgroundColor:
                                _accent.withValues(alpha: 0.3),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            invited ? 'Invited' : 'Invite',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
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
        });
      },
    );
  }

  void _showScheduledOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2E).withValues(alpha: 0.60),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.schedule_rounded,
                            color: _accent, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Scheduled Activity',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Scheduled for $_scheduledTime',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {
                          _isUpcoming = false;
                        });
                        _triggerStartActivity();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'START NOW EARLY',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        'KEEP SCHEDULED',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
}

// ─── Slidable Squad Participant Tile Widget ──────────────────────────────────
class SlidableSquadTile extends StatefulWidget {
  final Map<String, dynamic> member;
  final VoidCallback onRemove;
  /// Only the host may swipe a member out of the squad.
  final bool canRemove;
  const SlidableSquadTile({
    super.key,
    required this.member,
    required this.onRemove,
    this.canRemove = false,
  });

  @override
  State<SlidableSquadTile> createState() => _SlidableSquadTileState();
}

class _SlidableSquadTileState extends State<SlidableSquadTile> {
  double _dragOffset = 0.0;
  static const double _actionWidth = 84.0;

  @override
  Widget build(BuildContext context) {
    final bool isReady = widget.member['isReady'] as bool? ?? false;
    final bool isAdmin = widget.member['isAdmin'] as bool? ?? false;
    final bool hasJoined = widget.member['hasJoined'] as bool? ?? true;
    final String name = widget.member['name'] as String;
    // The host row and anyone the viewer cannot remove render as a plain tile.
    if (isAdmin || !widget.canRemove) {
      return _buildTileContent(
        name,
        isReady,
        isAdmin,
        hasJoined,
        margin: const EdgeInsets.only(bottom: 10),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onRemove();
                },
                child: Container(
                  width: _actionWidth,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(height: 2),
                      Text(
                        'Remove',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragOffset += details.delta.dx;
                if (_dragOffset < -_actionWidth) _dragOffset = -_actionWidth;
                if (_dragOffset > 0) _dragOffset = 0;
              });
            },
            onHorizontalDragEnd: (details) {
              setState(() {
                if (_dragOffset < -(_actionWidth / 2)) {
                  _dragOffset = -_actionWidth;
                } else {
                  _dragOffset = 0.0;
                }
              });
            },
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: _buildTileContent(
                name,
                isReady,
                isAdmin,
                hasJoined,
                margin: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTileContent(
    String name,
    bool isReady,
    bool isAdmin,
    bool hasJoined, {
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFF2A2A2D) : const Color(0xFF1F1F22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAdmin
              ? const Color(0xFFFF5722).withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              UserAvatar(
                url: widget.member['avatar'] as String?,
                fallbackName: widget.member['name'] as String?,
                radius: 21,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isAdmin) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFFF5722).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFFF5722)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            'ADMIN',
                            style: GoogleFonts.hankenGrotesk(
                              color: const Color(0xFFFF5722),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pace: ${widget.member['pace']}',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Builder(builder: (context) {
            final Color pillColor = !hasJoined
                ? Colors.white38
                : (isReady ? Colors.green : Colors.orange);
            return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: pillColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: pillColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              !hasJoined
                  ? 'INVITED'
                  : (isReady ? 'READY' : 'NOT READY'),
              style: GoogleFonts.hankenGrotesk(
                color: !hasJoined
                    ? Colors.white54
                    : (isReady ? Colors.greenAccent : Colors.orangeAccent),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
          }),
        ],
      ),
    );
  }
}
