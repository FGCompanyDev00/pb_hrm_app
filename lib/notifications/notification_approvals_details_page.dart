import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/core/standard/constant_map.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationApprovalsDetailsPage extends StatefulWidget {
  final String id;
  final String type; // 'meeting' or 'car'

  const NotificationApprovalsDetailsPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  NotificationApprovalsDetailsPageState createState() =>
      NotificationApprovalsDetailsPageState();
}

class NotificationApprovalsDetailsPageState
    extends State<NotificationApprovalsDetailsPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  bool isFinalized = false;
  Map<String, dynamic>? approvalData;
  String? requestorImage;
  String? userResponse;
  late AnimationController _animationController;
  late Animation<double> _animation;

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchApprovalDetails();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchApprovalDetails() async {
    String apiUrl;

    // Determine API URL based on type
    if (widget.type == 'meeting') {
      apiUrl =
          '$baseUrl/api/office-administration/book_meeting_room/invite-meeting/${widget.id}';
    } else if (widget.type == 'car') {
      apiUrl =
          '$baseUrl/api/office-administration/car_permit/invite-car-member/${widget.id}';
    } else {
      _showErrorDialog('Error', 'Invalid approval type');
      return;
    }

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
            approvalData = Map<String, dynamic>.from(data['results']);

            String? imgName = widget.type == 'meeting'
                ? approvalData!['img_name']?.toString().trim()
                : approvalData!['requestor_img']?.toString().trim();

            if (imgName != null && imgName.isNotEmpty) {
              requestorImage = imgName;
            } else {
              requestorImage = 'https://via.placeholder.com/150';
            }

            userResponse = approvalData!['status']?.toString().toLowerCase();

            isLoading = false;
          });
        } else {
          throw Exception(
              data['message'] ?? 'Failed to load approval details.');
        }
      } else {
        throw Exception(
            'Failed to load approval details: ${response.statusCode}');
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
      DateTime parsedDate;

      // Handle different date formats
      if (dateStr.contains('T')) {
        // ISO format
        parsedDate = DateTime.parse(dateStr);
      } else if (dateStr.contains(' ')) {
        // SQL format with space
        parsedDate = DateTime.parse(dateStr);
      } else if (dateStr.contains('-')) {
        // Simple date like "2025-2-28"
        List<String> parts = dateStr.split('-');
        if (parts.length == 3) {
          return '${parts[2]}-${parts[1]}-${parts[0]}';
        }
        return dateStr;
      } else {
        return dateStr;
      }

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
    final darkModeGlobal = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: _buildAppBar(context, darkModeGlobal),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  _buildRequestorSection(darkModeGlobal),
                  const SizedBox(height: 20),
                  _buildHeaderSection(darkModeGlobal),
                  const SizedBox(height: 40),
                  _buildApprovalDetails(darkModeGlobal),
                  const SizedBox(height: 30),
                  _buildActionButtons(),
                ],
              ),
            ),
    );
  }

  AppBar _buildAppBar(BuildContext context, bool darkModeGlobal) {
    return AppBar(
      backgroundColor: darkModeGlobal ? Colors.grey[850] : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: darkModeGlobal ? Colors.white : Colors.black87,
        ),
        onPressed: () => Navigator.of(context).pop(isFinalized),
      ),
      title: Text(
        widget.type == 'meeting' ? 'Meeting Details' : 'Car Request Details',
        style: TextStyle(
          color: darkModeGlobal ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildRequestorSection(bool darkModeGlobal) {
    String requestorName;
    if (widget.type == 'meeting') {
      requestorName = approvalData?['employee_name']?.toString() ?? 'Unknown';
    } else {
      requestorName = approvalData?['requestor_name']?.toString() ?? 'Unknown';
    }

    String requestorTitle;
    if (widget.type == 'meeting') {
      requestorTitle = approvalData?['department_name']?.toString() ?? '';
    } else {
      requestorTitle = approvalData?['position_name']?.toString() ?? 'Employee';
    }

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: NetworkImage(
                  requestorImage ?? 'https://via.placeholder.com/150'),
              fit: BoxFit.cover,
              onError: (_, __) {
                setState(() {
                  requestorImage = 'https://via.placeholder.com/150';
                });
              },
            ),
          ),
        ),
        const SizedBox(height: 15),
        Text(
          requestorName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: darkModeGlobal ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          requestorTitle,
          style: TextStyle(
            fontSize: 16,
            color: darkModeGlobal ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(bool darkModeGlobal) {
    String headerText;
    if (widget.type == 'meeting') {
      headerText = 'MEETING ROOM INVITATION';
    } else {
      headerText = 'CAR BOOKING INVITATION';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: darkModeGlobal
            ? Colors.blueGrey.withOpacity(0.3)
            : Colors.lightBlueAccent.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        headerText,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: darkModeGlobal ? Colors.white : Colors.black,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildApprovalDetails(bool darkModeGlobal) {
    if (widget.type == 'meeting') {
      return _buildMeetingDetails(darkModeGlobal);
    } else {
      return _buildCarDetails(darkModeGlobal);
    }
  }

  Widget _buildMeetingDetails(bool darkModeGlobal) {
    bool hasRemarks = false;
    if (approvalData != null &&
        approvalData!.containsKey('remark') &&
        approvalData!['remark'] != null) {
      String remarkText = approvalData!['remark'].toString();
      hasRemarks = remarkText.isNotEmpty;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(
            'Meeting ID',
            approvalData?['meeting_id']?.toString() ?? 'N/A',
            Icons.meeting_room,
            Colors.green,
            darkModeGlobal),
        _buildInfoRow('Title', approvalData?['title'] ?? 'N/A', Icons.title,
            Colors.blue, darkModeGlobal),
        _buildInfoRow('From Date', formatDate(approvalData?['from_date_time']),
            Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow('To Date', formatDate(approvalData?['to_date_time']),
            Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow(
            'Room Name',
            approvalData?['room_name']?.toString() ?? 'N/A',
            Icons.room,
            Colors.orange,
            darkModeGlobal),
        _buildInfoRow('Floor', approvalData?['room_floor']?.toString() ?? 'N/A',
            Icons.layers, Colors.orange, darkModeGlobal),
        _buildInfoRow(
            'Branch Name',
            approvalData?['branch_name']?.toString() ?? 'N/A',
            Icons.business,
            Colors.red,
            darkModeGlobal),
        _buildInfoRow(
            'Status',
            approvalData?['status']?.toString() ?? 'Pending',
            Icons.stairs,
            Colors.red,
            darkModeGlobal),
        if (hasRemarks)
          _buildInfoRow('Remarks', approvalData!['remark'].toString(),
              Icons.comment, Colors.purple, darkModeGlobal),
      ],
    );
  }

  Widget _buildCarDetails(bool darkModeGlobal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow('Request ID', approvalData?['id']?.toString() ?? 'N/A',
            Icons.confirmation_number, Colors.green, darkModeGlobal),
        _buildInfoRow('Purpose', approvalData?['purpose'] ?? 'N/A', Icons.title,
            Colors.blue, darkModeGlobal),
        _buildInfoRow('Place', approvalData?['place'] ?? 'N/A', Icons.place,
            Colors.orange, darkModeGlobal),
        _buildInfoRow('Date Out', formatDate(approvalData?['date_out']),
            Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow(
            'Time Out',
            approvalData?['time_out']?.toString() ?? 'N/A',
            Icons.access_time,
            Colors.blue,
            darkModeGlobal),
        _buildInfoRow('Date In', formatDate(approvalData?['date_in']),
            Icons.calendar_today, Colors.blue, darkModeGlobal),
        _buildInfoRow('Time In', approvalData?['time_in']?.toString() ?? 'N/A',
            Icons.access_time, Colors.blue, darkModeGlobal),
        _buildInfoRow(
            'License Plate',
            approvalData?['license_plate']?.toString() ?? 'N/A',
            Icons.directions_car,
            Colors.purple,
            darkModeGlobal),
        _buildInfoRow(
            'Status',
            approvalData?['status']?.toString() ?? 'Pending',
            Icons.stairs,
            Colors.red,
            darkModeGlobal),
      ],
    );
  }

  Widget _buildInfoRow(String title, String content, IconData icon, Color color,
      bool darkModeGlobal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: darkModeGlobal ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    color: darkModeGlobal ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    // Don't show buttons if status is already decided
    final String response = userResponse?.toLowerCase() ?? '';

    if (response == 'yes' || response == 'approved') {
      return _buildResponseDisplay(
          'You have accepted this invitation', Colors.green);
    } else if (response == 'no' ||
        response == 'rejected' ||
        response == 'disapproved') {
      return _buildResponseDisplay(
          'You have declined this invitation', Colors.red);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: isFinalized ? null : () => _handleResponse('join'),
          icon: const Icon(Icons.check_circle_outline, color: Colors.white),
          label: const Text('Join', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isFinalized ? null : () => _handleResponse('decline'),
          icon: const Icon(Icons.cancel_outlined, color: Colors.white),
          label: const Text('Decline', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseDisplay(String message, Color color) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : Icons.cancel,
              color: color,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleResponse(String action) async {
    setState(() {
      isFinalized = true;
    });

    String endpoint;

    if (widget.type == 'meeting') {
      endpoint =
          '$baseUrl/api/office-administration/book_meeting_room/${action == 'join' ? 'yes' : 'no'}/${widget.id}';
    } else if (widget.type == 'car') {
      endpoint =
          '$baseUrl/api/work-tracking/out-meeting/outmeeting/${action == 'join' ? 'yes' : 'no'}/${widget.id}';
    } else {
      _showErrorDialog('Error', 'Invalid request type');
      setState(() {
        isFinalized = false;
      });
      return;
    }

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

      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          userResponse = action == 'join' ? 'yes' : 'no';
        });
        _animationController.forward().then((_) {
          _animationController.reset();
        });
        _showSuccessDialog('Success',
            'You have successfully ${action == 'join' ? 'joined' : 'declined'} the invitation.');
        Navigator.of(context).pop(true);
      } else {
        final responseBody = jsonDecode(response.body);
        String errorMessage =
            responseBody['message'] ?? 'Failed to $action the invitation.';
        _showErrorDialog('Error', errorMessage);
        setState(() {
          isFinalized = false;
        });
      }
    } catch (e) {
      _showErrorDialog('Error', 'An unexpected error occurred: $e');
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
