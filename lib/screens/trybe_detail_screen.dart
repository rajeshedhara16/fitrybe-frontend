import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_detail_screen.dart';
import 'create_post_screen.dart';
import 'edit_trybe_screen.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';

import '../services/api_service.dart';
import '../services/session_service.dart';
import '../services/units.dart';
import '../services/when_format.dart';
import '../widgets/post_options_sheet.dart';
import '../widgets/state_views.dart';
import '../widgets/trybe_event_sheet.dart';
import '../widgets/trybe_invite_sheet.dart';
import '../widgets/user_avatar.dart';

/// The span a leaderboard covers.
enum _Period { week, month, allTime }

class TrybeDetailScreen extends StatefulWidget {
  /// Server id for the Trybe. The screen still renders from the passed-in
  /// summary while the full record loads.
  final String? trybeId;
  final String title;
  final String? imageUrl;
  final String memberCount;
  final String category;
  final String location;
  final bool isJoined;

  /// 0 Feed, 1 Leaderboard, 2 Events, 3 Members. An event notification opens
  /// straight onto Events.
  final int initialTab;

  const TrybeDetailScreen({
    super.key,
    this.trybeId,
    required this.title,
    this.imageUrl,
    this.memberCount = '',
    this.category = '',
    this.location = '',
    this.isJoined = false,
    this.initialTab = 0,
  });

  @override
  State<TrybeDetailScreen> createState() => _TrybeDetailScreenState();
}

