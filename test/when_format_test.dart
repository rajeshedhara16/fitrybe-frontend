import 'package:flutter_test/flutter_test.dart';
import 'package:fitrybe/services/when_format.dart';

void main() {
  // Tuesday 15 September 2026.
  final now = DateTime(2026, 9, 15, 10);

  test('times are 12-hour with padded minutes', () {
    expect(WhenFormat.time(DateTime(2026, 9, 15, 7, 5)), '7:05 AM');
    expect(WhenFormat.time(DateTime(2026, 9, 15, 0, 0)), '12:00 AM');
    expect(WhenFormat.time(DateTime(2026, 9, 15, 12, 30)), '12:30 PM');
    expect(WhenFormat.time(DateTime(2026, 9, 15, 18, 45)), '6:45 PM');
  });

  test('nearby days read as words', () {
    expect(WhenFormat.day(DateTime(2026, 9, 15, 23), now: now), 'Today');
    expect(WhenFormat.day(DateTime(2026, 9, 16, 6), now: now), 'Tomorrow');
    expect(WhenFormat.day(DateTime(2026, 9, 14, 6), now: now), 'Yesterday');
  });

  test('other days carry weekday, date and month, and the year only when needed',
      () {
    expect(WhenFormat.day(DateTime(2026, 9, 20), now: now), 'Sun 20 Sep');
    expect(WhenFormat.day(DateTime(2027, 1, 3), now: now), 'Sun 3 Jan 2027');
  });

  test('durations drop the parts that are zero', () {
    expect(WhenFormat.duration(const Duration(minutes: 45)), '45 min');
    expect(WhenFormat.duration(const Duration(hours: 2)), '2 hr');
    expect(WhenFormat.duration(const Duration(minutes: 90)), '1 hr 30 min');
  });
}
