import 'package:flutter/material.dart';

enum AchievementRarity {
  common,
  rare,
  epic,
  legendary,
}

extension AchievementRarityX on AchievementRarity {
  String get label {
    switch (this) {
      case AchievementRarity.common:
        return 'COMMON';
      case AchievementRarity.rare:
        return 'RARE';
      case AchievementRarity.epic:
        return 'EPIC';
      case AchievementRarity.legendary:
        return 'LEGENDARY';
    }
  }

  Color get tagColor {
    switch (this) {
      case AchievementRarity.common:
        return const Color(0xFF9AA4B2);
      case AchievementRarity.rare:
        return const Color(0xFF7DC0F0);
      case AchievementRarity.epic:
        return const Color(0xFFC0A2FF);
      case AchievementRarity.legendary:
        return const Color(0xFFFFCF6B);
    }
  }

  double get glowOpacity {
    switch (this) {
      case AchievementRarity.common:
        return 0.10;
      case AchievementRarity.rare:
        return 0.17;
      case AchievementRarity.epic:
        return 0.25;
      case AchievementRarity.legendary:
        return 0.36;
    }
  }
}

enum BadgeShape {
  hex,
  hexflat,
  oct,
  pent,
  medal,
  compass,
  shield,
}

class AchievementBadge {
  final String id;
  final String cat;
  final String name;
  final double hue;
  final AchievementRarity rarity;
  final int d; // Detail level 1-5
  final String req;
  final double cur;
  final double tgt;
  final String unit;
  final String? date;
  final BadgeShape shape;
  final String? curTxt;
  final String? tgtTxt;
  final double? pctOverride;
  final String? remTxt;
  final IconData icon;

  const AchievementBadge({
    required this.id,
    required this.cat,
    required this.name,
    required this.hue,
    required this.rarity,
    required this.d,
    required this.req,
    required this.cur,
    required this.tgt,
    required this.unit,
    this.date,
    required this.shape,
    this.curTxt,
    this.tgtTxt,
    this.pctOverride,
    this.remTxt,
    required this.icon,
  });

  bool get unlocked => date != null && date!.isNotEmpty;

  int get pct {
    if (pctOverride != null) return pctOverride!.toInt();
    if (tgt <= 0) return 0;
    return (cur / tgt * 100).clamp(0, 100).toInt();
  }

  /// Used to overlay the athlete's real progress and server unlock date onto
  /// the static badge catalogue.
  AchievementBadge copyWith({
    double? cur,
    String? date,
    bool clearDate = false,
    double? pctOverride,
    bool clearPctOverride = false,
  }) {
    return AchievementBadge(
      id: id,
      cat: cat,
      name: name,
      hue: hue,
      rarity: rarity,
      d: d,
      req: req,
      cur: cur ?? this.cur,
      tgt: tgt,
      unit: unit,
      date: clearDate ? null : (date ?? this.date),
      shape: shape,
      curTxt: curTxt,
      tgtTxt: tgtTxt,
      pctOverride: clearPctOverride ? null : (pctOverride ?? this.pctOverride),
      remTxt: remTxt,
      icon: icon,
    );
  }
}

class AchievementCategory {
  final String id;
  final String title;
  final BadgeShape shape;

  const AchievementCategory({
    required this.id,
    required this.title,
    required this.shape,
  });
}

class AchievementData {
  static const List<AchievementCategory> categories = [
    AchievementCategory(id: 'activity', title: 'ACTIVITY MILESTONES', shape: BadgeShape.hex),
    AchievementCategory(id: 'distance', title: 'DISTANCE', shape: BadgeShape.shield),
    AchievementCategory(id: 'consistency', title: 'CONSISTENCY', shape: BadgeShape.oct),
    AchievementCategory(id: 'performance', title: 'PERFORMANCE', shape: BadgeShape.hexflat),
    AchievementCategory(id: 'trybe', title: 'TRYBE & SOCIAL', shape: BadgeShape.pent),
    AchievementCategory(id: 'challenges', title: 'CHALLENGES', shape: BadgeShape.medal),
    AchievementCategory(id: 'exploration', title: 'EXPLORATION', shape: BadgeShape.compass),
  ];