class _TrybeDetailScreenState extends State<TrybeDetailScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF0F0F12);
  final Color _cardBg = const Color(0xFF1B1B1E);

  late bool _isJoined;
  late int _activeSubTab;

  Map<String, dynamic>? _trybe;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _error;
  bool _isTogglingJoin = false;

  // Leaderboard for the chosen period, and this week's total for the goal.
  _Period _period = _Period.week;
  List<Map<String, dynamic>> _leaderboard = [];
  double _leaderboardTotalKm = 0;
  double _weekTotalKm = 0;
  bool _leaderboardLoading = false;

  List<Map<String, dynamic>> _upcomingEvents = [];
  List<Map<String, dynamic>> _pastEvents = [];
  bool _eventsLoading = true;
  String? _eventsError;
  bool _showPastEvents = false;
  final Set<String> _rsvpBusy = {};

  // Local overlays on top of server state for optimistic likes.
  final Set<String> _likedPostIds = {};
  final Map<String, int> _likeOverrides = {};

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isJoined;
    _activeSubTab = widget.initialTab.clamp(0, 3);
    _load();
  }

  // ── Loading ────────────────────────────────────────────────────────────────

  static DateTime? _periodStart(_Period period) {
    final now = DateTime.now();
    return switch (period) {
      // Monday at midnight, local time.
      _Period.week => DateTime(now.year, now.month, now.day - (now.weekday - 1)),
      _Period.month => DateTime(now.year, now.month, 1),
      _Period.allTime => null,
    };
  }

  Future<void> _load() async {
    final id = widget.trybeId;
    if (id == null) {
      setState(() {
        _isLoading = false;
        _error = 'This Trybe is no longer available.';
      });
      return;
    }

    if (mounted) setState(() => _error = null);
    try {
      final results = await Future.wait<Object?>([
        ApiService.getTrybe(id),
        ApiService.getTrybePosts(id),
        ApiService.getTrybeMembers(id),
        ApiService.getTrybeLeaderboard(id, since: _periodStart(_Period.week)),
      ]);

      if (!mounted) return;
      final trybe = results[0] as Map<String, dynamic>?;
      if (trybe == null) {
        setState(() {
          _isLoading = false;
          _error = 'This Trybe is private or no longer exists.';
        });
        return;
      }
      final week = results[3] as Map<String, dynamic>;
      setState(() {
        _trybe = trybe;
        _posts = results[1] as List<Map<String, dynamic>>;
        _members = results[2] as List<Map<String, dynamic>>;
        _weekTotalKm = (week['totalDistanceKm'] as num?)?.toDouble() ?? 0;
        if (_period == _Period.week) {
          _leaderboard = List<Map<String, dynamic>>.from(week['leaderboard'] as List);
          _leaderboardTotalKm = _weekTotalKm;
        }
        _isJoined = trybe['isMember'] == true;
        _isLoading = false;
      });
      if (_period != _Period.week) _loadLeaderboard();
      _loadEvents();
    } catch (e) {
      debugPrint('TrybeDetail load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We could not load this Trybe.';
      });
    }
  }

  Future<void> _loadLeaderboard() async {
    final id = widget.trybeId;
    if (id == null) return;
    final period = _period;
    setState(() => _leaderboardLoading = true);
    final data = await ApiService.getTrybeLeaderboard(id, since: _periodStart(period));
    if (!mounted || period != _period) return;
    setState(() {
      _leaderboard = List<Map<String, dynamic>>.from(data['leaderboard'] as List);
      _leaderboardTotalKm = (data['totalDistanceKm'] as num?)?.toDouble() ?? 0;
      if (period == _Period.week) _weekTotalKm = _leaderboardTotalKm;
      _leaderboardLoading = false;
    });
  }

  Future<void> _loadEvents() async {
    final id = widget.trybeId;
    if (id == null) return;
    try {
      final results = await Future.wait([
        ApiService.getTrybeEvents(id),
        ApiService.getTrybeEvents(id, past: true),
      ]);
      if (!mounted) return;
      setState(() {
        _upcomingEvents = results[0];
        _pastEvents = results[1];
        _eventsError = null;
        _eventsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _eventsLoading = false;
        _eventsError = e is ApiException ? e.message : 'We could not load events.';
      });
    }
  }

  // ── Derived state ──────────────────────────────────────────────────────────

  String? get _myRole => _trybe?['myRole'] as String?;
  bool get _isCreator => _myRole == 'CREATOR';
  bool get _canManage => _trybe?['canManage'] == true;
  bool get _isMuted => _trybe?['notificationsMuted'] == true;

  String get _displayTitle => '${_trybe?['name'] ?? widget.title}';

  String? get _displayImage =>
      ApiService.media(_trybe?['imageUrl'] as String?) ?? widget.imageUrl;

  String get _displayCategory =>
      '${_trybe?['category'] ?? widget.category}'.trim();

  /// "42 members • San Francisco, CA • Public"
  String get _displaySubtitle {
    if (_trybe == null) {
      return [widget.memberCount, widget.location]
          .where((s) => s.trim().isNotEmpty)
          .join(' • ');
    }
    final count = (_trybe!['memberCount'] as num?)?.toInt() ?? 0;
    final parts = <String>[
      '$count ${count == 1 ? 'member' : 'members'}',
      if ('${_trybe!['location'] ?? ''}'.trim().isNotEmpty)
        '${_trybe!['location']}',
      _trybe!['isPublic'] == false ? 'Private' : 'Public',
    ];
    return parts.join(' • ');
  }

  static String _nameOf(Map<String, dynamic>? user) {
    if (user == null) return 'Fitrybe Athlete';
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return name.isEmpty ? 'Fitrybe Athlete' : name;
  }

  static String _relativeTime(dynamic isoString) {
    final parsed = DateTime.tryParse('${isoString ?? ''}');
    if (parsed == null) return 'Just now';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF26262A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(message, style: GoogleFonts.hankenGrotesk(color: Colors.white)),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          message,
          style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: GoogleFonts.hankenGrotesk(
                color: destructive ? Colors.redAccent : _accent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  // ── Membership and management ──────────────────────────────────────────────

  Future<void> _onJoinButton() async {
    if (_isCreator) {
      _openEdit();
      return;
    }
    if (_isJoined) {
      final leave = await _confirm(
        title: 'Leave $_displayTitle?',
        message: _trybe?['isPublic'] == false
            ? 'This Trybe is private, so you will need a new invite to come back.'
            : 'You can join again at any time.',
        confirmLabel: 'Leave',
        destructive: true,
      );
      if (!leave) return;
    }
    await _setJoined(!_isJoined);
  }

  Future<void> _setJoined(bool join) async {
    final id = widget.trybeId;
    if (id == null || _isTogglingJoin) return;

    HapticFeedback.heavyImpact();
    setState(() {
      _isJoined = join;
      _isTogglingJoin = true;
    });

    final ok = await ApiService.setTrybeMembership(id, join);
    if (!mounted) return;
    setState(() {
      _isTogglingJoin = false;
      if (!ok) _isJoined = !join;
    });
    if (!ok) {
      _snack(join
          ? (_trybe?['isPublic'] == false
              ? 'This Trybe is invite-only. Ask a member for an invite.'
              : 'Could not join this Trybe. Please try again.')
          : 'Could not leave this Trybe. Please try again.');
      return;
    }
    // A private Trybe is hidden from non-members, so there is nothing left to
    // show once you leave it.
    if (!join && _trybe?['isPublic'] == false) {
      Navigator.pop(context, true);
      return;
    }
    await _load();
  }

  Future<void> _openEdit() async {
    final trybe = _trybe;
    if (trybe == null) return;
    HapticFeedback.lightImpact();
    final updated = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => EditTrybeScreen(trybe: trybe)),
    );
    if (updated == null || !mounted) return;
    setState(() => _trybe = {...trybe, ...updated});
    _snack('Trybe updated.');
  }

  Future<void> _toggleMute() async {
    final id = widget.trybeId;
    final trybe = _trybe;
    if (id == null || trybe == null) return;
    final next = !_isMuted;
    setState(() => trybe['notificationsMuted'] = next);
    try {
      await ApiService.setTrybeMuted(id, next);
      if (!mounted) return;
      _snack(next
          ? 'Muted. You will not be notified about new events in $_displayTitle.'
          : 'Notifications for $_displayTitle are back on.');
    } catch (_) {
      if (!mounted) return;
      setState(() => trybe['notificationsMuted'] = !next);
      _snack('Could not change notifications. Try again.');
    }
  }

  Future<void> _deleteTrybe() async {
    final id = widget.trybeId;
    if (id == null) return;
    final sure = await _confirm(
      title: 'Delete $_displayTitle?',
      message:
          'Everyone loses access to this Trybe and its events. Members keep their own posts and workouts. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!sure || !mounted) return;
    try {
      await ApiService.deleteTrybe(id);
      if (!mounted) return;
      _snack('$_displayTitle was deleted.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Could not delete this Trybe. Try again.');
    }
  }

  void _shareTrybe() {
    HapticFeedback.lightImpact();
    final name = _displayTitle;
    final text = _trybe?['isPublic'] == false
        ? 'I\'m in "$name" on Fitrybe. It\'s invite-only, so send me your Fitrybe name and I\'ll invite you.'
        : 'Join me in "$name" on Fitrybe. Open the Trybes tab and search for "$name".';
    SharePlus.instance.share(ShareParams(text: text));
  }

  void _openInvites() {
    final id = widget.trybeId;
    if (id == null) return;
    TrybeInviteSheet.show(context, trybeId: id, trybeName: _displayTitle);
  }

  void _showTrybeOptionsMenu() {
    HapticFeedback.mediumImpact();
    final items = <(IconData, String, String?, bool, VoidCallback)>[
      if (_isJoined)
        (Icons.person_add_alt_1_rounded, 'Invite people', 'They get a notification with a Join button', false, _openInvites),
      if (_canManage)
        (Icons.edit_rounded, 'Edit Trybe', 'Photo, details, privacy and weekly goal', false, _openEdit),
      if (_isJoined)
        (
          _isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          _isMuted ? 'Unmute notifications' : 'Mute notifications',
          _isMuted ? 'Get notified about new events again' : 'No notifications about new events',
          false,
          _toggleMute,
        ),
      (Icons.share_rounded, 'Share Trybe', 'Tell friends how to find it', false, _shareTrybe),
      if (_isJoined && !_isCreator)
        (Icons.logout_rounded, 'Leave Trybe', null, true, _onJoinButton),
      if (_isCreator)
        (Icons.delete_outline_rounded, 'Delete Trybe', 'Removes it for every member', true, _deleteTrybe),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              for (final (icon, title, subtitle, destructive, action) in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: destructive
                          ? Colors.redAccent.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: destructive ? Colors.redAccent : Colors.white70, size: 20),
                  ),
                  title: Text(
                    title,
                    style: GoogleFonts.hankenGrotesk(
                      color: destructive ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: subtitle == null
                      ? null
                      : Text(subtitle, style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    action();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: _bg,
              leading: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Center(
                  child: Icon(
                    Symbols.arrow_back_rounded,
                    color: Colors.white,
                    size: 26,
                    weight: 800,
                  ),
                ),
              ),
              actions: [
                if (_isJoined)
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      // Open (or create) this Trybe's group conversation.
                      final conversationId = await ApiService.createConversation(
                        trybeId: widget.trybeId,
                      );
                      if (conversationId == null || !mounted || !context.mounted) {
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chatId: conversationId,
                            name: _displayTitle,
                            avatar: _displayImage,
                            isTrybe: true,
                            trybeId: widget.trybeId,
                          ),
                        ),
                      );
                    },
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: SvgPicture.string(
                          '''<svg xmlns="http://www.w3.org/2000/svg" width="120" height="88" viewBox="0 0 120 88">
                            <defs>
                              <mask id="cutout-trybe">
                                <rect width="120" height="88" fill="white" />
                                <rect x="36" y="24" width="48" height="12" rx="6" fill="black" />
                                <rect x="36" y="42" width="32" height="12" rx="6" fill="black" />
                              </mask>
                            </defs>
                            <g fill="currentColor" mask="url(#cutout-trybe)">
                              <ellipse cx="60" cy="40" rx="42" ry="33"/>
                              <path d="M24 56 L17 68 Q14 73 20 73 L60 73 Z"/>
                            </g>
                          </svg>''',
                          height: 22,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _trybe == null ? null : _showTrybeOptionsMenu,
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 6, right: 18),
                      child: Icon(
                        Symbols.more_horiz_rounded,
                        color: Colors.white,
                        size: 28,
                        weight: 800,
                      ),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_displayImage == null)
                      Container(color: _accent.withValues(alpha: 0.18))
                    else
                      Image.network(
                        _displayImage!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(color: _accent.withValues(alpha: 0.18)),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.6),
                            _bg,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_displayCategory.isNotEmpty)
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _accent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _displayCategory.toUpperCase(),
                                    style: GoogleFonts.hankenGrotesk(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                if (_myRole == 'CAPTAIN' || _isCreator) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _isCreator ? 'CREATOR' : 'CAPTAIN',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          const SizedBox(height: 8),
                          Text(
                            _displayTitle,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _displaySubtitle,
                            style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _trybe == null || _isTogglingJoin ? null : _onJoinButton,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isJoined ? const Color(0xFF2A2A2E) : _accent,
                                      disabledBackgroundColor: const Color(0xFF2A2A2E),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _isCreator
                                                ? Icons.tune_rounded
                                                : _isJoined
                                                    ? Icons.check_circle_rounded
                                                    : Icons.group_add_rounded,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isCreator
                                                ? 'MANAGE TRYBE'
                                                : _isJoined
                                                    ? 'JOINED'
                                                    : 'JOIN TRYBE',
                                            style: GoogleFonts.hankenGrotesk(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _isJoined ? _openInvites : _shareTrybe,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: Icon(
                                    _isJoined ? Icons.person_add_alt_1_rounded : Icons.share_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Container(
              color: _bg,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSubTabItem(0, 'Feed'),
                  _buildSubTabItem(1, 'Leaderboard'),
                  _buildSubTabItem(2, 'Events'),
                  _buildSubTabItem(3, 'Members'),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: _isLoading
                  ? const LoadingStateView()
                  : _error != null
                      ? ErrorStateView(message: _error!, onRetry: _load)
                      : IndexedStack(
                          index: _activeSubTab,
                          children: [
                            _buildFeedView(),
                            _buildLeaderboardView(),
                            _buildEventsView(),
                            _buildMembersView(),
                          ],
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget? _buildFab() {
    if (_isLoading || _error != null) return null;
    if (_activeSubTab == 0 && _isJoined) {
      return FloatingActionButton(
        onPressed: () async {
          HapticFeedback.lightImpact();
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostScreen(
                trybeId: widget.trybeId,
                trybeName: _displayTitle,
              ),
            ),
          );
          if (mounted) _load();
        },
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 6,
        child: const Icon(Symbols.add_rounded, size: 28, fill: 1.0, weight: 700, grade: 200, opticalSize: 24),
      );
    }
    return null;
  }

  Widget _buildSubTabItem(int index, String label) {
    final bool isActive = _activeSubTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeSubTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: isActive ? _accent : Colors.transparent, width: 2.5),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: isActive ? _accent : Colors.white60,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  // ── 1. FEED ────────────────────────────────────────────────────────────────

  Widget _buildFeedView() {
    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          _buildGoalCard(),
          const SizedBox(height: 24),
          if (_posts.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 24),
              icon: Icons.forum_rounded,
              title: 'No posts yet',
              message: _isJoined
                  ? 'Nothing has been shared in this Trybe. Post a workout to kick things off.'
                  : 'Members have not shared anything yet.',
            )
          else
            for (final post in _posts) ...[
              _buildPostCardFor(post),
              const SizedBox(height: 20),
            ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// The weekly goal as the Trybe set it, against every member's distance
  /// since Monday. With no goal set, managers are offered to set one and
  /// everyone else just sees the week's total.
  Widget _buildGoalCard() {
    final goalKm = (_trybe?['weeklyGoalKm'] as num?)?.toDouble();
    final doneKm = _weekTotalKm;
    final hasGoal = goalKm != null && goalKm > 0;

    final Widget body;
    if (!hasGoal) {
      body = Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardLabel('THIS WEEK'),
                const SizedBox(height: 6),
                Text(
                  doneKm == 0
                      ? 'No distance logged by members yet'
                      : '${Units.distanceKm(doneKm, decimals: 1)} logged by members',
                  style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          if (_canManage)
            TextButton(
              onPressed: _openEdit,
              style: TextButton.styleFrom(
                backgroundColor: _accent.withValues(alpha: 0.12),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: Text(
                'Set a goal',
                style: GoogleFonts.hankenGrotesk(color: _accent, fontWeight: FontWeight.bold, fontSize: 12.5),
              ),
            ),
        ],
      );
    } else {
      final progress = (doneKm / goalKm).clamp(0.0, 1.0);
      final remaining = goalKm - doneKm;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardLabel('WEEKLY TRYBE GOAL'),
              Text(
                '${Units.fromKm(doneKm).toStringAsFixed(1)} / ${Units.fromKm(goalKm).toStringAsFixed(0)} ${Units.distanceUnit}',
                style: GoogleFonts.hankenGrotesk(color: _accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation<Color>(_accent),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            remaining <= 0
                ? 'Goal reached this week. Everything else is a bonus.'
                : '${Units.distanceKm(remaining, decimals: 1)} to go • resets Monday',
            style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: body,
    );
  }

  Widget _cardLabel(String text) => Text(
        text,
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white54,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );

  /// Adapts an API post onto the feed-card layout.
  Widget _buildPostCardFor(Map<String, dynamic> post) {
    final postId = '${post['id'] ?? ''}';
    final author = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : <String, dynamic>{};
    final images = (post['imageUrls'] is List)
        ? List<dynamic>.from(post['imageUrls'])
        : const [];

    final liked = _likedPostIds.contains(postId) || post['likedByMe'] == true;
    final baseLikes = (post['likeCount'] as num?)?.toInt() ?? 0;
    final likes = _likeOverrides[postId] ?? baseLikes;
    final authorName = _nameOf(author);
    final isMine = author['id'] == SessionService().userId;

    return _buildFeedCard(
      post: post,
      authorId: author['id'] as String?,
      author: authorName,
      time: _relativeTime(post['createdAt']),
      avatarUrl: ApiService.media(author['avatarUrl'] as String?),
      caption: '${post['caption'] ?? ''}',
      imageUrl: images.isEmpty ? null : ApiService.media('${images.first}'),
      isLiked: liked,
      likesCount: likes,
      commentCount: (post['commentCount'] as num?)?.toInt() ?? 0,
      onLikeTap: () async {
        HapticFeedback.lightImpact();
        final next = !liked;
        setState(() {
          if (next) {
            _likedPostIds.add(postId);
          } else {
            _likedPostIds.remove(postId);
          }
          _likeOverrides[postId] = likes + (next ? 1 : -1);
        });
        final ok = await ApiService.setLiked(postId, next);
        if (!ok && mounted) {
          setState(() {
            if (next) {
              _likedPostIds.remove(postId);
            } else {
              _likedPostIds.add(postId);
            }
            _likeOverrides[postId] = likes;
          });
        }
      },
      onOptions: isMine
          ? null
          : () {
              final index = _posts.indexOf(post);
              PostOptions.open(
                context,
                postId: postId,
                authorName: authorName,
                authorId: author['id'] as String?,
                onAuthorBlocked: (id) {
                  if (!mounted) return;
                  setState(() => _posts.removeWhere((p) => (p['author'] as Map?)?['id'] == id));
                },
                onRemove: () {
                  if (mounted) setState(() => _posts.remove(post));
                },
                onRestore: () {
                  if (!mounted || _posts.contains(post)) return;
                  setState(() => _posts.insert(index.clamp(0, _posts.length), post));
                },
              );
            },
    );
  }

  Widget _buildFeedCard({
    required Map<String, dynamic> post,
    required String? authorId,
    required String author,
    required String time,
    required String? avatarUrl,
    required String caption,
    required String? imageUrl,
    required bool isLiked,
    required int likesCount,
    required int commentCount,
    required VoidCallback onLikeTap,
    required VoidCallback? onOptions,
  }) {
    return GestureDetector(
      onTap: () => PostDetailScreen.navigate(context, post),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => UserProfileScreen.navigate(context, authorId),
                  child: UserAvatar(url: avatarUrl, fallbackName: author, radius: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => UserProfileScreen.navigate(context, authorId),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(author, style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
                        Text(time, style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ),
                if (onOptions != null)
                  GestureDetector(
                    onTap: onOptions,
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.more_horiz, color: Colors.white38),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (caption.isNotEmpty)
              Text(caption, style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 13.5, height: 1.4)),
            if (imageUrl != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLikeTap,
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            color: isLiked ? _accent : Colors.white60,
                            size: 19,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$likesCount',
                            style: GoogleFonts.hankenGrotesk(color: isLiked ? _accent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () => PostDetailScreen.navigate(context, post),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white60, size: 18),
                          const SizedBox(width: 6),
                          Text('$commentCount', style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white60, size: 18),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    SharePlus.instance.share(ShareParams(text: 'Check out this post from $_displayTitle on Fitrybe: "$caption"'));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. LEADERBOARD ─────────────────────────────────────────────────────────

  Widget _buildLeaderboardView() {
    final myUserId = SessionService().userId;

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          _segmented<_Period>(
            value: _period,
            options: const [
              (_Period.week, 'This week'),
              (_Period.month, 'This month'),
              (_Period.allTime, 'All time'),
            ],
            onChanged: (p) {
              setState(() => _period = p);
              _loadLeaderboard();
            },
          ),
          const SizedBox(height: 14),
          if (!_leaderboardLoading && _leaderboard.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'Trybe total: ${Units.distanceKm(_leaderboardTotalKm, decimals: 1)}',
                style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          if (_leaderboardLoading)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: LoadingStateView(),
            )
          else if (_leaderboard.isEmpty || _leaderboardTotalKm == 0)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              icon: Icons.leaderboard_rounded,
              title: 'No distance yet',
              message: switch (_period) {
                _Period.week => 'Nobody has logged distance since Monday. Record a workout to top the board.',
                _Period.month => 'Nobody has logged distance this month yet.',
                _Period.allTime => 'Members rank here by distance covered. Record a workout to get on the board.',
              },
            )
          else
            for (final item in _leaderboard) _leaderboardRow(item, isMe: item['userId'] == myUserId),
        ],
      ),
    );
  }

  Widget _leaderboardRow(Map<String, dynamic> item, {required bool isMe}) {
    final rank = (item['rank'] as num?)?.toInt() ?? 0;
    final distanceKm = (item['distanceKm'] as num?) ?? 0;
    final medal = switch (rank) {
      1 => const Color(0xFFFFC107),
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
    final userId = item['userId'] as String?;

    return GestureDetector(
      onTap: () => UserProfileScreen.navigate(context, userId),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? _accent.withValues(alpha: 0.08) : _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMe ? _accent.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: medal == null
                  ? Text(
                      '$rank',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  : Icon(Icons.emoji_events_rounded, color: medal, size: 22),
            ),
            const SizedBox(width: 8),
            UserAvatar(
              url: ApiService.media(item['avatarUrl'] as String?),
              fallbackName: '${item['name'] ?? ''}',
              radius: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isMe ? 'You' : '${item['name'] ?? 'Athlete'}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(
                  color: isMe ? _accent : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Text(
              Units.distanceKm(distanceKm, decimals: 1),
              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _segmented<T>({
    required T value,
    required List<(T, String)> options,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (option == value) return;
                  HapticFeedback.selectionClick();
                  onChanged(option);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: option == value ? _accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      color: option == value ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── 3. EVENTS ──────────────────────────────────────────────────────────────

  Future<void> _openEventSheet([Map<String, dynamic>? event]) async {
    final id = widget.trybeId;
    if (id == null) return;
    HapticFeedback.lightImpact();
    final saved = await TrybeEventSheet.show(context, trybeId: id, event: event);
    if (saved == null || !mounted) return;
    setState(() => _showPastEvents = false);
    _snack(event == null ? 'Event scheduled and shared with members.' : 'Event updated.');
    _loadEvents();
  }

  Future<void> _deleteEvent(Map<String, dynamic> event) async {
    final id = widget.trybeId;
    if (id == null) return;
    final going = (event['goingCount'] as num?)?.toInt() ?? 0;
    final sure = await _confirm(
      title: 'Cancel "${event['title']}"?',
      message: going > 1
          ? 'It is removed for everyone, including the $going people going.'
          : 'It is removed for everyone.',
      confirmLabel: 'Cancel event',
      destructive: true,
    );
    if (!sure || !mounted) return;
    try {
      await ApiService.deleteTrybeEvent(id, '${event['id']}');
      if (!mounted) return;
      setState(() {
        _upcomingEvents.remove(event);
        _pastEvents.remove(event);
      });
      _snack('Event cancelled.');
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Could not cancel the event. Try again.');
    }
  }

  Future<void> _toggleRsvp(Map<String, dynamic> event) async {
    final id = widget.trybeId;
    final eventId = '${event['id']}';
    if (id == null || _rsvpBusy.contains(eventId)) return;

    HapticFeedback.lightImpact();
    final next = event['goingByMe'] != true;
    final previousCount = (event['goingCount'] as num?)?.toInt() ?? 0;
    final previousAttendees = List<dynamic>.from(event['attendees'] as List? ?? const []);
    final session = SessionService();

    setState(() {
      _rsvpBusy.add(eventId);
      event['goingByMe'] = next;
      event['goingCount'] = previousCount + (next ? 1 : -1);
      final attendees = List<dynamic>.from(previousAttendees)
        ..removeWhere((a) => a is Map && a['id'] == session.userId);
      if (next && attendees.length < 5) {
        attendees.add({
          'id': session.userId,
          'firstName': session.displayName,
          'avatarUrl': session.avatarUrl,
        });
      }
      event['attendees'] = attendees;
    });

    try {
      final result = await ApiService.setEventRsvp(id, eventId, next);
      if (!mounted) return;
      setState(() {
        event['goingCount'] = (result['goingCount'] as num?)?.toInt() ?? event['goingCount'];
        _rsvpBusy.remove(eventId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        event['goingByMe'] = !next;
        event['goingCount'] = previousCount;
        event['attendees'] = previousAttendees;
        _rsvpBusy.remove(eventId);
      });
      _snack(e is ApiException ? e.message : 'Could not update your RSVP. Try again.');
    }
  }

  Widget _buildEventsView() {
    final events = _showPastEvents ? _pastEvents : _upcomingEvents;

    final Widget content;
    if (_eventsLoading) {
      content = const Padding(padding: EdgeInsets.only(top: 60), child: LoadingStateView());
    } else if (_eventsError != null) {
      content = ErrorStateView(message: _eventsError!, onRetry: _loadEvents);
    } else if (events.isEmpty) {
      content = EmptyStateView(
        padding: const EdgeInsets.symmetric(vertical: 40),
        icon: Icons.event_rounded,
        title: _showPastEvents ? 'No past events' : 'No upcoming events',
        message: _showPastEvents
            ? 'Events move here once they are over.'
            : _canManage
                ? 'Schedule a group run or ride. Members get a notification and can say they are going.'
                : 'The creator and captains schedule group workouts here.',
        actionLabel: !_showPastEvents && _canManage ? 'Schedule an event' : null,
        onAction: !_showPastEvents && _canManage ? () => _openEventSheet() : null,
      );
    } else {
      content = Column(
        children: [for (final event in events) _eventCard(event)],
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          _segmented<bool>(
            value: _showPastEvents,
            options: [
              (false, _upcomingEvents.isEmpty ? 'Upcoming' : 'Upcoming (${_upcomingEvents.length})'),
              (true, 'Past'),
            ],
            onChanged: (past) => setState(() => _showPastEvents = past),
          ),
          const SizedBox(height: 16),
          content,
        ],
      ),
    );
  }

  Widget _eventCard(Map<String, dynamic> event) {
    final start = DateTime.tryParse('${event['startsAt'] ?? ''}')?.toLocal() ?? DateTime.now();
    final end = DateTime.tryParse('${event['endsAt'] ?? ''}')?.toLocal();
    final isPast = event['isPast'] == true;
    final going = event['goingByMe'] == true;
    final goingCount = (event['goingCount'] as num?)?.toInt() ?? 0;
    final attendees = [
      for (final a in (event['attendees'] as List? ?? const []))
        if (a is Map) Map<String, dynamic>.from(a),
    ];
    final creator = event['creator'] is Map ? Map<String, dynamic>.from(event['creator']) : null;
    final location = '${event['location'] ?? ''}'.trim();
    final activityType = '${event['activityType'] ?? ''}'.trim();
    final description = '${event['description'] ?? ''}'.trim();
    final busy = _rsvpBusy.contains('${event['id']}');

    final when = [
      WhenFormat.day(start),
      WhenFormat.time(start),
      if (end != null) WhenFormat.duration(end.difference(start)),
    ].join(' • ');

    return Opacity(
      opacity: isPast ? 0.7 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: going && !isPast ? _accent.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: isPast ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        WhenFormat.month(start).toUpperCase(),
                        style: GoogleFonts.hankenGrotesk(color: _accent, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                      ),
                      Text(
                        '${start.day}',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                      Text(
                        WhenFormat.weekday(start),
                        style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event['title'] ?? 'Event'}',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(when, style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 12.5)),
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, color: Colors.white38, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (event['canManage'] == true)
                  GestureDetector(
                    onTap: () => _showEventMenu(event, isPast: isPast),
                    child: const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.more_horiz, color: Colors.white38),
                    ),
                  ),
              ],
            ),
            if (activityType.isNotEmpty || description.isNotEmpty) const SizedBox(height: 10),
            if (activityType.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activityType,
                  style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ),
            if (description.isNotEmpty)
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.hankenGrotesk(color: Colors.white60, fontSize: 13, height: 1.4),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (attendees.isNotEmpty) ...[
                  SizedBox(
                    width: 16.0 * attendees.length + 10,
                    height: 26,
                    child: Stack(
                      children: [
                        for (var i = 0; i < attendees.length; i++)
                          Positioned(
                            left: i * 16.0,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(color: _cardBg, shape: BoxShape.circle),
                              child: UserAvatar(
                                url: ApiService.media(attendees[i]['avatarUrl'] as String?),
                                fallbackName: _nameOf(attendees[i]),
                                radius: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    [
                      isPast ? '$goingCount went' : '$goingCount going',
                      if (creator != null) 'by ${_nameOf(creator)}',
                    ].join(' • '),
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                  ),
                ),
                if (!isPast)
                  SizedBox(
                    height: 34,
                    child: ElevatedButton(
                      onPressed: busy ? null : (_isJoined ? () => _toggleRsvp(event) : _onJoinButton),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: going ? Colors.white.withValues(alpha: 0.08) : _accent,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                        foregroundColor: going ? _accent : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder(),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (going) ...[
                            const Icon(Icons.check_rounded, size: 16),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            !_isJoined ? 'Join to RSVP' : going ? 'Going' : "I'm in",
                            style: GoogleFonts.hankenGrotesk(fontWeight: FontWeight.bold, fontSize: 12.5),
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
    );
  }

  void _showEventMenu(Map<String, dynamic> event, {required bool isPast}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              if (!isPast)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_rounded, color: Colors.white70),
                  title: Text('Edit event', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openEventSheet(event);
                  },
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  isPast ? 'Delete event' : 'Cancel event',
                  style: GoogleFonts.hankenGrotesk(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteEvent(event);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 4. MEMBERS ─────────────────────────────────────────────────────────────

  Future<void> _reloadMembers() async {
    final id = widget.trybeId;
    if (id == null) return;
    final members = await ApiService.getTrybeMembers(id);
    if (mounted) setState(() => _members = members);
  }

  Future<void> _setRole(String userId, String name, String role) async {
    final id = widget.trybeId;
    if (id == null) return;
    try {
      await ApiService.setTrybeMemberRole(id, userId, role);
      if (!mounted) return;
      _snack(role == 'CAPTAIN' ? '$name is now a captain.' : '$name is no longer a captain.');
      _reloadMembers();
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Could not change their role. Try again.');
    }
  }

  Future<void> _removeMember(String userId, String name) async {
    final id = widget.trybeId;
    if (id == null) return;
    final sure = await _confirm(
      title: 'Remove $name?',
      message: _trybe?['isPublic'] == false
          ? 'They lose access to this Trybe and its chat, and need a new invite to come back.'
          : 'They leave this Trybe and its chat. They can join again, since the Trybe is public.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!sure || !mounted) return;
    try {
      await ApiService.removeTrybeMember(id, userId);
      if (!mounted) return;
      _snack('$name was removed.');
      _load();
    } catch (e) {
      if (!mounted) return;
      _snack(e is ApiException ? e.message : 'Could not remove them. Try again.');
    }
  }

  /// What the viewer may do to [role]: the creator appoints and removes
  /// captains, and managers remove members, with captains unable to remove
  /// each other. Nobody can act on the creator.
  List<(IconData, String, bool, VoidCallback)> _memberActions(String userId, String name, String role) {
    final canRemove = role != 'CREATOR' && (_isCreator || (_myRole == 'CAPTAIN' && role == 'MEMBER'));
    return [
      if (_isCreator && role == 'MEMBER')
        (Icons.star_outline_rounded, 'Make captain', false, () => _setRole(userId, name, 'CAPTAIN')),
      if (_isCreator && role == 'CAPTAIN')
        (Icons.star_border_rounded, 'Remove captain role', false, () => _setRole(userId, name, 'MEMBER')),
      if (canRemove)
        (Icons.person_remove_outlined, 'Remove from Trybe', true, () => _removeMember(userId, name)),
    ];
  }

  void _showMemberMenu(String name, List<(IconData, String, bool, VoidCallback)> actions) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(name, style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              for (final (icon, label, destructive, action) in actions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(icon, color: destructive ? Colors.redAccent : Colors.white70),
                  title: Text(
                    label,
                    style: GoogleFonts.hankenGrotesk(
                      color: destructive ? Colors.redAccent : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    action();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembersView() {
    final myUserId = SessionService().userId;

    return RefreshIndicator(
      onRefresh: _reloadMembers,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          if (_isJoined)
            GestureDetector(
              onTap: _openInvites,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, color: _accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Invite people',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),
          if (_isCreator)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Captains can edit the Trybe, schedule events and remove members.',
                style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          if (_members.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              icon: Icons.group_rounded,
              title: 'No members yet',
              message: 'Be the first to join this Trybe.',
            )
          else
            for (final member in _members) _memberRow(member, myUserId),
        ],
      ),
    );
  }

  Widget _memberRow(Map<String, dynamic> member, String? myUserId) {
    final user = (member['user'] is Map)
        ? Map<String, dynamic>.from(member['user'])
        : <String, dynamic>{};
    final userId = user['id'] as String?;
    final name = _nameOf(user);
    final isMe = userId == myUserId;
    final role = '${member['role'] ?? 'MEMBER'}';
    final isFollowing = member['isFollowing'] == true;
    final actions = isMe || userId == null
        ? const <(IconData, String, bool, VoidCallback)>[]
        : _memberActions(userId, name, role);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => UserProfileScreen.navigate(context, userId),
            child: UserAvatar(
              url: ApiService.media(user['avatarUrl'] as String?),
              fallbackName: name,
              radius: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => UserProfileScreen.navigate(context, userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '$name (You)' : name,
                    style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    switch (role) {
                      'CREATOR' => 'Trybe Creator',
                      'CAPTAIN' => 'Captain',
                      _ => 'Member',
                    },
                    style: GoogleFonts.hankenGrotesk(
                      color: role == 'MEMBER' ? Colors.white38 : _accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isMe && userId != null)
            _MemberFollowButton(
              key: ValueKey('$userId-$isFollowing'),
              userId: userId,
              initiallyFollowing: isFollowing,
              accent: _accent,
            ),
          if (actions.isNotEmpty)
            GestureDetector(
              onTap: () => _showMemberMenu(name, actions),
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.more_vert_rounded, color: Colors.white38, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

/// Follow toggle in the members list, kept local so one row's request does not
/// rebuild the whole roster. Starts from what the server says.
class _MemberFollowButton extends StatefulWidget {
  final String userId;
  final bool initiallyFollowing;
  final Color accent;

  const _MemberFollowButton({
    super.key,
    required this.userId,
    required this.initiallyFollowing,
    required this.accent,
  });

  @override
  State<_MemberFollowButton> createState() => _MemberFollowButtonState();
}

class _MemberFollowButtonState extends State<_MemberFollowButton> {
  late bool _isFollowing = widget.initiallyFollowing;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: _isBusy
          ? null
          : () async {
              HapticFeedback.lightImpact();
              final next = !_isFollowing;
              setState(() {
                _isFollowing = next;
                _isBusy = true;
              });
              final ok = await ApiService.setFollowing(widget.userId, next);
              if (!mounted) return;
              setState(() {
                if (!ok) _isFollowing = !next;
                _isBusy = false;
              });
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: _isFollowing ? widget.accent : Colors.white,
        side: BorderSide(
          color: _isFollowing
              ? widget.accent.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(
        _isFollowing ? 'Following' : 'Follow',
        style: GoogleFonts.hankenGrotesk(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
