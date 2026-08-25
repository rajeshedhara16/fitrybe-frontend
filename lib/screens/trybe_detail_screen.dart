import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';
import 'chat_detail_screen.dart';
import 'create_post_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

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

  const TrybeDetailScreen({
    super.key,
    this.trybeId,
    required this.title,
    this.imageUrl,
    this.memberCount = '',
    this.category = '',
    this.location = '',
    this.isJoined = false,
  });

  @override
  State<TrybeDetailScreen> createState() => _TrybeDetailScreenState();
}

class _TrybeDetailScreenState extends State<TrybeDetailScreen>
    with SingleTickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF0F0F12);
  final Color _cardBg = const Color(0xFF1B1B1E);

  late bool _isJoined;
  int _activeSubTab = 0; // 0: Feed, 1: Leaderboard, 2: Events, 3: Members

  Map<String, dynamic>? _trybe;
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  String? _error;
  bool _isTogglingJoin = false;

  // Local overlays on top of server state for optimistic like/hide actions.
  final Set<String> _likedPostIds = {};
  final Map<String, int> _likeOverrides = {};
  final Set<String> _hiddenPostIds = {};

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isJoined;
    _load();
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
      final results = await Future.wait([
        ApiService.getTrybe(id),
        ApiService.getTrybePosts(id),
        ApiService.getTrybeLeaderboard(id),
        ApiService.getTrybeMembers(id),
      ]);

      if (!mounted) return;
      final trybe = results[0] as Map<String, dynamic>?;
      setState(() {
        _trybe = trybe;
        _posts = (results[1] as List<Map<String, dynamic>>)
            .where((p) => !_hiddenPostIds.contains('${p['id']}'))
            .toList();
        _leaderboard = results[2] as List<Map<String, dynamic>>;
        _members = results[3] as List<Map<String, dynamic>>;
        _isJoined = trybe?['isMember'] == true;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('TrybeDetail load error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'We could not load this Trybe.';
      });
    }
  }

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
    final parts = <String>[
      '${_trybe!['memberCount'] ?? 0} members',
      if ('${_trybe!['location'] ?? ''}'.trim().isNotEmpty)
        '${_trybe!['location']}',
      _trybe!['isPublic'] == false ? 'Private' : 'Public',
    ];
    return parts.join(' • ');
  }

  Future<void> _toggleJoin() async {
    final id = widget.trybeId;
    if (id == null || _isTogglingJoin) return;

    HapticFeedback.heavyImpact();
    final shouldJoin = !_isJoined;
    setState(() {
      _isJoined = shouldJoin;
      _isTogglingJoin = true;
    });

    final ok = await ApiService.setTrybeMembership(id, shouldJoin);
    if (!mounted) return;
    if (!ok) {
      // The creator cannot leave their own Trybe, so revert and explain.
      setState(() {
        _isJoined = !shouldJoin;
        _isTogglingJoin = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            shouldJoin
                ? 'Could not join this Trybe. Please try again.'
                : "You created this Trybe, so you can't leave it.",
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
      return;
    }
    setState(() => _isTogglingJoin = false);
    _load();
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

  void _showTrybeOptionsMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_rounded, color: _accent, size: 20),
                ),
                title: Text('Share Trybe', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Invite friends to join ${widget.title}', style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  SharePlus.instance.share(
                    ShareParams(text: 'Join ${widget.title} on FitRybe! 🏃‍♂️💨 https://fitrybe.app/trybe/${widget.title.replaceAll(' ', '-')}'),
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_outlined, color: Colors.white70, size: 20),
                ),
                title: Text('Mute Trybe Notifications', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Trybe notifications muted', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                      backgroundColor: _accent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
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
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    // Open (or create) this Trybe's group conversation.
                    final conversationId = await ApiService.createConversation(
                      trybeId: widget.trybeId,
                    );
                    if (!mounted || conversationId == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatDetailScreen(
                          chatId: conversationId,
                          name: _displayTitle,
                          avatar: _displayImage,
                          isTrybe: true,
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
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showTrybeOptionsMenu,
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
                        errorBuilder: (_, __, ___) =>
                            Container(color: _accent.withValues(alpha: 0.18)),
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
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _toggleJoin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isJoined ? const Color(0xFF2A2A2E) : _accent,
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
                                            _isJoined ? Icons.check_circle_rounded : Icons.group_add_rounded,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isJoined ? 'JOINED' : 'JOIN TRYBE',
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
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  SharePlus.instance.share(
                                    ShareParams(text: 'Check out ${widget.title} on FitRybe! 🏃‍♂️'),
                                  );
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2E),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
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
            // Sub-Tab Navigation Bar
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

            // Main Body Content
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
      floatingActionButton: _activeSubTab == 0
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
              },
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 6,
              child: const Icon(
                Symbols.add_rounded,
                size: 28,
                fill: 1.0,
                weight: 700,
                grade: 200,
                opticalSize: 24,
              ),
            )
          : null,
    );
  }

  Widget _buildSubTabItem(int index, String label) {
    final bool isActive = _activeSubTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeSubTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? _accent : Colors.transparent,
              width: 2.5,
            ),
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

  // ── 1. FEED TAB VIEW ────────────────────────────────────────────────────────
  Widget _buildFeedView() {
    // Weekly goal is derived from what members actually logged this week.
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    double weeklyKm = 0;
    for (final post in _posts) {
      final activity = post['activity'];
      if (activity is! Map) continue;
      final created = DateTime.tryParse('${post['createdAt'] ?? ''}');
      if (created == null || created.isBefore(weekAgo)) continue;
      weeklyKm += ((activity['distance'] as num?) ?? 0) / 1000;
    }
    // Scale the target with the roster so the bar stays meaningful.
    final memberCount = (_trybe?['memberCount'] as num?)?.toInt() ?? _members.length;
    final targetKm = (memberCount * 25).clamp(25, 100000).toDouble();
    final progress = (weeklyKm / targetKm).clamp(0.0, 1.0);

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      children: [
        // Weekly Trybe Goal Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WEEKLY TRYBE GOAL',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    '${weeklyKm.toStringAsFixed(1)} / ${targetKm.toStringAsFixed(0)} km (${(progress * 100).round()}%)',
                    style: GoogleFonts.hankenGrotesk(
                      color: _accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(_accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                weeklyKm == 0
                    ? 'No distance logged by members this week yet'
                    : '${weeklyKm.toStringAsFixed(1)} km achieved by members this week',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_posts.isEmpty)
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            icon: Icons.forum_rounded,
            title: 'No posts yet',
            message:
                'Nothing has been shared in this Trybe. Post a workout to kick things off.',
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

  /// Adapts an API post onto the existing feed-card layout.
  Widget _buildPostCardFor(Map<String, dynamic> post) {
    final postId = '${post['id'] ?? ''}';
    final author = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : <String, dynamic>{};
    final counts = (post['_count'] is Map)
        ? Map<String, dynamic>.from(post['_count'])
        : <String, dynamic>{};
    final images = (post['imageUrls'] is List)
        ? List<dynamic>.from(post['imageUrls'])
        : const [];

    final liked = _likedPostIds.contains(postId) || post['likedByMe'] == true;
    final baseLikes = (counts['likes'] as num?)?.toInt() ??
        (post['likeCount'] as num?)?.toInt() ??
        0;
    final likes = _likeOverrides[postId] ?? baseLikes;

    return _buildFeedCard(
      postId: postId,
      author: _nameOf(author),
      time: _relativeTime(post['createdAt']),
      avatarUrl: ApiService.media(author['avatarUrl'] as String?),
      caption: '${post['caption'] ?? ''}',
      imageUrl: images.isEmpty ? null : ApiService.media('${images.first}'),
      isLiked: liked,
      likesCount: likes,
      commentCount: (counts['comments'] as num?)?.toInt() ??
          (post['commentCount'] as num?)?.toInt() ??
          0,
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
      onHide: () => setState(() => _hiddenPostIds.add(postId)),
    );
  }



  Widget _buildFeedCard({
    required String postId,
    required String author,
    required String time,
    required String? avatarUrl,
    required String caption,
    required String? imageUrl,
    required bool isLiked,
    required int likesCount,
    required int commentCount,
    required VoidCallback onLikeTap,
    required VoidCallback onHide,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(url: avatarUrl, fallbackName: author, radius: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(author, style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold)),
                    Text(time, style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 11.5)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showPostOptionsSheet(context, author, onHide: onHide),
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
              child: Image.network(
                imageUrl,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
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
                          '$likesCount Likes',
                          style: GoogleFonts.hankenGrotesk(color: isLiked ? _accent : Colors.white70, fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _showCommentsSheet(context, postId),
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
                  SharePlus.instance.share(ShareParams(text: 'Check out this post from ${widget.title}: "$caption"'));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCommentsSheet(BuildContext context, String postId) {
    HapticFeedback.lightImpact();
    final commentCtrl = TextEditingController();
    final commentsList = <Map<String, String>>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isLoading = true;

        return StatefulBuilder(
        builder: (ctx, setSheetState) {
          // Load the real thread the first time the sheet lays out.
          if (isLoading) {
            ApiService.getComments(postId).then((fetched) {
              commentsList
                ..clear()
                ..addAll(fetched.map((raw) {
                  final author = (raw['author'] is Map)
                      ? Map<String, dynamic>.from(raw['author'])
                      : <String, dynamic>{};
                  return {
                    'name': _nameOf(author),
                    'text': '${raw['text'] ?? ''}',
                    'time': _relativeTime(raw['createdAt']),
                    'avatar':
                        ApiService.media(author['avatarUrl'] as String?) ?? '',
                  };
                }));
              isLoading = false;
              setSheetState(() {});
            }).catchError((_) {
              isLoading = false;
              setSheetState(() {});
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Comments (${commentsList.length})',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: isLoading
                        ? const LoadingStateView()
                        : commentsList.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Be the first to comment!',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: commentsList.length,
                            itemBuilder: (ctx, index) {
                              final comment = commentsList[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _accent.withValues(alpha: 0.2),
                                      child: Icon(Icons.person_rounded, color: _accent, size: 16),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comment['name'] ?? 'User',
                                            style: GoogleFonts.hankenGrotesk(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            comment['text'] ?? '',
                                            style: GoogleFonts.hankenGrotesk(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      comment['time'] ?? 'Just now',
                                      style: GoogleFonts.hankenGrotesk(
                                        color: Colors.white38,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white10)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2D),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: TextField(
                              controller: commentCtrl,
                              style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 13),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final text = commentCtrl.text.trim();
                            if (text.isEmpty) return;
                            HapticFeedback.mediumImpact();
                            final created =
                                await ApiService.addComment(postId, text);
                            if (created == null) return;
                            commentsList.add({
                              'name': SessionService().displayName,
                              'text': '${created['text'] ?? text}',
                              'time': 'Just now',
                              'avatar': SessionService().avatarUrl ?? '',
                            });
                            commentCtrl.clear();
                            setSheetState(() {});
                            // Keep the card's comment count in step.
                            if (mounted) _load();
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      },
    );
  }

  void _showPostOptionsSheet(BuildContext context, String postAuthor, {required VoidCallback onHide}) {
    HapticFeedback.mediumImpact();
    bool isSaved = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Post Options',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: isSaved ? _accent : Colors.white70,
                      size: 22,
                    ),
                    title: Text(
                      isSaved ? 'Remove from Saved' : 'Save Post',
                      style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setSheetState(() {
                        isSaved = !isSaved;
                      });
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70, size: 22),
                    title: Text('Hide this post', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
                    subtitle: Text('See fewer posts like this', style: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 12)),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                      onHide();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person_remove_outlined, color: Colors.white70, size: 22),
                    title: Text('Unfollow $postAuthor', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14.5)),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined, color: Colors.red.shade400, size: 22),
                    title: Text('Report Post', style: GoogleFonts.hankenGrotesk(color: Colors.red.shade400, fontWeight: FontWeight.w600, fontSize: 14.5)),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 2. LEADERBOARD TAB VIEW ──────────────────────────────────────────────────
  Widget _buildLeaderboardView() {
    if (_leaderboard.isEmpty) {
      return EmptyStateView(
        icon: Icons.leaderboard_rounded,
        title: 'No rankings yet',
        message:
            'The leaderboard ranks members by distance covered. Record a workout to put yourself on the board.',
      );
    }

    final myUserId = SessionService().userId;

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        itemCount: _leaderboard.length,
        itemBuilder: (ctx, idx) {
          final item = _leaderboard[idx];
          final isMe = item['userId'] == myUserId;
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: Text(
                    '${item['rank'] ?? idx + 1}',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
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
                    style: GoogleFonts.hankenGrotesk(
                      color: isMe ? _accent : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Text(
                  '${item['stat'] ?? '0 km'}',
                  style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── 3. EVENTS TAB VIEW ───────────────────────────────────────────────────────
  Widget _buildEventsView() {
    // Scheduled Trybe events are not modelled in the backend yet; live group
    // sessions are organised through the Clique tab instead.
    return EmptyStateView(
      icon: Icons.event_rounded,
      title: 'No events scheduled',
      message:
          'This Trybe has no upcoming events. Group workouts you can join right now live in the Clique tab.',
    );
  }

  // ── 4. MEMBERS TAB VIEW ──────────────────────────────────────────────────────
  Widget _buildMembersView() {
    if (_members.isEmpty) {
      return EmptyStateView(
        icon: Icons.group_rounded,
        title: 'No members yet',
        message: 'Be the first to join this Trybe.',
      );
    }

    final myUserId = SessionService().userId;

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      backgroundColor: _cardBg,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        itemCount: _members.length,
        itemBuilder: (ctx, idx) {
          final member = _members[idx];
          final user = (member['user'] is Map)
              ? Map<String, dynamic>.from(member['user'])
              : <String, dynamic>{};
          final userId = user['id'] as String?;
          final name = _nameOf(user);
          final isMe = userId == myUserId;
          final role = '${member['role'] ?? 'MEMBER'}';

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                UserAvatar(
                  url: ApiService.media(user['avatarUrl'] as String?),
                  fallbackName: name,
                  radius: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isMe ? '$name (You)' : name,
                          style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(
                        switch (role) {
                          'CREATOR' => 'Trybe Creator',
                          'CAPTAIN' => 'Captain',
                          _ => 'Member',
                        },
                        style: GoogleFonts.hankenGrotesk(
                            color: _accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                if (!isMe && userId != null)
                  _MemberFollowButton(userId: userId, accent: _accent),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Follow toggle in the members list, kept local so one row's request does not
/// rebuild the whole roster.
class _MemberFollowButton extends StatefulWidget {
  final String userId;
  final Color accent;

  const _MemberFollowButton({required this.userId, required this.accent});

  @override
  State<_MemberFollowButton> createState() => _MemberFollowButtonState();
}

class _MemberFollowButtonState extends State<_MemberFollowButton> {
  bool _isFollowing = false;
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
      child: Text(_isFollowing ? 'Following' : 'Follow',
          style: GoogleFonts.hankenGrotesk(
              fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
