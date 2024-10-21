// staff_approvals_view_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_office_booking_event_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApprovalsViewPage extends StatefulWidget {
  final String type;
  final String id;

  const ApprovalsViewPage({
    super.key,
    required this.type,
    required this.id,
  });

  @override
  _ApprovalsViewPageState createState() => _ApprovalsViewPageState();
}

class _ApprovalsViewPageState extends State<ApprovalsViewPage> {
  Map<String, dynamic>? data;
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fetch main approval data
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String type = widget.type.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String endpoint = '';

    switch (type) {
      case 'leave':
        endpoint = '$baseUrl/api/leave_request/$id';
        break;
      case 'car':
        endpoint = '$baseUrl/api/office-administration/car_permit/me/$id';
        break;
      case 'meeting room':
        endpoint = '$baseUrl/api/office-administration/book_meeting_room/my-request/$id';
        break;
      case 'meeting':
        endpoint = '$baseUrl/api/work-tracking/meeting/get-meeting/$id';
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
        setState(() {
          isLoading = false;
        });
        return;
    }

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(endpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (type == 'leave') {
          data = decoded['results'] != null && decoded['results'].isNotEmpty
              ? decoded['results'][0]
              : null;
        } else if (type == 'car') {
          data = decoded['results'];
        } else if (type == 'meeting room') {
          data = decoded['results'];
        } else if (type == 'meeting') {
          data = decoded['result'] != null && decoded['result'].isNotEmpty
              ? decoded['result'][0]
              : null;
        }

        if (data != null) {
          // Debug: Print the fetched data
          print('Fetched Data for type "$type": $data');

          // Extract employee_id (pID) from the fetched data
          String? pID = data?['employee_id']?.toString();

          if (pID != null && pID.isNotEmpty) {
            // Fetch profile image using pID
            await _fetchProfileImage(pID);
          } else {
            // If pID is not available, use default avatar
            setState(() {
              imageUrl = _defaultAvatarUrl();
              isLoading = false;
            });
          }
        } else {
          // If data is null, use default avatar
          setState(() {
            imageUrl = _defaultAvatarUrl();
            isLoading = false;
          });
        }
      } else {
        _showErrorDialog('Error', 'Failed to fetch data: ${response.reasonPhrase}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching data: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while fetching data.');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch profile image using pID
  Future<void> _fetchProfileImage(String pID) async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String profileEndpoint = '$baseUrl/api/profile/$pID';

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(profileEndpoint),
        headers: {
          'Authorization': 'Bearer $tokenValue',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final profileResults = decoded['results'];
        if (profileResults != null &&
            profileResults['images'] != null &&
            profileResults['images'].isNotEmpty) {
          setState(() {
            imageUrl = profileResults['images'];
            isLoading = false;
          });
        } else {
          // If images field is missing or empty, use default avatar
          setState(() {
            imageUrl = _defaultAvatarUrl();
            isLoading = false;
          });
        }
      } else {
        // If profile API fails, use default avatar
        print('Failed to fetch profile image: ${response.reasonPhrase}');
        setState(() {
          imageUrl = _defaultAvatarUrl();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching profile image: $e');
      // In case of error, use default avatar
      setState(() {
        imageUrl = _defaultAvatarUrl();
        isLoading = false;
      });
    }
  }

  // Helper method to get a default avatar URL
  String _defaultAvatarUrl() {
    // Replace with a publicly accessible image URL
    return 'https://www.w3schools.com/howto/img_avatar.png';
  }

  // Retrieve token from SharedPreferences
  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  // Format date string
  String formatDate(String? dateStr, {bool includeTime = false}) {
    try {
      if (dateStr == null || dateStr.isEmpty) {
        return 'N/A';
      }
      final DateTime parsedDate = DateTime.parse(dateStr);
      return includeTime
          ? DateFormat('dd-MM-yyyy, HH:mm').format(parsedDate)
          : DateFormat('dd-MM-yyyy').format(parsedDate);
    } catch (e) {
      print('Date parsing error: $e');
      return 'Invalid Date';
    }
  }

  // Build AppBar
  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
        'Approval Details',
        style: TextStyle(
          color: Colors.black,
          fontSize: 22,
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

  // Build Requestor Section
  Widget _buildRequestorSection() {
    // Correctly assign requestorName without duplication
    String requestorName = data?['requestor_name'] ?? data?['employee_name'] ?? 'No Name';
    String submittedOn = '';
    switch (widget.type.toLowerCase()) {
      case 'leave':
        submittedOn = formatDate(data?['created_at']);
        break;
      case 'car':
        submittedOn = formatDate(data?['created_date']);
        break;
      case 'meeting room':
        submittedOn = formatDate(data?['date_create']);
        break;
      case 'meeting':
        submittedOn = formatDate(data?['created_at']);
        break;
      default:
        submittedOn = 'N/A';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0), // Increased vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Requestor',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 20, // Increased font size for prominence
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                    ? NetworkImage(imageUrl!)
                    : const NetworkImage('https://www.w3schools.com/howto/img_avatar.png'),
                radius: 35, // Increased radius for better visibility
                backgroundColor: Colors.grey[300],
                onBackgroundImageError: (_, __) {
                  // Handle image loading error by setting default avatar
                  setState(() {
                    imageUrl = _defaultAvatarUrl();
                  });
                },
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 18, // Consistent font size
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Submitted on $submittedOn',
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Build Blue Section
  Widget _buildBlueSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _getTypeHeader(),
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Get Type Header Text
  String _getTypeHeader() {
    switch (widget.type.toLowerCase()) {
      case 'meeting':
        return 'Meeting and Booking Meeting Room';
      case 'leave':
        return 'Leave Request';
      case 'car':
        return 'Car Permit Request';
      case 'meeting room':
        return 'Meeting Room Booking';
      default:
        return 'Approval Details';
    }
  }

  // Build Details Section
  Widget _buildDetailsSection() {
    final String type = widget.type.toLowerCase();

    switch (type) {
      case 'meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.room, 'Room', data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Details', data?['description'] ?? 'No Details Provided', Colors.purple),
            // Removed 'Employee' row to prevent duplication
          ],
        );
      case 'leave':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['name'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${data?['take_leave_from'] ?? 'N/A'} - ${data?['take_leave_to'] ?? 'N/A'}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.time_to_leave, 'Reason', data?['take_leave_reason'] ?? 'No Reason Provided', Colors.purple),
            // Removed 'Employee' row to prevent duplication
          ],
        );
      case 'car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Purpose', data?['purpose'] ?? 'No Purpose', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.place, 'Place', data?['place'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.directions_car, 'Vehicle ID', data?['vehicle_id'] ?? 'N/A', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Date Out', data?['date_out'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Date In', data?['date_in'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Time Out', data?['time_out'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Time In', data?['time_in'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Driver Name', data?['driver_name'] ?? 'N/A', Colors.red),
          ],
        );
      case 'meeting room':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.room, 'Room', data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Remark', data?['remark'] ?? 'No Remarks', Colors.purple),
            // Removed 'Employee' row to prevent duplication
          ],
        );
      default:
        return const Center(
          child: Text(
            'Unknown Request Type',
            style: TextStyle(fontSize: 16, color: Colors.red),
          ),
        );
    }
  }

  // Build Workflow Section
  Widget _buildWorkflowSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildUserAvatar(imageUrl!, label: 'Requestor'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(
            data?['line_manager_img'] ?? _defaultAvatarUrl(),
            label: 'Line Manager',
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(
            data?['hr_img'] ?? _defaultAvatarUrl(),
            label: 'HR',
          ),
        ],
      ),
    );
  }

  // Build User Avatar with Label
  Widget _buildUserAvatar(String imageUrl, {String label = ''}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : const NetworkImage('https://www.w3schools.com/howto/img_avatar.png'),
          radius: 20,
          backgroundColor: Colors.grey[300],
          onBackgroundImageError: (_, __) {
            // Handle image loading error by setting default avatar
            setState(() {
              imageUrl = _defaultAvatarUrl();
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

  // Build Info Row
  Widget _buildInfoRow(IconData icon, String title, String content, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$title: $content',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  // Build Action Buttons
  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStyledButton(
            label: 'Delete',
            icon: Icons.delete,
            backgroundColor: Colors.red.shade300,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleDelete(),
          ),
          _buildStyledButton(
            label: 'Edit',
            icon: Icons.edit,
            backgroundColor: Colors.blue,
            textColor: Colors.white,
            onPressed: isFinalized ? null : () => _handleEdit(),
          ),
        ],
      ),
    );
  }

  // Build Styled Button
  Widget _buildStyledButton({
    required String label,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: Icon(
        icon,
        color: textColor,
        size: 20,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Handle Edit Action
  Future<void> _handleEdit() async {
    setState(() {
      isFinalized = true;
    });

    final String type = widget.type.toLowerCase();
    String idToSend;

    if (type == 'leave') {
      idToSend = data?['take_leave_request_id'] ?? widget.id; // Use take_leave_request_id
    } else {
      idToSend = data?['uid'] ?? widget.id; // Use uid for car and meeting
    }

    // Debug: Print the data and id before navigating to the edit page
    print('Navigating to Edit Page with data: $data and id: $idToSend');

    // Navigate to OfficeBookingEventEditPage with id and type
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OfficeBookingEventEditPage(
          id: idToSend,
          type: type,
        ),
      ),
    ).then((result) {
      // Debug: Print the result from the edit page
      print('Returned from Edit Page with result: $result');

      // Refresh data after returning from edit page if result is true
      if (result == true) {
        _fetchData();
      }
    });

    setState(() {
      isFinalized = false;
    });
  }

  // Handle Delete Action
  Future<void> _handleDelete() async {
    final String type = widget.type.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Request ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog('Authentication Error', 'Token not found. Please log in again.');
      return;
    }

    setState(() {
      isFinalized = true;
    });

    try {
      http.Response response;

      switch (type) {
        case 'leave':
          response = await http.put(
            Uri.parse('$baseUrl/api/leave_cancel/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Leave request deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete leave request: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'car':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/car_permit/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            _showSuccessDialog('Success', 'Car permit deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete car permit: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'meeting room':
          response = await http.delete(
            Uri.parse('$baseUrl/api/office-administration/book_meeting_room/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            _showSuccessDialog('Success', 'Meeting room booking deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete meeting room booking: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'meeting':
          response = await http.put(
            Uri.parse('$baseUrl/api/work-tracking/meeting/delete/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Meeting deleted successfully.');
          } else {
            _showErrorDialog('Error', 'Failed to delete meeting: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      print('Error deleting request: $e');
      _showErrorDialog('Error', 'An unexpected error occurred while deleting the request.');
    }

    setState(() {
      isFinalized = false;
    });
  }

  // Show Error Dialog
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Show Success Dialog
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
              Navigator.of(context).pop(); // Navigate back after success
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : data == null
          ? const Center(
        child: Text(
          'No Data Available',
          style: TextStyle(fontSize: 16, color: Colors.red),
        ),
      )
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildRequestorSection(),
              _buildBlueSection(),
              const SizedBox(height: 20),
              _buildDetailsSection(),
              const SizedBox(height: 20),
              _buildWorkflowSection(),
              const SizedBox(height: 20),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }
}
