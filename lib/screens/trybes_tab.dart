import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'chat_detail_screen.dart';
import 'trybe_detail_screen.dart';
import 'create_trybe_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';

class TrybesTab extends StatefulWidget {
  final ValueChanged<int> onSubTabChanged;
  const TrybesTab({super.key, required this.onSubTabChanged});

  @override
  State<TrybesTab> createState() => _TrybesTabState();
}

class _TrybesTabState extends State<TrybesTab> with TickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);

  // States
  int _activeSubTab = 0; // 0: Trybe, 1: Friends
  String _friendSearchQuery = '';
  final TextEditingController _friendSearchController = TextEditingController();
  String _trybeSearchQuery = '';
  final TextEditingController _trybeSearchController = TextEditingController();

  List<Map<String, dynamic>> _myTrybes = [];
  List<Map<String, dynamic>> _discoverTrybes = [];
  List<Map<String, dynamic>> _trybeFeedPosts = [];
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _discoverUsers = [];

  bool _isTrybesLoading = true;
  bool _isFriendsLoading = true;
  String? _trybesError;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadTrybeTab();
    _loadFriendsTab();
  }

  Future<void> _loadTrybeTab() async {
    if (mounted) setState(() => _trybesError = null);
    try {
      final query = _trybeSearchQuery.trim();
      final results = await Future.wait([
        ApiService.getTrybes(mine: true, search: query.isEmpty ? null : query),
        ApiService.getTrybes(search: query.isEmpty ? null : query),
      ]);
      final mine = results[0];
      final all = results[1];

      // Feed the Trybe tab from the groups the user actually belongs to.
      final feedSourceId = mine.isNotEmpty ? mine.first['id'] as String? : null;
      final feed = feedSourceId == null
          ? <Map<String, dynamic>>[]
          : await ApiService.getTrybePosts(feedSourceId);

      if (!mounted) return;
      setState(() {
        _myTrybes = mine;
        // "Local Groups" is the discovery rail: everything not already joined.
        _discoverTrybes = all.where((t) => t['isMember'] != true).toList();
        _trybeFeedPosts = feed;
        _isTrybesLoading = false;
      });
    } catch (e) {
      debugPrint('TrybesTab load error: $e');
      if (!mounted) return;
      setState(() {
        _isTrybesLoading = false;
        _trybesError = 'We could not load your Trybes. Pull down to retry.';
      });
    }
  }

  Future<void> _loadFriendsTab() async {
    final userId = SessionService().userId;
    if (userId == null) {
      if (mounted) setState(() => _isFriendsLoading = false);
      return;
    }
    final results = await Future.wait([
      ApiService.getFollowing(userId),
      ApiService.searchUsers('', suggested: true, limit: 10),
    ]);
    if (!mounted) return;
    setState(() {
      _friends = results[0];
      _discoverUsers = results[1];
      _isFriendsLoading = false;
    });
  }

  /// Re-queries the server a beat after typing stops so each keystroke does
  /// not fire its own request.
  void _onTrybeSearchChanged(String value) {
    setState(() => _trybeSearchQuery = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _loadTrybeTab);
  }

  /// Pulls a display name off the varied user shapes the API returns.
  static String _nameOf(Map<String, dynamic>? user) {
    if (user == null) return 'Fitrybe Athlete';
    final name =
        '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return name.isEmpty ? 'Fitrybe Athlete' : name;
  }



  @override
  void dispose() {
    _searchDebounce?.cancel();
    _friendSearchController.dispose();
    _trybeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
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
                    Expanded(child: _buildSubTabItem(0, 'Trybe')),
                    Expanded(child: _buildSubTabItem(1, 'Friends')),
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
          _activeSubTab == 0
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: _cardBg.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _trybeSearchController,
                                onChanged: _onTrybeSearchChanged,
                                style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search trybes and groups...',
                                  hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_trybeSearchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _trybeSearchController.clear();
                                  _onTrybeSearchChanged('');
                                },
                                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isTrybesLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: LoadingStateView(),
                      )
                    else if (_trybesError != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: ErrorStateView(
                          message: _trybesError!,
                          onRetry: _loadTrybeTab,
                        ),
                      )
                    else if (_trybeSearchQuery.isNotEmpty &&
                        _myTrybes.isEmpty &&
                        _discoverTrybes.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: EmptyStateView(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message:
                              'No Trybes match "$_trybeSearchQuery". Try a different name, sport, or city.',
                        ),
                      )
                    else ...[
                      // Section 2: My Trybes Carousel
                      _buildMyTrybesSection(),
                      const SizedBox(height: 24),

                      // Section 3: Local Groups
                      _buildLocalGroupsSection(),
                      const SizedBox(height: 24),

                      // Section 4: Trybe Feed
                      _buildTrybeFeedSection(),
                    ],
                    const SizedBox(height: 100), // Padding for mobile floating navigation
                  ],
                )
              : _buildFriendsTabSection(),
        ],
      ),
    ),
  );
}

  Widget _buildMyTrybesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Text(
            'My Trybes',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_myTrybes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              icon: Icons.groups_rounded,
              title: 'You have not joined a Trybe yet',
              message:
                  'Trybes are training groups you join with friends. Browse the groups below or start your own.',
              actionLabel: 'Create a Trybe',
              onAction: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateTrybeScreen()),
                );
                _loadTrybeTab();
              },
            ),
          )
        else
          SizedBox(
          height: 260,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final trybe in _myTrybes) ...[
                _buildTrybeCarouselCard(
                  trybe['id'] as String?,
                  '${trybe['name'] ?? 'Trybe'}',
                  ApiService.media(trybe['imageUrl'] as String?),
                  '${trybe['memberCount'] ?? 1} members',
                  '${trybe['category'] ?? 'Fitrybe'}',
                ),
                const SizedBox(width: 14),
              ],
              // Card 3: Join New Action Card
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateTrybeScreen()),
                  );
                  _loadTrybeTab();
                },
                child: Container(
                  width: 140,
                  decoration: BoxDecoration(
                    color: _cardBg.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: _accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, color: _accent, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'JOIN NEW',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white70,
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrybeCarouselCard(
    String? trybeId,
    String title,
    String? imageUrl,
    String members,
    String active,
  ) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrybeDetailScreen(
              trybeId: trybeId,
              title: title,
              imageUrl: imageUrl,
              memberCount: members,
            ),
          ),
        );
        _loadTrybeTab();
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(23),
          child: Stack(
            children: [
              // Photo background — Trybes without a cover fall back to a tint.
              Positioned.fill(
                child: imageUrl == null
                    ? Container(color: _accent.withValues(alpha: 0.18))
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _accent.withValues(alpha: 0.18)),
                      ),
              ),
              // Dark gradient overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
              // Card Details bottom
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
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
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.group_rounded, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          members,
                          style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 11),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.emoji_events_rounded, color: _accent, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          active,
                          style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 11),
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
    );
  }

  Widget _buildLocalGroupsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Local Groups',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => _showAllLocalGroupsModal(context),
                child: Text(
                  'SEE ALL',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_discoverTrybes.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              icon: Icons.explore_rounded,
              title: 'No groups to discover',
              message:
                  "You've joined every Trybe on Fitrybe. Create a new one to bring more athletes together.",
            )
          else
            // Preview the first few; "SEE ALL" opens the searchable list.
            for (final trybe in _discoverTrybes.take(2)) ...[
              _buildLocalGroupRow(
                trybe['id'] as String?,
                '${trybe['name'] ?? 'Trybe'}',
                ApiService.media(trybe['imageUrl'] as String?),
                _trybeSubtitle(trybe),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  /// "San Francisco, CA • 42 members" style line under a Trybe name.
  static String _trybeSubtitle(Map<String, dynamic> trybe) {
    final location = (trybe['location'] as String?)?.trim();
    final members = '${trybe['memberCount'] ?? 0} members';
    return (location == null || location.isEmpty)
        ? members
        : '$location • $members';
  }

  void _showAllLocalGroupsModal(BuildContext context) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) {
        // Seeded with what the tab already loaded, then re-queried server-side
        // as the user types so the whole directory is searchable.
        List<Map<String, dynamic>> filtered = _discoverTrybes;
        Timer? debounce;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
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
                        'All Local Groups',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(modalCtx),
                        child: const Icon(Icons.close, color: Colors.white54, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Search box inside modal
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              debounce?.cancel();
                              debounce = Timer(
                                const Duration(milliseconds: 350),
                                () async {
                                  final results = await ApiService.getTrybes(
                                    search: val.trim().isEmpty ? null : val.trim(),
                                    limit: 50,
                                  );
                                  filtered = results
                                      .where((t) => t['isMember'] != true)
                                      .toList();
                                  setModalState(() {});
                                },
                              );
                            },
                            style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 13.5),
                            decoration: InputDecoration(
                              hintText: 'Search local groups...',
                              hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 13.5),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyStateView(
                            icon: Icons.search_off_rounded,
                            title: 'No groups found',
                            message:
                                'Try a different name, sport, or city — or create the group yourself.',
                          )
                        : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, idx) {
                        final grp = filtered[idx];
                        final grpImage =
                            ApiService.media(grp['imageUrl'] as String?);
                        return GestureDetector(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            Navigator.pop(modalCtx);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TrybeDetailScreen(
                                  trybeId: grp['id'] as String?,
                                  title: '${grp['name'] ?? 'Trybe'}',
                                  imageUrl: grpImage,
                                  memberCount: _trybeSubtitle(grp),
                                  location: (grp['location'] as String?) ??
                                      'Public group',
                                ),
                              ),
                            );
                            _loadTrybeTab();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: grpImage == null
                                        ? Container(
                                            color: _accent.withValues(alpha: 0.18),
                                            child: Icon(Icons.groups_rounded,
                                                color: _accent, size: 22),
                                          )
                                        : Image.network(
                                            grpImage,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              color: _accent.withValues(alpha: 0.18),
                                              child: Icon(Icons.groups_rounded,
                                                  color: _accent, size: 22),
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${grp['name'] ?? 'Trybe'}',
                                        style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _trybeSubtitle(grp),
                                        style: GoogleFonts.hankenGrotesk(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
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

  Widget _buildLocalGroupRow(
    String? trybeId,
    String title,
    String? imageUrl,
    String stats,
  ) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TrybeDetailScreen(
              trybeId: trybeId,
              title: title,
              imageUrl: imageUrl,
              memberCount: stats,
              location: 'Local Group • Public',
            ),
          ),
        );
        _loadTrybeTab();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 52,
                child: imageUrl == null
                    ? Container(
                        color: _accent.withValues(alpha: 0.18),
                        child: Icon(Icons.groups_rounded, color: _accent, size: 22),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _accent.withValues(alpha: 0.18),
                          child: Icon(Icons.groups_rounded,
                              color: _accent, size: 22),
                        ),
                      ),
              ),
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
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stats,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _accent, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildTrybeFeedSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Feed Header
          Text(
            'Trybe Feed',
            style: GoogleFonts.hankenGrotesk(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (_trybeFeedPosts.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              icon: Icons.forum_rounded,
              title: _myTrybes.isEmpty
                  ? 'Join a Trybe to see its feed'
                  : 'No posts in your Trybe yet',
              message: _myTrybes.isEmpty
                  ? 'Once you join a group, workouts and milestones your teammates share appear here.'
                  : 'Be the first to share a workout with your teammates.',
            )
          else
            for (final post in _trybeFeedPosts) ...[
              _buildTrybePostCard(post),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  /// Compact feed card for a post shared inside one of the user's Trybes.
  Widget _buildTrybePostCard(Map<String, dynamic> post) {
    final author = (post['author'] is Map)
        ? Map<String, dynamic>.from(post['author'])
        : <String, dynamic>{};
    final activity = (post['activity'] is Map)
        ? Map<String, dynamic>.from(post['activity'])
        : null;
    final counts = (post['_count'] is Map)
        ? Map<String, dynamic>.from(post['_count'])
        : <String, dynamic>{};
    final images = (post['imageUrls'] is List)
        ? List<dynamic>.from(post['imageUrls'])
        : const [];
    final heroImage =
        images.isEmpty ? null : ApiService.media('${images.first}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(
                url: ApiService.media(author['avatarUrl'] as String?),
                fallbackName: _nameOf(author),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameOf(author),
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_relativeTime(post['createdAt'])} • ${post['type'] ?? 'Update'}',
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if ('${post['caption'] ?? ''}'.isNotEmpty)
            Text(
              '${post['caption']}',
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white70,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          if (heroImage != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                heroImage,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (activity != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.route_rounded, color: _accent, size: 15),
                const SizedBox(width: 6),
                Text(
                  '${((activity['distance'] as num? ?? 0) / 1000).toStringAsFixed(2)} km',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(Icons.local_fire_department_rounded,
                    color: _accent, size: 15),
                const SizedBox(width: 6),
                Text(
                  '${activity['calories'] ?? 0} kcal',
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.favorite_outline_rounded,
                  color: Colors.white60, size: 18),
              const SizedBox(width: 6),
              Text(
                '${counts['likes'] ?? 0}',
                style: GoogleFonts.hankenGrotesk(
                    color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(width: 18),
              const Icon(Icons.chat_bubble_outline_rounded,
                  color: Colors.white60, size: 17),
              const SizedBox(width: 6),
              Text(
                '${counts['comments'] ?? 0}',
                style: GoogleFonts.hankenGrotesk(
                    color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Condenses a timestamp into the "2h ago" style used across the app.
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

  Widget _buildSubTabItem(int index, String label) {
    final bool isActive = _activeSubTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _activeSubTab = index;
        });
        widget.onSubTabChanged(index);
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

  Widget _buildFriendsTabSection() {
    final filteredFriends = _friends.where((friend) {
      return _nameOf(friend)
          .toLowerCase()
          .contains(_friendSearchQuery.toLowerCase());
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Squad & Friends',
                style: GoogleFonts.hankenGrotesk(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_friends.length} Following',
                  style: GoogleFonts.hankenGrotesk(
                    color: _accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search Friends Bar
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: _cardBg.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white38, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _friendSearchController,
                    onChanged: (val) {
                      setState(() {
                        _friendSearchQuery = val;
                      });
                    },
                    style: GoogleFonts.hankenGrotesk(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search friends by name or trybe...',
                      hintStyle: GoogleFonts.hankenGrotesk(color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_friendSearchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _friendSearchController.clear();
                      setState(() {
                        _friendSearchQuery = '';
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.white54, size: 18),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isFriendsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: LoadingStateView(),
            )
          else if (filteredFriends.isEmpty)
            EmptyStateView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              icon: Icons.person_add_alt_1_rounded,
              title: _friendSearchQuery.isNotEmpty
                  ? 'No match'
                  : 'You are not following anyone yet',
              message: _friendSearchQuery.isNotEmpty
                  ? 'No one you follow matches "$_friendSearchQuery".'
                  : 'Follow athletes to see their workouts and message them here.',
            )
          else
            ...filteredFriends.map((friend) => _buildFriendListRow(friend)),

          const SizedBox(height: 24),

          // Discover Friends Section
          _buildSectionHeader('Discover Athletes'),
          const SizedBox(height: 12),
          if (_discoverUsers.isEmpty)
            Text(
              'No new athletes to discover right now.',
              style: GoogleFonts.hankenGrotesk(
                  color: Colors.white38, fontSize: 12.5),
            )
          else
            for (final user in _discoverUsers) ...[
              _buildDiscoverCard(user),
              const SizedBox(height: 10),
            ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.hankenGrotesk(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFriendListRow(Map<String, dynamic> friend) {
    final name = _nameOf(friend);
    final avatar = ApiService.media(friend['avatarUrl'] as String?);
    final location = (friend['location'] as String?)?.trim();
    final bio = (friend['bio'] as String?)?.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          UserAvatar(url: avatar, fallbackName: name, radius: 23),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (location == null || location.isEmpty)
                      ? 'Fitrybe athlete'
                      : location,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white38,
                    fontSize: 11.5,
                  ),
                ),
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    bio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white54,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  // Open (or create) the direct conversation with this athlete.
                  final conversationId = await ApiService.createConversation(
                    userId: friend['id'] as String?,
                  );
                  if (!mounted || conversationId == null) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailScreen(
                        chatId: conversationId,
                        name: name,
                        avatar: avatar,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C2C30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white70, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoverCard(Map<String, dynamic> user) {
    final userId = user['id'] as String?;
    final name = _nameOf(user);
    final avatar = ApiService.media(user['avatarUrl'] as String?);
    final location = (user['location'] as String?)?.trim();
    final subtitle = (location == null || location.isEmpty)
        ? 'Fitrybe community'
        : location;
    bool hasAdded = user['isFollowing'] == true;

    return StatefulBuilder(
      builder: (context, setCardState) {
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.02)),
          ),
          child: Row(
            children: [
              UserAvatar(url: avatar, fallbackName: name, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (userId == null) return;
                  HapticFeedback.lightImpact();
                  final shouldFollow = !hasAdded;
                  setCardState(() => hasAdded = shouldFollow);

                  final ok =
                      await ApiService.setFollowing(userId, shouldFollow);
                  if (!ok) {
                    setCardState(() => hasAdded = !shouldFollow);
                    return;
                  }
                  // Refresh so the athlete moves into the friends list.
                  _loadFriendsTab();
                  if (!mounted || !shouldFollow) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: _accent,
                      content: Text(
                        'Now following $name!',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasAdded ? Colors.white10 : _accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAdded ? Colors.transparent : _accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    hasAdded ? 'Following' : 'Follow',
                    style: GoogleFonts.hankenGrotesk(
                      color: hasAdded ? Colors.white38 : _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final int count;
  final VoidCallback onTap;

  const _AnimatedLikeButton({
    required this.isLiked,
    required this.count,
    required this.onTap,
  });

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.45), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFFFF5722);
    return GestureDetector(
      onTap: _handleTap,
      child: Row(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_outline_rounded,
              color: widget.isLiked ? accentColor : Colors.white60,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              '${widget.count} Likes',
              key: ValueKey(widget.count),
              style: GoogleFonts.hankenGrotesk(
                color: widget.isLiked ? accentColor : Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
