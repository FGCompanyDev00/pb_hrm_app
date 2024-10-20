// details_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/car_booking_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/leave_request_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/meeting_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/meeting_room_booking_edit_page.dart';

class DetailsPage extends StatefulWidget {
  final String types;
  final String id;
  final String status;

  const DetailsPage(
      {super.key,
        required this.types,
        required this.id,
        required this.status});

  @override
  _DetailsPageState createState() => _DetailsPageState();
}

class _DetailsPageState extends State<DetailsPage> {
  Map<String, dynamic>? data;
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // Fetch detailed data using POST API
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    final String status = widget.status;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    final String postApiUrl = '$baseUrl/api/app/users/history/pending/id';

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Prepare the request body based on the type
      Map<String, dynamic> requestBody;

      switch(type) {
        case 'leave':
          requestBody = {
            'types': widget.types,
            'take_leave_request_id': widget.id,
            'status': widget.status, // Include the 'status' as per API requirement
          };
          break;
        case 'car':
        case 'meeting':
          requestBody = {
            'types': widget.types,
            'uid': widget.id,
            'status': widget.status,
          };
          break;
        default:
          requestBody = {
            'types': widget.types,
            'id': widget.id, // Fallback if type is unknown
            'status': widget.status,
          };
      }

      print('Sending POST request to $postApiUrl with body: $requestBody');

      final response = await http.post(
        Uri.parse(postApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
        body: jsonEncode(requestBody),
      );

      print('Received response with status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 202) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check if 'result' key exists; adjust based on actual API response
        if (!responseData.containsKey('result')) {
          _showErrorDialog(
              'Error', 'Invalid API response structure.');
          setState(() {
            isLoading = false;
          });
          return;
        }

        setState(() {
          data = responseData['result'];
          isLoading = false;
        });

        if (data != null) {
          // Fetch employee image if available
          String? pID = data?['employee_id']?.toString();

          if (pID != null && pID.isNotEmpty) {
            await _fetchProfileImage(pID);
          } else {
            // Use default avatar
            setState(() {
              imageUrl = _defaultAvatarUrl();
            });
          }
        } else {
          setState(() {
            imageUrl = _defaultAvatarUrl();
          });
        }
      } else {
        _showErrorDialog(
            'Error',
            'Failed to fetch details: ${response.statusCode} ${response.reasonPhrase}\nResponse Body: ${response.body}');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching details: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred while fetching details.');
      setState(() {
        isLoading = false;
      });
    }
  }

  // Fetch profile image using employee_id (pID)
  Future<void> _fetchProfileImage(String pID) async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String profileEndpoint = '$baseUrl/api/profile/$pID';

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
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

