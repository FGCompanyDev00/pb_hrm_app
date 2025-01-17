import 'dart:async';

import '../../calendar_day_view.dart';
import '../extensions/date_time_extension.dart';
import 'package:flutter/material.dart';

import '../models/typedef.dart';
import '../utils/date_time_utils.dart';
import '../widgets/background_ignore_pointer.dart';
import '../widgets/current_time_line_widget.dart';
import 'widgets/overflow_list_view_row.dart';

class OverFlowCalendarDayView<T extends Object> extends StatefulWidget {
  const OverFlowCalendarDayView({
    super.key,
    required this.events,
    this.timeTitleColumnWidth = 70.0,
    this.startOfDay = const TimeOfDay(hour: 7, minute: 00),
    this.endOfDay = const TimeOfDay(hour: 17, minute: 00),
    this.heightPerMin = 1.0,
    this.timeGap = 60,
    this.showCurrentTimeLine = false,
    this.renderRowAsListView = false,
    this.showMoreOnRowButton = false,
    required this.currentDate,
    this.timeTextColor,
    this.timeTextStyle,
    this.dividerColor,
    this.currentTimeLineColor,
    this.overflowItemBuilder,
    this.moreOnRowButton,
    this.onTimeTap,
    this.primary,
    this.physics,
    this.controller,
    this.cropBottomEvents = true,
    this.time12 = false,
    this.overflowEvents = const [],
  });

  /// The width of the column that contain list of time points
  final double timeTitleColumnWidth;

  /// To show a line that indicate current hour and minute;
  final bool showCurrentTimeLine;

  /// Color of the current time line
  final Color? currentTimeLineColor;

  /// height in pixel per minute
  final double heightPerMin;

  /// List of events to be display in the day view
  final List<AdvancedDayEvent<T>> events;

  /// the date that this dayView is presenting
  final DateTime currentDate;

  /// To set the start time of the day view
  final TimeOfDay startOfDay;

  /// To set the end time of the day view
  final TimeOfDay endOfDay;

  /// time gap/duration of a row.
  final int timeGap;

  /// color of time point label
  final Color? timeTextColor;

  /// style of time point label
  final TextStyle? timeTextStyle;

  /// time slot divider color
  final Color? dividerColor;

  /// builder for single event
  final DayViewItemBuilder<T>? overflowItemBuilder;

  /// allow render an events row as a ListView
  final bool renderRowAsListView;

  /// allow render button indicate there are more events on the row
  /// also tap to scroll the list to the right
  final bool showMoreOnRowButton;

  /// customized button that indicate there are more events on the row
  final Widget? moreOnRowButton;

  /// allow user to tap on Day view
  final OnTimeTap? onTimeTap;

  /// if true, the bottom events' end time will be cropped by the end time of day view
  /// if false, events that have end time after day view end time will have the show the length that pass through day view end time
  final bool cropBottomEvents;

  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  /// show time in 12 hour format
  final bool time12;

  final List<OverflowEventsRow<T>> overflowEvents;

  @override
  State<OverFlowCalendarDayView> createState() => _OverFlowCalendarDayViewState<T>();
}

class _OverFlowCalendarDayViewState<T extends Object> extends State<OverFlowCalendarDayView<T>> {
  DateTime _currentTime = DateTime.now();
  ValueNotifier<DateTime> selectedDateNotifier = ValueNotifier<DateTime>(DateTime.now());
  Timer? _timer;
  double _rowScale = 1;
  late DateTime timeStart;
  late DateTime timeEnd;

