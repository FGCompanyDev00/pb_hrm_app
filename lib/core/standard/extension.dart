import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/widgets/snackbar/snackbar.dart';

// /// Normalizes the date by removing the time component
// DateTime normalizeDate(DateTime date) {
//   return DateTime(date.year, date.month, date.day);
// }

/// Formats date strings to ensure consistency
String formatDateString(BuildContext context, String dateStr) {
  try {
    // Assuming the date is in 'yyyy-MM-dd' or 'yyyy-MM-dd HH:mm:ss' format
    DateTime parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    return DateFormat('yyyy-MM-dd').format(parsedDate);
  } catch (e) {
    showSnackBar(context, 'Error formatting date string: $e');
    return dateStr;
  }
}
