/// Utility functions for date range, calendar week, and month calculations.
class DateRangeUtils {
  DateRangeUtils._();

  /// Returns the start of the week (Monday at 00:00:00) for a given date.
  static DateTime startOfWeek(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Returns the end of the week (Sunday at 23:59:59.999) for a given date.
  static DateTime endOfWeek(DateTime date) {
    final start = startOfWeek(date);
    return start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));
  }

  /// Checks if two dates fall within the exact same Monday-Sunday week.
  static bool isSameWeek(DateTime d1, DateTime d2) {
    final start1 = startOfWeek(d1);
    final start2 = startOfWeek(d2);
    return start1.year == start2.year &&
        start1.month == start2.month &&
        start1.day == start2.day;
  }

  /// Checks if two dates fall in the same calendar month and year.
  static bool isSameMonth(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month;
  }

  /// Returns unique count of calendar weeks (Monday start) that contain at least 1 date.
  static int countActiveWeeks(List<DateTime> dates) {
    if (dates.isEmpty) return 0;
    final Set<String> uniqueWeekKeys = {};
    for (final d in dates) {
      final start = startOfWeek(d);
      final key = '${start.year}-${start.month}-${start.day}';
      uniqueWeekKeys.add(key);
    }
    return uniqueWeekKeys.length;
  }
}
