import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';

// /// Normalizes the date by removing the time component
// DateTime normalizeDate(DateTime date) {
//   return DateTime(date.year, date.month, date.day);
// }

/// Formats date strings to ensure consistency
String formatDateString(String dateStr) {
  try {
    // Assuming the date is in 'yyyy-MM-dd' or 'yyyy-MM-dd HH:mm:ss' format
    DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  } catch (e) {
    showSnackBar('Error formatting date string: $e');
    return dateStr;
  }
}

int startManageHour(String hour) {
  final convertHour = int.parse(hour);

  if (convertHour > 7 && convertHour < 11) {
    return 8;
  }
  if (convertHour > 9 && convertHour > 14) {
    return 10;
  }
  if (convertHour > 13 && convertHour > 18) {
    return 13;
  }

  return 8;
}

int endManageHour(String hour) {
  final convertHour = int.parse(hour);

  if (convertHour > 7 && convertHour < 11) {
    return 10;
  }
  if (convertHour > 9 && convertHour > 14) {
    return 13;
  }
  if (convertHour > 13 && convertHour > 18) {
    return 17;
  }

  return 10;
}
