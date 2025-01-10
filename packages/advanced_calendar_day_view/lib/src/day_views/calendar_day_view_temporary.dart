import 'dart:async';
import 'package:flutter/material.dart';

import '../../calendar_day_view.dart';
import '../extensions/date_time_extension.dart';
import '../models/typedef.dart';
import '../utils/date_time_utils.dart';
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

  // Widget properties
  final double timeTitleColumnWidth;
  final bool showCurrentTimeLine;
  final Color? currentTimeLineColor;
  final double heightPerMin;
  final List<AdvancedDayEvent<T>> events;
  final DateTime currentDate;
  final TimeOfDay startOfDay;
  final TimeOfDay endOfDay;
  final int timeGap;
  final Color? timeTextColor;
  final TextStyle? timeTextStyle;
  final Color? dividerColor;
  final DayViewItemBuilder<T>? overflowItemBuilder;
  final bool renderRowAsListView;
  final bool showMoreOnRowButton;
  final Widget? moreOnRowButton;
  final OnTimeTap? onTimeTap;
  final bool cropBottomEvents;
  final bool? primary;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool time12;
  final List<OverflowEventsRow<T>> overflowEvents;

  @override
  State<OverFlowCalendarDayView> createState() => _OverFlowCalendarDayViewState<T>();
}

class _OverFlowCalendarDayViewState<T extends Object> extends State<OverFlowCalendarDayView<T>> {
  late DateTime _currentTime;
  late DateTime timeStart;
  late DateTime timeEnd;
  Timer? _timer;
  final double _rowScale = 1;

  @override
  void initState() {
    super.initState();
    _currentTime = DateTime.now();
    timeStart = widget.currentDate.copyTimeAndMinClean(widget.startOfDay);
    timeEnd = widget.currentDate.copyTimeAndMinClean(widget.endOfDay);

    if (widget.showCurrentTimeLine) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) {
        setState(() => _currentTime = DateTime.now());
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
    final rowHeight = widget.timeGap * heightUnit;
    final timesInDay = getTimeList(timeStart, timeEnd, widget.timeGap);
    final totalHeight = timesInDay.length * rowHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewWidth = constraints.maxWidth;
        final eventColumnWidth = viewWidth - widget.timeTitleColumnWidth;

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
                  _buildTimeRows(timesInDay, rowHeight, viewWidth),
                  _buildEvents(heightUnit, eventColumnWidth, totalHeight),
                  if (widget.showCurrentTimeLine && _currentTime.isAfter(timeStart) && _currentTime.isBefore(timeEnd))
                    CurrentTimeLineWidget(
                      top: _currentTime.minuteFrom(timeStart).toDouble() * heightUnit,
                      width: viewWidth,
                      color: widget.currentTimeLineColor,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeRows(List<DateTime> timesInDay, double rowHeight, double viewWidth) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timesInDay.length,
      itemBuilder: (context, index) {
        final time = timesInDay[index];
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
                  thickness: time.minute == 0 ? 1 : 0.5,
                  indent: widget.timeTitleColumnWidth + 3,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  child: SizedBox(
                    width: widget.timeTitleColumnWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.time12 ? time.hourDisplayZero12 : time.hourDisplay24,
                          style: widget.timeTextStyle ?? TextStyle(color: widget.timeTextColor),
                        ),
                        if (widget.time12)
                          Text(
                            time.displayAMPM,
                            style: widget.timeTextStyle?.copyWith(fontSize: 10) ?? const TextStyle(fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEvents(double heightUnit, double eventColumnWidth, double totalHeight) {
    return Stack(
      children: widget.renderRowAsListView ? renderAsListView(heightUnit, eventColumnWidth, totalHeight) : renderWithFixedWidth(heightUnit, eventColumnWidth),
    );
  }

  List<Widget> renderWithFixedWidth(double heightUnit, double eventColumnWidth) {
    final widgets = <Widget>[];
    for (final oEvents in widget.overflowEvents) {
      for (var i = 0; i < oEvents.events.length; i++) {
        final event = oEvents.events[i];
        final width = eventColumnWidth / oEvents.events.length;
        final topPosition = event.minutesFrom(oEvents.start) * heightUnit;
        final tileHeight = widget.cropBottomEvents && event.end!.isAfter(timeEnd) ? (event.minutesFrom(oEvents.end).abs() * heightUnit) : (event.durationInMins * heightUnit);

        widgets.add(Positioned(
          top: topPosition,
          left: widget.timeTitleColumnWidth + (i * width),
          child: Container(
            constraints: BoxConstraints.tightFor(
              height: tileHeight,
              width: width,
            ),
            child: widget.overflowItemBuilder!(context, BoxConstraints.tightFor(height: tileHeight, width: width), i, event),
          ),
        ));
      }
    }
    return widgets;
  }

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