      print(
          'Fetching profile image from $profileEndpoint with status code: ${response.statusCode}');
      print('Profile response body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final profileResults = decoded['results'];
        if (profileResults != null &&
            profileResults['images'] != null &&
            profileResults['images'].isNotEmpty) {
          setState(() {
            imageUrl = profileResults['images'];
          });
        } else {
          // Use default avatar
          setState(() {
            imageUrl = _defaultAvatarUrl();
          });
        }
      } else {
        // Use default avatar
        print('Failed to fetch profile image: ${response.reasonPhrase}');
        setState(() {
          imageUrl = _defaultAvatarUrl();
        });
      }
    } catch (e) {
      print('Error fetching profile image: $e');
      // Use default avatar
      setState(() {
        imageUrl = _defaultAvatarUrl();
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
    String requestorName =
        data?['requestor_name'] ?? data?['employee_name'] ?? 'No Name';
    String submittedOn = '';
    switch (widget.types.toLowerCase()) {
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
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
              CircleAvatar(
                backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
                    ? NetworkImage(imageUrl!)
                    : const NetworkImage(
                    'https://www.w3schools.com/howto/img_avatar.png'),
                radius: 35,
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
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Submitted on $submittedOn',
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black54),
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
        padding:
        const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _getTypeHeader(),
          style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // Get Type Header Text
  String _getTypeHeader() {
    switch (widget.types.toLowerCase()) {
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
    final String type = widget.types.toLowerCase();

    switch (type) {
      case 'meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title',
                data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.room, 'Room',
                data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Remark',
                data?['remark'] ?? 'No Remarks', Colors.purple),
          ],
        );
      case 'leave':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title',
                data?['name'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['take_leave_from'])} - ${formatDate(data?['take_leave_to'])}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.time_to_leave, 'Reason',
                data?['take_leave_reason'] ?? 'No Reason Provided', Colors.purple),
          ],
        );
      case 'car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Purpose',
                data?['purpose'] ?? 'No Purpose', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.place, 'Place',
                data?['place'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.directions_car, 'Vehicle ID',
                data?['vehicle_id'] ?? 'N/A', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Date Out',
                data?['date_out'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.calendar_today, 'Date In',
                data?['date_in'] ?? 'N/A', Colors.blue),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Time Out',
                data?['time_out'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Time In',
                data?['time_in'] ?? 'N/A', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.person, 'Driver Name',
                data?['driver_name'] ?? 'N/A', Colors.red),
          ],
        );
      case 'meeting room':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.bookmark, 'Title',
                data?['title'] ?? 'No Title', Colors.green),
            const SizedBox(height: 12),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}',
              Colors.blue,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.room, 'Room',
                data?['room_name'] ?? 'No Room Info', Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Remark',
                data?['remark'] ?? 'No Remarks', Colors.purple),
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
          _buildUserAvatar(imageUrl ?? _defaultAvatarUrl(),
              label: 'Requestor'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(
              data?['line_manager_img'] ?? _defaultAvatarUrl(),
              label: 'Line Manager'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(
              data?['hr_img'] ?? _defaultAvatarUrl(),
              label: 'HR'),
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
              : const NetworkImage(
              'https://www.w3schools.com/howto/img_avatar.png'),
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
  Widget _buildInfoRow(
      IconData icon, String title, String content, Color color) {
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

  // Handle Edit Action
  Future<void> _handleEdit() async {
    setState(() {
      isFinalized = true;
    });

    final String type = widget.types.toLowerCase();

    Widget? editPage;

    // Debug: Print the data before navigating to the edit page
    print('Navigating to Edit Page with data: $data');

    switch (type) {
      case 'meeting':
        editPage = MeetingEditPage(item: data!);
        break;
      case 'leave':
        editPage = LeaveRequestEditPage(item: data!);
        break;
      case 'car':
        editPage = CarBookingEditPage(item: data!);
        break;
      case 'meeting room':
        editPage = MeetingRoomBookingEditPage(item: data!);
        break;
      default:
        _showErrorDialog('Error', 'Unknown request type.');
        setState(() {
          isFinalized = false;
        });
        return;
    }

    if (editPage != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => editPage!),
      ).then((result) {
        // Debug: Print the result from the edit page
        print('Returned from Edit Page with result: $result');

        // Refresh data after returning from edit page if result is true
        if (result == true) {
          _fetchData();
        }
      });
    }

    setState(() {
      isFinalized = false;
    });
  }

  // Handle Delete Action
  Future<void> _handleDelete() async {
    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    const String baseUrl = 'https://demo-application-api.flexiflows.co';

    if (id.isEmpty) {
      _showErrorDialog('Invalid Data', 'Request ID is missing.');
      return;
    }

    final String? tokenValue = await _getToken();
    if (tokenValue == null) {
      _showErrorDialog(
          'Authentication Error',
          'Token not found. Please log in again.');
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
            _showSuccessDialog(
                'Success', 'Leave request deleted successfully.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete leave request: ${response.reasonPhrase}\nResponse Body: ${response.body}');
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
            _showSuccessDialog(
                'Success', 'Car permit deleted successfully.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete car permit: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'meeting room':
          response = await http.delete(
            Uri.parse(
                '$baseUrl/api/office-administration/book_meeting_room/$id'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 204) {
            _showSuccessDialog(
                'Success',
                'Meeting room booking deleted successfully.');
          } else {
            _showErrorDialog(
                'Error',
                'Failed to delete meeting room booking: ${response.reasonPhrase}\nResponse Body: ${response.body}');
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
            _showErrorDialog(
                'Error',
                'Failed to delete meeting: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      print('Error deleting request: $e');
      _showErrorDialog(
          'Error',
          'An unexpected error occurred while deleting the request.');
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
          padding: const EdgeInsets.symmetric(
              horizontal: 24.0, vertical: 16.0),
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