  static const List<AchievementBadge> badges = [
    // ── ACTIVITY ─────────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'first_step',
      cat: 'activity',
      name: 'First Step',
      hue: 26,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Log your first activity',
      cur: 1,
      tgt: 1,
      unit: 'activity',
      date: 'February 3, 2026',
      shape: BadgeShape.hex,
      icon: Icons.directions_walk_rounded,
    ),
    AchievementBadge(
      id: 'getting_started',
      cat: 'activity',
      name: 'Getting Started',
      hue: 200,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Complete 5 activities',
      cur: 5,
      tgt: 5,
      unit: 'activities',
      date: 'February 11, 2026',
      shape: BadgeShape.hex,
      icon: Icons.directions_run_rounded,
    ),
    AchievementBadge(
      id: 'on_the_move',
      cat: 'activity',
      name: 'On the Move',
      hue: 156,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Complete 25 activities',
      cur: 25,
      tgt: 25,
      unit: 'activities',
      date: 'April 6, 2026',
      shape: BadgeShape.hex,
      icon: Icons.fast_forward_rounded,
    ),
    AchievementBadge(
      id: 'unstoppable',
      cat: 'activity',
      name: 'Unstoppable',
      hue: 272,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Complete 50 activities',
      cur: 50,
      tgt: 50,
      unit: 'activities',
      date: 'June 22, 2026',
      shape: BadgeShape.hex,
      icon: Icons.bolt_rounded,
    ),
    AchievementBadge(
      id: 'century_club',
      cat: 'activity',
      name: 'Century Club',
      hue: 40,
      rarity: AchievementRarity.legendary,
      d: 5,
      req: 'Complete 100 activities',
      cur: 100,
      tgt: 100,
      unit: 'activities',
      date: 'August 8, 2026',
      shape: BadgeShape.hex,
      icon: Icons.workspace_premium_rounded,
    ),

