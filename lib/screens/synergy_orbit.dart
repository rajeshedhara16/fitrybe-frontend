import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'user_profile_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/synergy.dart';
import '../services/units.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

enum _StatsStatus { loading, ready, hidden, failed }

class _MemberStats {
  const _MemberStats(this.status, [this.report]);
  final _StatsStatus status;
  final SynergyReport? report;
}

/// The athletes you follow, orbiting you, and how in step your training is.
///
/// The orbit drifts slowly on its own, can be spun with a finger, and swings a
/// tapped athlete round to the front before drawing a link to them. Their card
/// then compares the last 30 days of real training on both sides.
class SynergyOrbit extends StatefulWidget {
  const SynergyOrbit({super.key});

  @override
  State<SynergyOrbit> createState() => _SynergyOrbitState();
}

class _SynergyOrbitState extends State<SynergyOrbit>
    with TickerProviderStateMixin {
  static const Color _accent = Color(0xFFFF5722);
  static const Color _warm = Color(0xFFFF9800);
  static const Color _cardBg = Color(0xFF1E1E22);
  static const int _maxMembers = 8;

  /// Idle drift, in radians per second. Slow enough to read as alive rather
  /// than busy.
  static const double _idleSpin = 0.10;

  List<Map<String, dynamic>> _members = const [];
  bool _loadingMembers = true;
  String? _selectedId;

  /// The athlete the link is drawn to. Kept after closing so the link can
  /// retract instead of vanishing.
  String? _linkId;
  final Map<String, _MemberStats> _stats = {};
  Future<List<dynamic>>? _mine;

  final ValueNotifier<double> _rotation = ValueNotifier(math.pi / 2);
  late final Ticker _ticker;
  Duration? _lastTick;
  bool _dragging = false;
  double? _lastDragAngle;
  bool _reduceMotion = false;

  late final AnimationController _pulse;
  late final AnimationController _intro;
  late final AnimationController _focus;
  late final AnimationController _link;
  double _focusFrom = 0;
  double _focusDelta = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _focus = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addListener(() {
        _rotation.value = _focusFrom +
            _focusDelta * Curves.easeOutCubic.transform(_focus.value);
      });
    _link = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _ticker = createTicker(_onTick)..start();
    _loadMembers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _pulse.stop();
      _intro.value = 1;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _pulse.dispose();
    _intro.dispose();
    _focus.dispose();
    _link.dispose();
    _rotation.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  Future<void> _loadMembers() async {
    final userId = SessionService().userId;
    if (userId == null) {
      setState(() => _loadingMembers = false);
      return;
    }

    final following = await ApiService.getFollowing(userId);
    if (!mounted) return;

    setState(() {
      _members = following.take(_maxMembers).map((user) {
        final first = '${user['firstName'] ?? ''}'.trim();
        final full = '$first ${user['lastName'] ?? ''}'.trim();
        return <String, dynamic>{
          'id': '${user['id']}',
          'name': first.isEmpty ? 'Athlete' : first,
          'fullName': full.isEmpty ? 'Athlete' : full,
          'avatar': ApiService.media(user['avatarUrl'] as String?),
        };
      }).toList();
      _loadingMembers = false;
    });

    if (_members.isEmpty) return;
    if (_reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward(from: 0);
    }
  }

  /// Your own history, fetched once and shared by every comparison.
  Future<List<dynamic>> _myActivities() {
    return _mine ??= ApiService.getAnalytics().then((analytics) {
      if (!analytics.containsKey('summary')) {
        // A failed load must not be cached as "no workouts".
        _mine = null;
        throw StateError('Your analytics could not be loaded');
      }
      return (analytics['recentActivities'] as List?) ?? const [];
    });
  }

  Future<void> _loadStats(String id, {bool force = false}) async {
    final existing = _stats[id];
    if (!force &&
        existing != null &&
        existing.status != _StatsStatus.failed) {
      return;
    }
    setState(() => _stats[id] = const _MemberStats(_StatsStatus.loading));

    try {
      final results = await Future.wait<Object?>([
        _myActivities(),
        ApiService.getAnalytics(userId: id),
        ApiService.getUserProfile(id),
      ]);
      if (!mounted) return;

      final theirs = results[1] as Map<String, dynamic>;
      final profile = results[2] as Map<String, dynamic>;
      if (!theirs.containsKey('summary')) {
        throw StateError('Their analytics could not be loaded');
      }

      // Someone who hid their workouts would otherwise read as a flat 0%,
      // which says something untrue about them.
      final user = profile['user'];
      final hidden = user is Map && user['activitiesVisible'] == false;

      setState(() {
        _stats[id] = hidden
            ? const _MemberStats(_StatsStatus.hidden)
            : _MemberStats(
                _StatsStatus.ready,
                SynergyReport.compute(
                  mine: results[0] as List<dynamic>,
                  theirs: (theirs['recentActivities'] as List?) ?? const [],
                ),
              );
      });
    } catch (e) {
      debugPrint('Synergy stats failed for $id: $e');
      if (mounted) {
        setState(() => _stats[id] = const _MemberStats(_StatsStatus.failed));
      }
    }
  }

  // ── Motion ────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null ||
        _reduceMotion ||
        _selectedId != null ||
        _dragging ||
        _focus.isAnimating ||
        _members.isEmpty) {
      return;
    }
    _rotation.value += (elapsed - last).inMicroseconds / 1e6 * _idleSpin;
  }

  double _baseAngle(int index) => index / _members.length * 2 * math.pi;

  /// How far a member has flown out from the centre on first load, staggered
  /// so they fan out one after another.
  double _introFor(int index) {
    final start = index / math.max(_members.length, 1) * 0.45;
    return Interval(start, math.min(start + 0.55, 1.0), curve: Curves.easeOutBack)
        .transform(_intro.value);
  }

  void _select(int index) {
    final id = _members[index]['id'] as String;
    if (_selectedId == id) {
      _deselect();
      return;
    }
    HapticFeedback.selectionClick();

    // Swing the shortest way round to put them at the front, bottom centre.
    final target = math.pi / 2 - _baseAngle(index);
    var delta = (target - _rotation.value) % (2 * math.pi);
    if (delta > math.pi) delta -= 2 * math.pi;
    _focusFrom = _rotation.value;
    _focusDelta = delta;

    setState(() {
      _selectedId = id;
      _linkId = id;
    });

    if (_reduceMotion) {
      _rotation.value = _focusFrom + delta;
      _link.value = 1;
    } else {
      _focus.forward(from: 0);
      _link.forward(from: 0);
    }
    _loadStats(id);
  }

  void _deselect() {
    if (_selectedId == null) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedId = null);
    if (_reduceMotion) {
      _link.value = 0;
    } else {
      _link.reverse();
    }
  }

  void _onPanStart(DragStartDetails details, Offset center) {
    if (_selectedId != null) return;
    _focus.stop();
    _dragging = true;
    _lastDragAngle = (details.localPosition - center).direction;
  }

  void _onPanUpdate(DragUpdateDetails details, Offset center) {
    final previous = _lastDragAngle;
    if (!_dragging || previous == null) return;
    // Follows the finger round the centre, rather than just sideways.
    final angle = (details.localPosition - center).direction;
    var delta = angle - previous;
    if (delta > math.pi) delta -= 2 * math.pi;
    if (delta < -math.pi) delta += 2 * math.pi;
    _rotation.value += delta;
    _lastDragAngle = angle;
  }

  void _onPanEnd() {
    _dragging = false;
    _lastDragAngle = null;
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Synergy Orbit',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How often you train on the same days as the people you follow.',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white38,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 90),
              child: Center(
                child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
              ),
            )
          else if (_members.isEmpty)
            const EmptyStateView(
              padding: EdgeInsets.symmetric(vertical: 40),
              icon: Icons.hub_rounded,
              title: 'Your orbit is empty',
              message:
                  'Follow athletes from the Trybes tab and they will appear here, along with how often you train on the same days.',
            )
          else ...[
            _buildOrbit(),
            const SizedBox(height: 6),
            _buildHint(),
            const SizedBox(height: 20),
            _buildDetails(),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildHint() {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: Text(
          _selectedId == null
              ? 'Tap someone to compare  ·  drag to spin'
              : 'Tap anywhere in the orbit to close',
          key: ValueKey(_selectedId == null),
          style: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 11.5),
        ),
      ),
    );
  }

  Widget _buildOrbit() {
    return LayoutBuilder(builder: (context, constraints) {
      final size = math.min(constraints.maxWidth, 330.0);
      final radius = size * 0.36;
      final center = Offset(size / 2, size / 2);

      return Center(
        child: SizedBox(
          width: size,
          height: size,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _deselect,
            onPanStart: (d) => _onPanStart(d, center),
            onPanUpdate: (d) => _onPanUpdate(d, center),
            onPanEnd: (_) => _onPanEnd(),
            onPanCancel: _onPanEnd,
            child: AnimatedBuilder(
              animation: Listenable.merge([_rotation, _pulse, _intro, _link]),
              builder: (context, _) {
                final positions = [
                  for (var i = 0; i < _members.length; i++)
                    _positionFor(i, center, radius),
                ];
                final linkIndex =
                    _members.indexWhere((m) => m['id'] == _linkId);
                final selectedIndex =
                    _members.indexWhere((m) => m['id'] == _selectedId);

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _OrbitBackdropPainter(
                          pulse: _pulse.value,
                          radius: radius,
                          accent: _accent,
                          warm: _warm,
                          calm: _reduceMotion,
                        ),
                      ),
                    ),
                    if (linkIndex != -1 && _link.value > 0)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _LinkPainter(
                            start: center,
                            end: positions[linkIndex],
                            progress: Curves.easeOutCubic.transform(_link.value),
                            spark: _pulse.value,
                            color: _accent,
                            calm: _reduceMotion,
                          ),
                        ),
                      ),
                    _centerAvatar(center),
                    for (final i in _paintOrder())
                      _member(i, positions[i], selectedIndex),
                  ],
                );
              },
            ),
          ),
        ),
      );
    });
  }

  Offset _positionFor(int index, Offset center, double radius) {
    final angle = _baseAngle(index) + _rotation.value;
    final r = radius * _introFor(index);
    return center + Offset(math.cos(angle) * r, math.sin(angle) * r);
  }

  /// Back of the orbit first, front last, and the selected athlete on top.
  List<int> _paintOrder() {
    double depth(int i) => math.sin(_baseAngle(i) + _rotation.value);
    final order = [for (var i = 0; i < _members.length; i++) i];
    order.sort((a, b) {
      if (_members[a]['id'] == _selectedId) return 1;
      if (_members[b]['id'] == _selectedId) return -1;
      return depth(a).compareTo(depth(b));
    });
    return order;
  }

  Widget _centerAvatar(Offset center) {
    final breathe = _reduceMotion
        ? 0.5
        : (math.sin(_pulse.value * 2 * math.pi) + 1) / 2;
    const size = 70.0;

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_accent, _warm],
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withValues(alpha: 0.22 + 0.2 * breathe),
              blurRadius: 16 + 12 * breathe,
              spreadRadius: 1 + 2 * breathe,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black,
          ),
          child: UserAvatar(
            url: SessionService().avatarUrl,
            fallbackName: SessionService().displayName,
            radius: 30,
          ),
        ),
      ),
    );
  }

  Widget _member(int index, Offset position, int selectedIndex) {
    final member = _members[index];
    final id = member['id'] as String;
    final angle = _baseAngle(index) + _rotation.value;
    // 0 at the back of the orbit, 1 at the front.
    final depth = (math.sin(angle) + 1) / 2;
    final isSelected = index == selectedIndex;
    final dimmed = selectedIndex != -1 && !isSelected;
    final intro = _introFor(index).clamp(0.0, 1.0);
    final bob = _reduceMotion
        ? 0.0
        : math.sin(_pulse.value * 2 * math.pi + _baseAngle(index)) * 3;
    const size = 46.0;

    return Positioned(
      key: ValueKey('orbit-$id'),
      left: position.dx - size / 2,
      top: position.dy - size / 2 + bob,
      child: Opacity(
        opacity: ((0.6 + 0.4 * depth) * intro).clamp(0.0, 1.0),
        child: Transform.scale(
          scale: (0.84 + 0.16 * depth) * intro,
          child: AnimatedOpacity(
            opacity: dimmed ? 0.35 : 1,
            duration: const Duration(milliseconds: 300),
            child: AnimatedScale(
              scale: isSelected ? 1.28 : 1,
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              child: GestureDetector(
                onTap: () => _select(index),
                child: _avatarRing(member, isSelected),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarRing(Map<String, dynamic> member, bool selected) {
    final score = _stats[member['id']]?.report?.score;

    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: selected
                  ? const SweepGradient(colors: [_accent, _warm, _accent])
                  : LinearGradient(colors: [
                      Colors.white.withValues(alpha: 0.14),
                      Colors.white.withValues(alpha: 0.14),
                    ]),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : const [],
            ),
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
              child: UserAvatar(
                url: member['avatar'] as String?,
                fallbackName: member['name'] as String?,
                radius: 19.5,
              ),
            ),
          ),
          if (score != null)
            Positioned(
              right: -8,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Text(
                  '$score%',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Details card ──────────────────────────────────────────────────────────

  Widget _buildDetails() {
    final id = _selectedId;
    final member = id == null
        ? null
        : _members.firstWhere(
            (m) => m['id'] == id,
            orElse: () => const <String, dynamic>{},
          );
    final status = id == null
        ? null
        : (_stats[id]?.status ?? _StatsStatus.loading);

    final Widget child;
    if (member == null || member.isEmpty || status == null) {
      child = const SizedBox(key: ValueKey('none'), width: double.infinity);
    } else {
      final key = ValueKey('$id-${status.name}');
      child = switch (status) {
        _StatsStatus.loading => _loadingCard(key, member),
        _StatsStatus.hidden => _hiddenCard(key, member),
        _StatsStatus.failed => _failedCard(key, member),
        _StatsStatus.ready => _readyCard(key, member, _stats[id]!.report!),
      };
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                .animate(animation),
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _card({required Key key, required List<Widget> children}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent.withValues(alpha: 0.12), _cardBg, _cardBg],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _header(Map<String, dynamic> member, {String? tag}) {
    return Row(
      children: [
        UserAvatar(
          url: member['avatar'] as String?,
          fallbackName: member['name'] as String?,
          radius: 22,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${member['fullName']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anybody(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (tag != null) ...[
                const SizedBox(height: 2),
                Text(
                  tag.toUpperCase(),
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: _deselect,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
        ),
      ],
    );
  }

  Widget _loadingCard(Key key, Map<String, dynamic> member) {
    Widget bar(double width, double height, [double radius = 8]) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          final shimmer = _reduceMotion
              ? 0.5
              : (math.sin(_pulse.value * 2 * math.pi) + 1) / 2;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04 + 0.05 * shimmer),
              borderRadius: BorderRadius.circular(radius),
            ),
          );
        },
      );
    }

    return _card(
      key: key,
      children: [
        _header(member, tag: 'Comparing your training…'),
        const SizedBox(height: 18),
        Row(
          children: [
            bar(92, 92, 46),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bar(double.infinity, 12),
                  const SizedBox(height: 8),
                  bar(double.infinity, 12),
                  const SizedBox(height: 8),
                  bar(120, 12),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(child: bar(double.infinity, 58, 16)),
            const SizedBox(width: 8),
            Expanded(child: bar(double.infinity, 58, 16)),
            const SizedBox(width: 8),
            Expanded(child: bar(double.infinity, 58, 16)),
          ],
        ),
      ],
    );
  }

  Widget _hiddenCard(Key key, Map<String, dynamic> member) {
    return _card(
      key: key,
      children: [
        _header(member, tag: 'Private'),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: const Icon(Icons.lock_rounded, color: Colors.white54, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '${member['name']} keeps their workouts private, so there is nothing to compare.',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _profileButton(member),
      ],
    );
  }

  Widget _failedCard(Key key, Map<String, dynamic> member) {
    return _card(
      key: key,
      children: [
        _header(member),
        const SizedBox(height: 14),
        Text(
          'Could not load training to compare. Check your connection and try again.',
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton.icon(
            onPressed: () => _loadStats(member['id'] as String, force: true),
            style: OutlinedButton.styleFrom(
              foregroundColor: _accent,
              side: BorderSide(color: _accent.withValues(alpha: 0.6)),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              'Try again',
              style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _readyCard(Key key, Map<String, dynamic> member, SynergyReport r) {
    return _card(
      key: key,
      children: [
        _header(member, tag: r.tierLabel),
        const SizedBox(height: 18),
        Row(
          children: [
            _SyncRing(score: r.score, accent: _accent, warm: _warm),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                r.summary,
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _statBox(
                'Workouts',
                r.theirWorkouts.toDouble(),
                (v) => '${v.round()}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statBox(
                'Distance',
                r.theirDistanceKm,
                (v) => Units.distanceKm(v, decimals: 1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statBox(
                'Streak',
                r.theirStreak.toDouble(),
                (v) => '${v.round()}d',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          "${member['name']}'s last 30 days",
          style: GoogleFonts.hankenGrotesk(color: Colors.white24, fontSize: 10.5),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text(
              'LAST 14 DAYS',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const Spacer(),
            _legend(),
          ],
        ),
        const SizedBox(height: 12),
        _timeline(r),
        if (r.theirFavourite != null) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded,
                    color: _accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Their go-to lately: ${r.theirFavourite}',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _profileButton(member),
      ],
    );
  }

  Widget _statBox(String label, double value, String Function(double) format) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                format(v),
                maxLines: 1,
                style: GoogleFonts.anybody(
                  color: _accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 10),
            ),
          ],
        );
    Widget dot(Color color) => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        item(dot(_accent), 'You'),
        const SizedBox(width: 10),
        item(dot(Colors.white70), 'Them'),
        const SizedBox(width: 10),
        item(
          Container(
            width: 8,
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_accent, _warm],
              ),
            ),
          ),
          'Both',
        ),
      ],
    );
  }

  Widget _timeline(SynergyReport r) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final count = r.timeline.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < count; i++)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 950),
            // Pops in left to right, today last.
            curve: Interval(i / count * 0.6, math.min(i / count * 0.6 + 0.4, 1),
                curve: Curves.easeOutBack),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
            ),
            child: _timelineDay(
              r.timeline[i],
              letters[r.timelineDates[i].weekday - 1],
              isToday: i == count - 1,
            ),
          ),
      ],
    );
  }

  Widget _timelineDay(DayOverlap overlap, String letter, {required bool isToday}) {
    final both = overlap == DayOverlap.both;
    final you = both || overlap == DayOverlap.you;
    final them = both || overlap == DayOverlap.them;

    Widget dot(bool on, Color color) => Container(
          width: 11,
          height: 11,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? color : Colors.white.withValues(alpha: 0.07),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: both
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_accent, _warm],
                  )
                : null,
            boxShadow: both
                ? [BoxShadow(color: _accent.withValues(alpha: 0.4), blurRadius: 8)]
                : null,
          ),
          child: Column(
            children: [
              dot(you, both ? Colors.white : _accent),
              const SizedBox(height: 4),
              dot(them, both ? Colors.white : Colors.white70),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          letter,
          style: GoogleFonts.hankenGrotesk(
            color: isToday ? Colors.white : Colors.white24,
            fontSize: 9.5,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _profileButton(Map<String, dynamic> member) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          UserProfileScreen.navigate(context, member['id'] as String?);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        icon: const Icon(Icons.person_rounded, size: 18),
        label: Text(
          "View ${member['name']}'s profile",
          style: GoogleFonts.hankenGrotesk(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// The big synergy ring, which fills and counts up to the score.
class _SyncRing extends StatelessWidget {
  const _SyncRing({
    required this.score,
    required this.accent,
    required this.warm,
  });

  final int score;
  final Color accent;
  final Color warm;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score / 100),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: 92,
        height: 92,
        child: CustomPaint(
          painter: _RingPainter(progress: v, accent: accent, warm: warm),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(v * 100).round()}%',
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'SYNC',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.accent, required this.warm});

  final double progress;
  final Color accent;
  final Color warm;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.07),
    );
    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [warm, accent, warm],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );

    final tipAngle = -math.pi / 2 + sweep;
    canvas.drawCircle(
      center + Offset(math.cos(tipAngle) * radius, math.sin(tipAngle) * radius),
      5,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent || old.warm != warm;
}

/// Glow, ripples spreading from you, and the dashed orbit track.
class _OrbitBackdropPainter extends CustomPainter {
  _OrbitBackdropPainter({
    required this.pulse,
    required this.radius,
    required this.accent,
    required this.warm,
    required this.calm,
  });

  final double pulse;
  final double radius;
  final Color accent;
  final Color warm;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final glowRadius = radius * 1.35;

    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            accent.withValues(alpha: 0.16),
            warm.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );

    if (!calm) {
      for (var i = 0; i < 3; i++) {
        final t = (pulse + i / 3) % 1.0;
        final r = 38 + (radius + 26 - 38) * Curves.easeOut.transform(t);
        canvas.drawCircle(
          center,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = accent.withValues(alpha: 0.22 * (1 - t)),
        );
      }
    }

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10);
    const dashes = 64;
    final trackRect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        trackRect,
        i / dashes * 2 * math.pi,
        math.pi / dashes,
        false,
        track,
      );
    }

    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.04),
    );
  }

  @override
  bool shouldRepaint(_OrbitBackdropPainter old) =>
      old.pulse != pulse || old.radius != radius || old.calm != calm;
}

/// The link from you to the chosen athlete: draws out, then a spark travels it.
class _LinkPainter extends CustomPainter {
  _LinkPainter({
    required this.start,
    required this.end,
    required this.progress,
    required this.spark,
    required this.color,
    required this.calm,
  });

  final Offset start;
  final Offset end;
  final double progress;
  final double spark;
  final Color color;
  final bool calm;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final tip = Offset.lerp(start, end, progress)!;

    canvas.drawLine(
      start,
      tip,
      Paint()
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          start,
          end,
          [color.withValues(alpha: 0.05), color],
        ),
    );

    if (!calm && progress >= 0.999) {
      final s = Offset.lerp(start, end, Curves.easeInOut.transform(spark))!;
      canvas.drawCircle(
        s,
        5,
        Paint()
          ..color = color.withValues(alpha: 0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(s, 2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) =>
      old.start != start ||
      old.end != end ||
      old.progress != progress ||
      old.spark != spark ||
      old.calm != calm;
}
