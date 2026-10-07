/// Plain, local formatting for dates and times shown on events.
///
/// Written out rather than pulled from a package: the app needs five small
/// shapes, and they have to read the same on every screen.
class WhenFormat {
  const WhenFormat._();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String weekday(DateTime d) => _weekdays[d.weekday - 1];

  static String month(DateTime d) => _months[d.month - 1];

  /// "7:05 AM".
  static String time(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  /// "Today", "Tomorrow", "Yesterday", or "Sun 20 Sep", adding the year only
  /// when it is not this one.
  static String day(DateTime d, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    // Whole days between calendar dates, counted in UTC so a daylight saving
    // change cannot make "tomorrow" come out as 0 days away.
    final diff = DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(clock.year, clock.month, clock.day))
        .inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    final base = '${weekday(d)} ${d.day} ${month(d)}';
    return d.year == clock.year ? base : '$base ${d.year}';
  }

  /// "45 min", "1 hr", "1 hr 30 min".
  static String duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes % 60;
    if (hours == 0) return '$minutes min';
    if (minutes == 0) return '$hours hr';
    return '$hours hr $minutes min';
  }
}
