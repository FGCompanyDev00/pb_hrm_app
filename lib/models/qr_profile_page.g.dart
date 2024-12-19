// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'qr_profile_page.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileRecordAdapter extends TypeAdapter<UserProfileRecord> {
  @override
  final int typeId = 1;

  @override
  UserProfileRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfileRecord(
      id: fields[0] as String,
      employeeId: fields[1] as String,
      name: fields[2] as String,
      surname: fields[3] as String,
      images: fields[4] as String,
      employeeTel: fields[5] as String,
      employeeEmail: fields[6] as String,
      gender: fields[7] as String,
      roles: fields[8] as String,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfileRecord obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.employeeId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.surname)
      ..writeByte(4)
      ..write(obj.images)
      ..writeByte(5)
      ..write(obj.employeeTel)
      ..writeByte(6)
      ..write(obj.employeeEmail)
      ..writeByte(7)
      ..write(obj.gender)
      ..writeByte(8)
      ..write(obj.roles);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class QRRecordAdapter extends TypeAdapter<QRRecord> {
  @override
  final int typeId = 2;

  @override
  QRRecord read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return QRRecord(
      data: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, QRRecord obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.data);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QRRecordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
