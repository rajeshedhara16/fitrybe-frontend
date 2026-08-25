import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_screen.dart';
import 'achievements_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../widgets/state_views.dart';
import '../widgets/user_avatar.dart';
import '../models/achievement_model.dart';
import '../widgets/achievement_badge_widget.dart';
import '../services/health_service.dart';
import '../services/achievement_service.dart';
import 'package:share_plus/share_plus.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);

  // Post Likes state
  final Set<String> _likedProfilePostIds = {};
  final Map<String, int> _profilePostLikesCount = {};

  late AnimationController _streakController;

  Map<String, dynamic> _stats = const {};
  Map<String, dynamic> _analytics = const {};
  List<Map<String, dynamic>> _myPosts = [];
  bool _isLoading = true;

  String? get _bannerUrl => SessionService().bannerUrl;
  String? get _avatarUrl => SessionService().avatarUrl;

  @override
  void initState() {
    super.initState();
    HealthService().fetchTodayHealthData();
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    // Trigger progress circle animation on load
    _streakController.forward();
    _load();
    AchievementService().sync();
  }

  Future<void> _load() async {
    final userId = SessionService().userId;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final results = await Future.wait([
      ApiService.getUserProfile(userId),
      ApiService.getAnalytics(),
      ApiService.getFeed(authorId: userId, limit: 30),
    ]);

    if (!mounted) return;
    final profile = results[0] as Map<String, dynamic>;
    setState(() {
      SessionService().update(profile['user'] as Map<String, dynamic>?);
      _stats = (profile['stats'] as Map?)?.cast<String, dynamic>() ?? const {};
      _analytics = results[1] as Map<String, dynamic>;
      _myPosts = results[2] as List<Map<String, dynamic>>;
      _isLoading = false;
    });
  }

  /// Formats large follower counts as "1.2k".
  static String _compact(num? value) {
    final v = (value ?? 0).toInt();
    if (v < 1000) return '$v';
    return '${(v / 1000).toStringAsFixed(1)}k';
  }

  String? get _location {
    final value = (SessionService().user?['location'] as String?)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? get _bio {
    final value = (SessionService().user?['bio'] as String?)?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String get _joinedLabel {
    final created =
        DateTime.tryParse('${SessionService().user?['createdAt'] ?? ''}');
    if (created == null) return 'New member';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Joined ${months[created.month - 1]} ${created.year}';
  }

  @override
  void dispose() {
    _streakController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Profile Header Banner & Avatar Stack
          _buildProfileHeaderCard(),
          const SizedBox(height: 24),

          // Fitness Summary Title
          Text(
            'Fitness Summary',
            style: GoogleFonts.anybody(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Bento Grid Layout
          _buildBentoGrid(),
          const SizedBox(height: 24),

          // Achievements Showcase
          _buildAchievementsSection(),
          const SizedBox(height: 24),

          // Consistency Heatmap
          _buildConsistencySection(),
          const SizedBox(height: 24),

          // Favorite Activities
          _buildFavoritesSection(),
          const SizedBox(height: 24),

          // My Posts (from PostStore)
          _buildMyPostsSection(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Banner Background Image
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Opacity(
                opacity: 0.3,
                child: _bannerUrl == null
                    ? Container(color: _accent.withValues(alpha: 0.35))
                    : Image.network(
                        _bannerUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: _accent.withValues(alpha: 0.35)),
                      ),
              ),
            ),

            // Content Column
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Avatar
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.2),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: UserAvatar(
                      url: _avatarUrl,
                      fallbackName: SessionService().displayName,
                      radius: 44,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Profile details
                  Text(
                    SessionService().displayName,
                    style: GoogleFonts.anybody(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Metadata tags
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_location != null) ...[
                        const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          _location!,
                          style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                      ],
                      const Icon(Icons.calendar_month_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _joinedLabel,
                        style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bio description
                  Text(
                    _bio ?? 'Add a short bio to tell your Trybe who you are.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      color: _bio == null ? Colors.white38 : Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CTAs
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const EditProfileScreen(),
                              ),
                            );
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _accent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Edit Profile',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                          },
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.share_rounded, color: Colors.white70, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  'Share',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                  const SizedBox(height: 16),

                  // Stats metrics
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeaderStat(
                          _compact(_stats['followerCount'] as num?), 'FOLLOWERS'),
                      _buildHeaderStat(
                          _compact(_stats['followingCount'] as num?), 'FOLLOWING'),
                      _buildHeaderStat(
                          _compact(_stats['postCount'] as num?), 'POSTS'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String num, String label) {
    return Column(
      children: [
        Text(
          num,
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> get _summary =>
      (_analytics['summary'] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Dates (day-precision) on which the athlete recorded an activity.
  Set<DateTime> get _activityDays {
    final raw = (_analytics['recentActivities'] as List?) ?? const [];
    return raw
        .whereType<Map>()
        .map((a) => DateTime.tryParse('${a['createdAt'] ?? ''}')?.toLocal())
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
  }

  /// Consecutive days ending today (or yesterday, so a rest-day-so-far
  /// morning does not read as a broken streak).
  int get _currentStreak {
    final days = _activityDays;
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

  int get _bestStreak {
    final days = _activityDays.toList()..sort();
    if (days.isEmpty) return 0;
    var best = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
        best = run > best ? run : best;
      } else {
        run = 1;
      }
    }
    return best;
  }

  Widget _buildBentoGrid() {
    return ValueListenableBuilder<HealthDataSummary>(
      valueListenable: HealthService().healthNotifier,
      builder: (context, health, _) {
        // Prefer workouts recorded in-app; fall back to device health data.
        final totalDistanceKm =
            (_summary['totalDistanceKm'] as num?)?.toDouble() ??
                health.distanceKm;
        final totalWorkouts = (_summary['totalWorkouts'] as num?)?.toInt() ?? 0;
        final totalHours =
            (_summary['totalDurationHours'] as num?)?.toDouble() ?? 0;

        return Column(
          children: [
            // Total Distance card
            _buildBentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.route_rounded, color: _accent, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'TOTAL DISTANCE',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${health.steps} Steps Today',
                        style: GoogleFonts.hankenGrotesk(
                          color: _accent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      text: '${totalDistanceKm.toStringAsFixed(1)} ',
                      style: GoogleFonts.anybody(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: 'km',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white38,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 10),

        // Row of stats and streak
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left column with Activities & Active Hours
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildBentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ACTIVITIES',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '$totalWorkouts',
                              style: GoogleFonts.anybody(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildBentoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'ACTIVE HOURS',
                              style: GoogleFonts.hankenGrotesk(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${totalHours.toStringAsFixed(1)}h',
                              style: GoogleFonts.anybody(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Right column — Streak card (dark + fire watermark)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cardBg.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.03)),
                  ),
                  child: Stack(
                    children: [
                      // Fire watermark — bottom-right
                      Positioned(
                        right: -8,
                        bottom: -8,
                        child: Opacity(
                          opacity: 0.06,
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            color: _accent,
                            size: 88,
                          ),
                        ),
                      ),

                      // Content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Label
                          Text(
                            'CURRENT STREAK',
                            style: GoogleFonts.hankenGrotesk(
                              color: Colors.white38,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          // Fire icon + streak count
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: _accent,
                                size: 28,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_currentStreak ${_currentStreak == 1 ? 'Day' : 'Days'}',
                                style: GoogleFonts.anybody(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          // Best streak
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Best',
                                style: GoogleFonts.hankenGrotesk(
                                  color: Colors.white38,
                                  fontSize: 9.5,
                                ),
                              ),
                              Text(
                                '$_bestStreak ${_bestStreak == 1 ? 'Day' : 'Days'}',
                                style: GoogleFonts.anybody(
                                  color: Colors.white54,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
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
  },
);
}

  Widget _buildBentoCard({required Widget child, double? height}) {
    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: child,
    );
  }

  Widget _buildAchievementsSection() {
    return ValueListenableBuilder<List<AchievementBadge>>(
      valueListenable: AchievementService().badgesNotifier,
      builder: (context, allBadges, _) =>
          _buildAchievementsContent(allBadges),
    );
  }

  Widget _buildAchievementsContent(List<AchievementBadge> allBadges) {
    final showcaseBadges = allBadges.where((b) => b.unlocked).take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Achievements',
              style: GoogleFonts.anybody(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                );
              },
              child: Text(
                'View All (${showcaseBadges.length > 0 ? allBadges.where((b) => b.unlocked).length : 0}/${allBadges.length})',
                style: GoogleFonts.hankenGrotesk(
                  color: _accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (showcaseBadges.isEmpty)
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            icon: Icons.emoji_events_rounded,
            title: 'No badges yet',
            message:
                'Log workouts, build streaks, and join Trybes to start unlocking badges.',
            actionLabel: 'Browse badges',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AchievementsScreen()),
            ),
          )
        else
        SizedBox(
          height: 154,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: showcaseBadges.length,
            itemBuilder: (context, index) {
              final badge = showcaseBadges[index];
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: AchievementBadgeWidget(
                  badge: badge,
                  size: 72,
                  showLabel: true,
                  showStatusText: false,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AchievementsScreen()),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConsistencySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Training Consistency',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardBg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: Builder(builder: (context) {
                  // Intensity per day = minutes trained that day.
                  final minutesByDay = <DateTime, double>{};
                  for (final entry
                      in (_analytics['recentActivities'] as List? ?? const [])
                          .whereType<Map>()) {
                    final at =
                        DateTime.tryParse('${entry['createdAt'] ?? ''}')?.toLocal();
                    if (at == null) continue;
                    final day = DateTime(at.year, at.month, at.day);
                    minutesByDay[day] = (minutesByDay[day] ?? 0) +
                        ((entry['duration'] as num?) ?? 0) / 60;
                  }

                  const weeks = 32;
                  final today = DateTime.now();
                  final startOfToday =
                      DateTime(today.year, today.month, today.day);
                  // Begin on the Monday that starts the earliest visible week.
                  final firstDay = startOfToday
                      .subtract(Duration(days: (weeks - 1) * 7 + (today.weekday - 1)));

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: weeks,
                    itemBuilder: (context, weekIdx) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (dayIdx) {
                            final day =
                                firstDay.add(Duration(days: weekIdx * 7 + dayIdx));
                            final minutes = day.isAfter(startOfToday)
                                ? null
                                : minutesByDay[day];

                            Color cellColor =
                                const Color(0xFF353438).withValues(alpha: 0.3);
                            if (minutes != null && minutes > 0) {
                              cellColor = switch (minutes) {
                                < 20 => _accent.withValues(alpha: 0.2),
                                < 40 => _accent.withValues(alpha: 0.4),
                                < 70 => _accent.withValues(alpha: 0.7),
                                _ => _accent,
                              };
                            }

                            return Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Less Intense',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                  Row(
                    children: [
                      _buildHeatmapLegendCell(const Color(0xFF353438).withValues(alpha: 0.3)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.2)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent.withValues(alpha: 0.7)),
                      const SizedBox(width: 4),
                      _buildHeatmapLegendCell(_accent),
                    ],
                  ),
                  Text(
                    'More Intense',
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white38,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeatmapLegendCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Icon for an activity type name coming from the API.
  static IconData _iconForActivity(String type) =>
      switch (type.toLowerCase()) {
        'run' || 'running' => Icons.directions_run_rounded,
        'ride' || 'cycling' || 'bike' => Icons.pedal_bike_rounded,
        'walk' || 'walking' => Icons.directions_walk_rounded,
        'hike' || 'hiking' => Icons.hiking_rounded,
        'swim' || 'swimming' => Icons.pool_rounded,
        'yoga' => Icons.self_improvement_rounded,
        _ => Icons.fitness_center_rounded,
      };

  Widget _buildFavoritesSection() {
    // Rank the athlete's own activity types by how often they appear.
    final counts = <String, int>{};
    for (final entry
        in (_analytics['recentActivities'] as List? ?? const []).whereType<Map>()) {
      final type = '${entry['type'] ?? 'Workout'}';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final favorites = ranked
        .take(3)
        .map((e) => {
              'label': e.key,
              'icon': _iconForActivity(e.key),
              'count': '${e.value} ${e.value == 1 ? 'session' : 'sessions'}',
            })
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favorite Activities',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (favorites.isEmpty)
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            icon: Icons.fitness_center_rounded,
            title: 'No activities logged',
            message:
                'Record a workout and your most-trained activities will show up here.',
          )
        else
        Row(
          children: favorites.map((fav) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: _cardBg.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                ),
                child: Column(
                  children: [
                    Icon(fav['icon'] as IconData, color: _accent, size: 20),
                    const SizedBox(height: 6),
                    Text(
                      fav['label'] as String,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fav['count'] as String,
                      style: GoogleFonts.hankenGrotesk(
                        color: Colors.white38,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPostAction(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color ?? Colors.white38, size: 16),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.hankenGrotesk(
                color: color ?? Colors.white38,
                fontWeight: color != null ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── My Posts section ────────────────────────────────────────────────────────
  Widget _buildMyPostsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Posts',
          style: GoogleFonts.anybody(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingStateView(),
          )
        else if (_myPosts.isEmpty)
          EmptyStateView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            icon: Icons.post_add_rounded,
            title: 'You have not posted yet',
            message:
                'Share a workout, a milestone, or a photo and it will appear here.',
          )
        else
          ..._myPosts.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPostCard(post),
              )),
      ],
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    // Type badge color
    final Map<String, Color> typeColors = {
      'Activity': const Color(0xFF4CAF50),
      'Milestone': const Color(0xFFFFB300),
      'Challenge': const Color(0xFFFF5722),
      'Update': const Color(0xFF2196F3),
    };
    final postType = '${post['type'] ?? 'Update'}';
    final postId = '${post['id'] ?? ''}';
    final caption = '${post['caption'] ?? ''}';
    final locationTag = post['locationTag'] as String?;
    final imagePaths = (post['imageUrls'] is List)
        ? List<dynamic>.from(post['imageUrls'])
            .map((u) => ApiService.media('$u'))
            .whereType<String>()
            .toList()
        : <String>[];
    final badgeColor = typeColors[postType] ?? _accent;

    // Relative time
    final createdAt =
        DateTime.tryParse('${post['createdAt'] ?? ''}') ?? DateTime.now();
    final diff = DateTime.now().difference(createdAt);
    String timeAgo;
    if (diff.inMinutes < 1) {
      timeAgo = 'Just now';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              UserAvatar(
                url: _avatarUrl,
                fallbackName: SessionService().displayName,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          SessionService().displayName,
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            postType,
                            style: GoogleFonts.hankenGrotesk(
                              color: badgeColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '$timeAgo • ${postType}',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (locationTag != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.location_on_rounded,
                              color: _accent, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            locationTag,
                            style: GoogleFonts.hankenGrotesk(
                              color: _accent,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Three-dot menu
              PopupMenuButton<String>(
                onSelected: (value) async {
                  HapticFeedback.lightImpact();
                  if (value == 'delete') {
                    // Drop it locally first, then reconcile with the server.
                    setState(() => _myPosts
                        .removeWhere((p) => '${p['id']}' == postId));
                    final ok = await ApiService.deletePost(postId);
                    if (!ok) _load();
                  }
                },
                color: const Color(0xFF1E1E22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white30,
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: _accent, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          'Delete Post',
                          style: GoogleFonts.hankenGrotesk(color: _accent, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Caption
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              caption,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],

          // Photo grid
          if (imagePaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPostPhotoGrid(imagePaths),
          ],

          const SizedBox(height: 16),

          // Interaction row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (context) {
                      final isLiked = _likedProfilePostIds.contains(postId);
                      final count = _profilePostLikesCount[postId] ?? 0;
                      return _buildPostAction(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        '$count Likes',
                        () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isLiked) {
                              _likedProfilePostIds.remove(postId);
                              _profilePostLikesCount[postId] = (count - 1).clamp(0, 9999);
                            } else {
                              _likedProfilePostIds.add(postId);
                              _profilePostLikesCount[postId] = count + 1;
                            }
                          });
                        },
                        color: isLiked ? _accent : Colors.white60,
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildPostAction(Icons.chat_bubble_outline_rounded, '0', () {
                    HapticFeedback.lightImpact();
                  }),
                  const SizedBox(width: 24),
                  // Audience info
                  Row(
                    children: [
                      Icon(
                        '${post['audience'] ?? 'EVERYONE'}' == 'Everyone'
                            ? Icons.public_rounded
                            : Icons.group_rounded,
                        color: Colors.white38,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${post['audience'] ?? 'EVERYONE'}',
                        style: GoogleFonts.hankenGrotesk(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(
                  Icons.share_outlined,
                  color: Colors.white60,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SharePlus.instance.share(ShareParams(text: "Check out my post on FiTrybe! 💪\n\n${caption}"));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Post photos are served by the API, so these are network images.
  Widget _buildPostPhotoGrid(List<String> paths) {
    Widget photo(String url, {BoxFit fit = BoxFit.cover}) => Image.network(
          url,
          fit: fit,
          errorBuilder: (_, __, ___) => Container(
            color: _cardBg,
            child: const Icon(Icons.broken_image_rounded,
                color: Colors.white24, size: 24),
          ),
        );

    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: SizedBox(width: double.infinity, child: photo(paths[0])),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: paths.length > 5 ? 5 : paths.length,
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: photo(paths[i]),
      ),
    );
  }
}
