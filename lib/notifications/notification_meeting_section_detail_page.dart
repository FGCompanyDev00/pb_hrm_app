// notification_meeting_detail_page.dart

// ignore_for_file: avoid_print, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class NotificationMeetingDetailsPage extends StatefulWidget {
  final String id;
  final bool isOutMeeting;

  const NotificationMeetingDetailsPage({
    super.key,
    required this.id,
    this.isOutMeeting = false,
  });

  @override
  NotificationMeetingDetailsPageState createState() =>
      NotificationMeetingDetailsPageState();
}

class NotificationMeetingDetailsPageState
    extends State<NotificationMeetingDetailsPage>
    with SingleTickerProviderStateMixin {
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
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  Future<void> _fetchMeetingDetails() async {
    // Choose API based on meeting type
    String apiUrl = widget.isOutMeeting
        ? '$baseUrl/api/work-tracking/out-meeting/outmeeting/my-member/${widget.id}'
        : '$baseUrl/api/office-administration/book_meeting_room/invite-meeting/${widget.id}';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log in again.');
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

            // For out-meeting, check if the current user's response is in the member list
            if (widget.isOutMeeting && meetingData!['members'] != null) {
              getMyResponseFromOutMeeting();
            }

            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load meeting details.');
        }
      } else {
        throw Exception('Failed to load meeting details');
      }
    } catch (e) {
      _showErrorDialog('Error', e.toString());
      setState(() {
        isLoading = false;
      });
    }
  }

  // Function to get the current user's response from out-meeting members list
  Future<void> getMyResponseFromOutMeeting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? employeeId = prefs.getString('employee_id');

      if (employeeId != null && meetingData!['members'] != null) {
        final List<dynamic> members = meetingData!['members'];
        for (var member in members) {
          if (member['employee_id'] == employeeId) {
            setState(() {
              userResponse =
                  member['going']?.toString().toLowerCase() ?? 'pending';
            });
            break;
          }
        }
      }
    } catch (e) {
      print('Error getting response from out-meeting: $e');
    }
  }

  // Function to submit a response for out-meeting
  Future<void> submitOutMeetingResponse(String response) async {
    setState(() {
      isLoading = true;
    });

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      // Get the outmeeting_uid from meetingData, fallback to widget.id if not available
      String outmeetingUid =
          meetingData?['outmeeting_uid']?.toString() ?? widget.id;

      if (kDebugMode) {
        print('Using outmeeting_uid: $outmeetingUid for $response response');
      }

      // Determine which API to call based on the response
      String apiUrl;
      switch (response.toLowerCase()) {
        case 'yes':
          apiUrl =
              '$baseUrl/api/work-tracking/out-meeting/outmeeting/yes/$outmeetingUid';
          break;
        case 'no':
          apiUrl =
              '$baseUrl/api/work-tracking/out-meeting/outmeeting/no/$outmeetingUid';
          break;
        case 'maybe':
          apiUrl =
              '$baseUrl/api/work-tracking/out-meeting/outmeeting/maybe/$outmeetingUid';
          break;
        default:
          throw Exception('Invalid response');
      }

      if (kDebugMode) {
        print('Making PUT request to: $apiUrl');
      }

      final responseData = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Response status: ${responseData.statusCode}');
        print('Response body: ${responseData.body}');
      }

      // Accept both 200 and 201 as successful status codes
      if (responseData.statusCode == 200 || responseData.statusCode == 201) {
        final data = jsonDecode(responseData.body);
        // Check if the API response itself indicates success
        if (data['statusCode'] == 200 || data['statusCode'] == 201) {
          setState(() {
            userResponse = response.toLowerCase();
            isFinalized = true;
          });

          // Refresh meeting details
          await _fetchMeetingDetails();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Response submitted successfully')),
          );
        } else {
          throw Exception(data['message'] ?? 'Failed to submit response');
        }
      } else {
        throw Exception(
            'Failed to submit response: ${responseData.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in submitOutMeetingResponse: $e');
      }
      _showErrorDialog('Error', e.toString());
    } finally {
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
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: _buildAppBar(context, isDarkMode),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  _buildRequestorSection(isDarkMode),
                  const SizedBox(height: 20),
                  _buildBlueSection(isDarkMode),
                  const SizedBox(height: 40),
                  _buildMeetingDetails(isDarkMode),
                  const SizedBox(height: 30),
                  widget.isOutMeeting
                      ? _buildOutMeetingActionButtons()
                      : _buildMeetingActionButtons(),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDarkMode) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
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
        style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black, fontSize: 20),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black, size: 20),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection(bool isDarkMode) {
    String requestorName = meetingData?['created_by_name'] ?? 'No Name';
    String submittedOn = formatDate(meetingData?['created_at']);
    String profileImage = requestorImage ??
        'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('Organizer',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
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
              backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[300],
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
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Submitted on $submittedOn',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
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

  Widget _buildBlueSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.blueGrey.withOpacity(0.3)
            : Colors.lightBlueAccent.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        widget.isOutMeeting
            ? 'ADD MEETING INVITATION'
            : 'MEETING ROOM BOOKING REQUEST',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildMeetingDetails(bool isDarkMode) {
    if (widget.isOutMeeting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              'Meeting ID',
              meetingData?['outmeeting_uid']?.toString() ?? 'N/A',
              Icons.meeting_room,
              Colors.purple,
              isDarkMode),
          _buildInfoRow('Title', meetingData?['title'] ?? 'N/A', Icons.title,
              Colors.blue, isDarkMode),
          _buildInfoRow('Description', meetingData?['description'] ?? 'N/A',
              Icons.description, Colors.teal, isDarkMode),
          _buildInfoRow('From Date', formatDate(meetingData?['fromdate']),
              Icons.calendar_today, Colors.blue, isDarkMode),
          _buildInfoRow('To Date', formatDate(meetingData?['todate']),
              Icons.calendar_today, Colors.blue, isDarkMode),
          _buildInfoRow(
              'Notification',
              '${meetingData?['notification'] ?? 'N/A'} minutes',
              Icons.notifications,
              Colors.pink,
              isDarkMode),
          _buildInfoRow(
              'Status',
              meetingData?['status']?.toString() ?? 'Pending',
              Icons.info,
              Colors.red,
              isDarkMode),
          _buildInfoRow(
              'Created By',
              meetingData?['created_by_name']?.toString() ?? 'N/A',
              Icons.person,
              Colors.indigo,
              isDarkMode),
          _buildOutMeetingMembersSection(isDarkMode),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
              'Meeting ID',
              meetingData?['meeting_id']?.toString() ?? 'N/A',
              Icons.meeting_room,
              Colors.green,
              isDarkMode),
          _buildInfoRow('Title', meetingData?['title'] ?? 'N/A', Icons.title,
              Colors.blue, isDarkMode),
          _buildInfoRow('From Date', formatDate(meetingData?['from_date_time']),
              Icons.calendar_today, Colors.blue, isDarkMode),
          _buildInfoRow('To Date', formatDate(meetingData?['to_date_time']),
              Icons.calendar_today, Colors.blue, isDarkMode),
          _buildInfoRow(
              'Room Name',
              meetingData?['room_name']?.toString() ?? 'N/A',
              Icons.room,
              Colors.orange,
              isDarkMode),
          _buildInfoRow(
              'Floor',
              meetingData?['room_floor']?.toString() ?? 'N/A',
              Icons.layers,
              Colors.orange,
              isDarkMode),
          _buildInfoRow(
              'Branch Name',
              meetingData?['branch_name']?.toString() ?? 'N/A',
              Icons.business,
              Colors.red,
              isDarkMode),
          _buildInfoRow(
              'Status',
              meetingData?['status']?.toString() ?? 'Pending',
              Icons.stairs,
              Colors.red,
              isDarkMode),
          _buildMembersSection(isDarkMode),
        ],
      );
    }
  }

  Widget _buildInfoRow(String title, String content, IconData icon, Color color,
      bool isDarkMode) {
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
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersSection(bool isDarkMode) {
    List<dynamic> members = meetingData?['members'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Members:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        ...members.map((member) {
          String memberName = member['member_name'] ?? 'No Name';
          String status = member['status'] ?? 'Unknown';
          String memberImage = member['img_name'] ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: ListTile(
              leading: CircleAvatar(
                backgroundImage: NetworkImage(memberImage),
                backgroundColor:
                    isDarkMode ? Colors.grey[700] : Colors.grey[300],
                radius: 20,
                onBackgroundImageError: (error, stackTrace) {},
              ),
              title: Text(
                memberName,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              subtitle: Text(
                'Status: $status',
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
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
    bool alreadyResponded = userResponse != null &&
        (userResponse == 'yes' ||
            userResponse == 'no' ||
            userResponse == 'undecided');
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    icon: Icon(buttonIcon, color: Colors.white, size: 18),
                    label: Text(responseLabel,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        icon: Icon(icon, color: textColor, size: 18),
        label: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
      ),
    );
  }

  Future<void> _handleMeetingAction(String action) async {
    final String uid = widget.id;

    String endpoint;

    if (action == 'join') {
      endpoint =
          '$baseUrl/api/office-administration/book_meeting_room/yes/$uid';
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
        _showErrorDialog(
            'Authentication Error', 'Token not found. Please log in again.');
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

      // Accept both 200 and 201 as successful status codes
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
        _showSuccessDialog('Success',
            'You have successfully ${action == 'join' ? 'joined' : 'responded to'} the meeting invite.');
        Navigator.of(context).pop(true);
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Failed to $action the meeting invite.';
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
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          title,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          message,
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: isDarkMode ? Colors.amber : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    final themeNotifier = Provider.of<ThemeNotifier>(context, listen: false);
    final bool isDarkMode = themeNotifier.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
        title: Text(
          title,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        content: Text(
          message,
          style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(true);
            },
            child: Text(
              'OK',
              style: TextStyle(color: isDarkMode ? Colors.green : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  // New method to build action buttons for out-meeting
  Widget _buildOutMeetingActionButtons() {
    // Check if user has already responded
    bool hasResponded = userResponse != null && userResponse != 'pending';
    String currentResponse = userResponse?.toLowerCase() ?? 'pending';

    return Column(
      children: [
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStylishButton(
              label: 'Confirm',
              icon: Icons.check_circle_outline,
              activeColor: Colors.green.shade600,
              isActive: currentResponse == 'yes',
              isDisabled: hasResponded && currentResponse != 'yes',
              onPressed: () => submitOutMeetingResponse('yes'),
            ),
            _buildStylishButton(
              label: 'Undecided',
              icon: Icons.help_outline,
              activeColor: Colors.amber.shade600,
              isActive: currentResponse == 'maybe',
              isDisabled: hasResponded && currentResponse != 'maybe',
              onPressed: () => submitOutMeetingResponse('maybe'),
            ),
            _buildStylishButton(
              label: 'Decline',
              icon: Icons.cancel_outlined,
              activeColor: Colors.red.shade600,
              isActive: currentResponse == 'no',
              isDisabled: hasResponded && currentResponse != 'no',
              onPressed: () => submitOutMeetingResponse('no'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        AnimatedOpacity(
          opacity: currentResponse == 'pending' ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 500),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(currentResponse).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _getStatusColor(currentResponse), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  currentResponse == 'yes'
                      ? Icons.check_circle
                      : currentResponse == 'no'
                          ? Icons.cancel
                          : Icons.help,
                  color: _getStatusColor(currentResponse),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Your Response: ${currentResponse.toUpperCase()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _getStatusColor(currentResponse),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Helper method for creating stylish buttons
  Widget _buildStylishButton({
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required bool isDisabled,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: isActive ? activeColor : Colors.white,
            foregroundColor: isActive ? Colors.white : Colors.grey.shade800,
            elevation: isActive ? 4 : 1,
            shadowColor:
                isActive ? activeColor.withOpacity(0.6) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isActive ? activeColor : Colors.grey.shade300,
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : activeColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'yes':
        return Colors.green.shade600;
      case 'no':
        return Colors.red.shade600;
      case 'maybe':
        return Colors.amber.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  // New widget to build the members section for out-meeting
  Widget _buildOutMeetingMembersSection(bool isDarkMode) {
    List<dynamic> members = meetingData?['members'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.people, size: 18, color: Colors.green.shade600),
            const SizedBox(width: 8),
            Text(
              'Members:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...members.map((member) {
          String memberName = member['employee_name'] ?? 'No Name';
          String status = member['going'] ?? 'Pending';
          String memberImage = member['img_name'] ??
              'https://demo-flexiflows-hr-employee-images.s3.ap-southeast-1.amazonaws.com/default_avatar.jpg';
          String department = member['department_name'] ?? '';
          String branch = member['branch_name'] ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            color: isDarkMode ? Colors.grey[850] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: _getResponderStatusColor(status),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(memberImage),
                    backgroundColor:
                        isDarkMode ? Colors.grey[700] : Colors.grey[300],
                    radius: 20,
                    onBackgroundImageError: (error, stackTrace) {},
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memberName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        if (department.isNotEmpty || branch.isNotEmpty)
                          Text(
                            '$department${department.isNotEmpty && branch.isNotEmpty ? ' - ' : ''}$branch',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getResponderStatusColor(status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Color _getResponderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'yes':
        return Colors.green.shade600;
      case 'no':
        return Colors.red.shade600;
      case 'maybe':
        return Colors.amber.shade600;
      case 'pending':
        return Colors.amber.shade500; // Changed to amber color for pending
      default:
        return Colors.grey.shade400;
    }
  }
}
