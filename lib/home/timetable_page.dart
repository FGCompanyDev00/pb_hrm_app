import 'package:advanced_calendar_day_view/calendar_day_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/color.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:pb_hrsystem/core/utils/user_preferences.dart';
import 'package:pb_hrsystem/core/widgets/timetable_day/timetable_day_veiw.dart';
import 'package:pb_hrsystem/services/services_locator.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class TimetablePage extends StatefulWidget {
  final DateTime date;

  const TimetablePage({
    super.key,
    required this.date,
  });

  @override
  TimetablePageState createState() => TimetablePageState();
}

class TimetablePageState extends State<TimetablePage> {
  late DateTime selectedDate = widget.date;
  final switchTime = ValueNotifier(false);
  final liveDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    switchTime.value = (liveDay.hour < 18 && liveDay.hour > 6) ? false : true;

    fetchData();
  }

  /// Filters and searches events based on selected category and search query
  void filterDate() {
    List<Events>? dayEvents = _getEventsForDay(selectedDate);

    setState(() {
      eventsForDay = dayEvents;
    });
  }

  /// Retrieves events for a specific day
  List<Events> _getEventsForDay(DateTime day) {
    final normalizedDay = normalizeDate(day);
    return events.value[normalizedDay] ?? [];
  }

  /// Fetches all required data concurrently
  Future<void> fetchData() async {
    filterDate();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.calendar,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            switchTime.value = !switchTime.value;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 10.0,
                horizontal: 25,
              ),
              child: Text(
                DateFormat.yMMMM(sl<UserPreferences>().getLocalizeSupport().languageCode).format(selectedDate),
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (index) {
                  final day = selectedDate.add(Duration(days: index - 3));
                  final hasEvent = eventsForAll.any((event) => event.start.day == day.day && event.start.month == day.month && event.start.year == day.year);
                  return _buildDateItem(
                    DateFormat.E(sl<UserPreferences>().getLocalizeSupport().languageCode).format(day),
                    day.day,
                    isSelected: day.day == selectedDate.day,
                    hasEvent: hasEvent,
                    onTap: () async {
                      setState(() {
                        selectedDate = day;
                      });
                      await fetchData();
                    },
                    isDarkMode: isDarkMode,
                  );
                }),
              ),
            ),
            Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: ColorStandardization().colorDarkGold,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.grey,
                    spreadRadius: 1.0,
                    blurRadius: 5.0,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TimeTableDayWidget(
              eventsTimeTable: eventsForDay,
              selectedDay: selectedDate,
              passDefaultCurrentHour: switchTime.value
                  ? 0
                  : liveDay.hour < 18
                      ? liveDay.hour
                      : 7,
              passDefaultEndHour: switchTime.value ? 25 : 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateItem(String day, int date, {bool isSelected = false, bool hasEvent = false, required VoidCallback onTap, required bool isDarkMode}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 12,
        ),
        width: 45,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFD4A017)
              : hasEvent
                  ? Colors.green.withOpacity(0.5)
                  : isDarkMode
                      ? Colors.grey[700]
                      : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              day.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.grey),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$date",
              style: TextStyle(
                fontSize: 16,
                color: isSelected || hasEvent ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
