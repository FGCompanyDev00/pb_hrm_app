// details_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/car_booking_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/leave_request_edit_page.dart';
import 'package:pb_hrsystem/home/dashboard/Card/approval/edit_section/meeting_edit_page.dart';

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
  Map<int, String> _leaveTypes = {};
  bool isFinalized = false;
  bool isLoading = true;
  String? imageUrl;
  String? lineManagerImageUrl;
  String? hrImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes().then((_) {
      _fetchData();
    });
  }

  /// Handle refresh action
  Future<void> _handleRefresh() async {
    await _fetchData();  // Re-fetch data when user pulls down
  }

  /// Fetch Leave Types
  Future<void> _fetchLeaveTypes() async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    const String leaveTypesUrl = '$baseUrl/api/leave-types';
    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        return;
      }
      final response = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody['statusCode'] == 200) {
          final List<dynamic> leaveTypesData = responseBody['results'];
          setState(() {
            _leaveTypes = {
              for (var lt in leaveTypesData) lt['leave_type_id']: lt['name']
            };
          });
        } else {
          _showErrorDialog('Error',
              responseBody['message'] ?? 'Failed to load leave types');
        }
      } else {
        _showErrorDialog(
            'Error', 'Failed to load leave types: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error',
          'An unexpected error occurred while fetching leave types.');
    }
  }

  /// Fetch detailed data using POST API
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    final String type = widget.types.toLowerCase();
    final String id = widget.id;
    final String status;
    if (widget.types.toLowerCase() == 'leave') {
      if (widget.status.toLowerCase() == 'approved') {
        status = 'Approved';
      } else if (widget.status.toLowerCase() == 'cancel') {
        status = 'Cancel';
      } else if (widget.status.toLowerCase() == 'processing') {
        status = 'Processing';
      } else {
        status = widget.status; // Keep as is for other statuses
      }
    } else if (widget.types.toLowerCase() == 'meeting') {
      if (widget.status.toLowerCase() == 'approved') {
        status = 'approved';
      } else if (widget.status.toLowerCase() == 'cancel') {
        status = 'cancel';
      } else {
        status = widget.status; // Keep as is for other statuses
      }
    } else {
      status = widget.status; // Keep as is for other types like car
    }

    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    // Correct API endpoint by appending the actual ID
    final String postApiUrl = '$baseUrl/api/app/users/history/pending/$id';

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

      // Prepare the request body with 'types' and 'status'
      Map<String, dynamic> requestBody = {
        'types': widget.types,
        'status': status,
      };

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

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // Check the 'statusCode' in the response body
        if (responseData.containsKey('statusCode') &&
            (responseData['statusCode'] == 200 ||
                responseData['statusCode'] == 201 ||
                responseData['statusCode'] == 202)) {
          // Success
          if (!responseData.containsKey('results')) {
            _showErrorDialog('Error', 'Invalid API response structure.');
            setState(() {
              isLoading = false;
            });
            return;
          }

          // Handle 'results' as a list for 'leave' type
          if (type == 'leave') {
            if (responseData['results'] is List) {
              final List<dynamic> resultsList = responseData['results'];
              if (resultsList.isNotEmpty) {
                setState(() {
                  data = resultsList[0] as Map<String, dynamic>;
                  isLoading = false;
                });

                if (data != null) {
                  // Directly use 'img_name' from the response for the image URL
                  setState(() {
                    imageUrl = data?['img_name'] ?? _defaultAvatarUrl();
                    // Optional: Handle workflow images if available
                    lineManagerImageUrl =
                        data?['line_manager_img'] ?? _defaultAvatarUrl();
                    hrImageUrl = data?['hr_img'] ?? _defaultAvatarUrl();
                  });
                } else {
                  setState(() {
                    imageUrl = _defaultAvatarUrl();
                    lineManagerImageUrl = _defaultAvatarUrl();
                    hrImageUrl = _defaultAvatarUrl();
                  });
                }
              } else {
                // Empty list
                setState(() {
                  data = null;
                  isLoading = false;
                });
              }
            } else {
              // Unexpected structure
              setState(() {
                data = null;
                isLoading = false;
              });
              _showErrorDialog('Error', 'Unexpected data format.');
            }
          } else {
            // For meeting, check if 'results' is a list or a map
            if (type == 'meeting') {
              if (responseData['results'] is List && responseData['results'].isNotEmpty) {
                setState(() {
                  data = responseData['results'][0] as Map<String, dynamic>;
                  isLoading = false;
                });
              } else if (responseData['results'] is Map<String, dynamic>) {
                setState(() {
                  data = responseData['results'] as Map<String, dynamic>;
                  isLoading = false;
                });
              } else {
                // Unexpected structure
                setState(() {
                  data = null;
                  isLoading = false;
                });
                _showErrorDialog('Error', 'Unexpected data format.');
              }
            } else {
              // For other types like car, leave
              if (responseData['results'] is Map<String, dynamic>) {
                setState(() {
                  data = responseData['results'] as Map<String, dynamic>;
                  isLoading = false;
                });
              } else {
                // Unexpected structure for other types
                setState(() {
                  data = null;
                  isLoading = false;
                });
                _showErrorDialog('Error', 'Unexpected data format.');
              }
            }
          }
        } else {
          // Handle API-level errors
          String errorMessage =
              responseData['message'] ?? 'Unknown error.';
          _showErrorDialog('Error', errorMessage);
          setState(() {
            isLoading = false;
          });
        }
      } else {
        // Handle HTTP errors
        _showErrorDialog(
            'Error', 'Failed to fetch details: ${response.statusCode}');
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

  /// Helper method to get a default avatar URL
  String _defaultAvatarUrl() {
    // Replace with a publicly accessible image URL
    return 'https://www.w3schools.com/howto/img_avatar.png';
  }

  /// Retrieve token from SharedPreferences
  Future<String?> _getToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('token');
    } catch (e) {
      print('Error retrieving token: $e');
      return null;
    }
  }

  /// Format date string
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

  /// Build AppBar
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

  /// Build Requestor Section
  Widget _buildRequestorSection() {
    // Correctly assign requestorName and requestor image URL
    String requestorName = data?['requestor_name'] ?? data?['employee_name'] ?? 'No Name';
    String submittedOn = '';

    // Fetch image URL for requestor from 'img_path' or 'img_ref'
    String requestorImageUrl = data?['img_path'] ?? data?['img_ref'] ?? _defaultAvatarUrl();

    switch (widget.types.toLowerCase()) {
      case 'leave':
        submittedOn = formatDate(data?['created_at']);
        break;
      case 'car':
        submittedOn = formatDate(data?['created_date']);
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
          _buildStatusRow(widget.status), // Display status
          const SizedBox(height: 20), // Add spacing
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
              // Display the requestor's image using CircleAvatar
              CircleAvatar(
                backgroundImage: NetworkImage(requestorImageUrl),
                radius: 35, // Larger circle for profile image
                backgroundColor: Colors.grey[300],
                onBackgroundImageError: (_, __) {
                  // Handle image load error by setting default avatar
                  setState(() {
                    requestorImageUrl = _defaultAvatarUrl();
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

  Widget _buildStatusRow(String status) {
    final Color statusColor = _getStatusColor(status);
    final IconData statusIcon = _getStatusIcon(status);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 30, // Larger size for better visibility
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.bold,
            fontSize: 20, // Larger font size for emphasis
          ),
        ),
      ],
    );
  }

  /// Build Blue Section
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

  /// Get Type Header Text
  String _getTypeHeader() {
    switch (widget.types.toLowerCase()) {
      case 'meeting':
        return 'Meeting Details';
      case 'leave':
        return 'Leave Request Details';
      case 'car':
        return 'Car Booking Details';
      default:
        return 'Approval Details';
    }
  }

  /// Build Details Section
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
            _buildInfoRow(Icons.phone, 'Employee Tel',
                data?['employee_tel'] ?? 'No Telephone', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.email, 'Employee Email',
                data?['employee_email'] ?? 'No Email', Colors.purple),
          ],
        );
      case 'leave':
        String leaveTypeName =
            _leaveTypes[data?['leave_type_id']] ?? 'Unknown';
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
            _buildInfoRow(Icons.label, 'Leave Type',
                leaveTypeName, Colors.orange),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.access_time, 'Days',
                data?['days']?.toString() ?? 'N/A', Colors.purple),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.description, 'Reason',
                data?['take_leave_reason'] ?? 'No Reason Provided',
                Colors.red),
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

  /// Build Workflow Section
  Widget _buildWorkflowSection() {
    // Only show this section if the request type is 'leave'
    if (widget.types.toLowerCase() != 'leave') {
      return const SizedBox.shrink(); // Returns an empty widget if not 'leave'
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildUserAvatar(imageUrl ?? _defaultAvatarUrl(), label: 'Requestor'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(lineManagerImageUrl ?? _defaultAvatarUrl(), label: 'Line Manager'),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward, color: Colors.green),
          const SizedBox(width: 12),
          _buildUserAvatar(hrImageUrl ?? _defaultAvatarUrl(), label: 'HR'),
        ],
      ),
    );
  }

  /// Build User Avatar with Label
  Widget _buildUserAvatar(String imageUrl, {String label = ''}) {
    return Column(
      children: [
        CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
          radius: 20,
          backgroundColor: Colors.grey[300],
          onBackgroundImageError: (_, __) {
            // Handle image loading error by using default avatar
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
        return Colors.grey; // Default color for other statuses
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
        return Icons.info; // Default icon for other statuses
    }
  }

  Widget _buildStatusBox(String status) {
    final Color statusColor = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2), // Light background
        border: Border.all(color: statusColor, width: 2), // Border color
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: statusColor, // Text color matching the border
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  /// Build Info Row
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

  /// Build Action Buttons
  Widget _buildActionButtons(BuildContext context) {
    // Hide action buttons if status is approved, disapproved, or cancel
    if (widget.status.toLowerCase() == 'approved' ||
        widget.status.toLowerCase() == 'disapproved' ||
        widget.status.toLowerCase() == 'cancel') {
      return const SizedBox.shrink();
    }

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

  /// Build Styled Button
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

    final String type = widget.types.toLowerCase();
    String idToSend;

    if (type == 'leave') {
      idToSend = data?['take_leave_request_id'] ?? widget.id; // Use take_leave_request_id
    } else {
      idToSend = data?['uid'] ?? widget.id; // Use uid for car and meeting
    }

    Widget? editPage;

    // Debug: Print the data and id before navigating to the edit page
    print('Navigating to Edit Page with data: $data and id: $idToSend');

    switch (type) {
      case 'meeting':
        editPage = MeetingEditPage(item: data!, id: idToSend);
        break;
      case 'leave':
        editPage = LeaveRequestEditPage(item: data!, id: idToSend);
        break;
      case 'car':
        editPage = CarBookingEditPage(item: data!, id: idToSend);
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

  /// Handle Delete Action
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

  /// Show Error Dialog
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

  /// Show Success Dialog
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
          : RefreshIndicator(
        onRefresh: _handleRefresh,  // Pull down to refresh
        child: data == null
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
                const SizedBox(height: 10),
                _buildRequestorSection(),
                _buildBlueSection(),
                const SizedBox(height: 20),
                _buildDetailsSection(),
                const SizedBox(height: 20),
                _buildWorkflowSection(),
                _buildActionButtons(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
