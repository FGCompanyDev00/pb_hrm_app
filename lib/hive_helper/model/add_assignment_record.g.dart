// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_assignment_record.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AddAssignmentRecordAdapter extends TypeAdapter<AddAssignmentRecord> {
  @override
  final int typeId = 2;

  @override
  AddAssignmentRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AddAssignmentRecord(
      projectId: fields[0] as String,
      title: fields[1] as String,
      descriptions: fields[2] as String,
      statusId: fields[3] as String,
      members: (fields[4] as List)
          .map((dynamic e) => (e as Map).cast<String, String>())
          .toList(),
      imagePath: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AddAssignmentRecord obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.projectId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.descriptions)
      ..writeByte(3)
      ..write(obj.statusId)
      ..writeByte(4)
      ..write(obj.members)
      ..writeByte(5)
      ..write(obj.imagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddAssignmentRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
