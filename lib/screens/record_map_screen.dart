import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'subscription_screen.dart';
import '../services/api_service.dart';
import '../services/achievement_service.dart';

class RecordMapScreen extends StatefulWidget {
  static const routeName = '/RecordMapScreen';
  const RecordMapScreen({super.key});

  @override
  State<RecordMapScreen> createState() => _RecordMapScreenState();
}

class _RecordMapScreenState extends State<RecordMapScreen>
    with TickerProviderStateMixin {
  // ── Colors ──────────────────────────────────────────────────────────────────
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF0F0F12);
  final Color _surfaceHigh = const Color(0xFF242429);

  // ── Subscription Gating ─────────────────────────────────────────────────────
  bool _isSubscribed = true; // Toggleable for testing free vs premium map

  // ── Bottom Sheet Minimized State ────────────────────────────────────────────
  bool _isSheetMinimized = false;

  // ── Activity selection ───────────────────────────────────────────────────────
  final String _selectedActivityName = 'Walking';
  final IconData _selectedActivityIcon = Icons.directions_walk_rounded;

  // ── Tracking state ──────────────────────────────────────────────────────────
  bool _isRecording = false;
  bool _isPaused = false;

  // ── Stopwatch ────────────────────────────────────────────────────────────────
  Timer? _stopwatchTimer;
  int _elapsedSeconds = 0;

  // ── Live metrics ─────────────────────────────────────────────────────────────
  double _activeDistance = 0.0;
  int _activeCalories = 0;
  int _activeHeartRate = 0;

  // ── Real GPS & Route tracking ──────────────────────────────────────────────
  final MapController _mapController = MapController();
  final List<LatLng> _routeLatLngs = [];
  StreamSubscription<Position>? _positionStreamSub;
  LatLng? _realUserLatLng;

  // ── Activity Log ─────────────────────────────────────────────────────────────
  final List<_ActivityLog> _activityLogs = [];

  // ── Animation ────────────────────────────────────────────────────────────────
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _initRealGpsLocation();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _pulseController.dispose();
    _stopwatchTimer?.cancel();
    super.dispose();
  }

  Future<void> _initRealGpsLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      final LatLng latLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _realUserLatLng = latLng;
        if (_routeLatLngs.isEmpty) {
          _routeLatLngs.add(latLng);
        } else {
          _routeLatLngs[0] = latLng;
        }
      });
      _mapController.move(latLng, 16.5);
    } catch (e) {
      debugPrint('Real GPS fetch error: $e');
    }
  }

  void _startRealGpsStream() {
    _positionStreamSub?.cancel();
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position pos) {
      if (!mounted || !_isRecording || _isPaused) return;
      final LatLng newLoc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _realUserLatLng = newLoc;
        if (_routeLatLngs.isNotEmpty) {
          final double distMeters = Geolocator.distanceBetween(
            _routeLatLngs.last.latitude,
            _routeLatLngs.last.longitude,
            newLoc.latitude,
            newLoc.longitude,
          );
          if (distMeters > 0.5) {
            _activeDistance += (distMeters / 1000.0);
            _routeLatLngs.add(newLoc);
          }
        } else {
          _routeLatLngs.add(newLoc);
        }
      });
      _mapController.move(newLoc, 16.5);
    });
  }

  // ── Timer helpers ────────────────────────────────────────────────────────────
  void _startTimer() {
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isPaused) return;
      setState(() {
        _elapsedSeconds++;
        // Simulate GPS distance ~0.003 km/s ≈ 10.8 km/h
        _activeDistance += 0.003;
        _activeCalories = (_elapsedSeconds * 0.165).round();
        _activeHeartRate = 130 + (_elapsedSeconds % 15);

        // Append real GPS coordinate
        final LatLng lastPos = _routeLatLngs.isEmpty
            ? const LatLng(28.6139, 77.2090)
            : _routeLatLngs.last;
        final double nextLat = lastPos.latitude +
            0.00004 +
            (math.sin(_elapsedSeconds * 0.1) * 0.00002);
        final double nextLng = lastPos.longitude +
            0.00005 +
            (math.cos(_elapsedSeconds * 0.12) * 0.00002);
        _routeLatLngs.add(LatLng(nextLat, nextLng));
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
      _activeHeartRate = 135;
      _routeLatLngs.clear();
      if (_realUserLatLng != null) {
        _routeLatLngs.add(_realUserLatLng!);
      } else {
        _routeLatLngs.add(const LatLng(28.6139, 77.2090));
      }
    });
    _startTimer();
    _startRealGpsStream();
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
    _positionStreamSub?.cancel();
    _positionStreamSub = null;

    final shouldSave = _isRecording && _elapsedSeconds >= 3;
    final durationSeconds = _elapsedSeconds;
    final distanceKm = _activeDistance;
    final calories = _activeCalories;
    // Snapshot the traced route before the map is reset.
    final route = _routeLatLngs
        .map((p) => {'lat': p.latitude, 'lng': p.longitude})
        .toList();

    if (shouldSave) {
      _activityLogs.insert(
        0,
        _ActivityLog(
          activityName: _selectedActivityName,
          activityIcon: _selectedActivityIcon,
          duration: durationSeconds,
          distanceKm: distanceKm,
          calories: calories,
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
      _routeLatLngs.clear();
      if (_realUserLatLng != null) {
        _routeLatLngs.add(_realUserLatLng!);
      }
    });

    if (shouldSave) {
      _persistActivity(
        durationSeconds: durationSeconds,
        distanceKm: distanceKm,
        calories: calories,
        route: route,
      );
    }
  }

  /// Saves the GPS workout, including its traced route, to the backend.
  Future<void> _persistActivity({
    required int durationSeconds,
    required double distanceKm,
    required int calories,
    required List<Map<String, double>> route,
  }) async {
    try {
      await ApiService.logActivity({
        'title': _selectedActivityName,
        'type': _selectedActivityName,
        'duration': durationSeconds,
        'distance': distanceKm * 1000,
        'calories': calories,
        if (distanceKm > 0) 'avgPace': (durationSeconds / 60) / distanceKm,
        if (route.isNotEmpty) 'routeData': route,
      });
      AchievementService().sync();
    } catch (e) {
      debugPrint('Save GPS activity error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1F1F22),
          content: Text(
            e is ApiException
                ? e.message
                : 'Workout could not sync. Check your connection.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
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
                Expanded(
                  child: _activityLogs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.history_rounded,
                                color: Colors.white24,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No logged activities yet',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white54,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Recorded sessions will appear here automatically.',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white30,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _activityLogs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) =>
                              _buildLogTile(_activityLogs[i]),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogTile(_ActivityLog log) {
    final durationStr = _formatTime(log.duration);
    final dateStr = _formatLogDate(log.timestamp);
    final timeStr =
        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E22).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
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
                          fontSize: 15,
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
          Row(
            children: [
              _logChip(Icons.map_outlined,
                  '${log.distanceKm.toStringAsFixed(2)} KM'),
              const SizedBox(width: 10),
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
      '',
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
    return '${months[dt.month]} ${dt.day}';
  }

  // ── Build Interactive Real GPS Map (For Subscribed Users) ─────────────────
  Widget _buildInteractiveMap() {
    final LatLng currentPos = _routeLatLngs.isNotEmpty
        ? _routeLatLngs.last
        : const LatLng(28.6139, 77.2090);

    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: currentPos,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // Real Dark CartoDB Street Map Tile Layer
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.fitrybe.fitrybe',
              ),
              // Live Route Polyline Trace
              if (_routeLatLngs.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routeLatLngs,
                      color: const Color(0xFFFF5722),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
              // Start & Current Live Position Markers
              MarkerLayer(
                markers: [
                  if (_routeLatLngs.length > 1)
                    Marker(
                      point: _routeLatLngs.first,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.greenAccent.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Marker(
                    point: currentPos,
                    width: 44,
                    height: 44,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 44 * _pulseController.value,
                            height: 44 * _pulseController.value,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722).withValues(
                                alpha: 0.4 * (1.0 - _pulseController.value),
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5722),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Map Floating Controls & GPS Badge (Top Right)
        Positioned(
          top: MediaQuery.of(context).padding.top + 70,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Re-center Location Button
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _initRealGpsLocation();
                  _mapController.move(currentPos, 16.5);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '📍 Map re-centered on live location',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white),
                      ),
                      duration: const Duration(seconds: 1),
                      backgroundColor: const Color(0xFF2A2A2E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2E).withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Build Locked Map Placeholder (For Non-Subscribed Users) ────────────────
  Widget _buildNonSubscribedMapPlaceholder() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Real Dark Street Map Tile Layer (Non-functional/Non-interactive)
        FlutterMap(
          options: MapOptions(
            initialCenter: _realUserLatLng ?? const LatLng(28.6139, 77.2090),
            initialZoom: 15.0,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.none),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.fitrybe.fitrybe',
            ),
          ],
        ),

        // Translucent Glassmorphic Lock Upgrade Card
        Align(
          alignment: const Alignment(0.0, -0.32),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2E).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 35,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          color: _accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'TRYBE PREMIUM',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Unlock GPS Route Mapping',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Interactive map trace, elevation profiles and live GPS route tracking are available exclusively for Subscribed members.',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white60,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () async {
                            HapticFeedback.heavyImpact();
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SubscriptionScreen(),
                              ),
                            );
                            if (result == true) {
                              setState(() {
                                _isSubscribed = true;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'UNLOCK MAPS WITH PREMIUM',
                            style: GoogleFonts.hankenGrotesk(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Build Glassmorphic Active Metrics Bottom Sheet ──────────────────────────
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
          filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            decoration: BoxDecoration(
              color: const Color(0xFF141417).withValues(alpha: 0.55),
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
                  blurRadius: 35,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom +
                  (_isSheetMinimized ? 12 : 20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                AnimatedCrossFade(
                  crossFadeState: _isSheetMinimized
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                  firstChild: Column(
                    children: [
                      // Hero Metric Displays: Distance & Duration
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DISTANCE',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _isRecording
                                          ? _activeDistance.toStringAsFixed(2)
                                          : '0.00',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white,
                                        fontSize: 44,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'KM',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white38,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DURATION',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(_elapsedSeconds),
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 40,
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
                              _isRecording ? _getPace() : "-'--\"",
                              '/km',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoCard(
                              'CALORIES',
                              _isRecording ? '$_activeCalories' : '0',
                              'kcal',
                              hasAccentBorder: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildBentoCard(
                              'AVG BPM',
                              _isRecording ? '$_activeHeartRate' : '--',
                              'bpm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Main Control Buttons
                      if (!_isRecording)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _onStartPressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.play_arrow_rounded,
                                    color: Colors.white, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'START ACTIVITY',
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
                      else if (!_isPaused)
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _onPausePressed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: const StadiumBorder(),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.pause_rounded,
                                    color: Colors.white, size: 22),
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
                                  onPressed: _onResumePressed,
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
                                  onPressed: _onStopPressed,
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      _isRecording
                                          ? _activeDistance.toStringAsFixed(2)
                                          : '0.00',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'km',
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
                                  _formatTime(_elapsedSeconds),
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white,
                                    fontSize: 24,
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
                            onTap: () {
                              if (_isRecording) {
                                if (_isPaused) {
                                  _onResumePressed();
                                } else {
                                  _onPausePressed();
                                }
                              } else {
                                _onStartPressed();
                              }
                            },
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
                                _isRecording
                                    ? (_isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded)
                                    : Icons.play_arrow_rounded,
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
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Header Widget ──────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Icon(_selectedActivityIcon, color: _accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _selectedActivityName.toUpperCase(),
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              // Log button
              GestureDetector(
                onTap: _showLogsSheet,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(
                      Symbols.format_list_bulleted_rounded,
                      color: Colors.white,
                      size: 22,
                      weight: 800,
                      grade: 200,
                    ),
                    if (_activityLogs.isNotEmpty)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${_activityLogs.length}',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontSize: 8,
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Background: Real Dark Interactive Map (Subscribed) or Locked Upgrade Card (Free)
          Positioned.fill(
            child: _isSubscribed
                ? _buildInteractiveMap()
                : _buildNonSubscribedMapPlaceholder(),
          ),

          // Floating Top Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: _buildTopHeader(),
          ),

          // Bottom Sheet: Glassmorphic Active Recording Metrics
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildActiveMetricsSheet(),
          ),
        ],
      ),
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