    // ── DISTANCE ─────────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'first_5k',
      cat: 'distance',
      name: 'First 5K',
      hue: 222,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Cover 5 km in a single activity',
      cur: 5,
      tgt: 5,
      unit: 'km',
      date: 'February 9, 2026',
      shape: BadgeShape.shield,
      icon: Icons.timeline_rounded,
    ),
    AchievementBadge(
      id: 'ten_k',
      cat: 'distance',
      name: '10K',
      hue: 300,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Cover 10 km in a single activity',
      cur: 10,
      tgt: 10,
      unit: 'km',
      date: 'March 15, 2026',
      shape: BadgeShape.shield,
      icon: Icons.show_chart_rounded,
    ),
    AchievementBadge(
      id: 'marathoner',
      cat: 'distance',
      name: 'Marathoner',
      hue: 26,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Cover 42.2 km in a single activity',
      cur: 24.6,
      tgt: 42.2,
      unit: 'km',
      shape: BadgeShape.shield,
      icon: Icons.military_tech_rounded,
    ),
    AchievementBadge(
      id: 'hundred_k',
      cat: 'distance',
      name: '100K Club',
      hue: 178,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Travel 100 km in total',
      cur: 100,
      tgt: 100,
      unit: 'km',
      date: 'May 2, 2026',
      shape: BadgeShape.shield,
      icon: Icons.terrain_rounded,
    ),
    AchievementBadge(
      id: 'road_warrior',
      cat: 'distance',
      name: 'Road Warrior',
      hue: 250,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Travel 500 km',
      cur: 342,
      tgt: 500,
      unit: 'km',
      shape: BadgeShape.shield,
      icon: Icons.alt_route_rounded,
    ),
    AchievementBadge(
      id: 'thousand_km',
      cat: 'distance',
      name: '1,000 KM',
      hue: 40,
      rarity: AchievementRarity.legendary,
      d: 5,
      req: 'Travel 1,000 km in total',
      cur: 342,
      tgt: 1000,
      unit: 'km',
      shape: BadgeShape.shield,
      icon: Icons.speed_rounded,
    ),

    // ── CONSISTENCY ──────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'streak_3',
      cat: 'consistency',
      name: '3-Day Streak',
      hue: 26,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Stay active 3 days in a row',
      cur: 3,
      tgt: 3,
      unit: 'days',
      date: 'February 6, 2026',
      shape: BadgeShape.oct,
      icon: Icons.local_fire_department_rounded,
    ),
    AchievementBadge(
      id: 'streak_7',
      cat: 'consistency',
      name: '7-Day Streak',
      hue: 6,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Stay active 7 days in a row',
      cur: 7,
      tgt: 7,
      unit: 'days',
      date: 'February 14, 2026',
      shape: BadgeShape.oct,
      icon: Icons.whatshot_rounded,
    ),
    AchievementBadge(
      id: 'streak_30',
      cat: 'consistency',
      name: '30-Day Streak',
      hue: 332,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Stay active 30 days in a row',
      cur: 30,
      tgt: 30,
      unit: 'days',
      date: 'April 29, 2026',
      shape: BadgeShape.oct,
      icon: Icons.calendar_today_rounded,
    ),
    AchievementBadge(
      id: 'streak_100',
      cat: 'consistency',
      name: '100-Day Streak',
      hue: 40,
      rarity: AchievementRarity.legendary,
      d: 5,
      req: 'Stay active 100 days in a row',
      cur: 41,
      tgt: 100,
      unit: 'days',
      shape: BadgeShape.oct,
      icon: Icons.auto_awesome_rounded,
    ),
    AchievementBadge(
      id: 'perfect_week',
      cat: 'consistency',
      name: 'Perfect Week',
      hue: 156,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Hit your daily goal 7 days in a row',
      cur: 7,
      tgt: 7,
      unit: 'days',
      date: 'March 8, 2026',
      shape: BadgeShape.oct,
      icon: Icons.check_circle_rounded,
    ),

    // ── PERFORMANCE ──────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'personal_best',
      cat: 'performance',
      name: 'Personal Best',
      hue: 88,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Beat one of your previous best times',
      cur: 1,
      tgt: 1,
      unit: 'record',
      date: 'March 21, 2026',
      shape: BadgeShape.hexflat,
      icon: Icons.trending_up_rounded,
    ),
    AchievementBadge(
      id: 'speed_demon',
      cat: 'performance',
      name: 'Speed Demon',
      hue: 272,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Hold a pace under 5:00 /km for 5 km',
      cur: 0,
      tgt: 1,
      unit: '',
      curTxt: '5:24 /km',
      tgtTxt: 'best pace',
      pctOverride: 71,
      remTxt: '24 s/km faster to unlock',
      shape: BadgeShape.hexflat,
      icon: Icons.offline_bolt_rounded,
    ),
    AchievementBadge(
      id: 'long_haul',
      cat: 'performance',
      name: 'Long Haul',
      hue: 200,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Stay active for 2 hours in one session',
      cur: 96,
      tgt: 120,
      unit: 'min',
      shape: BadgeShape.hexflat,
      icon: Icons.timer_rounded,
    ),
    AchievementBadge(
      id: 'early_bird',
      cat: 'performance',
      name: 'Early Bird',
      hue: 42,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Complete 10 activities before 7 AM',
      cur: 10,
      tgt: 10,
      unit: 'activities',
      date: 'June 5, 2026',
      shape: BadgeShape.hexflat,
      icon: Icons.wb_sunny_rounded,
    ),
    AchievementBadge(
      id: 'night_owl',
      cat: 'performance',
      name: 'Night Owl',
      hue: 250,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Complete 10 activities after 9 PM',
      cur: 4,
      tgt: 10,
      unit: 'activities',
      shape: BadgeShape.hexflat,
      icon: Icons.nights_stay_rounded,
    ),

    // ── TRYBE & SOCIAL ────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'first_trybe',
      cat: 'trybe',
      name: 'First Trybe',
      hue: 26,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Join your first Trybe',
      cur: 1,
      tgt: 1,
      unit: 'Trybe',
      date: 'February 18, 2026',
      shape: BadgeShape.pent,
      icon: Icons.group_rounded,
    ),
    AchievementBadge(
      id: 'team_player',
      cat: 'trybe',
      name: 'Team Player',
      hue: 178,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Complete 10 group activities',
      cur: 10,
      tgt: 10,
      unit: 'activities',
      date: 'April 2, 2026',
      shape: BadgeShape.pent,
      icon: Icons.groups_rounded,
    ),
    AchievementBadge(
      id: 'dynamic_duo',
      cat: 'trybe',
      name: 'Dynamic Duo',
      hue: 300,
      rarity: AchievementRarity.rare,
      d: 2,
      req: 'Train with the same partner 5 times',
      cur: 5,
      tgt: 5,
      unit: 'sessions',
      date: 'April 18, 2026',
      shape: BadgeShape.pent,
      icon: Icons.people_alt_rounded,
    ),
    AchievementBadge(
      id: 'strong_partner',
      cat: 'trybe',
      name: 'Strong Partner',
      hue: 222,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Train with the same partner 25 times',
      cur: 12,
      tgt: 25,
      unit: 'sessions',
      shape: BadgeShape.pent,
      icon: Icons.diversity_3_rounded,
    ),
    AchievementBadge(
      id: 'crew_goals',
      cat: 'trybe',
      name: 'Crew Goals',
      hue: 88,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Finish a group challenge with 5+ members',
      cur: 3,
      tgt: 5,
      unit: 'members',
      shape: BadgeShape.pent,
      icon: Icons.flag_rounded,
    ),
    AchievementBadge(
      id: 'rally_leader',
      cat: 'trybe',
      name: 'Rally Leader',
      hue: 6,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Grow a Trybe you created to 10 members',
      cur: 6,
      tgt: 10,
      unit: 'members',
      shape: BadgeShape.pent,
      icon: Icons.campaign_rounded,
    ),
    AchievementBadge(
      id: 'full_house',
      cat: 'trybe',
      name: 'Full House',
      hue: 40,
      rarity: AchievementRarity.legendary,
      d: 5,
      req: 'Get every Trybe member active on the same day',
      cur: 9,
      tgt: 12,
      unit: 'members',
      shape: BadgeShape.pent,
      icon: Icons.stars_rounded,
    ),

    // ── CHALLENGES ────────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'challenger',
      cat: 'challenges',
      name: 'Challenger',
      hue: 200,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Join your first challenge',
      cur: 1,
      tgt: 1,
      unit: 'challenge',
      date: 'March 2, 2026',
      shape: BadgeShape.medal,
      icon: Icons.emoji_events_rounded,
    ),
    AchievementBadge(
      id: 'challenge_acc',
      cat: 'challenges',
      name: 'Challenge Accepted',
      hue: 156,
      rarity: AchievementRarity.common,
      d: 2,
      req: 'Complete a challenge',
      cur: 1,
      tgt: 1,
      unit: 'challenge',
      date: 'March 26, 2026',
      shape: BadgeShape.medal,
      icon: Icons.verified_rounded,
    ),
    AchievementBadge(
      id: 'podium_finish',
      cat: 'challenges',
      name: 'Podium Finish',
      hue: 26,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Finish in the top 3 of a challenge',
      cur: 1,
      tgt: 1,
      unit: 'finish',
      date: 'July 4, 2026',
      shape: BadgeShape.medal,
      icon: Icons.leaderboard_rounded,
    ),
    AchievementBadge(
      id: 'champion',
      cat: 'challenges',
      name: 'Champion',
      hue: 272,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Win a challenge outright',
      cur: 0,
      tgt: 1,
      unit: 'win',
      shape: BadgeShape.medal,
      icon: Icons.military_tech_rounded,
    ),
    AchievementBadge(
      id: 'challenge_mach',
      cat: 'challenges',
      name: 'Challenge Machine',
      hue: 40,
      rarity: AchievementRarity.legendary,
      d: 5,
      req: 'Complete 25 challenges',
      cur: 6,
      tgt: 25,
      unit: 'challenges',
      shape: BadgeShape.medal,
      icon: Icons.settings_suggest_rounded,
    ),

    // ── EXPLORATION ───────────────────────────────────────────────────────────
    AchievementBadge(
      id: 'explorer',
      cat: 'exploration',
      name: 'Explorer',
      hue: 332,
      rarity: AchievementRarity.common,
      d: 1,
      req: 'Record a route away from home',
      cur: 1,
      tgt: 1,
      unit: 'route',
      date: 'March 11, 2026',
      shape: BadgeShape.compass,
      icon: Icons.explore_rounded,
    ),
    AchievementBadge(
      id: 'wanderer',
      cat: 'exploration',
      name: 'Wanderer',
      hue: 178,
      rarity: AchievementRarity.rare,
      d: 2,
      req: 'Record routes in 10 different areas',
      cur: 6,
      tgt: 10,
      unit: 'areas',
      shape: BadgeShape.compass,
      icon: Icons.map_rounded,
    ),
    AchievementBadge(
      id: 'trailblazer',
      cat: 'exploration',
      name: 'Trailblazer',
      hue: 88,
      rarity: AchievementRarity.epic,
      d: 4,
      req: 'Log 250 km on trails',
      cur: 88,
      tgt: 250,
      unit: 'km',
      shape: BadgeShape.compass,
      icon: Icons.navigation_rounded,
    ),
    AchievementBadge(
      id: 'new_territory',
      cat: 'exploration',
      name: 'New Territory',
      hue: 250,
      rarity: AchievementRarity.rare,
      d: 3,
      req: 'Be first in your Trybe to run a new route',
      cur: 2,
      tgt: 5,
      unit: 'routes',
      shape: BadgeShape.compass,
      icon: Icons.pin_drop_rounded,
    ),
  ];
}
