// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EventRecordAdapter extends TypeAdapter<EventRecord> {
  @override
  final int typeId = 4;

  @override
  EventRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EventRecord(
      title: fields[0] as String,
      startDateTime: fields[1] as DateTime,
      endDateTime: fields[2] as DateTime,
      description: fields[3] as String,
      status: fields[4] as String,
      isMeeting: fields[5] as bool,
      location: fields[6] as String?,
      createdBy: fields[7] as String?,
      imgName: fields[8] as String?,
      createdAt: fields[9] as String?,
      uid: fields[10] as String,
      isRepeat: fields[11] as String?,
      videoConference: fields[12] as String?,
      backgroundColor: fields[13] as Color?,
      outmeetingUid: fields[14] as String?,
      leaveType: fields[15] as String?,
      category: fields[16] as String,
      days: fields[17] as double?,
      members: (fields[18] as List?)
          ?.map((dynamic e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }

  @override
  void write(BinaryWriter writer, EventRecord obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.startDateTime)
      ..writeByte(2)
      ..write(obj.endDateTime)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.isMeeting)
      ..writeByte(6)
      ..write(obj.location)
      ..writeByte(7)
      ..write(obj.createdBy)
      ..writeByte(8)
      ..write(obj.imgName)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.uid)
      ..writeByte(11)
      ..write(obj.isRepeat)
      ..writeByte(12)
      ..write(obj.videoConference)
      ..writeByte(13)
      ..write(obj.backgroundColor)
      ..writeByte(14)
      ..write(obj.outmeetingUid)
      ..writeByte(15)
      ..write(obj.leaveType)
      ..writeByte(16)
      ..write(obj.category)
      ..writeByte(17)
      ..write(obj.days)
      ..writeByte(18)
      ..write(obj.members);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
