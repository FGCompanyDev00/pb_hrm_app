import 'package:flutter/material.dart';
import 'package:pb_hrsystem/nav/custom_buttom_nav_bar.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  bool _showAllMeetings = false;
  bool _showAllApprovals = false;
  int _selectedIndex = 0;

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          // Handle navigation
        },
      ),
      body: Column(
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
    final meetings = List.generate(30, (index) => _buildMeetingItem(context, isDarkMode));
    return _buildNotificationList(context, meetings, _showAllMeetings, () {
      setState(() {
        _showAllMeetings = !_showAllMeetings;
      });
    }, isDarkMode);
  }

  Widget _buildApprovalList(BuildContext context, bool isDarkMode) {
    final approvals = List.generate(30, (index) => _buildApprovalItem(context, isDarkMode));
    return _buildNotificationList(context, approvals, _showAllApprovals, () {
      setState(() {
        _showAllApprovals = !_showAllApprovals;
      });
    }, isDarkMode);
  }

  Widget _buildNotificationList(
      BuildContext context, List<Widget> items, bool showAll, VoidCallback onViewMore, bool isDarkMode) {
    final visibleItems = showAll ? items : items.take(10).toList();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              return visibleItems[index];
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

  Widget _buildMeetingItem(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: const Icon(Icons.meeting_room, color: Colors.green),
          title: Text(
            AppLocalizations.of(context)!.meetingTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context)!.meetingDate, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black)),
              Text(AppLocalizations.of(context)!.meetingRoom, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black)),
              Text(AppLocalizations.of(context)!.statusPending, style: TextStyle(color: isDarkMode ? Colors.orange : Colors.orange)),
            ],
          ),
          trailing: const CircleAvatar(
            backgroundImage: AssetImage('assets/avatar_placeholder.png'),
          ),
        ),
      ),
    );
  }

  Widget _buildApprovalItem(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: ListTile(
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event, color: Colors.green),
              const SizedBox(height: 8),
              Text(
                'Room',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          title: const Text(
            'Meeting and Booking meeting room',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: 01-05-2024, 8:30 To 01-05-2024, 12:00'),
              Text('Room: Back can yon 2F', style: TextStyle(color: Colors.red)),
              Text('Status: Pending', style: TextStyle(color: Colors.orange)),
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
