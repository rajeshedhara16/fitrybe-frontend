import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import 'api_service.dart';

/// Overlays the athlete's real training data onto the static badge catalogue.
///
/// The backend only records *which* achievements are unlocked; the thresholds
/// and artwork live in [AchievementData]. This service computes progress from
/// the analytics endpoint, unlocks anything newly earned, and publishes the
/// merged list so the profile and achievements screens agree.
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final ValueNotifier<List<AchievementBadge>> badgesNotifier =
      ValueNotifier<List<AchievementBadge>>(_lockedCatalogue());

  List<AchievementBadge> get badges => badgesNotifier.value;

  int get unlockedCount => badges.where((b) => b.unlocked).length;
  int get totalCount => badges.length;

  bool _isSyncing = false;

  /// Every badge with progress zeroed — the honest starting point for a new
  /// account, before the server tells us what has been earned.
  static List<AchievementBadge> _lockedCatalogue() => AchievementData.badges
      .map((b) => b.copyWith(cur: 0, clearDate: true, clearPctOverride: true))
      .toList();

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String _formatDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';

  Future<void> sync() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final results = await Future.wait([
        ApiService.getAchievements(),
        ApiService.getAnalytics(),
        ApiService.getTrybes(mine: true),
      ]);

      final unlockedMap =
          (results[0] as Map<String, dynamic>)['unlockedMap'] as Map? ?? {};
      final analytics = results[1] as Map<String, dynamic>;
      final myTrybes = results[2] as List;

      final summary =
          (analytics['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
      final totalWorkouts = (summary['totalWorkouts'] as num?)?.toInt() ?? 0;
      final totalDistanceKm =
          (summary['totalDistanceKm'] as num?)?.toDouble() ?? 0;
      final streakDays = _streakDays(analytics);
      final trybeCount = myTrybes.length;

      final merged = <AchievementBadge>[];
      final toUnlock = <String>[];

      for (final badge in AchievementData.badges) {
        final progress = _progressFor(
          badge,
          totalWorkouts: totalWorkouts,
          totalDistanceKm: totalDistanceKm,
          streakDays: streakDays,
          trybeCount: trybeCount,
        );

        final serverDate = unlockedMap[badge.id];
        final parsed = DateTime.tryParse('${serverDate ?? ''}');
        final earnedNow = progress != null && progress >= badge.tgt;

        if (parsed == null && earnedNow) {
          toUnlock.add(badge.id);
        }

        merged.add(badge.copyWith(
          cur: progress ?? 0,
          clearPctOverride: true,
          date: parsed != null
              ? _formatDate(parsed.toLocal())
              : (earnedNow ? _formatDate(DateTime.now()) : null),
          clearDate: parsed == null && !earnedNow,
        ));
      }

      badgesNotifier.value = merged;

      // Persist anything the athlete just earned so it survives a reload.
      for (final id in toUnlock) {
        await ApiService.unlockAchievement(id);
      }
    } catch (e) {
      debugPrint('AchievementService sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Longest run of consecutive days ending today or yesterday.
  static double _streakDays(Map<String, dynamic> analytics) {
    final days = (analytics['recentActivities'] as List? ?? const [])
        .whereType<Map>()
        .map((a) => DateTime.tryParse('${a['createdAt'] ?? ''}')?.toLocal())
        .whereType<DateTime>()
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();
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
    return streak.toDouble();
  }

  /// Maps a badge's unit onto a metric we actually track. Returns null when
  /// the badge measures something the backend does not record yet (challenge
  /// wins, explored routes, race finishes), leaving it locked rather than
  /// showing invented progress.
  static double? _progressFor(
    AchievementBadge badge, {
    required int totalWorkouts,
    required double totalDistanceKm,
    required double streakDays,
    required int trybeCount,
  }) {
    switch (badge.unit) {
      case 'activity':
      case 'activities':
      case 'sessions':
        return totalWorkouts.toDouble();
      case 'km':
        return totalDistanceKm;
      case 'days':
        return streakDays;
      case 'Trybe':
      case 'members':
        return trybeCount.toDouble();
      default:
        return null;
    }
  }
}
