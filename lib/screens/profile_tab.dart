import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_screen.dart';
import 'achievements_screen.dart';
import '../models/post_store.dart';
import '../models/achievement_model.dart';
import '../widgets/achievement_badge_widget.dart';
import '../services/health_service.dart';
import 'package:share_plus/share_plus.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  final Color _accent = const Color(0xFFFF5722);
  final Color _cardBg = const Color(0xFF1F1F22);

  // Profile URLs matching user request
  final String _bannerUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuB6TPeMuX0LW4ItpQWypk7_L5uUJEXStbcwTo0u6Qh2iiaJAnM_gvOKAwZHOjmQQrYYN3ryuR96W3O6yy0NClyBiDzgbW7GehFko-vrnjWLAvO_VeKAi-ixSqLJazJ2rsV7TnPyPq6GNsIRv0J7rXJg24hBRNgAAH5omJcCclVTJ1X7ODm1ZXjf8EqafkBDPwWz6P9rP61AW5nEe8yUMyOy6GEu8aN2Uh6B2l_2fK3GsYKCN4Mhu1rf';
  final String _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuAHT0fSiT-tBM9-LHbHVlF65CZIgyCqn-DoDUSl05Y0gcWZ5GDqFvUrdutx26mNY5DtnE0ZpijRovfDxUuDLTu5hStbuDoEqMg95eZOlGU7rLLNjJ0EvPXvLs18QfqyMuOb-lgEkqg4Ybw2FlQVeIXwhwd8mUkP3SpCWEUMQnuUuHL2ac9TI_c2sG5wyicbvZ1rz7TuvQ74aVOFymH_WjY3EuexlU6cz0GhX0Kb_z1JbXHSiQhULIuH';

  // Post Likes state
  final Set<String> _likedProfilePostIds = {};
  final Map<String, int> _profilePostLikesCount = {};

  late AnimationController _streakController;

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
                child: Image.network(
                  _bannerUrl,
                  fit: BoxFit.cover,
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
                    width: 88,
                    height: 88,
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
                      image: DecorationImage(
                        image: NetworkImage(_avatarUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Profile details
                  Text(
                    'Alex Thorne',
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
                      const Icon(Icons.location_on_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'London, UK',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.calendar_month_rounded, color: Colors.white38, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Joined Jan 2023',
                        style: GoogleFonts.hankenGrotesk(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Bio description
                  Text(
                    'Pushing limits. Ultra-runner & Calisthenics enthusiast. Chasing the next PR.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.hankenGrotesk(
                      color: Colors.white70,
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
                      _buildHeaderStat('1.2k', 'FOLLOWERS'),
                      _buildHeaderStat('342', 'FOLLOWING'),
                      _buildHeaderStat('4', 'CLIQUES'),
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

  Widget _buildBentoGrid() {
    return ValueListenableBuilder<HealthDataSummary>(
      valueListenable: HealthService().healthNotifier,
      builder: (context, health, _) {
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
                      text: '${health.distanceKm} ',
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
                              '428',
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
                              '340h',
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
                                '14 Days',
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
                                '42 Days',
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
    final showcaseBadges = AchievementData.badges.where((b) => b.unlocked).take(8).toList();

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
                'View All (${AchievementData.badges.where((b) => b.unlocked).length}/${AchievementData.badges.length})',
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
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 32, // 32 weeks simulation
                  itemBuilder: (context, weekIdx) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (dayIdx) {
                          final int hash = (weekIdx * 7 + dayIdx) % 11;
                          Color cellColor = const Color(0xFF353438).withValues(alpha: 0.3);
                          if (hash == 1 || hash == 5) {
                            cellColor = _accent.withValues(alpha: 0.2);
                          } else if (hash == 3 || hash == 8) {
                            cellColor = _accent.withValues(alpha: 0.4);
                          } else if (hash == 6) {
                            cellColor = _accent.withValues(alpha: 0.7);
                          } else if (hash == 10) {
                            cellColor = _accent;
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
                ),
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

  Widget _buildFavoritesSection() {
    final favorites = [
      {'label': 'Running', 'icon': Icons.directions_run_rounded, 'count': '184 sessions'},
      {'label': 'Strength', 'icon': Icons.fitness_center_rounded, 'count': '142 sessions'},
      {'label': 'Cycling', 'icon': Icons.pedal_bike_rounded, 'count': '102 sessions'},
    ];

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
    return ListenableBuilder(
      listenable: PostStore.instance,
      builder: (context, _) {
        final posts = PostStore.instance.posts;
        if (posts.isEmpty) return const SizedBox.shrink();

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
            ...posts.map((post) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPostCard(post),
                )),
          ],
        );
      },
    );
  }

  Widget _buildPostCard(UserPost post) {
    // Type badge color
    final Map<String, Color> typeColors = {
      'Activity': const Color(0xFF4CAF50),
      'Milestone': const Color(0xFFFFB300),
      'Challenge': const Color(0xFFFF5722),
      'Update': const Color(0xFF2196F3),
    };
    final badgeColor = typeColors[post.type] ?? _accent;

    // Relative time
    final diff = DateTime.now().difference(post.createdAt);
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
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: NetworkImage(_avatarUrl),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Alex Thorne',
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
                            post.type,
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
                          '$timeAgo • ${post.type}',
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        if (post.locationTag != null) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.location_on_rounded,
                              color: _accent, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            post.locationTag!,
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
                onSelected: (value) {
                  HapticFeedback.lightImpact();
                  if (value == 'edit') {
                    _showEditPostDialog(context, post);
                  } else if (value == 'delete') {
                    PostStore.instance.removePost(post.id);
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
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_rounded, color: Colors.white54, size: 16),
                        const SizedBox(width: 10),
                        Text(
                          'Edit Post',
                          style: GoogleFonts.hankenGrotesk(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
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
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.caption,
              style: GoogleFonts.hankenGrotesk(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],

          // Photo grid
          if (post.imagePaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildPostPhotoGrid(post.imagePaths),
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
                      final isLiked = _likedProfilePostIds.contains(post.id);
                      final count = _profilePostLikesCount[post.id] ?? 0;
                      return _buildPostAction(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                        '$count Likes',
                        () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (isLiked) {
                              _likedProfilePostIds.remove(post.id);
                              _profilePostLikesCount[post.id] = (count - 1).clamp(0, 9999);
                            } else {
                              _likedProfilePostIds.add(post.id);
                              _profilePostLikesCount[post.id] = count + 1;
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
                        post.audience == 'Everyone'
                            ? Icons.public_rounded
                            : Icons.group_rounded,
                        color: Colors.white38,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        post.audience,
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
                  SharePlus.instance.share(ShareParams(text: "Check out my post on FiTrybe! 💪\n\n${post.caption}"));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(BuildContext context, UserPost post) {
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
                  PostStore.instance.removePost(post.id);
                  PostStore.instance.addPost(
                    UserPost(
                      id: post.id,
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

  Widget _buildPostPhotoGrid(List<String> paths) {
    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.file(
            File(paths[0]),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
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
        child: Image.file(File(paths[i]), fit: BoxFit.cover),
      ),
    );
  }
}
