import 'dart:collection';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';
import 'package:pb_hrsystem/home/home_calendar.dart';

class CalendarDayWidget extends StatelessWidget {
  const CalendarDayWidget({
    super.key,
    required this.eventsCalendar,
    this.selectedDay,
  });

  final List<Event> eventsCalendar;
  final DateTime? selectedDay;

  @override
  Widget build(BuildContext context) {
    final currentTime = DateTime.now();
    int currentHour = currentTime.hour > 9 ? 11 : 7;
    int untilEnd = currentTime.hour > 9 ? 19 : 10;

    List<AdvancedDayEvent<String>> currentEvents = [];
    List<OverflowEventsRow<String>> currentOverflowEventsRow = [];

    eventsCalendar.removeWhere((e) => e.startDateTime.hour == 0 || e.endDateTime.hour == 0);

    for (var e in eventsCalendar) {
      DateTime endTime = DateTime.utc(e.startDateTime.year, e.startDateTime.month, e.startDateTime.day, e.endDateTime.hour, e.endDateTime.minute);
      Duration storeHours = e.startDateTime.difference(endTime);

      if (currentTime.hour > 9) {
        if (storeHours.inHours > 4) {
          // int splitHoursStart = e.startDateTime.hour - storeHours.inHours;
          int splitHours = endTime.hour - storeHours.inHours;
          endTime = endTime.subtract(Duration(hours: splitHours));

          // startTime = startTime.add(const Duration(hours: 0));
          currentEvents.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.description,
            start: e.startDateTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
          ));
        } else {
          currentEvents.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.description,
            start: e.startDateTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
          ));
        }
      } else {
        currentEvents.add(AdvancedDayEvent(
          value: e.uid,
          title: e.title,
          desc: e.description,
          start: e.startDateTime,
          end: endTime,
          category: e.category,
          members: e.members,
          status: e.status,
        ));
      }
    }

    for (var i in currentEvents) {
      currentOverflowEventsRow.add(
        OverflowEventsRow(
          events: currentEvents,
          start: i.start,
          end: i.end ?? i.start.add(const Duration(minutes: 30)),
        ),
      );
    }
    return OverFlowCalendarDayView(
      onTimeTap: (s) {},
      overflowEvents: currentOverflowEventsRow,
      events: UnmodifiableListView(currentEvents),
      dividerColor: Colors.black,
      currentDate: selectedDay ?? DateTime.now(),
      heightPerMin: 2,
      startOfDay: TimeOfDay(hour: currentHour, minute: 0),
      endOfDay: TimeOfDay(hour: untilEnd, minute: 0),
      renderRowAsListView: true,
      showCurrentTimeLine: true,
      cropBottomEvents: true,
      showMoreOnRowButton: true,
      timeTitleColumnWidth: 40,
      time12: true,
      overflowItemBuilder: (context, constraints, itemIndex, event) {
        Color statusColor = Colors.orange;
        if (event.category.contains('Meeting Room Bookings')) {
          statusColor = Colors.green;
        } else if (event.category.contains('Booking Car')) {
          statusColor = Colors.blue.shade300;
        } else if (event.category.contains('Add Meeting')) {
          statusColor = Colors.orange.shade500;
        } else {
          statusColor = Colors.red;
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          key: ValueKey(event.hashCode),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventDetailView(
                  event: {
                    'title': event.title,
                    'description': eventsCalendar[itemIndex].description,
                    'startDateTime': eventsCalendar[itemIndex].startDateTime.toString(),
                    'endDateTime': eventsCalendar[itemIndex].endDateTime.toString(),
                    'isMeeting': eventsCalendar[itemIndex].isMeeting,
                    'createdBy': eventsCalendar[itemIndex].createdBy ?? '',
                    'location': eventsCalendar[itemIndex].location ?? '',
                    'status': event.status,
                    'img_name': eventsCalendar[itemIndex].imgName ?? '',
                    'created_at': eventsCalendar[itemIndex].createdAt ?? '',
                    'is_repeat': eventsCalendar[itemIndex].isRepeat ?? '',
                    'video_conference': eventsCalendar[itemIndex].videoConference ?? '',
                    'uid': eventsCalendar[itemIndex].uid,
                    'members': event.members ?? [],
                    'category': event.category,
                  },
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 3, left: 3),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              border: Border(
                left: BorderSide(color: statusColor, width: 4),
                right: BorderSide(color: statusColor),
                top: BorderSide(color: statusColor),
                bottom: BorderSide(color: statusColor),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(10)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.window_rounded, size: 15),
                        const SizedBox(width: 5),
                        Text(event.category),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: _buildMembersAvatars(event, context)),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.connect_without_contact, size: 15),
                                const SizedBox(width: 5),
                                Text(event.desc, style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                            const SizedBox(width: 20),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 15),
                                const SizedBox(width: 5),
                                Text(
                                  '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${event.end != null ? FLDateTime.formatWithNames(event.end!, 'hh:mm a') : ''}',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildMembersAvatars(
    AdvancedDayEvent<String> event,
    BuildContext context,
  ) {
    List<Widget> membersAvatar = [];
    List<Widget> membersList = [];
    int moreMembers = 0;
    int countMembers = 0;
    bool isEnoughCount = false;

    if (event.members != null) {
      event.members?.forEach((v) {
        countMembers += 1;
        membersList.add(_avatarUserList(v['img_name'], v['member_name']));
        if (isEnoughCount) return;
        if (countMembers < 4) {
          membersAvatar.add(_avatarUser(v['img_name']));
        } else {
          moreMembers = (event.members?.length ?? 0) - (countMembers - 1);
          membersAvatar.add(
            _avatarMore(context, membersList, count: '+ $moreMembers'),
          );
          isEnoughCount = true;
        }
      });
    }
    return membersAvatar;
  }

  Widget _avatarUser(String link) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: CircleAvatar(
        radius: 15,
        backgroundImage: NetworkImage(link),
      ),
    );
  }

  Widget _avatarUserList(String link, name) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(link),
          ),
          const SizedBox(
            width: 20,
          ),
          Text(name),
        ],
      ),
    );
  }

  Widget _avatarMore(BuildContext context, List<Widget> avatarList, {String? count}) {
    return Padding(
      padding: const EdgeInsets.only(right: 3),
      child: GestureDetector(
        onTap: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Attendant'),
                  content: Column(
                    children: avatarList,
                  ),
                )),
        child: CircleAvatar(
          radius: 15,
          backgroundColor: Colors.black54,
          child: Text(
            count ?? '',
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ),
      ),
    );
  }
}

// class CalendarDayWidget extends HookWidget {
//   const CalendarDayWidget({
//     super.key,
//     required this.events,
//     this.selectedDay,
//   });
// }
