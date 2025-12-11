import 'package:intl/intl.dart';

/// Local override providing the same API plus formatWithNames for compatibility.
class FLDateTime {
  static String formatTime(DateTime? date, String format,
      {String locale = 'en', String fallback = 'No Date Provided'}) {
    if (date == null) return fallback;

    final weekdays = DateFormat.E(locale).dateSymbols.STANDALONEWEEKDAYS;
    final months = DateFormat.MMMM(locale).dateSymbols.STANDALONEMONTHS;

    return format
        .replaceAll('EEE', weekdays[(date.weekday % 7)])
        .replaceAll('MMMM', months[date.month - 1])
        .replaceAll('YYYY', date.year.toString())
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('DD', date.day.toString().padLeft(2, '0'))
        .replaceAll('HH', date.hour.toString().padLeft(2, '0'))
        .replaceAll('hh', _formatHour(date.hour))
        .replaceAll('mm', date.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', date.second.toString().padLeft(2, '0'))
        .replaceAll('md', date.hour >= 12 ? 'PM' : 'AM');
  }

  /// Backwards-compatible helper matching older API usage; delegates to [formatTime].
  static String formatWithNames(DateTime? date, String format,
      {String locale = 'en', String fallback = 'No Date Provided'}) {
    return formatTime(date, format, locale: locale, fallback: fallback);
  }

  static String formatRelative(DateTime date, {DateTime? referenceDate}) {
    referenceDate ??= DateTime.now();
    final diff = referenceDate.difference(date);

    if (diff.inSeconds.abs() < 60) {
      return diff.isNegative
          ? 'in ${diff.inSeconds.abs()} seconds'
          : '${diff.inSeconds} seconds ago';
    } else if (diff.inMinutes.abs() < 60) {
      return diff.isNegative
          ? 'in ${diff.inMinutes.abs()} minutes'
          : '${diff.inMinutes} minutes ago';
    } else if (diff.inHours.abs() < 24) {
      return diff.isNegative
          ? 'in ${diff.inHours.abs()} hours'
          : '${diff.inHours} hours ago';
    } else if (diff.inDays.abs() < 7) {
      return diff.isNegative
          ? 'in ${diff.inDays.abs()} days'
          : '${diff.inDays} days ago';
    } else {
      final weeks = (diff.inDays / 7).abs().floor();
      return diff.isNegative ? 'in $weeks weeks' : '$weeks weeks ago';
    }
  }

  static String _formatHour(int hour) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return hour12.toString().padLeft(2, '0');
  }

  static String formatCustom(DateTime date, String format) {
    return format
        .replaceAll('YYYY', date.year.toString())
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('DD', date.day.toString().padLeft(2, '0'))
        .replaceAll('HH', date.hour.toString().padLeft(2, '0'))
        .replaceAll('hh', _formatHour12(date.hour))
        .replaceAll('mm', date.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', date.second.toString().padLeft(2, '0'))
        .replaceAll('a', date.hour >= 12 ? 'PM' : 'AM');
  }

  static String _formatHour12(int hour) {
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    return hour12.toString().padLeft(2, '0');
  }

  static String formatName(DateTime date, String format) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return format
        .replaceAll('EEE', weekdays[(date.weekday % 7)])
        .replaceAll('MMMM', months[date.month - 1])
        .replaceAll('YYYY', date.year.toString())
        .replaceAll('MM', date.month.toString().padLeft(2, '0'))
        .replaceAll('DD', date.day.toString().padLeft(2, '0'))
        .replaceAll('HH', date.hour.toString().padLeft(2, '0'))
        .replaceAll('hh', _formatHour12(date.hour))
        .replaceAll('mm', date.minute.toString().padLeft(2, '0'))
        .replaceAll('ss', date.second.toString().padLeft(2, '0'))
        .replaceAll('a', date.hour >= 12 ? 'PM' : 'AM');
  }
}
