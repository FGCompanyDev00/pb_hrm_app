// event_detail_view.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Entry point for the Event Detail View.
class EventDetailView extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailView({super.key, required this.event});

  @override
  _EventDetailViewState createState() => _EventDetailViewState();
}

class _EventDetailViewState extends State<EventDetailView>
    with SingleTickerProviderStateMixin {
  // State variables
  bool _isLoading = false;
  bool _hasResponded = false;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late String _eventType;

  @override
  void initState() {
    super.initState();
    _determineEventType();
    _initializeAnimations();
    _checkUserResponse();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Determines the type of event based on its category.
  void _determineEventType() {
    _eventType = widget.event['category'] == 'Meetings' ? 'Meeting' : 'Other';
  }

  /// Initializes the animation controller and animations.
  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();
  }

  /// Checks if the user has already responded to the event.
  Future<void> _checkUserResponse() async {
    final prefs = await SharedPreferences.getInstance();
    final responses = prefs.getStringList('eventResponses') ?? [];
    final uid = widget.event['uid'] ??
        widget.event['outmeeting_uid'] ??
        '';

    final response = responses.firstWhere(
          (resp) {
        final parts = resp.split(':');
        return parts.length == 2 && parts[0] == uid;
      },
      orElse: () => '',
    );

    if (response.isNotEmpty) {
      setState(() {
        _hasResponded = true;
      });
    }
  }

  /// Handles the user response to the meeting event.
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

    final uid = widget.event['uid'] ??
        widget.event['outmeeting_uid'] ??
        '';
    const baseUrl = 'https://demo-application-api.flexiflows.co';

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showSnackBar(
        'Authentication Error. Please log in again.',
        Colors.red,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    String endpoint;
    String successMessage;
    Color snackBarColor;

    // Only 'Meeting' events have response functionality
    if (_eventType == 'Meeting') {
      switch (responseType) {
        case 'yes':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/yes/$uid';
          successMessage = 'Successfully joined the meeting.';
          snackBarColor = Colors.green;
          break;
        case 'no':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/no/$uid';
          successMessage = 'You have rejected the meeting.';
          snackBarColor = Colors.red;
          break;
        case 'maybe':
          endpoint = '/api/work-tracking/out-meeting/outmeeting/maybe/$uid';
          successMessage = 'You have marked your response as Maybe.';
          snackBarColor = Colors.orange;
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
      _showSnackBar(
        'Responding to this event type is not supported.',
        Colors.red,
      );
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

      if ([200, 201, 202].contains(response.statusCode)) {
        setState(() {
          _hasResponded = true;
        });
        // Store the user's response locally
        final responses = prefs.getStringList('eventResponses') ?? [];
        responses.add('$uid:$responseType');
        await prefs.setStringList('eventResponses', responses);
        _showSnackBar(successMessage, snackBarColor);
      } else {
        _showSnackBar(
          'Failed to respond. Status: ${response.statusCode}',
          Colors.red,
        );
      }
    } catch (error) {
      _showSnackBar('An unexpected error occurred.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Displays a confirmation dialog based on the response type.
  Future<bool> _showConfirmationDialog(String responseType) async {
    String title;
    String content;
    Color dialogColor;
    IconData dialogIcon;

    switch (responseType) {
      case 'no':
        title = 'Reject Meeting';
        content = 'Are you sure you want to reject this meeting?';
        dialogColor = Colors.red;
        dialogIcon = Icons.cancel;
        break;
      case 'maybe':
        title = 'Maybe Attend';
        content = 'Are you unsure about attending this meeting?';
        dialogColor = Colors.orange;
        dialogIcon = Icons.help_outline;
        break;
      default:
        return true;
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [

              Text(
                title,
                style: TextStyle(
                  color: dialogColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            content,
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: dialogColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Confirm'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  /// Displays a SnackBar with a custom message and color.
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Builds a detail item with an icon, title, and content.
  Widget _buildDetailItem(
      IconData icon,
      String title,
      String content,
      Color iconColor,
      ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 30),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          content,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  /// Formats a given date string into a readable format.
  String _formatDate(String dateStr, {String format = 'MMM dd, yyyy hh:mm a'}) {
    if (dateStr.isEmpty) return '';
    try {
      DateTime parsedDate = DateTime.parse(dateStr);
      return DateFormat(format).format(parsedDate);
    } catch (e) {
      return dateStr;
    }
  }

  /// Extracts and formats necessary event details.
  Map<String, String> _getEventDetails() {
    String creatorName =
        widget.event['createdBy'] ?? widget.event['created_by_name'] ?? 'Unknown';
    String imageUrl = widget.event['img_name'] ?? '';
    String createdAt = widget.event['created_at'] ?? '';

    String formattedCreatedAt = _formatDate(createdAt, format: 'MMM dd, yyyy');
    String formattedStartDate = '';
    String formattedEndDate = '';

    if (widget.event['startDateTime'] != null &&
        widget.event['endDateTime'] != null) {
      formattedStartDate = _formatDate(
          widget.event['startDateTime'].toString(),
          format: 'MMM dd, yyyy hh:mm a');
      formattedEndDate =
          _formatDate(widget.event['endDateTime'].toString(), format: 'MMM dd, yyyy hh:mm a');
    }

    return {
      'creatorName': creatorName,
      'imageUrl': imageUrl,
      'formattedCreatedAt': formattedCreatedAt,
      'formattedStartDate': formattedStartDate,
      'formattedEndDate': formattedEndDate,
    };
  }

  /// Builds the members list widget.
  Widget _buildMembersList(List<dynamic> members) {
    if (members.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          'Members',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 15),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            String memberName = member['member_name'] ?? 'Unknown Member';
            String department = member['department_name'] ?? '';
            String memberImage = member['img_name'] ?? '';

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundImage: memberImage.isNotEmpty
                      ? NetworkImage(memberImage)
                      : const AssetImage('assets/default_avatar.png')
                  as ImageProvider,
                ),
                title: Text(
                  memberName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  department,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Builds the action buttons (Join, Maybe, Reject).
  Widget _buildActionButtons(double horizontalPadding) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding, vertical: 25),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, -3),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Join Button
            Expanded(
              child: _buildResponsiveButton(
                label: 'Join',
                color: _hasResponded ? Colors.grey : Colors.green,
                onPressed:
                _hasResponded ? null : () => _respondToMeeting('yes'),
              ),
            ),
            const SizedBox(width: 15),
            // Maybe Button
            Expanded(
              child: _buildResponsiveButton(
                label: 'Maybe',
                color: _hasResponded ? Colors.grey : Colors.orange,
                onPressed:
                _hasResponded ? null : () => _respondToMeeting('maybe'),
              ),
            ),
            const SizedBox(width: 15),
            // Reject Button
            Expanded(
              child: _buildResponsiveButton(
                label: 'Reject',
                color: _hasResponded ? Colors.grey : Colors.red,
                onPressed:
                _hasResponded ? null : () => _respondToMeeting('no'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a styled ElevatedButton with responsive design.
  Widget _buildResponsiveButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: onPressed != null ? 6 : 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Builds the creator section for Meeting events.
  Widget _buildCreatorSection(Map<String, String> details) {
    return Column(
      children: [
        const SizedBox(height: 25),
        CircleAvatar(
          radius: 50,
          backgroundImage: details['imageUrl']!.isNotEmpty
              ? NetworkImage(details['imageUrl']!)
              : const AssetImage('assets/default_avatar.png') as ImageProvider,
        ),
        Text(
          details['creatorName']!,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        if (details['formattedCreatedAt']!.isNotEmpty)
          Text(
            'Submitted on ${details['formattedCreatedAt']}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 5),
      ],
    );
  }

  /// Builds the event title widget.
  Widget _buildEventTitle() {
    return Text(
      widget.event['title'] ?? 'No Title',
      style: const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Builds the event type widget.
  Widget _buildEventType() {
    return Container(
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _eventType,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.blueAccent,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  /// Builds the list of event details.
  Widget _buildEventDetails() {
    final details = _getEventDetails();
    return Column(
      children: [
        if (widget.event['description'] != null &&
            widget.event['description'].isNotEmpty)
          _buildDetailItem(
            Icons.description,
            'Description',
            widget.event['description'],
            Colors.blueAccent,
          ),
        if (details['formattedStartDate']!.isNotEmpty)
          _buildDetailItem(
            Icons.calendar_today,
            'Start Date',
            details['formattedStartDate']!,
            Colors.green,
          ),
        if (details['formattedEndDate']!.isNotEmpty)
          _buildDetailItem(
            Icons.calendar_today_outlined,
            'End Date',
            details['formattedEndDate']!,
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
      ],
    );
  }

  /// Builds the main content of the Event Detail View.
  Widget _buildContent(BuildContext context) {
    final details = _getEventDetails();
    final isMeeting = _eventType == 'Meeting';
    final members = widget.event['members'] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (isMeeting) _buildCreatorSection(details),
          const SizedBox(height: 15),
          _buildEventTitle(),
          const SizedBox(height: 8),
          _buildEventType(),
          const SizedBox(height: 20),
          _buildEventDetails(),
          if (members.isNotEmpty) _buildMembersList(members),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double horizontalPadding = MediaQuery.of(context).size.width * 0.05;
    final isMeeting = _eventType == 'Meeting';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _buildAnimatedContent(_buildContent(context)),
            ),
          ),
          if (isMeeting) _buildActionButtons(horizontalPadding),
        ],
      ),
    );
  }

  /// Builds the AppBar with background.png.
  AppBar _buildAppBar() {
    return AppBar(
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
          fontWeight: FontWeight.w600,
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
    );
  }

  /// Builds animated content with slide and fade transitions.
  Widget _buildAnimatedContent(Widget child) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: child,
      ),
    );
  }
}
