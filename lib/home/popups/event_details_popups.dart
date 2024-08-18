import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/home_calendar.dart';

class EventDetailsPopup extends StatelessWidget {
  final Event event;

  const EventDetailsPopup({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    int daysDifference = event.endDateTime.difference(event.startDateTime).inDays + 1;

    Color statusColor;
    switch (event.status) {
      case 'Approved':
        statusColor = Colors.green;
        break;
      case 'Rejected':
        statusColor = Colors.red;
        break;
      case 'Waiting':
      case 'Pending':
      default:
        statusColor = Colors.orange;
        break;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange, Colors.yellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    AppBar(
                      title: const Text('Event Details'),
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    'Requestor',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const ListTile(
                    leading: CircleAvatar(
                      backgroundImage: AssetImage('assets/avatar_placeholder.png'),
                    ),
                    title: Text('Ms. Zhao Lusi'),
                    subtitle: Text('Submitted on 26 Feb 2024 - 11:30:00'),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange.withOpacity(0.3), Colors.yellow.withOpacity(0.3)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Center(
                      child: Text(
                        event.isMeeting ? 'Meeting and Booking meeting room' : 'Leave Request',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.title),
                    title: const Text('Title'),
                    subtitle: Text(event.title),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Start Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(event.startDateTime)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('End Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(event.endDateTime)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Days'),
                    subtitle: Text('$daysDifference days'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Start Time'),
                    subtitle: Text(DateFormat('hh:mm a').format(event.startDateTime)),
                  ),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('End Time'),
                    subtitle: Text(DateFormat('hh:mm a').format(event.endDateTime)),
                  ),
                  const ListTile(
                    leading: Icon(Icons.videocam),
                    title: Text('Type'),
                    subtitle: Text('Meeting online'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.room),
                    title: Text('Room'),
                    subtitle: Text('Back can yon 2F'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: AssetImage('assets/avatar_placeholder.png'),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 10),
                  const Text('Description:'),
                  const SizedBox(height: 10),
                  const Text(
                    'This is a detailed description of the event. It can be multiple lines long.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  if (!event.isMeeting) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: Text(
                        event.status,
                        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (event.isMeeting) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                          ),
                          child: const Text('Reject'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                          ),
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
