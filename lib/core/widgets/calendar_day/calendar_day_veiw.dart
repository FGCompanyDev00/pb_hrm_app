import 'dart:collection';

import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/events_utils.dart';
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
    final currentTime = DateTime.now().toUtc();
    int currentHour = currentTime.hour > 9 ? 10 : 7;
    int untilEnd = currentTime.hour > 9 ? 19 : 11;

    List<AdvancedDayEvent<String>> currentEvents = [];
    List<OverflowEventsRow<String>> currentOverflowEventsRow = [];

    for (var e in eventsCalendar) {
      DateTime startTime = DateTime.utc(
        selectedDay!.year,
        selectedDay!.month,
        selectedDay!.day,
        e.startDateTime.hour == 0
            ? currentTime.hour > 9
                ? 10
                : 7
            : e.startDateTime.hour,
        e.startDateTime.minute,
      );
      DateTime endTime = DateTime.utc(
        selectedDay!.year,
        selectedDay!.month,
        selectedDay!.day,
        e.endDateTime.hour == 0
            ? currentTime.hour > 9
                ? 18
                : 10
            : e.endDateTime.hour,
        e.endDateTime.minute,
      );
      Duration storeHours = endTime.difference(startTime);

      if (currentTime.hour > 10) {
        if (storeHours.inHours < 4) {
          currentEvents.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.description,
            start: startTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
          ));
        } else {
          if (startTime.hour <= 10 && startTime.minute > 0) {
            int addHours = 10 - startTime.hour;
            startTime = startTime.add(Duration(hours: addHours)).subtract(Duration(minutes: startTime.minute));
          }

          if (endTime.hour > 18 && endTime.minute > 0) {
            int subHours = 18 - endTime.hour;
            endTime = endTime.subtract(Duration(hours: subHours, minutes: endTime.minute));
          }
          currentEvents.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.description,
            start: startTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
          ));
        }
      } else {
        if (startTime.hour < currentHour) {
          if (startTime.hour < 7) {
            int addHours = 7 - startTime.hour;

            startTime = startTime.add(Duration(hours: addHours)).subtract(Duration(minutes: startTime.minute));
          }

          if (endTime.hour >= 10 && endTime.minute > 0) {
            int subHours = endTime.hour - 11;
            endTime = endTime.subtract(Duration(hours: subHours, minutes: endTime.minute));
          }

          currentEvents.add(AdvancedDayEvent(
            value: e.uid,
            title: e.title,
            desc: e.description,
            start: startTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
          ));
        }
      }
    }
    currentOverflowEventsRow = processOverflowEvents(
      [...currentEvents]..sort((a, b) => a.compare(b)),
      startOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: currentHour, minute: 0)),
      endOfDay: selectedDay!.copyTimeAndMinClean(TimeOfDay(hour: untilEnd, minute: 0)),
      // cropBottomEvents: true,
    );

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
        Color statusColor = categoryColors[event.category] ?? Colors.grey;
        IconData? iconCategory = categoryIcon[event.category];

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
                                iconCategory != null ? Icon(iconCategory, size: 15) : const SizedBox.shrink(),
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
