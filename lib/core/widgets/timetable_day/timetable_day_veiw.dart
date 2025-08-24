// ignore_for_file: deprecated_member_use

import 'dart:collection';
import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter_datetime_format/flutter_datetime_format.dart';
import 'package:pb_hrsystem/l10n/app_localizations.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/widgets/avatar.dart';
import 'package:pb_hrsystem/core/widgets/calendar_day/events_utils.dart';
import 'package:pb_hrsystem/home/event_detail_view.dart';

class TimeTableDayWidget extends HookWidget {
  const TimeTableDayWidget({
    super.key,
    required this.eventsTimeTable,
    this.selectedDay,
  });

  final List<Events> eventsTimeTable;
  final DateTime? selectedDay;

  // Helper method to get appropriate title based on event category
  String getEventTitle(Events event) {
    if (event.category == 'Leave' && event.leaveType != null) {
      return event.leaveType!;
    } else if (event.category == 'Add Meeting') {
      return event.title;
    }
    return event.title;
  }

  // Helper method to get appropriate description based on event category
  String getEventDescription(Events event) {
    if (event.category == 'Leave') {
      return event.desc; // take_leave_reason
    } else if (event.category == 'Add Meeting') {
      return event.title; // Show title for Add Meeting events
    }
    return event.desc;
  }

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<List<Events>> currentEvents = useState([]);
    final ValueNotifier<List<OverTimeEventsRow<String>>>
        currentOverflowEventsRow = useState([]);
    int currentHour = 0;
    int untilEnd = 24;
    late String eventType;

