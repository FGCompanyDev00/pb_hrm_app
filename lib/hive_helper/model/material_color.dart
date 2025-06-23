// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class MaterialColorAdapter extends TypeAdapter<MaterialColor> {
  @override
  final int typeId = 100;

  @override
  MaterialColor read(BinaryReader reader) {
    final int value = reader.readInt();
    return Colors.primaries.firstWhere((color) => color.value == value);
  }

  @override
  void write(BinaryWriter writer, MaterialColor obj) {
    writer.writeInt(obj.value);
  }
}
