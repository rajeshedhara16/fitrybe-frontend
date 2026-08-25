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
import 'subscription_screen.dart';
import 'messaging_screen.dart';
import 'welcome_screen.dart';
import '../models/post_store.dart';
import '../services/socket_service.dart';
import '../services/post_service.dart';
import '../services/api_client.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import '../services/session_service.dart';
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
  final Set<String> _hiddenUserPostIds = {};

  /// Comment threads keyed by post id, filled from the API on demand.
  final Map<String, List<Map<String, String>>> _postComments = {};

  final Map<String, int> _userPostLikes = {};
  final Set<String> _likedUserPostIds = {};

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Map<String, dynamic>> _backendPosts = [];
  List<Map<String, dynamic>> _suggestedUsers = [];
  Map<String, dynamic> _analytics = const {};
  bool _isFeedLoading = true;
  String? _feedError;

  @override
  void initState() {
    super.initState();
    SocketService().connect();
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
      final posts = await PostService().fetchFeed();
      if (!mounted) return;
      setState(() {
        _backendPosts = posts;
        _isFeedLoading = false;
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search activities, trybes...',
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
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _isSearching = false;
                        });
                      },
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
                                          _showSettingsBottomSheet(context);
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



  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131316),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF131316),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
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
                  const SizedBox(height: 24),
                  Text(
                    'Settings',
                    style: GoogleFonts.anybody(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSettingsItem(
                    Icons.stars_rounded,
                    'Trybe Pro Premium',
                    () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubscriptionScreen(),
                        ),
                      );
                    },
                    color: _accent,
                  ),
                  _buildSettingsItem(
                    Icons.person_outline_rounded,
                    'Account Settings',
                    () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingsItem(
                    Icons.notifications_none_rounded,
                    'Notifications',
                    () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingsItem(
                    Icons.privacy_tip_outlined,
                    'Privacy & Sharing',
                    () {
                      Navigator.pop(context);
                    },
                  ),
                  _buildSettingsItem(
                    Icons.help_outline_rounded,
                    'Help & Support',
                    () {
                      Navigator.pop(context);
                    },
                  ),
                  const Divider(color: Colors.white10, height: 24),
                  _buildSettingsItem(
                    Icons.logout_rounded,
                    'Log Out',
                    () async {
                      final nav = Navigator.of(context);
                      nav.pop();
                      await ApiClient().clearTokens();
                      nav.pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (route) => false,
                      );
                    },
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.white70}) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: GoogleFonts.hankenGrotesk(
          color: color,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 18),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentNavIndex) {
      case 0:
        return RefreshIndicator(
          onRefresh: _loadBackendFeed,
          color: _accent,
          backgroundColor: _cardBg,
          child: ListenableBuilder(
            listenable: PostStore.instance,
            builder: (context, _) {
              final userPosts = PostStore.instance.posts.where((p) => !_hiddenUserPostIds.contains(p.id)).toList();
              final visiblePosts = _backendPosts
                  .where((p) => !_hiddenUserPostIds.contains(p['id']))
                  .toList();
              final hasNoPosts = userPosts.isEmpty && visiblePosts.isEmpty;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWeeklyStats(),
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
                    else if (hasNoPosts)
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
                    else ...[
                      ...userPosts.map((post) => _buildDynamicUserPost(post)),
                      ...visiblePosts.map((bPost) => _buildBackendPostCard(bPost)),
                    ],
                    _buildGrowYourTrybeSection(),
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
    final String postType = (post['type'] ?? 'Workout').toString();
    final String locationTag = post['locationTag'] ?? 'Fitrybe Feed';

    final bool isLiked = _likedUserPostIds.contains(postId) || (post['likedByMe'] == true);
    final int kudosCount = (_userPostLikes[postId] ?? (post['likeCount'] as int? ?? 0));
    final List commentsList = _postComments[postId] ?? [];

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                UserAvatar(
                  url: avatarUrl,
                  fallbackName: authorName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
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

          const SizedBox(height: 16),

          // Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${postType.toUpperCase()} SESSION 🔥',
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Activity image, resolved against the configured API host.
          Builder(
            builder: (context) {
              final String? displayImageUrl = imageUrls.isEmpty
                  ? null
                  : ApiService.media('${imageUrls.first}');

              return AspectRatio(
                aspectRatio: 4 / 5,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: displayImageUrl == null
                          ? Container(
                              color: _cardBg,
                              child: const Center(
                                child: Icon(Icons.directions_run_rounded,
                                    color: Colors.white24, size: 48),
                              ),
                            )
                          : Image.network(
                              displayImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: _cardBg,
                                child: const Center(
                                  child: Icon(Icons.directions_run_rounded, color: Colors.white24, size: 48),
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
                    Positioned(
                      bottom: 24,
                      left: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DISTANCE',
                                  style: GoogleFonts.hankenGrotesk(
                                    fontSize: 9,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${activity != null ? ((activity['distance'] ?? 0) / 1000.0).toStringAsFixed(1) : '7.0'} km',
                                  style: GoogleFonts.anybody(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
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
                                  '${activity != null ? (activity['avgPace'] ?? '5:00') : '5.0'} /km',
                                  style: GoogleFonts.anybody(
                                    fontSize: 18,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 24,
                      right: 20,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: _accent,
                        child: const Icon(Icons.map, color: Colors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Interaction Bar (Matching Hardcoded Post UI!)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                            _userPostLikes[postId] = kudosCount + 1;
                          } else {
                            _likedUserPostIds.remove(postId);
                            _userPostLikes[postId] = (kudosCount - 1).clamp(0, 999999);
                          }
                        });
                        // Roll the optimistic update back if the server rejects it.
                        final ok = await ApiService.setLiked(postId, newLiked);
                        if (!ok && mounted) {
                          setState(() {
                            if (newLiked) {
                              _likedUserPostIds.remove(postId);
                              _userPostLikes[postId] = kudosCount;
                            } else {
                              _likedUserPostIds.add(postId);
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
                          const SizedBox(width: 8),
                          Text(
                            '$kudosCount Likes',
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
                      onTap: () => _showCommentsBottomSheet(context, postId),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white60,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${commentsList.length} Comments',
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
                    Share.share('Check out this workout post on Fitrybe! 🏃‍♂️🔥');
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
                final weekly = (_analytics['weekly'] is Map)
                    ? Map<String, dynamic>.from(_analytics['weekly'])
                    : const <String, dynamic>{};

                final workouts = health.weeklyWorkoutsCount > 0
                    ? health.weeklyWorkoutsCount
                    : (weekly['workoutCount'] as num? ?? 0).toInt();
                final distanceKm = health.weeklyDistanceKm > 0
                    ? health.weeklyDistanceKm
                    : (weekly['distanceKm'] as num? ?? 0).toDouble();
                final calories = health.weeklyCalories > 0
                    ? health.weeklyCalories
                    : (weekly['calories'] as num? ?? 0).toInt();

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

  int _getCommentCount(String postId) {
    return _postComments[postId]?.length ?? 0;
  }

  /// Condenses a timestamp into the "2h ago" style the feed already uses.
  static String _relativeTime(dynamic isoString) {
    final parsed = DateTime.tryParse('${isoString ?? ''}');
    if (parsed == null) return 'Just now';
    final diff = DateTime.now().difference(parsed);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  /// Flattens an API comment into the flat map the sheet renders.
  Map<String, String> _normalizeComment(Map<String, dynamic> raw) {
    final author = (raw['author'] is Map)
        ? Map<String, dynamic>.from(raw['author'])
        : const <String, dynamic>{};
    final name =
        '${author['firstName'] ?? ''} ${author['lastName'] ?? ''}'.trim();
    return {
      'author': name.isEmpty ? 'Fitrybe Athlete' : name,
      'avatar': ApiService.media(author['avatarUrl'] as String?) ?? '',
      'text': '${raw['text'] ?? ''}',
      'time': _relativeTime(raw['createdAt']),
    };
  }

  void _showCommentsBottomSheet(BuildContext context, String postId) {
    final textController = TextEditingController();
    final scrollController = ScrollController();
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF131316),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        bool isLoading = true;
        bool isSending = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final comments = _postComments[postId] ?? [];

            // Pull the real thread the first time the sheet is laid out.
            if (isLoading) {
              ApiService.getComments(postId).then((fetched) {
                if (!mounted) return;
                final mapped = fetched.map(_normalizeComment).toList();
                setState(() => _postComments[postId] = mapped);
                isLoading = false;
                setSheetState(() {});
              }).catchError((_) {
                isLoading = false;
                setSheetState(() {});
              });
            }

            Future<void> submitComment() async {
              final text = textController.text.trim();
              if (text.isEmpty || isSending) return;
              HapticFeedback.lightImpact();
              isSending = true;
              setSheetState(() {});

              final created = await ApiService.addComment(postId, text);
              if (!mounted) return;
              if (created != null) {
                setState(() {
                  _postComments
                      .putIfAbsent(postId, () => [])
                      .add(_normalizeComment(created));
                });
                textController.clear();
              }
              isSending = false;
              setSheetState(() {});

              Timer(const Duration(milliseconds: 100), () {
                if (scrollController.hasClients) {
                  scrollController.animateTo(
                    scrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments (${comments.length})',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white10),
                  Expanded(
                    child: isLoading
                        ? const LoadingStateView()
                        : comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet. Be the first to comment!',
                              style: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: comments.length,
                            itemBuilder: (context, index) {
                              final comment = comments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 20.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    UserAvatar(
                                      url: comment['avatar'],
                                      fallbackName: comment['author'],
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                comment['author'] ?? 'User',
                                                style: GoogleFonts.hankenGrotesk(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                comment['time'] ?? 'Just now',
                                                style: GoogleFonts.hankenGrotesk(
                                                  color: Colors.white30,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            comment['text'] ?? '',
                                            style: GoogleFonts.hankenGrotesk(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color(0xFF131316),
                    child: Row(
                      children: [
                        UserAvatar(
                          url: SessionService().avatarUrl,
                          fallbackName: SessionService().displayName,
                          radius: 16,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(21),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: textController,
                                    style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Add a comment...',
                                      hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white30, fontSize: 13),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: submitComment,
                                  child: isSending
                                      ? SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _accent,
                                          ),
                                        )
                                      : Icon(Icons.send_rounded,
                                          color: _accent, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
                      PostStore.instance.removePost(postId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: _accent,
                          content: Text('Post deleted.', style: GoogleFonts.hankenGrotesk(color: Colors.white)),
                        ),
                      );
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

  void _showEditPostDialog(String postId) {
    final posts = PostStore.instance.posts;
    final post = posts.firstWhere((p) => p.id == postId);
    final controller = TextEditingController(text: post.caption);

    showDialog(
      context: context,
      builder: (context) {
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
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.hankenGrotesk(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final newCaption = controller.text.trim();
                if (newCaption.isNotEmpty) {
                  PostStore.instance.removePost(postId);
                  PostStore.instance.addPost(
                    UserPost(
                      id: postId,
                      caption: newCaption,
                      type: post.type,
                      audience: post.audience,
                      locationTag: post.locationTag,
                      imagePaths: post.imagePaths,
                      createdAt: post.createdAt,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              child: Text('Save', style: GoogleFonts.hankenGrotesk(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDynamicUserPost(UserPost post) {
    final bool isLiked = _likedUserPostIds.contains(post.id);
    final int likesCount = _userPostLikes[post.id] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                UserAvatar(
                  url: _userProfileUrl,
                  fallbackName: SessionService().displayName,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SessionService().displayName,
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Just now • ${post.type}',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.white54),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    _showPostOptions(
                      context: context,
                      isOwnPost: true,
                      postId: post.id,
                      authorName: SessionService().displayName,
                      onHide: () {
                        setState(() {
                          _hiddenUserPostIds.add(post.id);
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Title & Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${post.type.toUpperCase()} UPDATE 🔥',
                  style: GoogleFonts.anybody(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  post.caption,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Interaction Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_likedUserPostIds.contains(post.id)) {
                            _likedUserPostIds.remove(post.id);
                            _userPostLikes[post.id] = (likesCount - 1).clamp(0, 999999);
                          } else {
                            _likedUserPostIds.add(post.id);
                            _userPostLikes[post.id] = likesCount + 1;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                            color: isLiked ? _accent : Colors.white60,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$likesCount Likes',
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
                      onTap: () => _showCommentsBottomSheet(context, post.id),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.white60,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_getCommentCount(post.id)} Comments',
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
                    Share.share('Check out this workout post on Fitrybe! 🏃‍♂️🔥');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
                separatorBuilder: (_, __) => const SizedBox(width: 14),
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
          Expanded(child: _buildNavItem(4, Symbols.notifications_rounded, 'Notification')),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
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
            Icon(
              icon,
              size: 24,
              fill: 1.0,
              weight: 700,
              grade: 200,
              opticalSize: 24,
              color: active ? Colors.white : inactive,
            ),
          ],
        ),
      ),
    );
  }

}
