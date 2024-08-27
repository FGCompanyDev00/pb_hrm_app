// import 'package:flutter/material.dart';
// import 'package:flutter_timetable/flutter_timetable.dart';
// import 'package:intl/intl.dart';
// import 'package:pb_hrsystem/home/home_calendar.dart';

// class TimetablePage extends StatefulWidget {
//   final DateTime date;
//   final List<Event> events;

//   const TimetablePage({required this.date, required this.events, Key? key}) : super(key: key);

//   @override
//   _TimetablePageState createState() => _TimetablePageState();
// }

// class _TimetablePageState extends State<TimetablePage> {
//   late TimetableController controller;
//   late List<TimetableItem<String>> timetableItems;

//   @override
//   void initState() {
//     super.initState();
//     controller = TimetableController(
//       start: DateUtils.dateOnly(widget.date).subtract(const Duration(days: 7)),
//       initialColumns: 3,
//       cellHeight: 100.0,
//       startHour: 9,
//       endHour: 18,
//     );

//     timetableItems = widget.events.map((event) {
//       return TimetableItem<String>(
//         event.startDateTime,
//         event.endDateTime,
//         data: event.title,
//       );
//     }).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.grey,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.calendar_view_day),
//             onPressed: () => controller.setColumns(1),
//           ),
//           IconButton(
//             icon: const Icon(Icons.calendar_view_month_outlined),
//             onPressed: () => controller.setColumns(3),
//           ),
//           IconButton(
//             icon: const Icon(Icons.calendar_view_week),
//             onPressed: () => controller.setColumns(5),
//           ),
//           IconButton(
//             icon: const Icon(Icons.zoom_in),
//             onPressed: () => controller.setCellHeight(controller.cellHeight + 10),
//           ),
//           IconButton(
//             icon: const Icon(Icons.zoom_out),
//             onPressed: () => controller.setCellHeight(controller.cellHeight - 10),
//           ),
//         ],
//       ),
//       body: Timetable<String>(
//         controller: controller,
//         items: timetableItems,
//         cellBuilder: (dateTime) => Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.blueGrey, width: 0.2),
//           ),
//           child: Center(
//             child: Text(
//               DateFormat("MM/d/yyyy\nha").format(dateTime),
//               style: TextStyle(
//                 color: Color(0xff000000 + (0x002222 * dateTime.hour) + (0x110000 * dateTime.day)).withOpacity(0.5),
//               ),
//               textAlign: TextAlign.center,
//             ),
//           ),
//         ),
//         cornerBuilder: (datetime) => Container(
//           color: Colors.accents[datetime.day % Colors.accents.length],
//           child: Center(child: Text("${datetime.year}")),
//         ),
//         headerCellBuilder: (datetime) {
//           final color = Colors.primaries[datetime.day % Colors.accents.length];
//           return Container(
//             decoration: BoxDecoration(
//               border: Border(bottom: BorderSide(color: color, width: 2)),
//             ),
//             child: Center(
//               child: Text(
//                 DateFormat("E\nMMM d").format(datetime),
//                 style: TextStyle(
//                   color: color,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//             ),
//           );
//         },
//         hourLabelBuilder: (time) {
//           final hour = time.hour == 12 ? 12 : time.hour % 12;
//           final period = time.hour < 12 ? "am" : "pm";
//           final isCurrentHour = time.hour == DateTime.now().hour;
//           return Text(
//             "$hour$period",
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
//             ),
//           );
//         },
//         itemBuilder: (item) => Container(
//           decoration: BoxDecoration(
//             color: Colors.white.withAlpha(220),
//             borderRadius: BorderRadius.circular(16),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.2),
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: Center(
//             child: Text(
//               item.data ?? "No Title",
//               style: const TextStyle(fontSize: 14),
//             ),
//           ),
//         ),
//         nowIndicatorColor: Colors.red,
//         snapToDay: true,
//       ),
//       floatingActionButton: FloatingActionButton(
//         child: const Text("Now"),
//         onPressed: () => controller.jumpTo(DateTime.now()),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_timetable/flutter_timetable.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/home_calendar.dart';

class TimetablePage extends StatefulWidget {
  final DateTime date;
  final List<Event> events;

  const TimetablePage({required this.date, required this.events, Key? key}) : super(key: key);

  @override
  _TimetablePageState createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late TimetableController controller;
  late List<TimetableItem<String>> timetableItems;

  @override
  void initState() {
    super.initState();
    controller = TimetableController(
      start: DateUtils.dateOnly(widget.date).subtract(const Duration(days: 7)),
      initialColumns: 3,
      cellHeight: 100.0,
      startHour: 9,
      endHour: 18,
    );


    timetableItems = widget.events.map((event) {

      if (event.startDateTime.isBefore(event.endDateTime)) {
        return TimetableItem<String>(
          event.startDateTime,
          event.endDateTime,
          data: event.title,
        );
      } else {
        // Handle edge cases where the start is not before the end
        // Log the error, show a placeholder, or set a default end time (e.g., start + 1 hour)
        final adjustedEndTime = event.startDateTime.add(const Duration(hours: 1));
        return TimetableItem<String>(
          event.startDateTime,
          adjustedEndTime,
          data: "[Invalid Event] ${event.title}",
        );
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_day),
            onPressed: () => controller.setColumns(1),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_month_outlined),
            onPressed: () => controller.setColumns(3),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            onPressed: () => controller.setColumns(5),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => controller.setCellHeight(controller.cellHeight + 10),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => controller.setCellHeight(controller.cellHeight - 10),
          ),
        ],
      ),
      body: Timetable<String>(
        controller: controller,
        items: timetableItems,
        cellBuilder: (dateTime) => Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blueGrey, width: 0.2),
          ),
          child: Center(
            child: Text(
              DateFormat("MM/d/yyyy\nha").format(dateTime),
              style: TextStyle(
                color: Color(0xff000000 + (0x002222 * dateTime.hour) + (0x110000 * dateTime.day)).withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        cornerBuilder: (datetime) => Container(
          color: Colors.accents[datetime.day % Colors.accents.length],
          child: Center(child: Text("${datetime.year}")),
        ),
        headerCellBuilder: (datetime) {
          final color = Colors.primaries[datetime.day % Colors.accents.length];
          return Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: color, width: 2)),
            ),
            child: Center(
              child: Text(
                DateFormat("E\nMMM d").format(datetime),
                style: TextStyle(
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        hourLabelBuilder: (time) {
          final hour = time.hour == 12 ? 12 : time.hour % 12;
          final period = time.hour < 12 ? "am" : "pm";
          final isCurrentHour = time.hour == DateTime.now().hour;
          return Text(
            "$hour$period",
            style: TextStyle(
              fontSize: 14,
              fontWeight: isCurrentHour ? FontWeight.bold : FontWeight.normal,
            ),
          );
        },
        itemBuilder: (item) => Container(
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(220),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              item.data ?? "No Title",
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        nowIndicatorColor: Colors.red,
        snapToDay: true,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Text("Now"),
        onPressed: () => controller.jumpTo(DateTime.now()),
      ),
    );
  }
}
