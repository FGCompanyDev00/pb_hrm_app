// models/calendar_events_record.dart

import 'package:hive/hive.dart';
import 'package:pb_hrsystem/models/event_record.dart';

part 'calendar_events_list_record.g.dart';

@HiveType(typeId: 1)
class CalendarEventsListRecord extends HiveObject {
  @HiveField(0)
  Map<DateTime, List<EventRecord>> listEvents;

  CalendarEventsListRecord({
    required this.listEvents,
  });
}
