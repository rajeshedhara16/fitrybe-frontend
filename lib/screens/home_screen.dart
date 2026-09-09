import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'activity_analytics_tab.dart';
import 'record_screen.dart';
import 'trybes_tab.dart';
import 'clique_tab.dart';
import 'profile_tab.dart';
import 'notifications_tab.dart';
import 'create_post_screen.dart';
import 'create_trybe_screen.dart';
import 'create_clique_activity_screen.dart';
import 'customize_goal_screen.dart';
import 'messaging_screen.dart';
import 'user_profile_screen.dart';
import 'post_detail_screen.dart';
import 'settings_screen.dart';

import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../services/goal_progress.dart';
import '../services/health_service.dart';
import '../services/session_service.dart';
import '../services/notification_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/HomeScreen';
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  int _activeTrybesSubTab = 0; // 0: Trybe, 1: Friends
  int _activeCliqueSubTab = 0; // 0: Activity, 1: Challenges, 2: Synergy
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);
  final Color _bg = const Color(0xFF131316);

  /// Avatar shown for the signed-in user across the feed chrome.
  String? get _userProfileUrl => SessionService().avatarUrl;

  final Set<String> _followedUsers = {};

  /// Users explicitly unfollowed this session, so a server `isFollowing: true`
  /// does not immediately undo the tap.
  final Set<String> _unfollowedUsers = {};
  final Set<String> _hiddenUserPostIds = {};

  /// Comment threads keyed by post id, filled from the API on demand.
  final Map<String, List<Map<String, String>>> _postComments = {};

  /// Optimistic like state for posts touched this session. Cleared whenever the
  /// feed is reloaded so the server's `likedByMe` and `likeCount` win again.
  final Map<String, int> _userPostLikes = {};
  final Set<String> _likedUserPostIds = {};

  /// Posts unliked this session. Without this, a post the server still reports
  /// as liked would spring back to liked on the next rebuild.
  final Set<String> _unlikedUserPostIds = {};

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Debounced feed search. Athletes come from the API; posts are filtered
  /// out of the feed already in memory, so typing stays responsive.
  Timer? _searchDebounce;
  String _searchQuery = '';
  List<Map<String, dynamic>> _searchedUsers = [];
  bool _isSearchLoading = false;
  List<Map<String, dynamic>> _backendPosts = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  Map<String, dynamic> _analytics = const {};
  bool _isFeedLoading = true;
  String? _feedError;

  @override
  void initState() {
    super.initState();
    SocketService().connect();
    // Seeds the notifications badge and keeps it live while the app is open.
    NotificationService().start();
    _loadBackendFeed();
    _loadSuggestedUsers();
    _loadAnalytics();
    HealthService().fetchTodayHealthData();
  }

  Future<void> _loadAnalytics() async {
    final analytics = await ApiService.getAnalytics();
    if (!mounted) return;
    setState(() => _analytics = analytics);
  }

  Future<void> _loadBackendFeed() async {
    if (mounted) setState(() => _feedError = null);
    try {
      final posts = await ApiService.getFeed();
      if (!mounted) return;
      setState(() {
        _backendPosts = posts;
        _isFeedLoading = false;
        // The response is the truth now. Dropping this session's optimistic
        // overrides means a like that silently failed cannot keep showing as
        // applied after a refresh.
        _likedUserPostIds.clear();
        _unlikedUserPostIds.clear();
        _userPostLikes.clear();
        _postComments.clear();
      });
    } catch (e) {
      debugPrint('FitRybe feed load error: $e');
      if (!mounted) return;
      setState(() {
        _isFeedLoading = false;
        _feedError = 'We could not load your feed. Pull down to retry.';
      });
    }
  }

  Future<void> _loadSuggestedUsers() async {
    final users = await ApiService.searchUsers('', suggested: true, limit: 10);
    if (!mounted) return;
    setState(() => _suggestedUsers = users);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
    _searchDebounce?.cancel();
    if (_searchQuery.isEmpty) {
      setState(() {
        _searchedUsers = [];
        _isSearchLoading = false;
      });
      return;
    }
    setState(() => _isSearchLoading = true);
    _searchDebounce =
        Timer(const Duration(milliseconds: 350), _runSearch);
  }

  Future<void> _runSearch() async {
    final query = _searchQuery;
    if (query.isEmpty) return;
    final users = await ApiService.searchUsers(query, limit: 15);
    // A slower earlier request must not overwrite newer results.
    if (!mounted || query != _searchQuery) return;
    setState(() {
      _searchedUsers = users;
      _isSearchLoading = false;
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _searchedUsers = [];
      _isSearchLoading = false;
      _isSearching = false;
    });
  }

  /// Feed posts matching the query by caption, author, or location tag.
  List<Map<String, dynamic>> get _matchingPosts {
    final needle = _searchQuery.toLowerCase();
    if (needle.isEmpty) return const [];
    return _backendPosts.where((p) {
      if (_hiddenUserPostIds.contains(p['id'])) return false;
      final author = (p['author'] is Map)
          ? Map<String, dynamic>.from(p['author'])
          : const <String, dynamic>{};
      final haystack = [
        p['caption'],
        p['locationTag'],
        p['type'],
        author['firstName'],
        author['lastName'],
      ].where((v) => v != null).join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bool isSynergyOrbit = _currentNavIndex == 3 && _activeCliqueSubTab == 2;
    final String tabTitle = const ['Home', 'Trybes', 'Activity', 'Clique', 'Notification'][_currentNavIndex];
    return Scaffold(
      backgroundColor: isSynergyOrbit ? Colors.black : _bg,
      appBar: AppBar(
        backgroundColor: isSynergyOrbit
            ? Colors.black
            : _bg.withValues(alpha: 0.9),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: _isSearching
            ? Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search athletes and posts...',
                          hintStyle: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white54,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _closeSearch,
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
              )
            : Stack(
                alignment: Alignment.center,
                children: [
                  // Left: Logo + Tab title
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'assets/images/fitrybe-mark.svg',
                          height: 28,
                          colorFilter: const ColorFilter.mode(
                            Color(0xFFFF5722),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tabTitle,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Center: Record button
                  if (_currentNavIndex == 0)
                    Align(
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const RecordScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFFFF5722).withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Symbols.circle_rounded,
                                color: Color(0xFFFF5722),
                                size: 10,
                                fill: 1.0,
                                weight: 700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'RECORD',
                                style: GoogleFonts.hankenGrotesk(
                                  color: const Color(0xFFFF5722),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Right: Search + Message (Inbox) + User Profile (Rightmost)
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_currentNavIndex == 0) ...[
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSearching = true;
                              });
                            },
                            child: SvgPicture.string(
                              '''<svg xmlns="http://www.w3.org/2000/svg" width="104" height="100" viewBox="0 0 104 100">
                                <defs>
                                  <mask id="search-cutout">
                                    <rect width="104" height="100" fill="white" />
                                    <circle cx="44" cy="40" r="20" fill="black" />
                                  </mask>
                                </defs>
                                <g fill="currentColor" stroke="currentColor" mask="url(#search-cutout)">
                                  <path d="M60 56 L92 88" stroke-width="20" stroke-linecap="round" fill="none"/>
                                  <circle cx="44" cy="40" r="34" stroke="none" fill="currentColor"/>
                                </g>
                              </svg>''',
                              height: 22,
                              colorFilter: const ColorFilter.mode(
                                Colors.white70,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const MessagingScreen(),
                              ),
                            );
                          },
                          child: SvgPicture.string(
                            '''<svg xmlns="http://www.w3.org/2000/svg" width="120" height="88" viewBox="0 0 120 88">
                              <defs>
                                <mask id="cutout">
                                  <rect width="120" height="88" fill="white" />
                                  <rect x="36" y="24" width="48" height="12" rx="6" fill="black" />
                                  <rect x="36" y="42" width="32" height="12" rx="6" fill="black" />
                                </mask>
                              </defs>
                              <g fill="currentColor" mask="url(#cutout)">
                                <ellipse cx="60" cy="40" rx="42" ry="33"/>
                                <path d="M24 56 L17 68 Q14 73 20 73 L60 73 Z"/>
                              </g>
                            </svg>''',
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white70,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  backgroundColor: const Color(0xFF131316),
                                  appBar: AppBar(
                                    backgroundColor: const Color(0xFF131316),
                                    elevation: 0,
                                    scrolledUnderElevation: 0,
                                    leading: IconButton(
                                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                    title: Text(
                                      'Profile',
                                      style: GoogleFonts.anybody(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.settings_outlined, color: Colors.white),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SettingsScreen(),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                  body: const SingleChildScrollView(
                                    physics: BouncingScrollPhysics(),
                                    child: ProfileTab(),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: UserAvatar(
                            url: _userProfileUrl,
                            fallbackName: SessionService().displayName,
                            radius: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
      body: _buildCurrentTab(),
      floatingActionButton: _currentNavIndex == 2
          ? SizedBox(
              height: 48,
              child: FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomizeGoalScreen(),
                    ),
                  );
                },
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                icon: const Icon(
                  Symbols.track_changes_rounded,
                  size: 24,
                  weight: 800,
                  grade: 200,
                ),
                label: Text(
                  'Customize Goal',
                  style: GoogleFonts.hankenGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            )
          : _currentNavIndex == 3
              ? SizedBox(
                  height: 48,
                  child: FloatingActionButton.extended(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const CreateCliqueActivityScreen(),
                        ),
                      );
                    },
                    backgroundColor: _accent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    icon: const Icon(
                      Symbols.add_rounded,
                      size: 26,
                      weight: 900,
                      grade: 200,
                    ),
                    label: Text(
                      'Create Activity',
                      style: GoogleFonts.hankenGrotesk(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                )
          : _currentNavIndex == 1
              ? (_activeTrybesSubTab == 0
                  ? SizedBox(
                      height: 48,
                      child: FloatingActionButton.extended(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateTrybeScreen(),
                            ),
                          );
                        },
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        icon: const Icon(
                          Symbols.group_add_rounded,
                          size: 20,
                          fill: 1.0,
                          weight: 700,
                          grade: 200,
                          opticalSize: 24,
                        ),
                        label: Text(
                          'Create Trybe',
                          style: GoogleFonts.hankenGrotesk(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    )
                  : null)
              : _currentNavIndex == 4
                  ? null
                  : FloatingActionButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final res = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreatePostScreen(),
                          ),
                        );
                        if (res == true || mounted) {
                          _loadBackendFeed();
                        }
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
                    ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }





  Widget _buildCurrentTab() {
    // Search takes over the body while it is open, on whichever tab.
    if (_isSearching && _searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    switch (_currentNavIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: _loadBackendFeed,
          color: _accent,
          backgroundColor: _cardBg,
          child: Builder(
            builder: (context) {
              final visiblePosts = _backendPosts
                  .where((p) => !_hiddenUserPostIds.contains(p['id']))
                  .toList();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeeklyStats(),
                    _buildGrowYourTrybeSection(),
                    if (_isFeedLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: LoadingStateView(message: 'Loading your feed…'),
                      )
                    else if (_feedError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: ErrorStateView(
                          message: _feedError!,
                          onRetry: _loadBackendFeed,
                        ),
                      )
                    else if (visiblePosts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: EmptyStateView(
                          icon: Symbols.dynamic_feed_rounded,
                          title: 'Your feed is quiet',
                          message:
                              'Follow other athletes or share your first workout to get the feed moving.',
                          actionLabel: 'Create a post',
                          onAction: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreatePostScreen(),
                              ),
                            );
                            _loadBackendFeed();
                          },
                        ),
                      )
                    else
                      ...visiblePosts.map(_buildBackendPostCard),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            },
          ),
        );
      case 2:
        return const ActivityAnalyticsTab();
      case 1:
        return TrybesTab(
          onSubTabChanged: (subIdx) {
            setState(() {
              _activeTrybesSubTab = subIdx;
            });
          },
        );
      case 3:
        return CliqueTab(
          onSubTabChanged: (subIdx) {
            setState(() {
              _activeCliqueSubTab = subIdx;
            });
          },
        );
      case 4:
        return const NotificationsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBackendPostCard(Map<String, dynamic> post) {
    final String postId = post['id'] ?? '';
    final String caption = post['caption'] ?? '';
    final Map<String, dynamic> author = (post['author'] is Map) ? Map<String, dynamic>.from(post['author']) : {};
    final String authorName = '${author['firstName'] ?? 'Fitrybe'} ${author['lastName'] ?? 'User'}'.trim();
    final String? avatarUrl = ApiService.media(author['avatarUrl'] as String?);
    final List imageUrls = (post['imageUrls'] is List) ? post['imageUrls'] : [];
    final Map<String, dynamic>? activity = (post['activity'] is Map) ? Map<String, dynamic>.from(post['activity']) : null;
    final String locationTag = post['locationTag'] ?? 'Fitrybe Feed';

    // Local sets hold only what this session changed; anything untouched falls
    // back to what the server said. Both are cleared on refresh so a reload
    // cannot be overridden by stale optimistic state.
    final bool isLiked = _likedUserPostIds.contains(postId) ||
        (!_unlikedUserPostIds.contains(postId) && post['likedByMe'] == true);
    final int kudosCount = (_userPostLikes[postId] ?? (post['likeCount'] as int? ?? 0));

    // Once the thread has been opened its local length is authoritative, since
    // it includes anything just posted. Until then the feed shows the server's
    // count rather than zero.
    final int commentCount =
        _postComments[postId]?.length ?? (post['commentCount'] as int? ?? 0);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => UserProfileScreen.navigate(
                    context,
                    author['id'] as String? ?? post['authorId'] as String?,
                  ),
                  child: UserAvatar(
                    url: avatarUrl,
                    fallbackName: authorName,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => UserProfileScreen.navigate(
                      context,
                      author['id'] as String? ?? post['authorId'] as String?,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName.isEmpty ? 'Fitrybe Athlete' : authorName,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Recent • $locationTag',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _showPostOptions(
                      context: context,
                      isOwnPost: false,
                      postId: postId,
                      authorName: authorName,
                      onHide: () {
                        setState(() {
                          _backendPosts.removeWhere((p) => p['id'] == postId);
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Caption & Description (Tighter gap below author name)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => PostDetailScreen.navigate(context, post),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (caption.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Text(
                      caption,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 14.5,
                        height: 1.4,
                      ),
                    ),
                  ),

                // Activity image - rendered ONLY if an image is present.
                Builder(
                  builder: (context) {
                    final String? displayImageUrl = imageUrls.isEmpty
                        ? null
                        : ApiService.media('${imageUrls.first}');
                    final String activityTitle = (activity?['title'] ?? activity?['type'] ?? activity?['name'] ?? post['type'] ?? 'Workout').toString();

                    if (displayImageUrl == null) {
                      // If there's no image but there's a real activity attached, show a clean metrics card.
                      if (activity != null && (activity['distance'] != null || activity['avgPace'] != null)) {
                        final double distKm = _parseDistKm(activity['distance']);
                        final String paceStr = _formatPace(activity['avgPace']);
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: _cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.directions_run_rounded, color: _accent, size: 24),
                                const SizedBox(width: 12),
                                if (activity['distance'] != null) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(activityTitle.toUpperCase(), style: GoogleFonts.hankenGrotesk(fontSize: 9.5, color: _accent, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      const SizedBox(height: 1),
                                      Text('DISTANCE', style: GoogleFonts.hankenGrotesk(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      Text('${distKm.toStringAsFixed(1)} km', style: GoogleFonts.anybody(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(width: 24),
                                ],
                                if (activity['avgPace'] != null) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('PACE', style: GoogleFonts.hankenGrotesk(fontSize: 9, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                      Text('$paceStr /km', style: GoogleFonts.anybody(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 5,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  displayImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: _cardBg,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded, color: Colors.white24, size: 48),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.5),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              if (activity != null)
                                Positioned(
                                  bottom: 20,
                                  left: 16,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (activity['distance'] != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activityTitle.toUpperCase(),
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 9.5,
                                                  color: _accent,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              Text(
                                                'DISTANCE',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 8.5,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Text(
                                                '${_parseDistKm(activity['distance']).toStringAsFixed(1)} km',
                                                style: GoogleFonts.anybody(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (activity['avgPace'] != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white10),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'PACE',
                                                style: GoogleFonts.hankenGrotesk(
                                                  fontSize: 9,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Text(
                                                '${_formatPace(activity['avgPace'])} /km',
                                                style: GoogleFonts.anybody(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Interaction Bar (Like, Comment, Share with reduced bottom spacing)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final newLiked = !isLiked;
                        setState(() {
                          if (newLiked) {
                            _likedUserPostIds.add(postId);
                            _unlikedUserPostIds.remove(postId);
                            _userPostLikes[postId] = kudosCount + 1;
                          } else {
                            _likedUserPostIds.remove(postId);
                            _unlikedUserPostIds.add(postId);
                            _userPostLikes[postId] = (kudosCount - 1).clamp(0, 999999);
                          }
                        });
                        // Roll the optimistic update back if the server rejects it.
                        final ok = await ApiService.setLiked(postId, newLiked);
                        if (!ok && mounted) {
                          setState(() {
                            if (newLiked) {
                              _likedUserPostIds.remove(postId);
                              _unlikedUserPostIds.add(postId);
                              _userPostLikes[postId] = kudosCount;
                            } else {
                              _likedUserPostIds.add(postId);
                              _unlikedUserPostIds.remove(postId);
                              _userPostLikes[postId] = kudosCount;
                            }
                          });
                        }
                      },
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            color: isLiked ? _accent : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$kudosCount',
                            style: GoogleFonts.hankenGrotesk(
                              color: isLiked ? _accent : Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () => PostDetailScreen.navigate(context, post),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white60,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$commentCount',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white60, size: 20),
                  onPressed: () {
                    SharePlus.instance.share(ShareParams(
                      text: 'Check out this workout post on Fitrybe! 🏃‍♂️🔥',
                    ));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildWeeklyStats() {
    return ValueListenableBuilder<HealthDataSummary>(
      valueListenable: HealthService().healthNotifier,
      builder: (context, health, _) {
        return Container(
          color: const Color(0xFF1B1B1E).withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'WEEKLY PROGRESS',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _currentNavIndex = 2;
                      });
                    },
                    child: Text(
                      'Details',
                      style: GoogleFonts.hankenGrotesk(
                        color: _accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Device health data is authoritative when present; otherwise
              // fall back to workouts recorded through the app itself.
              Builder(builder: (context) {
                // Counted from Monday in the athlete's own days, the same week
                // the health service and the goal rings use. The server's
                // `weekly` block is a rolling seven days, so falling back to it
                // put a different week behind the same three labels.
                final logged = GoalProgress.weekToDateTotals(
                  _analytics['recentActivities'] as List<dynamic>? ?? const [],
                );

                final workouts = health.weeklyWorkoutsCount > 0
                    ? health.weeklyWorkoutsCount
                    : logged.workouts;
                final distanceKm = health.weeklyDistanceKm > 0
                    ? health.weeklyDistanceKm
                    : double.parse(logged.distanceKm.toStringAsFixed(2));
                final calories = health.weeklyCalories > 0
                    ? health.weeklyCalories
                    : logged.calories;

                return Row(
                  children: [
                    Expanded(child: _buildStatsCard('Activities', '$workouts', '')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatsCard('Distance', '$distanceKm', ' km')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildStatsCard('Calories', '$calories', ' kcal')),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(String label, String value, String unit) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _cardBg,
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
              letterSpacing: 0.5,
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
                  color: Colors.white,
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








  void _showPostOptions({
    required BuildContext context,
    required bool isOwnPost,
    required String postId,
    required String authorName,
    required VoidCallback onHide,
  }) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131316),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (isOwnPost) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.white70),
                    title: Text('Edit Post', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _showEditPostDialog(postId);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    title: Text('Delete Post', style: GoogleFonts.hankenGrotesk(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      _deletePost(postId);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent),
                    title: Text('Report Post', style: GoogleFonts.hankenGrotesk(color: Colors.redAccent)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: _accent,
                          content: Text('Thank you. Post reported.', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_off_rounded, color: Colors.white70),
                    title: Text('Mute $authorName', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: _accent,
                          content: Text('You won\'t see posts from $authorName.', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.link_rounded, color: Colors.white70),
                  title: Text('Copy Link', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    Clipboard.setData(const ClipboardData(text: 'https://fitrybe.com/posts/1'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _accent,
                        content: Text('Link copied to clipboard.', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_off_outlined, color: Colors.white70),
                  title: Text('Hide Post', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    onHide();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: _accent,
                        content: Text('Post hidden.', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Edits a post's caption. The dialog is seeded from the loaded feed entry
  /// and the change is persisted before the card is refreshed in place.
  void _showEditPostDialog(String postId) {
    final post = _backendPosts.firstWhere(
      (p) => p['id'] == postId,
      orElse: () => const <String, dynamic>{},
    );
    if (post.isEmpty) return;

    final controller =
        TextEditingController(text: '${post['caption'] ?? ''}');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          title: Text(
            'Edit Post',
            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: TextField(
            controller: controller,
            maxLines: 4,
            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Edit your post...',
              hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Cancel', style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _saveEditedCaption(postId, controller.text.trim());
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: Text('Save', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveEditedCaption(String postId, String caption) async {
    if (caption.isEmpty) return;
    try {
      final updated = await ApiService.updatePost(postId, caption: caption);
      if (!mounted || updated == null) return;
      setState(() {
        final index = _backendPosts.indexWhere((p) => p['id'] == postId);
        if (index != -1) _backendPosts[index] = updated;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _cardBg,
          content: Text(
            e is ApiException ? e.message : 'Could not save your changes.',
            style: GoogleFonts.hankenGrotesk(color: Colors.white70),
          ),
        ),
      );
    }
  }

  /// Deletes a post server-side, then drops it from the feed. Previously this
  /// only removed it from an in-memory store the feed no longer used, so the
  /// post reported as deleted and came straight back on refresh.
  Future<void> _deletePost(String postId) async {
    final ok = await ApiService.deletePost(postId);
    if (!mounted) return;
    if (ok) {
      setState(() => _backendPosts.removeWhere((p) => p['id'] == postId));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? _accent : _cardBg,
        content: Text(
          ok ? 'Post deleted.' : 'Could not delete this post.',
          style: GoogleFonts.hankenGrotesk(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final posts = _matchingPosts;
    final users = _searchedUsers;

    if (_isSearchLoading && users.isEmpty && posts.isEmpty) {
      return const LoadingStateView(message: 'Searching…');
    }

    if (users.isEmpty && posts.isEmpty) {
      return EmptyStateView(
        icon: Icons.search_off_rounded,
        title: 'Nothing matched',
        message: 'No athletes or posts found for "$_searchQuery".',
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        if (users.isNotEmpty) ...[
          _buildSearchSectionHeader('ATHLETES', users.length),
          ...users.map(_buildSearchUserRow),
        ],
        if (posts.isNotEmpty) ...[
          _buildSearchSectionHeader('POSTS', posts.length),
          ...posts.map(_buildBackendPostCard),
        ],
      ],
    );
  }

  Widget _buildSearchSectionHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        '$label · $count',
        style: GoogleFonts.hankenGrotesk(
          color: Colors.white38,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSearchUserRow(Map<String, dynamic> user) {
    final userId = '${user['id'] ?? ''}';
    final name =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    final displayName = name.isEmpty ? 'Fitrybe Athlete' : name;
    final subtitle = (user['location'] as String?)?.trim().isNotEmpty == true
        ? user['location'] as String
        : ((user['bio'] as String?)?.trim().isNotEmpty == true
            ? user['bio'] as String
            : 'Fitrybe community');
    // The server reports the real relationship; local toggles win once tapped.
    final isFollowing = _followedUsers.contains(userId) ||
        (user['isFollowing'] == true && !_unfollowedUsers.contains(userId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => UserProfileScreen.navigate(context, userId),
            child: UserAvatar(
              url: ApiService.media(user['avatarUrl'] as String?),
              fallbackName: displayName,
              radius: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => UserProfileScreen.navigate(context, userId),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () => _toggleFollow(userId, !isFollowing),
            style: TextButton.styleFrom(
              backgroundColor:
                  isFollowing ? Colors.transparent : _accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isFollowing ? Colors.white24 : Colors.transparent,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: GoogleFonts.hankenGrotesk(
                color: isFollowing ? Colors.white70 : Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Optimistically flips the follow state, reverting if the server refuses.
  Future<void> _toggleFollow(String userId, bool follow) async {
    HapticFeedback.lightImpact();
    setState(() {
      if (follow) {
        _followedUsers.add(userId);
        _unfollowedUsers.remove(userId);
      } else {
        _followedUsers.remove(userId);
        _unfollowedUsers.add(userId);
      }
    });
    final ok = await ApiService.setFollowing(userId, follow);
    if (!mounted || ok) return;
    setState(() {
      if (follow) {
        _followedUsers.remove(userId);
      } else {
        _unfollowedUsers.remove(userId);
      }
    });
  }

  static String _formatPace(dynamic rawPace) {
    if (rawPace == null) return '0:00';
    final str = rawPace.toString().trim();
    if (str.isEmpty) return '0:00';
    if (str.contains(':')) return str;
    final numVal = double.tryParse(str);
    if (numVal == null || numVal <= 0 || numVal.isInfinite || numVal.isNaN) return '0:00';
    final mins = numVal.floor();
    final secs = ((numVal - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  static double _parseDistKm(dynamic distVal) {
    final num? val = (distVal as num?);
    if (val == null) return 0.0;
    final d = val.toDouble();
    return d > 100 ? d / 1000.0 : d;
  }

  Widget _buildGrowYourTrybeSection() {
    return Container(
      color: const Color(0xFF1B1B1E).withValues(alpha: 0.3),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _currentNavIndex = 1;
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Grow your trybe',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: _accent, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_suggestedUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                "You're following everyone on Fitrybe right now. Check back as the community grows.",
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white30,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _suggestedUsers.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final user = _suggestedUsers[index];
                  final name =
                      '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
                          .trim();
                  return _buildRecommendationCard(
                    user['id'] as String,
                    name.isEmpty ? 'Fitrybe Athlete' : name,
                    (user['location'] as String?) ?? 'Fitrybe community',
                    ApiService.media(user['avatarUrl'] as String?),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(
    String userId,
    String name,
    String location,
    String? imgUrl,
  ) {
    final isFollowing = _followedUsers.contains(userId);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => UserProfileScreen.navigate(context, userId),
            child: Column(
              children: [
                UserAvatar(url: imgUrl, fallbackName: name, radius: 28),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  location.toUpperCase(),
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final shouldFollow = !isFollowing;
                setState(() {
                  if (shouldFollow) {
                    _followedUsers.add(userId);
                  } else {
                    _followedUsers.remove(userId);
                  }
                });
                final ok = await ApiService.setFollowing(userId, shouldFollow);
                if (!ok && mounted) {
                  // Revert so the button never lies about server state.
                  setState(() {
                    if (shouldFollow) {
                      _followedUsers.remove(userId);
                    } else {
                      _followedUsers.add(userId);
                    }
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isFollowing ? Colors.white12 : _accent,
                foregroundColor: isFollowing ? Colors.white : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
                elevation: 0,
              ),
              child: Text(
                isFollowing ? 'Following' : 'Follow',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131316).withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Row(
        children: [
          Expanded(child: _buildNavItem(0, Symbols.home_rounded, 'Home')),
          Expanded(child: _buildNavItem(1, Symbols.group_rounded, 'Trybes')),
          Expanded(child: _buildNavItem(2, Symbols.directions_run_rounded, 'Activity')),
          Expanded(child: _buildNavItem(3, Symbols.monitor_heart_rounded, 'Clique')),
          Expanded(
            child: _buildNavItem(4, Symbols.notifications_rounded, 'Notification',
                showBadge: true),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label,
      {bool showBadge = false}) {
    final active = _currentNavIndex == index;
    final inactive = Colors.white.withValues(alpha: 0.45);

    return Semantics(
      selected: active,
      button: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentNavIndex = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  fill: 1.0,
                  weight: 700,
                  grade: 200,
                  opticalSize: 24,
                  color: active ? Colors.white : inactive,
                ),
                if (showBadge)
                  Positioned(
                    top: -4,
                    right: -6,
                    child: ValueListenableBuilder<int>(
                      valueListenable: NotificationService().unreadCount,
                      builder: (context, count, _) {
                        if (count <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          constraints: const BoxConstraints(minWidth: 17),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                                color: const Color(0xFF131316), width: 1.5),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}