    autoEventsSlot() {
      currentEvents.value.clear();
      currentOverflowEventsRow.value.clear();
      for (var e in eventsTimeTable) {
        DateTime slotStartTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.start.hour,
          e.start.minute,
        );
        DateTime slotEndTime = DateTime.utc(
          selectedDay!.year,
          selectedDay!.month,
          selectedDay!.day,
          e.end.hour,
          e.end.minute,
        );
        DateTime startTime;
        DateTime endTime;

        if (e.start.hour != 0 &&
            e.end.hour != 0 &&
            slotStartTime.isAtSameMomentAs(slotEndTime)) {
          debugPrint('invalid same time');
          startTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            8,
            0,
          );
          endTime = DateTime.utc(
            selectedDay!.year,
            selectedDay!.month,
            selectedDay!.day,
            17,
            0,
          );
          currentEvents.value.add(Events(
            uid: e.uid,
            title: e.title,
            desc: e.desc,
            start: startTime,
            end: endTime,
            category: e.category,
            members: e.members,
            status: e.status,
            leaveType: e.leaveType,
          ));
        } else if (e.end.hour < e.start.hour) {
          debugPrint('wrong time');
        } else {
          if (e.start.hour == 0 && e.end.hour == 0) {
            startTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              8,
              0,
            );
            endTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              17,
              0,
            );
            currentEvents.value.add(Events(
              uid: e.uid,
              title: e.title,
              desc: e.desc,
              start: startTime,
              end: endTime,
              category: e.category,
              members: e.members,
              status: e.status,
              leaveType: e.leaveType,
            ));
          } else {
            startTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              e.start.hour,
              e.start.minute,
            );
            endTime = DateTime.utc(
              selectedDay!.year,
              selectedDay!.month,
              selectedDay!.day,
              e.end.hour,
              e.end.minute,
            );
            currentEvents.value.add(Events(
              uid: e.uid,
              title: e.title,
              desc: e.desc,
              start: startTime,
              end: endTime,
              category: e.category,
              members: e.members,
              status: e.status,
              leaveType: e.leaveType,
            ));
          }
        }
      }

      currentOverflowEventsRow.value = processOverTimeEvents(
        [...currentEvents.value]..sort((a, b) => a.compare(b)),
        startOfDay: selectedDay!
            .copyTimeAndMinClean(TimeOfDay(hour: currentHour, minute: 0)),
        endOfDay: selectedDay!
            .copyTimeAndMinClean(TimeOfDay(hour: untilEnd, minute: 0)),
        cropBottomEvents: true,
      );
    }

    useEffect(() => autoEventsSlot());

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 30),
        child: ValueListenableBuilder(
          valueListenable: currentOverflowEventsRow,
          builder: (context, data, child) {
            return TimeTableDayView(
              onTimeTap: (s) {},
              overflowEvents: data,
              events: UnmodifiableListView(eventsTimeTable),
              dividerColor: Colors.black,
              currentDate: selectedDay ?? DateTime.now(),
              heightPerMin: 1.5,
              startOfDay: const TimeOfDay(hour: 0, minute: 0),
              endOfDay: const TimeOfDay(hour: 25, minute: 0),
              renderRowAsListView: true,
              cropBottomEvents: true,
              showMoreOnRowButton: true,
              timeTitleColumnWidth: 40,
              time12: true,
              timeViewItemBuilder: (context, constraints, itemIndex, event) {
                Color statusColor;
                String? iconCategory = categoryIcon[event.category];
                Duration? time = event.end.difference(event.start);

                debugPrint(event.category);

                statusColor = categoryColors[event.category] ?? Colors.orange;

                switch (event.category) {
                  case 'Add Meeting':
                    eventType = AppLocalizations.of(context)!.meetingTitle;
                    break;
                  case 'Leave':
                    eventType = AppLocalizations.of(context)!.leave;
                    break;
                  case 'Meeting Room Bookings':
                    eventType =
                        AppLocalizations.of(context)!.meetingRoomBookings;
                    break;
                  case 'Booking Car':
                    eventType = AppLocalizations.of(context)!.bookingCar;
                    break;
                  case 'Minutes Of Meeting':
                    eventType = AppLocalizations.of(context)!.minutesOfMeeting;
                    break;
                  default:
                    eventType = AppLocalizations.of(context)!.other;
                }

                switch (event.status) {
                  case 'Approved':
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 10,
                      ),
                      height: constraints.maxHeight,
                      width: 60,
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10)),
                          border: Border.all(
                            color: statusColor,
                            width: 3,
                          )),
                      child: Text(
                        eventType,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  case 'Pending':
                    Container(
                      margin: const EdgeInsets.only(right: 10),
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius:
                            const BorderRadius.all(Radius.circular(10)),
                      ),
                      width: 60,
                      child: DottedBorder(
                        color: statusColor,
                        strokeWidth: 3,
                        dashPattern: const <double>[5, 5],
                        borderType: BorderType.RRect,
                        radius: const Radius.circular(12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 10),
                        child: Text(
                          eventType,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  default:
                }

                return event.category == 'Minutes Of Meeting'
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        key: ValueKey(event.hashCode),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailView(
                                event: {
                                  'title': getEventTitle(event),
                                  'description': event.category == 'Add Meeting'
                                      ? event.desc
                                      : event.desc,
                                  'startDateTime': event.start.toString(),
                                  'endDateTime': event.end.toString(),
                                  'isMeeting': event.isMeeting,
                                  'createdBy': event.createdBy ?? '',
                                  'location': event.location ?? '',
                                  'status': event.status,
                                  'img_name': event.imgName ?? '',
                                  'created_at': event.createdAt ?? '',
                                  'is_repeat': event.isRepeat ?? '',
                                  'video_conference':
                                      event.videoConference ?? '',
                                  'uid': event.uid,
                                  'members': event.members ?? [],
                                  'category': event.category,
                                  'leave_type': event.leaveType ?? '',
                                  'take_leave_reason': event.desc,
                                },
                              ),
                            ),
                          );
                        },
                        child: event.status == 'Cancelled'
                            ? const SizedBox.shrink()
                            : Container(
                                alignment: Alignment.center,
                                margin:
                                    const EdgeInsets.only(right: 3, left: 3),
                                padding: const EdgeInsets.all(8.0),
                                height: constraints.maxHeight,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: ColorStandardization().colorDarkGold,
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(10)),
                                ),
                                child: Text(
                                  eventType,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                      )
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        key: ValueKey(event.hashCode),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventDetailView(
                                event: {
                                  'title': getEventTitle(event),
                                  'description': event.desc,
                                  'startDateTime': event.start.toString(),
                                  'endDateTime': event.end.toString(),
                                  'isMeeting': event.isMeeting,
                                  'createdBy': event.createdBy ?? '',
                                  'location': event.location ?? '',
                                  'status': event.status,
                                  'img_name': event.imgName ?? '',
                                  'created_at': event.createdAt ?? '',
                                  'is_repeat': event.isRepeat ?? '',
                                  'video_conference':
                                      event.videoConference ?? '',
                                  'uid': event.uid,
                                  'members': event.members ?? [],
                                  'category': event.category,
                                  'leave_type': event.leaveType,
                                  'take_leave_reason': event.desc,
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 3, left: 3),
                          padding: const EdgeInsets.all(8.0),
                          height: constraints.maxHeight,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            border: Border(
                              left: BorderSide(color: statusColor, width: 4),
                              right: BorderSide(color: statusColor),
                              top: BorderSide(color: statusColor),
                              bottom: BorderSide(color: statusColor),
                            ),
                            borderRadius:
                                const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Row(
                            children: [
                              (time.inHours) < 2
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(
                                                      Icons.window_rounded,
                                                      size: 15),
                                                  const SizedBox(width: 5),
                                                  Text(eventType),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                children: [
                                                  iconCategory != null
                                                      ? Image.asset(
                                                          iconCategory,
                                                          width: 15)
                                                      : const SizedBox.shrink(),
                                                  const SizedBox(width: 5),
                                                  Text(getEventTitle(event),
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ],
                                              ),
                                              // Text(event.desc, style: const TextStyle(fontSize: 10)),
                                              Row(
                                                children:
                                                    buildMembersAvatarsTimeTable(
                                                        event, context),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(Icons.access_time,
                                                      size: 15),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    '${FLDateTime.formatWithNames(event.start, 'hh:mm a')} - ${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                    style: const TextStyle(
                                                        fontSize: 10),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // First column for eventType and event.desc
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Row for icon and eventType
                                            Row(
                                              children: [
                                                ColorFiltered(
                                                  colorFilter: ColorFilter.mode(
                                                    Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Colors.white
                                                        : Colors.black,
                                                    BlendMode.srcIn,
                                                  ),
                                                  child: Image.asset(
                                                    'assets/icons/element_4.png',
                                                    width: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                                Text(eventType),
                                              ],
                                            ),
                                            const SizedBox(height: 8),

                                            // Row for event.desc
                                            Row(
                                              children: [
                                                const Icon(Icons.title_sharp,
                                                    size: 18,
                                                    color: Colors.blueGrey),
                                                const SizedBox(width: 5),
                                                Align(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  child: Text(
                                                    getEventDescription(event),
                                                    textAlign: TextAlign.start,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      color: Colors.blueGrey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        const Spacer(), // Pushes the next content to the bottom

                                        // Second column for additional content like members, time, and other info
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Row for avatars
                                            Row(
                                              children:
                                                  buildMembersAvatarsTimeTable(
                                                      event, context),
                                            ),
                                            const SizedBox(height: 20),

                                            // Row for time and additional details
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    iconCategory != null
                                                        ? Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    left: 10),
                                                            child: Image.asset(
                                                                iconCategory,
                                                                width: 15),
                                                          )
                                                        : const SizedBox
                                                            .shrink(),
                                                  ],
                                                ),
                                                const SizedBox(width: 20),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 15,
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                          : Colors.black,
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '${FLDateTime.formatWithNames(event.start, 'hh:mm a')}-${FLDateTime.formatWithNames(event.end, 'hh:mm a')}',
                                                      style: const TextStyle(
                                                          fontSize: 10),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                            ],
                          ),
                        ),
                      );
              },
            );
          },
        ),
      ),
    );
  }
}