  @override
  void initState() {
    super.initState();
    _rowScale = 1;
    timeStart = widget.currentDate.copyTimeAndMinClean(widget.startOfDay);
    timeEnd = widget.currentDate.copyTimeAndMinClean(widget.endOfDay);

    if (widget.showCurrentTimeLine) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        setState(() {
          _currentTime = DateTime.now();
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant OverFlowCalendarDayView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    timeStart = widget.currentDate.copyTimeAndMinClean(widget.startOfDay);
    timeEnd = widget.currentDate.copyTimeAndMinClean(widget.endOfDay);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heightUnit = widget.heightPerMin * _rowScale;
    final rowHeight = widget.timeGap * widget.heightPerMin * _rowScale;
    final timesInDay = getTimeList(
      timeStart,
      timeEnd,
      widget.timeGap,
    );
    final totalHeight = timesInDay.length * rowHeight;

    return LayoutBuilder(builder: (context, constraints) {
      final viewWidth = constraints.maxWidth;
      final eventColumnWith = viewWidth - widget.timeTitleColumnWidth;

      return SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          primary: widget.primary,
          controller: widget.controller,
          physics: widget.physics ?? const ClampingScrollPhysics(),
          padding: const EdgeInsets.only(top: 20, bottom: 10),
          child: SizedBox(
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: timesInDay.length,
                  itemBuilder: (context, index) {
                    final time = timesInDay.elementAt(index);
                    return GestureDetector(
                      key: ValueKey(time.toString()),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onTimeTap == null ? null : () => widget.onTimeTap!(time),
                      child: SizedBox(
                        height: rowHeight,
                        width: viewWidth,
                        child: Stack(
                          children: [
                            Divider(
                              color: widget.dividerColor ?? Colors.amber,
                              height: 0,
                              thickness: time.minute == 0 ? 1 : .5,
                              indent: widget.timeTitleColumnWidth + 3,
                            ),
                            Transform(
                              transform: Matrix4.translationValues(0, -20, 0),
                              child: SizedBox(
                                height: 40,
                                width: widget.timeTitleColumnWidth,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    children: [
                                      Text(
                                        widget.time12 ? time.hourDisplayZero12 : time.hourDisplay24,
                                        style: widget.timeTextStyle ?? TextStyle(color: widget.timeTextColor),
                                        maxLines: 1,
                                      ),
                                      Visibility(
                                        visible: widget.time12,
                                        child: Text(
                                          time.displayAMPM,
                                          style: widget.timeTextStyle ?? TextStyle(color: widget.timeTextColor, fontSize: 10),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder(
                    valueListenable: selectedDateNotifier,
                    builder: (context, dynamic, child) {
                      child = BackgroundIgnorePointer(
                        ignored: widget.onTimeTap != null,
                        child: Stack(
                          // fit: StackFit.expand,
                          clipBehavior: Clip.none,
                          children: widget.renderRowAsListView
                              ? renderAsListView(
                                  heightUnit,
                                  eventColumnWith,
                                  totalHeight,
                                )
                              : renderWithFixedWidth(heightUnit, eventColumnWith),
                        ),
                      );

                      return child;
                    }),
                if (widget.showCurrentTimeLine && _currentTime.isAfter(timeStart) && _currentTime.isBefore(timeEnd))
                  CurrentTimeLineWidget(
                    top: _currentTime.minuteFrom(timeStart).toDouble() * heightUnit,
                    width: constraints.maxWidth,
                    color: widget.currentTimeLineColor,
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }

  List<Widget> renderWithFixedWidth(double heightUnit, double eventColumnWidth) {
    final widgets = <Widget>[];

    for (final oEvents in widget.overflowEvents) {
      final maxHeight = (heightUnit * oEvents.start.minuteUntil(oEvents.end).abs());

      final numberOfEvents = oEvents.events.length;
      final availableWidth = eventColumnWidth;
      final widthPerEvent = availableWidth / numberOfEvents;
      // int numbers = 0;
      // List<Map<String, DateTime>> listDate = [];

      for (var i = 0; i < oEvents.events.length; i++) {
        // if (listDate.isEmpty) numbers += 1;
        // listDate.add({'start': oEvents.events[i].start, 'end': oEvents.events[i].end!});
        // for (var val in listDate) {
        //   if (val['start']!.laterThan(oEvents.events[i].start) && val['end']!.earlierThan(oEvents.events[i].end!)) {
        //     numbers += 1;
        //     break;
        //   }
        // }
        widgets.add(
          Builder(
            builder: (context) {
              final event = oEvents.events[i];
              final topGap = event.minutesFrom(oEvents.start) * heightUnit;
              final tileHeight = (widget.cropBottomEvents && event.end!.isAfter(timeEnd)) ? (maxHeight - topGap) : (event.durationInMins * heightUnit);

              return Positioned(
                left: widget.timeTitleColumnWidth + i * widthPerEvent,
                top: topGap,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: tileHeight,
                    minHeight: tileHeight,
                    maxWidth: widthPerEvent,
                    minWidth: widthPerEvent,
                  ),
                  child: widget.overflowItemBuilder!(
                    context,
                    BoxConstraints.tight(Size(widthPerEvent, tileHeight)),
                    i,
                    event,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return widgets;
  }

// to render all events in same row as a horizontal istView
  List<Widget> renderAsListView(double heightUnit, double eventColumnWidth, double totalHeight) {
    return [
      for (final oEvents in widget.overflowEvents)
        Positioned(
          top: oEvents.start.minuteFrom(timeStart) * heightUnit,
          left: widget.timeTitleColumnWidth,
          child: OverflowListViewRow(
            totalHeight: totalHeight,
            oEvents: oEvents,
            ignored: widget.onTimeTap != null,
            overflowItemBuilder: widget.overflowItemBuilder!,
            heightUnit: heightUnit,
            eventColumnWith: eventColumnWidth,
            showMoreOnRowButton: widget.showMoreOnRowButton,
            moreOnRowButton: widget.moreOnRowButton,
            cropBottomEvents: widget.cropBottomEvents,
          ),
        ),
    ];
  }
}
