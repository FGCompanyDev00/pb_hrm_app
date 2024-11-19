// history_details_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_office_booking_event_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class DetailsPage extends StatefulWidget {
  final String types;
  final String id;
  final String status;

  const DetailsPage({
    super.key,
    required this.types,
    required this.id,
    required this.status,
  });

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Map<String, dynamic>? data;
  Map<int, String> _leaveTypes = {};
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;
  String? lineManagerImageUrl;
  String? hrImageUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchLeaveTypes();
    await _fetchData();
  }

  Future<void> _handleRefresh() async {
    await _fetchData();
  }

  Future<void> _fetchLeaveTypes() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String leaveTypesUrl = '$baseUrl/api/leave-types';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        return;
      }

      final response = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print('Fetching Leave Types from URL: $leaveTypesUrl');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if ([200, 201].contains(response.statusCode)) {
        final responseData = jsonDecode(response.body);
        if (responseData['statusCode'] == 200 && responseData['results'] is List) {
          setState(() {
            _leaveTypes = {
              for (var lt in responseData['results']) lt['leave_type_id']: lt['name']
            };
          });
        } else {
          throw Exception('Failed to fetch leave types');
        }
      } else {
        throw Exception('Failed to fetch leave types: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave types: $e';
      });
      if (kDebugMode) print('Error fetching leave types: $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });

    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    final String status = _getFormattedStatus(type, widget.status.toLowerCase());

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String apiUrl = _determineApiUrl(type, baseUrl, id);

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() => isLoading = false);
        return;
      }

      http.Response response;

      if (type == 'leave') {
        if (kDebugMode) print('Sending GET request to $apiUrl');
        response = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      } else {
        final Map<String, dynamic> requestBody = {
          'types': widget.types,
          'status': status,
        };

        if (kDebugMode) print('Sending POST request to $apiUrl with body: $requestBody');

        response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(requestBody),
        );
      }

      if (kDebugMode) {
        print('Received response with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

      if ([200, 201, 202].contains(response.statusCode)) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if ([200, 201, 202].contains(responseData['statusCode'])) {
          if (!responseData.containsKey('results')) {
            _showErrorDialog('Error', 'Invalid API response structure.');
            setState(() => isLoading = false);
            return;
          }

          setState(() {
            data = _extractData(type, responseData['results']);
            isLoading = false;
          });

          if (data != null) {
            _fetchProfileImage(_getProfileId(type));
          } else {
            setState(() {
              imageUrl = _defaultAvatarUrl();
            });
          }
        } else {
          _showErrorDialog('Error', responseData['message'] ?? 'Unknown error.');
          setState(() => isLoading = false);
        }
      } else {
        _showErrorDialog('Error', 'Failed to fetch details: ${response.statusCode}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching details: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while fetching details.');
      setState(() => isLoading = false);
    }
  }

  String _determineApiUrl(String type, String baseUrl, String id) {
    if (type == 'leave') {
      return '$baseUrl/api/leave_request/all/$id';
    } else {
      return '$baseUrl/api/app/users/history/pending/$id';
    }
  }

  String _getFormattedStatus(String type, String status) {
    if (type == 'leave') {
      switch (status) {
        case 'approved':
          return 'Approved';
        case 'cancel':
          return 'Cancel';
        case 'processing':
          return 'Processing';
        default:
          return status;
      }
    } else if (type == 'meeting') {
      switch (status) {
        case 'approved':
          return 'approved';
        case 'cancel':
          return 'cancel';
        default:
          return status;
      }
    } else {
      return status;
    }
  }

  Map<String, dynamic>? _extractData(String type, dynamic results) {
    if (type == 'leave') {
      if (results is List && results.isNotEmpty) {
        return results[0] as Map<String, dynamic>;
      }
    } else {
      if (results is List && results.isNotEmpty) {
        return results[0] as Map<String, dynamic>;
      } else if (results is Map<String, dynamic>) {
        return results;
      }
    }
    return null;
  }

  String _getProfileId(String type) {
    if (type == 'leave') {
      return data?['requestor_id'] ?? '';
    } else {
      return data?['employee_id'] ?? '';
    }
  }

  Future<void> _fetchProfileImage(String id) async {
    if (id.isEmpty) {
      setState(() => imageUrl = _defaultAvatarUrl());
      return;
    }

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String profileApiUrl = '$baseUrl/api/profile/$id';

    try {
      final String? token = await _getToken();
      if (token == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() => imageUrl = _defaultAvatarUrl());
        return;
      }

      if (kDebugMode) print('Fetching profile image from: $profileApiUrl');

      final response = await http.get(
        Uri.parse(profileApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (kDebugMode) {
        print('Profile API Response Status Code: ${response.statusCode}');
        print('Profile API Response Body: ${response.body}');
      }

      if ([200, 201].contains(response.statusCode)) {
        final Map<String, dynamic> profileData = jsonDecode(response.body);

        if ([200, 201, 202].contains(profileData['statusCode'])) {
          if (profileData['results'] is Map<String, dynamic>) {
            setState(() {
              imageUrl = profileData['results']['images'] ?? _defaultAvatarUrl();
            });
          } else {
            setState(() => imageUrl = _defaultAvatarUrl());
            _showErrorDialog('Error', 'Invalid profile API response.');
          }
        } else {
          _showErrorDialog('Error', profileData['message'] ?? 'Unknown error fetching profile.');
          setState(() => imageUrl = _defaultAvatarUrl());
        }
      } else {
        setState(() => imageUrl = _defaultAvatarUrl());
        _showErrorDialog('Error', 'Failed to fetch profile image: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Error fetching profile image: $e');
      setState(() => imageUrl = _defaultAvatarUrl());
      _showErrorDialog('Error', 'An unexpected error occurred while fetching profile image.');
    }
  }

  String _defaultAvatarUrl() => 'https://www.w3schools.com/howto/img_avatar.png';

  Future<String?> _getToken() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      if (kDebugMode) print('Error retrieving token: $e');
      return null;
    }
  }

  String formatDate(String? dateStr, {bool includeTime = false}) {
    try {
      if (dateStr == null || dateStr.isEmpty) return 'N/A';
      final DateTime parsedDate = DateTime.parse(dateStr);
      return includeTime
          ? DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate)
          : DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      if (kDebugMode) print('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  PreferredSizeWidget _buildAppBar() {
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
        'History Details',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.black,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      toolbarHeight: 80,
      elevation: 0,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildRequestorSection(double screenWidth) {
    final String requestorName = data?['requestor_name'] ?? data?['employee_name'] ?? 'No Name';
    final String submittedOn = _getSubmittedOn();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        children: [
          _buildStatusRow(widget.status),
          const SizedBox(height: 20),
          const Text(
            'Requestor',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProfileAvatar(imageUrl, radius: 35),
              const SizedBox(width: 16),
              SizedBox(
                width: screenWidth * 0.5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requestorName,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Submitted on $submittedOn',
                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getSubmittedOn() {
    switch (widget.types.toLowerCase()) {
      case 'leave':
        return formatDate(data?['created_at']);
      case 'car':
        return formatDate(data?['created_date']);
      case 'meeting':
        return formatDate(data?['date_create']);
      default:
        return 'N/A';
    }
  }

  Widget _buildStatusRow(String status) {
    final Color statusColor = _getStatusColor(status);
    final IconData statusIcon = _getStatusIcon(status);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 30,
        ),
        const SizedBox(width: 8),
        Text(
          '${status[0].toUpperCase()}${status.substring(1)}',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'cancel':
      case 'cancelled':
      case 'disapproved':
        return Colors.red;
      case 'processing':
      case 'waiting':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'cancel':
        return Icons.cancel;
      case 'processing':
        return Icons.hourglass_empty;
      default:
        return Icons.info;
    }
  }

  Widget _buildProfileAvatar(String? url, {double radius = 35}) {
    return CircleAvatar(
      backgroundImage: NetworkImage(url ?? _defaultAvatarUrl()),
      radius: radius,
      backgroundColor: Colors.grey[300],
      onBackgroundImageError: (_, __) {
        setState(() => imageUrl = _defaultAvatarUrl());
      },
    );
  }

  Widget _buildBlueSection(double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Container(
        width: screenWidth,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),

          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            _getTypeHeader(),
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeHeader() {
    switch (widget.types.toLowerCase()) {
      case 'meeting':
        return 'Meeting and Booking Meeting Room';
      case 'leave':
        return 'Leave';
      case 'car':
        return 'Booking Car';
      default:
        return 'Approval Details';
    }
  }

  Widget _buildDetailsSection(double screenWidth) {
    final String type = widget.types.toLowerCase();

    switch (type) {
      case 'meeting':
        return _buildMeetingDetails(screenWidth);
      case 'leave':
        return _buildLeaveDetails(screenWidth);
      case 'car':
        return _buildCarDetails(screenWidth);
      default:
        return const Center(
          child: Text(
            'Unknown Request Type',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        );
    }
  }

  Widget _buildMeetingDetails(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.green, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.calendar_today,
          'Date',
          '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
          Colors.blue,
          screenWidth,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.phone, 'Employee Tel', data?['employee_tel'] ?? 'No Telephone', Colors.purple, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.email, 'Employee Email', data?['employee_email'] ?? 'No Email', Colors.purple, screenWidth),
      ],
    );
  }

  Widget _buildLeaveDetails(double screenWidth) {
    final String leaveTypeName = _leaveTypes[data?['leave_type_id']] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(Icons.bookmark, 'Title', data?['name'] ?? 'No Title', Colors.green, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.calendar_today,
          'Date',
          '${formatDate(data?['take_leave_from'])} - ${formatDate(data?['take_leave_to'])}',
          Colors.blue,
          screenWidth,
        ),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.label, 'Leave Type', leaveTypeName, Colors.orange, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time, 'Days', data?['days']?.toString() ?? 'N/A', Colors.purple, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(
          Icons.description,
          'Reason',
          data?['take_leave_reason'] ?? 'No Reason Provided',
          Colors.red,
          screenWidth,
        ),
      ],
    );
  }

  Widget _buildCarDetails(double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(Icons.bookmark, 'Purpose', data?['purpose'] ?? 'No Purpose', Colors.green, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.place, 'Place', data?['place'] ?? 'N/A', Colors.blue, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.directions_car, 'Vehicle ID', data?['vehicle_id'] ?? 'N/A', Colors.orange, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.calendar_today, 'Date Out', data?['date_out'] ?? 'N/A', Colors.blue, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.calendar_today, 'Date In', data?['date_in'] ?? 'N/A', Colors.blue, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time, 'Time Out', data?['time_out'] ?? 'N/A', Colors.purple, screenWidth),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.access_time, 'Time In', data?['time_in'] ?? 'N/A', Colors.purple, screenWidth),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String content, Color color, double screenWidth) {
    return Wrap(
      spacing: 16, // Space between the icon and the text
      runSpacing: 8, // Space between wrapped rows
      crossAxisAlignment: WrapCrossAlignment.start, // Try changing this to 'start' instead of 'center'
      children: [
        Icon(icon, size: 25, color: color),
        Flexible(
          child: Text(
            '$title: $content',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkflowSection(double screenWidth) {
    if (widget.types.toLowerCase() != 'leave') return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildUserAvatar(imageUrl, label: 'Requestor'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(lineManagerImageUrl, label: 'Line Manager'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(hrImageUrl, label: 'HR'),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(String? url, {String label = ''}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(url ?? _defaultAvatarUrl()),
          radius: 20,
          backgroundColor: Colors.grey[300],
          onBackgroundImageError: (_, __) {
            setState(() {
              switch (label.toLowerCase()) {
                case 'requestor':
                  imageUrl = _defaultAvatarUrl();
                  break;
                case 'line manager':
                  lineManagerImageUrl = _defaultAvatarUrl();
                  break;
                case 'hr':
                  hrImageUrl = _defaultAvatarUrl();
                  break;
                default:
                  break;
              }
            });
          },
        ),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButtons(double screenWidth) {
    final String status = widget.status.toLowerCase();
    if (['approved', 'disapproved', 'cancel'].contains(status)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStyledButton(
            label: 'Delete',
            icon: Icons.delete,
            backgroundColor: const Color(0xFFC2C2C2),
            textColor: Colors.white,
            onPressed: isFinalized ? null : _handleDelete,
            buttonWidth: screenWidth < 400 ? screenWidth * 0.35 : 150,
          ),
          const SizedBox(width: 20),  // Add some spacing
          _buildStyledButton(
            label: 'Edit',
            icon: Icons.edit,
            backgroundColor: const Color(0xFFDBB342),
            textColor: Colors.white,
            onPressed: isFinalized ? null : _handleEdit,
            buttonWidth: screenWidth < 400 ? screenWidth * 0.35 : 150,
          ),
        ],
      ),
    );
  }

  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
    required double buttonWidth,
  }) {
    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          backgroundColor: backgroundColor,
        ),
        icon: Icon(
          icon,
          color: textColor,
          size: 20,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Future<void> _handleEdit() async {
    setState(() => isFinalized = true);

    final String type = widget.types.toLowerCase();
    final String idToSend = _getEditId(type);

    if (kDebugMode) print('Navigating to Edit Page with data: $data and id: $idToSend');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficeBookingEventEditPage(
          id: idToSend,
          type: type,
        ),
      ),
    ).then((result) {
      if (kDebugMode) print('Returned from Edit Page with result: $result');
      if (result == true) _fetchData();
    });

    setState(() => isFinalized = false);
  }

  String _getEditId(String type) {
    if (type == 'leave') {
      return data?['take_leave_request_id']?.toString() ?? widget.id;
    } else {
      return data?['uid']?.toString() ?? widget.id;
    }
  }

  Future<void> _handleDelete() async {
    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Request ID is missing.');
      return;
    }

    final String? token = await _getToken();
    if (token == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    setState(() => isFinalized = true);

    try {
      http.Response response;

      switch (type) {
        case 'leave':
          response = await http.put(
            Uri.parse('$baseUrl/api/leave_cancel/$id'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if ([200, 201].contains(response.statusCode)) {
            _showSuccessDialog('Success', 'Leave request deleted successfully.');
          } else {
            _showErrorDialog('Error',
                'Failed to delete leave request: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'car':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/car_permit/${data?['uid'] ?? id}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if ([200, 201].contains(response.statusCode)) {
            _showSuccessDialog('Success', 'Car permit deleted successfully.');
          } else {
            _showErrorDialog('Error',
                'Failed to delete car permit: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'meeting':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/book_meeting_room/${data?['uid'] ?? id}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          if ([200, 201].contains(response.statusCode)) {
            _showSuccessDialog('Success', 'Meeting deleted successfully.');
          } else {
            _showErrorDialog('Error',
                'Failed to delete meeting: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }

          if (kDebugMode) print('Full response body: ${response.body}');
          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      if (kDebugMode) print('Error deleting request: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while deleting the request.');
    }

    setState(() => isFinalized = false);
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
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: _buildAppBar(),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _handleRefresh,
        child: data == null
            ? const Center(
          child: Text(
            'No Data Available',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        )
            : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildRequestorSection(screenWidth),
                _buildBlueSection(screenWidth),
                const SizedBox(height: 14),
                _buildDetailsSection(screenWidth),
                const SizedBox(height: 14),
                _buildWorkflowSection(screenWidth),
                _buildActionButtons(screenWidth),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
