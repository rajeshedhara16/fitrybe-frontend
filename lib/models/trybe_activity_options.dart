import 'package:flutter/material.dart';

/// Activities a Trybe can say it is about, shared by creating and editing one so
/// the two screens can never offer different lists.
const List<({String name, IconData icon})> trybeActivityOptions = [
  (name: 'Walking', icon: Icons.directions_walk_rounded),
  (name: 'Running', icon: Icons.directions_run_rounded),
  (name: 'Hiking', icon: Icons.hiking_rounded),
  (name: 'Cycling', icon: Icons.directions_bike_rounded),
  (name: 'Roller Skating', icon: Icons.roller_skating_rounded),
  (name: 'Skateboarding', icon: Icons.skateboarding_rounded),
  (name: 'Scooter Riding', icon: Icons.electric_scooter_rounded),
  (name: 'Wheelchair Activity', icon: Icons.accessible_rounded),
  (name: 'Dog Walking', icon: Icons.pets_rounded),
  (name: 'Open Water Swimming', icon: Icons.pool_rounded),
  (name: 'Kayaking', icon: Icons.kayaking_rounded),
  (name: 'Canoeing', icon: Icons.rowing_rounded),
  (name: 'Paddleboarding', icon: Icons.surfing_rounded),
  (name: 'Skiing', icon: Icons.downhill_skiing_rounded),
  (name: 'Snowboarding', icon: Icons.snowboarding_rounded),
  (name: 'Nature Walk', icon: Icons.forest_rounded),
  (name: 'Commute Walk', icon: Icons.directions_walk_rounded),
  (name: 'Commute Ride', icon: Icons.directions_bike_rounded),
  (name: 'Gym Workout', icon: Icons.fitness_center_rounded),
  (name: 'Football/Soccer', icon: Icons.sports_soccer_rounded),
  (name: 'Basketball', icon: Icons.sports_basketball_rounded),
  (name: 'Volleyball', icon: Icons.sports_volleyball_rounded),
  (name: 'Tennis', icon: Icons.sports_tennis_rounded),
  (name: 'Badminton', icon: Icons.sports_tennis_rounded),
  (name: 'Cricket', icon: Icons.sports_cricket_rounded),
  (name: 'Rugby', icon: Icons.sports_rugby_rounded),
  (name: 'Boxing', icon: Icons.sports_mma_rounded),
  (name: 'Martial Arts', icon: Icons.sports_kabaddi_rounded),
  (name: 'Yoga (Outdoor)', icon: Icons.self_improvement_rounded),
  (name: 'Calisthenics (Park)', icon: Icons.accessibility_new_rounded),
  (name: 'Rock Climbing', icon: Icons.filter_hdr_rounded),
  (name: 'Golf', icon: Icons.sports_golf_rounded),
  (name: 'Disc Golf', icon: Icons.track_changes_rounded),
  (name: 'Frisbee', icon: Icons.sports_handball_rounded),
];

/// Resolves an icon for an activity name, case-insensitively.
IconData activityIconFor(String? activity) {
  if (activity == null || activity.trim().isEmpty) {
    return Icons.fitness_center_rounded;
  }
  final clean = activity.trim().toLowerCase();
  for (final option in trybeActivityOptions) {
    if (option.name.toLowerCase() == clean) {
      return option.icon;
    }
  }
  if (clean.contains('run')) return Icons.directions_run_rounded;
  if (clean.contains('walk')) return Icons.directions_walk_rounded;
  if (clean.contains('cycle') || clean.contains('bike') || clean.contains('ride')) {
    return Icons.directions_bike_rounded;
  }
  if (clean.contains('hike')) return Icons.hiking_rounded;
  if (clean.contains('swim')) return Icons.pool_rounded;
  if (clean.contains('gym') || clean.contains('workout') || clean.contains('weight')) {
    return Icons.fitness_center_rounded;
  }
  if (clean.contains('yoga')) return Icons.self_improvement_rounded;
  return Icons.fitness_center_rounded;
}

