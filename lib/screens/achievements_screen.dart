import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/achievement_model.dart';
import '../widgets/achievement_badge_widget.dart';
import '../services/api_service.dart';

class AchievementsScreen extends StatefulWidget {
  static const routeName = '/AchievementsScreen';

  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  final Color _accent = const Color(0xFFFF5722);
  final Color _bg = const Color(0xFF08090C);
  final Color _cardBg = const Color(0xFF16181E);

  String _selectedFilter = 'all'; // 'all', 'unlocked', 'locked'

  @override
  void initState() {
    super.initState();
    AchievementBadgeArt.precache(AchievementData.badges.map((b) => b.id));
    _syncServerAchievements();
  }

  Future<void> _syncServerAchievements() async {
    try {
      await ApiService.getAchievements();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final allBadges = AchievementData.badges;
    final totalCount = allBadges.length;
    final unlockedCount = allBadges.where((b) => b.unlocked).length;
    final percent = (unlockedCount / totalCount * 100).round();

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Ambient Radial Glow Background
          Positioned(
            top: -100,
            left: MediaQuery.of(context).size.width / 2 - 250,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accent.withValues(alpha: 0.14),
                    _accent.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Top Navigation Bar Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(context);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Achievements',
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

                // Summary Stats Card
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardBg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$unlockedCount',
                                  style: GoogleFonts.anybody(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  ' / $totalCount unlocked',
                                  style: GoogleFonts.hankenGrotesk(
                                    color: Colors.white54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '$percent%',
                              style: GoogleFonts.anybody(
                                color: _accent,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: unlockedCount / totalCount,
                            minHeight: 7,
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(_accent),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Rarity Legend
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: AchievementRarity.values.map((r) {
                            final count = allBadges.where((b) => b.rarity == r).length;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: r.tagColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: r.tagColor.withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: r.tagColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$count ${r.label}',
                                    style: GoogleFonts.hankenGrotesk(
                                      color: r.tagColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Interactive Filter Chips Row
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _filterChip('all', 'ALL'),
                        const SizedBox(width: 8),
                        _filterChip('unlocked', 'UNLOCKED'),
                        const SizedBox(width: 8),
                        _filterChip('locked', 'LOCKED'),
                      ],
                    ),
                  ),
                ),

                // Categories & Badge Grids
                ...AchievementData.categories.map((category) {
                  var catBadges = allBadges.where((b) => b.cat == category.id).toList();
                  if (_selectedFilter == 'unlocked') {
                    catBadges = catBadges.where((b) => b.unlocked).toList();
                  } else if (_selectedFilter == 'locked') {
                    catBadges = catBadges.where((b) => !b.unlocked).toList();
                  }

                  if (catBadges.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }

                  final catUnlocked = catBadges.where((b) => b.unlocked).length;
                  final totalInCat = AchievementData.badges.where((b) => b.cat == category.id).length;

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    sliver: SliverMainAxisGroup(
                      slivers: [
                        // Category Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Row(
                              children: [
                                Text(
                                  category.title,
                                  style: GoogleFonts.anybody(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.white10,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Text(
                                    '$catUnlocked / $totalInCat',
                                    style: GoogleFonts.hankenGrotesk(
                                      color: _accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Badges Grid
                        SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 8,
                            childAspectRatio: 0.67,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final badge = catBadges[index];
                              return AchievementBadgeWidget(
                                badge: badge,
                                size: 76,
                                showLabel: true,
                                showStatusText: true,
                                onTap: () => _showBadgeDetailModal(context, badge),
                              );
                            },
                            childCount: catBadges.length,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filterId, String label) {
    final bool isSelected = _selectedFilter == filterId;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilter = filterId;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _accent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.hankenGrotesk(
            color: isSelected ? _accent : Colors.white60,
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  void _showBadgeDetailModal(BuildContext context, AchievementBadge badge) {
    HapticFeedback.mediumImpact();
    final unlocked = badge.unlocked;
    final r = badge.rarity;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF12141A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sheet Handle Bar
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),

              // Glowing Badge Artwork Header
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          r.tagColor.withValues(alpha: unlocked ? 0.35 : 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  AchievementBadgeArt(
                    badgeId: badge.id,
                    size: 110,
                    locked: !unlocked,
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Rarity Tag Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: r.tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: r.tagColor.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars_rounded, color: r.tagColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      r.label,
                      style: GoogleFonts.hankenGrotesk(
                        color: r.tagColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Title & Requirements
              Text(
                badge.name,
                style: GoogleFonts.anybody(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  badge.req,
                  style: GoogleFonts.hankenGrotesk(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Progress Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatProgressText(badge),
                          style: GoogleFonts.hankenGrotesk(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${badge.pct}%',
                          style: GoogleFonts.hankenGrotesk(
                            color: _accent,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: badge.pct / 100,
                        minHeight: 6,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Status Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    unlocked ? Icons.check_circle_rounded : Icons.lock_rounded,
                    color: unlocked ? const Color(0xFF7EE0A6) : Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unlocked ? 'UNLOCKED • ${badge.date}' : 'LOCKED • ${_formatRemainingText(badge)}',
                    style: GoogleFonts.hankenGrotesk(
                      color: unlocked ? const Color(0xFF7EE0A6) : Colors.white54,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  String _formatProgressText(AchievementBadge badge) {
    if (badge.curTxt != null) return badge.curTxt!;
    final curStr = badge.cur.toStringAsFixed(badge.cur == badge.cur.roundToDouble() ? 0 : 1);
    final tgtStr = badge.tgt.toStringAsFixed(badge.tgt == badge.tgt.roundToDouble() ? 0 : 1);
    if (badge.unit.isNotEmpty) {
      return '$curStr / $tgtStr ${badge.unit}';
    }
    return curStr;
  }

  String _formatRemainingText(AchievementBadge badge) {
    if (badge.remTxt != null) return badge.remTxt!;
    final rem = badge.tgt - badge.cur;
    final remStr = rem.toStringAsFixed(rem == rem.roundToDouble() ? 0 : 1);
    return '$remStr ${badge.unit} remaining';
  }
}
