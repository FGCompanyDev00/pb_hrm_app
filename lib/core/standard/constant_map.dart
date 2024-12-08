// Category colors mapping
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/services/offline_service.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:provider/provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final mediaQuery = MediaQuery.of(navigatorKey.currentState!.context);
final fullHeight = mediaQuery.size.height;
final connectivityResult = sl<Connectivity>();
OfflineProvider offlineProvider = Provider.of<OfflineProvider>(navigatorKey.currentState!.context, listen: false);
FToast fToast = FToast();
List<Events> eventsForDay = [];
List<Events> eventsForAll = [];
final ValueNotifier<Map<DateTime, List<Events>>> events = ValueNotifier({});

final Map<String, Color> categoryColors = {
  'Add Meeting': Colors.blue,
  'Leave': Colors.red,
  'Meeting Room Bookings': Colors.green,
  'Booking Car': Colors.purple,
  'Minutes Of Meeting': ColorStandardization().colorDarkGold,
};

//Category icon mapping
final Map<String, String?> categoryIcon = {
  'Add Meeting': 'assets/icons/video_camera_record.png',
  'Leave': null,
  'Meeting Room Bookings': 'assets/icons/video_camera_record.png',
  'Booking Car': null,
  'Minutes Of Meeting': null,
};

/// Retrieves the color associated with an event category
Color getEventColor(Events event) {
  return categoryColors[event.category] ?? Colors.grey;
}

/// Maps API meeting status to human-readable status
String mapEventStatus(String apiStatus) {
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

Size sizeScreen(BuildContext context) => MediaQuery.of(context).size;
