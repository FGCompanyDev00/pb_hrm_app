// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_events_list_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CalendarEventsListRecordAdapter
    extends TypeAdapter<CalendarEventsListRecord> {
  @override
  final int typeId = 6;

  @override
  CalendarEventsListRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CalendarEventsListRecord(
      listEvents: (fields[0] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as DateTime, (v as List).cast<EventRecord>())),
    );
  }

  @override
  void write(BinaryWriter writer, CalendarEventsListRecord obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.listEvents);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalendarEventsListRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
