import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';

typedef DayViewItemBuilder<T extends Object> = Widget Function(
  BuildContext context,
  BoxConstraints constraints,

  ///index of the item in same row
  int itemIndex,
  AdvancedDayEvent<T> event,
);

typedef DayViewTimeRowBuilder<T extends Object> = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
  List<AdvancedDayEvent<T>> events,
);

typedef EventDayViewItemBuilder<T extends Object> = Widget Function(
  BuildContext context,
  int itemIndex,
  AdvancedDayEvent<T> event,
);

typedef OnTimeTap = Function(DateTime time);
