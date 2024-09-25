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
  bool _isLoading = false;
  bool _hasResponded = false;
  String _userResponse = '';
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
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

  Future<void> _checkUserResponse() async {
    setState(() {
      _hasResponded = widget.event['userHasResponded'] ?? false;
      _userResponse = widget.event['userResponse'] ?? '';
    });
  }

  Future<void> _respondToMeeting(String responseType) async {
    if (_hasResponded) return;
    setState(() {
      _isLoading = true;
    });

    final uid = widget.event['uid'] ?? widget.event['outmeeting_uid'];
    final baseUrl = 'https://demo-application-api.flexiflows.co';

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

    switch (responseType) {
      case 'yes':
        endpoint = 'yes';
        successMessage = 'Successfully joined the meeting.';
        break;
      case 'no':
        endpoint = 'no';
        successMessage = 'Successfully rejected the meeting.';
        break;
      case 'maybe':
        endpoint = 'maybe';
        successMessage = 'You have marked your response as Maybe.';
        break;
      default:
        _showSnackBar('Invalid response type.', Colors.red);
        setState(() {
          _isLoading = false;
        });
        return;
    }

    final url = Uri.parse(
        '$baseUrl/api/work-tracking/out-meeting/outmeeting/$endpoint/$uid');

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

    final isMeeting = widget.event['isMeeting'] == true;
    final String creatorName = widget.event['createdBy'] ??
        widget.event['created_by_name'] ??
        'Unknown';
    final String imageUrl = widget.event['img_name'] ?? '';
    final String createdAt = widget.event['created_at'] ?? '';

    String formattedDate = '';
    if (createdAt.isNotEmpty) {
      DateTime parsedDate = DateTime.parse(createdAt);
      formattedDate = DateFormat('MMM dd, yyyy').format(parsedDate);
    }

    String formattedStartDate = '';
    String formattedEndDate = '';
    if (isMeeting) {
      if (widget.event['fromdate'] != null && widget.event['todate'] != null) {
        DateTime startDate = DateTime.parse(widget.event['fromdate']);
        DateTime endDate = DateTime.parse(widget.event['todate']);
        formattedStartDate =
            DateFormat('MMM dd, yyyy hh:mm a').format(startDate);
        formattedEndDate = DateFormat('MMM dd, yyyy hh:mm a').format(endDate);
      }
    } else {
      if (widget.event['take_leave_from'] != null &&
          widget.event['take_leave_to'] != null) {
        DateTime startDate = DateTime.parse(widget.event['take_leave_from']);
        DateTime endDate = DateTime.parse(widget.event['take_leave_to']);
        formattedStartDate = DateFormat('MMM dd, yyyy').format(startDate);
        formattedEndDate = DateFormat('MMM dd, yyyy').format(endDate);
      }
    }

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
                          if (formattedDate.isNotEmpty)
                            Text(
                              'Submitted on $formattedDate',
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
                    if (widget.event['is_repeat'] != null &&
                        widget.event['is_repeat'].isNotEmpty)
                      _buildDetailItem(
                        Icons.repeat,
                        'Repeat',
                        widget.event['is_repeat'],
                        Colors.orange,
                      ),
                    if (widget.event['video_conference'] != null &&
                        widget.event['video_conference'].isNotEmpty)
                      _buildDetailItem(
                        Icons.videocam,
                        'Video Conference',
                        widget.event['video_conference'],
                        Colors.teal,
                      ),
                    if (widget.event['status'] != null &&
                        widget.event['status'].isNotEmpty)
                      _buildDetailItem(
                        Icons.info,
                        'Status',
                        widget.event['status'],
                        Colors.cyan,
                      ),
                    if (widget.event['allDay'] != null)
                      _buildDetailItem(
                        Icons.schedule,
                        'All Day Event',
                        widget.event['allDay'] == 1 ? 'Yes' : 'No',
                        Colors.brown,
                      ),
                    if (widget.event['days_of_week'] != null &&
                        widget.event['days_of_week'].isNotEmpty)
                      _buildDetailItem(
                        Icons.calendar_view_week,
                        'Days of Week',
                        widget.event['days_of_week'].join(', '),
                        Colors.indigo,
                      ),
                    const SizedBox(height: 20),
                    if (widget.event['members'] != null &&
                        widget.event['members'].isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...List<Widget>.from(widget.event['members'].map(
                                (member) => _buildDetailItem(
                              Icons.person,
                              'Member',
                              member.toString(),
                              Colors.deepPurple,
                            ),
                          )),
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
                            elevation:
                            _hasResponded ? 0 : 5,
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
                            elevation:
                            _hasResponded ? 0 : 5,
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
                            elevation:
                            _hasResponded ? 0 : 5,
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
