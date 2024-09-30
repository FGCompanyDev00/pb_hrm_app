// event_detail_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class EventDetailView extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailView({Key? key, required this.event}) : super(key: key);

  @override
  _EventDetailViewState createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView>
    with SingleTickerProviderStateMixin {
  // State variables
  bool _isLoading = false;
  bool _hasResponded = false;
  String _userResponse = '';
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late String _eventType;

  @override
  void initState() {
    super.initState();
    _determineEventType();
    _checkUserResponse();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Determine the event type based on the data available
  void _determineEventType() {
    if (widget.event['category'] == 'Meetings') {
      _eventType = 'Meeting';
    } else {
      _eventType = 'Other';
    }
  }

  // Check if the user has already responded to the event
  Future<void> _checkUserResponse() async {
    // Fetch stored responses from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final responses = prefs.getStringList('eventResponses') ?? [];

    final uid = widget.event['uid'] ?? widget.event['outmeeting_uid'] ?? '';

    for (var response in responses) {
      final parts = response.split(':');
      if (parts.length == 2 && parts[0] == uid) {
        setState(() {
          _hasResponded = true;
          _userResponse = parts[1];
        });
        break;
      }
    }
  }

  // Respond to the event with the selected response type
  Future<void> _respondToMeeting(String responseType) async {
    if (_hasResponded) return;

    // Show confirmation dialog for "Reject" and "Maybe"
    if (responseType == 'no' || responseType == 'maybe') {
      bool confirmed = await _showConfirmationDialog(responseType);
      if (!confirmed) return;
    }

    setState(() {
      _isLoading = true;
    });

    final uid = widget.event['uid'] ?? widget.event['outmeeting_uid'] ?? '';
    const baseUrl = 'https://demo-application-api.flexiflows.co';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showSnackBar('Authentication Error. Please log in again.', Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String endpoint;
    String successMessage;

    // Only 'Meeting' events have response functionality
    if (_eventType == 'Meeting') {
      switch (responseType) {
        case 'yes':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/yes/$uid';
          successMessage = 'Successfully joined the meeting.';
          break;
        case 'no':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/no/$uid';
          successMessage = 'You have rejected the meeting.';
          break;
        case 'maybe':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/maybe/$uid';
          successMessage = 'You have marked your response as Maybe.';
          break;
        default:
          _showSnackBar('Invalid response type.', Colors.red);
          setState(() {
            _isLoading = false;
          });
          return;
      }
    } else {
      // For other event types, responding is not supported
      _showSnackBar('Responding to this event type is not supported.', Colors.red);
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final url = Uri.parse('$baseUrl$endpoint');

    try {
      final response = await http.put(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        setState(() {
          _hasResponded = true;
          _userResponse = responseType;
        });
        // Store the user's response locally
        final responses = prefs.getStringList('eventResponses') ?? [];
        responses.add('$uid:$responseType');
        await prefs.setStringList('eventResponses', responses);
        _showSnackBar(successMessage, Colors.green);
      } else {
        _showSnackBar(
            'Failed to respond. Status: ${response.statusCode}', Colors.red);
      }
    } catch (_) {
      _showSnackBar('An unexpected error occurred.', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show confirmation dialog with color based on response type
  Future<bool> _showConfirmationDialog(String responseType) async {
    String title;
    String content;
    Color dialogColor;

    switch (responseType) {
      case 'no':
        title = 'Reject Meeting';
        content = 'Are you sure you want to reject this meeting?';
        dialogColor = Colors.red;
        break;
      case 'maybe':
        title = 'Maybe Attend Meeting';
        content = 'Are you unsure about attending this meeting?';
        dialogColor = Colors.orange;
        break;
      default:
        return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dialogColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: dialogColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                'Confirm',
                style: TextStyle(color: dialogColor),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  // Show a SnackBar with a custom message and color
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Build a detail item with an icon, title, and content
  Widget _buildDetailItem(
      IconData icon, String title, String content, Color iconColor) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(icon, color: iconColor, size: 28),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            content,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ),
    );
  }

  // Build animated content with slide and fade transitions
  Widget _buildAnimatedContent(Widget child) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = MediaQuery.of(context).size.width * 0.05;

    final isMeeting = _eventType == 'Meeting';
    final String creatorName = widget.event['createdBy'] ??
        widget.event['created_by_name'] ??
        'Unknown';
    final String imageUrl = widget.event['img_name'] ?? '';
    final String createdAt = widget.event['created_at'] ?? '';

    String formattedCreatedAt = '';
    if (createdAt.isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(createdAt);
        formattedCreatedAt = DateFormat('MMM dd, yyyy').format(parsedDate);
      } catch (e) {
        formattedCreatedAt = createdAt;
      }
    }

    String formattedStartDate = '';
    String formattedEndDate = '';
    if (widget.event['startDateTime'] != null &&
        widget.event['endDateTime'] != null) {
      try {
        // Parse the date strings into DateTime objects
        DateTime startDate = widget.event['startDateTime'] is DateTime
            ? widget.event['startDateTime']
            : DateTime.parse(widget.event['startDateTime']);
        DateTime endDate = widget.event['endDateTime'] is DateTime
            ? widget.event['endDateTime']
            : DateTime.parse(widget.event['endDateTime']);

        formattedStartDate =
            DateFormat('MMM dd, yyyy hh:mm a').format(startDate);
        formattedEndDate = DateFormat('MMM dd, yyyy hh:mm a').format(endDate);
      } catch (e) {
        // Handle parsing errors
        formattedStartDate = widget.event['startDateTime'].toString();
        formattedEndDate = widget.event['endDateTime'].toString();
      }
    }

    // Get members list
    List<dynamic> members = widget.event['members'] ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Event Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        toolbarHeight: 80,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Wrap content in SingleChildScrollView to prevent overflow
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding, vertical: 150.0),
            child: _buildAnimatedContent(
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isMeeting)
                      Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundImage: imageUrl.isNotEmpty
                                ? NetworkImage(imageUrl)
                                : const AssetImage('assets/default_avatar.png')
                            as ImageProvider,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            creatorName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (formattedCreatedAt.isNotEmpty)
                            Text(
                              'Submitted on $formattedCreatedAt',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
                            ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    Text(
                      widget.event['title'] ?? 'No Title',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _eventType,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (widget.event['description'] != null &&
                        widget.event['description'].isNotEmpty)
                      _buildDetailItem(
                        Icons.description,
                        'Description',
                        widget.event['description'],
                        Colors.blueAccent,
                      ),
                    if (formattedStartDate.isNotEmpty)
                      _buildDetailItem(
                        Icons.calendar_today,
                        'Start Date',
                        formattedStartDate,
                        Colors.green,
                      ),
                    if (formattedEndDate.isNotEmpty)
                      _buildDetailItem(
                        Icons.calendar_today_outlined,
                        'End Date',
                        formattedEndDate,
                        Colors.redAccent,
                      ),
                    if (widget.event['location'] != null &&
                        widget.event['location'].isNotEmpty)
                      _buildDetailItem(
                        Icons.location_on,
                        'Location',
                        widget.event['location'],
                        Colors.purple,
                      ),
                    if (widget.event['status'] != null &&
                        widget.event['status'].isNotEmpty)
                      _buildDetailItem(
                        Icons.info,
                        'Status',
                        widget.event['status'],
                        Colors.cyan,
                      ),
                    if (members.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...members.map((member) {
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 0),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundImage: member['img_name'] != null &&
                                      member['img_name'].isNotEmpty
                                      ? NetworkImage(member['img_name'])
                                      : const AssetImage('assets/default_avatar.png')
                                  as ImageProvider,
                                ),
                                title: Text(
                                  member['member_name'] ?? 'Unknown Member',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  member['department_name'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
          if (isMeeting)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasResponded
                              ? null
                              : () => _respondToMeeting('yes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasResponded
                                ? Colors.grey
                                : Colors.green,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _hasResponded ? 0 : 5,
                          ),
                          child: const Text(
                            'Join',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasResponded
                              ? null
                              : () => _respondToMeeting('maybe'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasResponded
                                ? Colors.grey
                                : Colors.orange,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _hasResponded ? 0 : 5,
                          ),
                          child: const Text(
                            'Maybe',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _hasResponded
                              ? null
                              : () => _respondToMeeting('no'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _hasResponded
                                ? Colors.grey
                                : Colors.red,
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: _hasResponded ? 0 : 5,
                          ),
                          child: const Text(
                            'Reject',
                            style: TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
