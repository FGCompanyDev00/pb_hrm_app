import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/dashboard.dart';
import 'package:pb_hrsystem/main.dart';
import 'package:pb_hrsystem/nav/custom_buttom_nav_bar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _showAllMeetings = false;
  bool _showAllApprovals = false;
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final String apiUrl = 'https://demo-application-api.flexiflows.co/api/work-tracking/proj/notifications';
    final String employeeId = 'PSV-00-000002'; // Replace with dynamic ID if needed

    try {
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          setState(() {
            _notifications = List<Map<String, dynamic>>.from(data['results']);
            _isLoading = false;
          });
        } else {
          throw Exception('No notifications found');
        }
      } else {
        throw Exception('Failed to load notifications');
      }
    } catch (e) {
      print("Error fetching notifications: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

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
        title: Text(
          AppLocalizations.of(context)!.notification,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const MainScreen()),
            );
          },
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        _buildSegment(AppLocalizations.of(context)!.meeting, 0, isDarkMode),
                        _buildSegment(AppLocalizations.of(context)!.approval, 1, isDarkMode),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: _selectedIndex == 0
                      ? _buildMeetingList(context, isDarkMode)
                      : _buildApprovalList(context, isDarkMode),
                ),
              ],
            ),
    );
  }

  Widget _buildSegment(String text, int index, bool isDarkMode) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.green : isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            borderRadius: index == 0
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: isSelected ? Colors.white : isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeetingList(BuildContext context, bool isDarkMode) {
    final meetings = _notifications.where((notif) => notif['meeting_id'] != "").toList();
    return _buildNotificationList(context, meetings, _showAllMeetings, () {
      setState(() {
        _showAllMeetings = !_showAllMeetings;
      });
    }, isDarkMode);
  }

  Widget _buildApprovalList(BuildContext context, bool isDarkMode) {
    final approvals = _notifications.where((notif) => notif['assignment_id'] != "").toList();
    return _buildNotificationList(context, approvals, _showAllApprovals, () {
      setState(() {
        _showAllApprovals = !_showAllApprovals;
      });
    }, isDarkMode);
  }

  Widget _buildNotificationList(
      BuildContext context, List<Map<String, dynamic>> items, bool showAll, VoidCallback onViewMore, bool isDarkMode) {
    final visibleItems = showAll ? items : items.take(10).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              return _buildNotificationItem(visibleItems[index], isDarkMode);
            },
          ),
        ),
        if (!showAll)
          Center(
            child: ElevatedButton(
              onPressed: onViewMore,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.green,
              ),
              child: Text(AppLocalizations.of(context)!.viewMore),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notification, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Icon(
            notification['meeting_id'] != "" ? Icons.meeting_room : Icons.event,
            color: Colors.green,
          ),
          title: Text(
            notification['message'] ?? "Notification",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification['created_at'] ?? "Unknown date", style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black)),
              Text("Status: ${notification['status'] == 0 ? 'Pending' : 'Completed'}", style: TextStyle(color: isDarkMode ? Colors.orange : Colors.orange)),
            ],
          ),
          trailing: const CircleAvatar(
            backgroundImage: AssetImage('assets/avatar_placeholder.png'),
          ),
        ),
      ),
    );
  }
}
