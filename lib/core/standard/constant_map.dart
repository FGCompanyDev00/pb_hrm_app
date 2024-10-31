// Category colors mapping
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/core/standard/color.dart';

final Map<String, Color> categoryColors = {
  'Add Meeting': Colors.blue,
  'Leave': Colors.red,
  'Meeting Room Bookings': Colors.green,
  'Booking Car': Colors.purple,
  'Minutes Of Meeting': ColorStandardization().colorDarkGold,
};

//Category icon mapping
final Map<String, IconData> categoryIcon = {
  'Add Meeting': Icons.connect_without_contact,
  'Leave': Icons.work_off,
  'Meeting Room Bookings': Icons.meeting_room,
  'Booking Car': Icons.car_rental,
  'Minutes Of Meeting': Icons.car_rental,
};

/// Maps API meeting status to human-readable status
String mapMeetingStatus(String apiStatus) {
  switch (apiStatus.toLowerCase()) {
    case 'approved':
      return 'Approved';
    case 'processing':
    case 'waiting':
      return 'Pending';
    case 'disapproved':
      return 'Cancelled';
    case 'cancel':
      return 'Cancelled';
    case 'finished':
      return 'Finished';
    default:
      return 'Pending';
  }
}

/// Parses color from hex string
Color parseColor(String colorString) {
  try {
    return Color(int.parse(colorString.replaceFirst('#', '0xff')));
  } catch (_) {
    return Colors.blueAccent;
  }
}