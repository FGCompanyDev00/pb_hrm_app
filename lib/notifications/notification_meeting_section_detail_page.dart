// notification_meeting_detail_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationMeetingDetailsPage extends StatefulWidget {
  final String id;

  const NotificationMeetingDetailsPage({
    super.key,
    required this.id,
  });

  @override
  NotificationMeetingDetailsPageState createState() => NotificationMeetingDetailsPageState();
}

class NotificationMeetingDetailsPageState extends State<NotificationMeetingDetailsPage> with SingleTickerProviderStateMixin {
  bool isLoading = true;
  bool isFinalized = false;
  Map<String, dynamic>? meetingData;
  String? requestorImage;
  String? userResponse;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchMeetingDetails();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  Future<void> _fetchMeetingDetails() async {
    String apiUrl = '$baseUrl/api/office-administration/book_meeting_room/invite-meeting/${widget.id}';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] != null) {
          setState(() {
            meetingData = Map<String, dynamic>.from(data['results']);

            String? imgName = meetingData!['img_name']?.toString().trim();

            if (imgName != null && imgName.isNotEmpty) {
              requestorImage = imgName;
            } else {
              requestorImage = 'https://via.placeholder.com/150';
            }

            userResponse = meetingData!['status']?.toString().toLowerCase();

            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load meeting details.');
        }
      } else {
        throw Exception('Failed to load meeting details: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error', e.toString());
      setState(() {
        isLoading = false;
      });
    }
  }

  String formatDate(String? dateStr) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      DateTime parsedDate = DateTime.parse(dateStr);

      return DateFormat('EEEE, dd MMM yyyy - HH:mm:ss').format(parsedDate);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context, darkModeGlobal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  _buildRequestorSection(darkModeGlobal),
                  const SizedBox(height: 20),
                  _buildBlueSection(darkModeGlobal),
                  const SizedBox(height: 40),
                  _buildMeetingDetails(darkModeGlobal),
                  const SizedBox(height: 30),
                  _buildMeetingActionButtons(),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool darkModeGlobal) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(darkModeGlobal ? 'assets/darkbg.png' : 'assets/background.png'),
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
        'Meeting Details',
        style: TextStyle(color: darkModeGlobal ? Colors.white : Colors.black, fontSize: 20),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, color: darkModeGlobal ? Colors.white : Colors.black, size: 20),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection(bool darkModeGlobal) {
    String requestorName = meetingData?['employee_name'] ?? 'No Name';
    String submittedOn = formatDate(meetingData?['date_create']);
    String profileImage = requestorImage ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Organizer',
            style: TextStyle(
              color: darkModeGlobal ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            )),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(profileImage),
              radius: 30,
              backgroundColor: Colors.grey[300],
              onBackgroundImageError: (error, stackTrace) {},
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: TextStyle(
                      color: darkModeGlobal ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted on $submittedOn',
                    style: TextStyle(
                      fontSize: 14,
                      color: darkModeGlobal ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlueSection(bool darkModeGlobal) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: darkModeGlobal ? Colors.blueGrey.withOpacity(0.3) : Colors.lightBlueAccent.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'MEETING ROOM BOOKING REQUEST',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: darkModeGlobal ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMeetingDetails(bool darkModeGlobal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Meeting ID', meetingData?['meeting_id']?.toString() ?? 'N/A', Icons.meeting_room, Colors.green, darkModeGlobal),
        _buildInfoRow('Title', meetingData?['title'] ?? 'N/A', Icons.title, Colors.blue, darkModeGlobal),
        _buildInfoRow('From Date', formatDate(meetingData?['from_date_time']), Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow('To Date', formatDate(meetingData?['to_date_time']), Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow('Room Name', meetingData?['room_name']?.toString() ?? 'N/A', Icons.room, Colors.orange, darkModeGlobal),
        _buildInfoRow('Floor', meetingData?['room_floor']?.toString() ?? 'N/A', Icons.layers, Colors.orange, darkModeGlobal),
        _buildInfoRow('Branch Name', meetingData?['branch_name']?.toString() ?? 'N/A', Icons.business, Colors.red, darkModeGlobal),
        _buildInfoRow('Status', meetingData?['status']?.toString() ?? 'Pending', Icons.stairs, Colors.red, darkModeGlobal),
        _buildMembersSection(darkModeGlobal),
      ],
    );
  }

  Widget _buildInfoRow(String title, String content, IconData icon, Color color, bool darkModeGlobal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon color stays the same in both light and dark mode
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$title: $content',
              style: TextStyle(
                fontSize: 14,
                color: darkModeGlobal ? Colors.white : Colors.black, // Text color changes based on dark mode
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(bool darkModeGlobal) {
    List<dynamic> members = meetingData?['members'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text(
          'Members:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        ...members.map((member) {
          String memberName = member['member_name'] ?? 'No Name';
          String status = member['status'] ?? 'Unknown';
          String memberImage = member['img_name'] ?? 'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(memberImage),
                backgroundColor: darkModeGlobal ? Colors.grey[700] : Colors.grey[300], // Adjust avatar background color
                radius: 20,
                onBackgroundImageError: (error, stackTrace) {},
              ),
              title: Text(
                memberName,
                style: TextStyle(
                  fontSize: 14,
                  color: darkModeGlobal ? Colors.white : Colors.black, // Text color for dark mode
                ),
              ),
              subtitle: Text(
                'Status: $status',
                style: TextStyle(
                  fontSize: 12,
                  color: darkModeGlobal ? Colors.white70 : Colors.black54, // Subtitle text color
                ),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMeetingActionButtons() {
    bool alreadyResponded = userResponse != null && (userResponse == 'yes' || userResponse == 'no' || userResponse == 'undecided');
    String responseLabel = '';
    Color buttonColor = Colors.grey;
    IconData buttonIcon = Icons.check;

    if (userResponse == 'yes') {
      responseLabel = 'Joined';
      buttonColor = Colors.blue;
      buttonIcon = Icons.check;
    } else if (userResponse == 'no') {
      responseLabel = 'Declined';
      buttonColor = Colors.red;
      buttonIcon = Icons.close;
    } else if (userResponse == 'undecided') {
      responseLabel = 'Undecided';
      buttonColor = Colors.orange;
      buttonIcon = Icons.help_outline;
    }

    return Column(
      children: [
        alreadyResponded
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: buttonColor,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: Icon(buttonIcon, color: Colors.white, size: 18),
                    label: Text(responseLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ],
              )
            : Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _buildResponsiveButton(
                    label: 'Join',
                    icon: Icons.person_add,
                    backgroundColor: Colors.blue,
                    textColor: Colors.white,
                    onPressed: () => _handleMeetingAction('join'),
                  ),
                  _buildResponsiveButton(
                    label: 'Decline',
                    icon: Icons.close,
                    backgroundColor: Colors.red,
                    textColor: Colors.white,
                    onPressed: () => _handleMeetingAction('decline'),
                  ),
                  _buildResponsiveButton(
                    label: 'Undecided',
                    icon: Icons.help_outline,
                    backgroundColor: Colors.orange,
                    textColor: Colors.white,
                    onPressed: () => _handleMeetingAction('undecided'),
                  ),
                ],
              ),
        if (_animationController.isAnimating)
          ScaleTransition(
            scale: _animation,
            child: const Icon(
              Icons.celebration,
              color: Colors.pink,
              size: 40,
            ),
          ),
      ],
    );
  }

  Widget _buildResponsiveButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.28,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        icon: Icon(icon, color: textColor, size: 18),
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
      ),
    );
  }

  Future<void> _handleMeetingAction(String action) async {
    final String uid = widget.id;

    String endpoint;

    if (action == 'join') {
      endpoint = '$baseUrl/api/office-administration/book_meeting_room/yes/$uid';
    } else if (action == 'decline' || action == 'undecided') {
      endpoint = '$baseUrl/api/office-administration/book_meeting_room/no/$uid';
    } else {
      _showErrorDialog('Error', 'Invalid action.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isFinalized = false;
        });
        return;
      }

      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          userResponse = action == 'join'
              ? 'yes'
              : action == 'decline'
                  ? 'no'
                  : 'undecided';
        });
        _animationController.forward().then((_) {
          _animationController.reset();
        });
        _showSuccessDialog('Success', 'You have successfully ${action == 'join' ? 'joined' : 'responded to'} the meeting invite.');
        Navigator.of(context).pop(true);
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage = responseBody['message'] ?? 'Failed to $action the meeting invite.';
        _showErrorDialog('Error', errorMessage);
        setState(() {
          isFinalized = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred.');
      setState(() {
        isFinalized = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
