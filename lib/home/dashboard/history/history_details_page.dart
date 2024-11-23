// history_details_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/history/history_office_booking_event_edit_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  String? _errorMessage; // Added error message variable

  @override
  void initState() {
    super.initState();
    _fetchLeaveTypes().then((_) {
      _fetchData();
    });
  }

  /// Handle refresh action
  Future<void> _handleRefresh() async {
    await _fetchData(); // Re-fetch data when user pulls down
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
        setState(() {
          _errorMessage = 'Token not found. Please log in again.';
        });
        return;
      }
      final response = await http.get(
        Uri.parse(leaveTypesUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
      );

      if (kDebugMode) {
        print('Fetching Leave Types from URL: $leaveTypesUrl');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] is List) {
          setState(() {
            _leaveTypes = {
              for (var lt in data['results']) lt['leave_type_id']: lt['name']
            };
          });
        } else {
          throw Exception('Failed to fetch leave types');
        }
      } else {
        throw Exception(
            'Failed to fetch leave types: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching leave types: $e';
      });
      if (kDebugMode) {
        print('Error fetching leave types: $e');
      }
    }
  }

  /// Fetch detailed data using appropriate API based on type
  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      _errorMessage = null; // Reset error message before fetching
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
    // Initialize API URL based on type
    String apiUrl;

    if (type == 'leave') {
      // For leave type, use GET request to /api/leave_request/all/{take_leave_request_id}
      apiUrl = '$baseUrl/api/leave_request/all/$id';
    } else {
      // For other types, use existing POST request
      apiUrl = '$baseUrl/api/app/users/history/pending/$id';
    }

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        setState(() {
          isLoading = false;
          _errorMessage = 'Token not found. Please log in again.';
        });
        return;
      }

      http.Response response;

      if (type == 'leave') {
        // Send GET request for leave type
        if (kDebugMode) {
          print('Sending GET request to $apiUrl');
        }
        response = await http.get(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenValue',
          },
        );
      } else {
        // Send POST request for other types
        // Prepare the request body with 'types' and 'status'
        Map<String, dynamic> requestBody = {
          'types': widget.types,
          'status': status,
        };

        if (kDebugMode) {
          print(
              'Sending POST request to $apiUrl with body: $requestBody');
        }

        response = await http.post(
          Uri.parse(apiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenValue',
          },
          body: jsonEncode(requestBody),
        );
      }

      if (kDebugMode) {
        print('Received response with status code: ${response.statusCode}');
        print('Response body: ${response.body}');
      }

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
              _errorMessage = 'Invalid API response structure.';
            });
            return;
          }

          if (type == 'leave') {
            // For leave, the API returns a GET response with a list containing leave details
            if (responseData['results'] is List) {
              final List<dynamic> resultsList = responseData['results'];
              if (resultsList.isNotEmpty) {
                setState(() {
                  data = resultsList[0] as Map<String, dynamic>;
                  isLoading = false;
                });

                if (data != null) {
                  // Determine the ID to fetch profile image
                  String profileId = data?['requestor_id'] ?? '';
                  if (profileId.isNotEmpty) {
                    _fetchProfileImage(profileId);
                  } else {
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
                // Empty list
                setState(() {
                  data = null;
                  isLoading = false;
                  _errorMessage = 'No data found.';
                });
              }
            } else {
              // Unexpected structure
              setState(() {
                data = null;
                isLoading = false;
                _errorMessage = 'Unexpected data format.';
              });
              _showErrorDialog('Error', 'Unexpected data format.');
            }
          } else {
            // For meeting and car, handle existing POST response
            // Handle 'results' as a list for 'meeting' and 'car' types
            if (responseData['results'] is List &&
                responseData['results'].isNotEmpty) {
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
                _errorMessage = 'Unexpected data format.';
              });
              _showErrorDialog('Error', 'Unexpected data format.');
            }

            if (type != 'leave' && data != null) {
              // Determine the ID to fetch profile image
              String profileId = data?['employee_id'] ?? '';
              if (profileId.isNotEmpty) {
                _fetchProfileImage(profileId);
              } else {
                setState(() {
                  imageUrl = _defaultAvatarUrl();
                });
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
            _errorMessage = errorMessage;
          });
        }
      } else {
        // Handle HTTP errors
        _showErrorDialog(
            'Error', 'Failed to fetch details: ${response.statusCode}');
        setState(() {
          isLoading = false;
          _errorMessage = 'Failed to fetch details: ${response.statusCode}';
        });
      }
    } catch (e) {
      print('Error fetching details: $e');
      setState(() {
        isLoading = false;
        _errorMessage =
        'An unexpected error occurred while fetching details.';
      });
      _showErrorDialog(
          'Error', 'An unexpected error occurred while fetching details.');
    }
  }

  /// Fetch Profile Image using the profile API
  Future<void> _fetchProfileImage(String id) async {
    const String baseUrl = 'https://demo-application-api.flexiflows.co';
    String profileApiUrl = '$baseUrl/api/profile/$id';

    try {
      final String? tokenValue = await _getToken();
      if (tokenValue == null) {
        _showErrorDialog('Authentication Error',
            'Token not found. Please log in again.');
        setState(() {
          imageUrl = _defaultAvatarUrl();
          _errorMessage = 'Token not found. Please log in again.';
        });
        return;
      }

      if (kDebugMode) {
        print('Fetching profile image from: $profileApiUrl');
      }

      final response = await http.get(
        Uri.parse(profileApiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenValue',
        },
      );

      if (kDebugMode) {
        print('Profile API Response Status Code: ${response.statusCode}');
        print('Profile API Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> profileData = jsonDecode(response.body);

        if (profileData.containsKey('statusCode') &&
            (profileData['statusCode'] == 200 ||
                profileData['statusCode'] == 201 ||
                profileData['statusCode'] == 202)) {
          if (profileData.containsKey('results') &&
              profileData['results'] is Map<String, dynamic>) {
            String fetchedImageUrl =
                profileData['results']['images'] ?? _defaultAvatarUrl();
            setState(() {
              imageUrl = fetchedImageUrl;
            });
          } else {
            setState(() {
              imageUrl = _defaultAvatarUrl();
              _errorMessage = 'Invalid profile API response.';
            });
            _showErrorDialog('Error', 'Invalid profile API response.');
          }
        } else {
          String errorMessage =
              profileData['message'] ?? 'Unknown error fetching profile.';
          _showErrorDialog('Error', errorMessage);
          setState(() {
            imageUrl = _defaultAvatarUrl();
            _errorMessage = errorMessage;
          });
        }
      } else {
        setState(() {
          imageUrl = _defaultAvatarUrl();
          _errorMessage =
          'Failed to fetch profile image: ${response.statusCode}';
        });
        _showErrorDialog('Error',
            'Failed to fetch profile image: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching profile image: $e');
      setState(() {
        imageUrl = _defaultAvatarUrl();
        _errorMessage = 'An error occurred while fetching profile image.';
      });
      _showErrorDialog(
          'Error', 'An unexpected error occurred while fetching profile image.');
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
    String requestorName = (data?['requestor_name'] ?? data?['employee_name']) ?? 'No Name';
    String submittedOn = formatDate(
        data?['created_at'] ?? data?['date_create'],
        includeTime: true
    );
    String requestorImageUrl = imageUrl ?? _defaultAvatarUrl();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Requestor Section Title
        const Text(
          'Requestor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8), // Reduced spacing

        // Profile Image and Name
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(requestorImageUrl),
              radius: 30, // Reduced profile image size
              backgroundColor: Colors.grey[300],
              onBackgroundImageError: (_, __) {
                setState(() {
                  imageUrl = _defaultAvatarUrl();
                });
              },
            ),
            const SizedBox(width: 12), // Reduced spacing
            Expanded( // Added Expanded to adjust to screen size
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    requestorName,
                    style: const TextStyle(
                      fontSize: 16, // Reduced font size
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // Handle overflow
                  ),
                  const SizedBox(height: 2), // Reduced spacing
                  Text(
                    'Submitted on $submittedOn',
                    style: const TextStyle(
                      fontSize: 12, // Reduced font size
                      fontWeight: FontWeight.w500,
                      color: Colors.black54,
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

  /// Build Blue Section
  Widget _buildBlueSection() {
    return Container(
      width: 100, // Reduced width
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.lightBlue[100], // Light blue background color
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          '${widget.types[0].toUpperCase()}${widget.types.substring(1).toLowerCase()}', // Capitalize first letter
          style: const TextStyle(
            fontSize: 12, // Reduced font size
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
    );
  }

  /// Build Details Section
  Widget _buildDetailsSection() {
    final String type = widget.types.toLowerCase();

    switch (type) {
      case 'meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
                Icons.bookmark, 'Title', data?['title'] ?? 'No Title', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Date',
                '${formatDate(data?['from_date_time'])} - ${formatDate(data?['to_date_time'])}', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Time',
                '${formatDate(data?['from_date_time'], includeTime: true)} - ${formatDate(data?['to_date_time'], includeTime: true)}', Colors.orange),
            const SizedBox(height: 8),
            _buildInfoRow(
                Icons.description, 'Description', data?['remark'] ?? 'No Remark', Colors.indigo),
            const SizedBox(height: 8),
            Text(
              'Room: ${data?['room_name'] ?? 'No room specified'}',
              style: const TextStyle(
                fontSize: 14, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        );
      case 'car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
                Icons.bookmark, 'Purpose', data?['purpose'] ?? 'No Purpose', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.place, 'Place', data?['place'] ?? 'N/A', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Date',
                '${formatDate(data?['date_out'])} - ${formatDate(data?['date_in'])}', Colors.orange),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.access_time, 'Time',
                '${data?['time_out'] ?? 'N/A'} - ${data?['time_in'] ?? 'N/A'}', Colors.purple),
            const SizedBox(height: 8),
            Text(
              'Discretion: ${data?['employee_tel'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 14, // Reduced font size
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ],
        );
      case 'leave':
        String leaveTypeName =
            _leaveTypes[data?['leave_type_id']] ?? 'Unknown Leave Type';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
                Icons.bookmark, 'Title', data?['name'] ?? 'No Title', Colors.blue),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.calendar_today, 'Date',
                '${formatDate(data?['take_leave_from'])} - ${formatDate(data?['take_leave_to'])}', Colors.green),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.label, 'Type of leave',
                '$leaveTypeName (${data?['days']?.toString() ?? 'N/A'})', Colors.orange),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8), // Reduced padding
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10), // Reduced margins
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Center(
                child: Text(
                  data?['take_leave_reason'] ?? 'No Description Provided',
                  style: const TextStyle(fontSize: 12, color: Colors.black), // Reduced font size
                ),
              ),
            ),
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

  Widget _buildInfoRow(IconData icon, String title, String content, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0), // Added padding to each row
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Adjusted alignment
        children: [
          Icon(icon, size: 18, color: color), // Reduced icon size
          const SizedBox(width: 6), // Reduced spacing
          Expanded( // Added Expanded to adjust to screen size
            child: Text(
              '$title: $content',
              style: const TextStyle(fontSize: 13, color: Colors.black), // Reduced font size
            ),
          ),
        ],
      ),
    );
  }

  /// Build Workflow Section
  Widget _buildWorkflowSection() {
    if (widget.types.toLowerCase() == 'leave') {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 10, // Reduced spacing
        runSpacing: 10, // Reduced spacing
        children: [
          _buildUserAvatar(imageUrl ?? _defaultAvatarUrl(), borderColor: Colors.green),
          Transform.translate(
            offset: const Offset(0, 13.0),
            child: const Icon(Icons.arrow_forward, color: Colors.orange, size: 18),
          ),
          _buildUserAvatar(lineManagerImageUrl ?? _defaultAvatarUrl(), borderColor: Colors.orange),
          Transform.translate(
            offset: const Offset(0, 13.0),
            child: const Icon(Icons.arrow_forward, color: Colors.grey, size: 18),
          ),
          _buildUserAvatar(hrImageUrl ?? _defaultAvatarUrl(), borderColor: Colors.grey),
        ],
      );
    } else if (widget.types.toLowerCase() == 'meeting') {
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 10,
        children: [
          _buildUserAvatar(imageUrl ?? _defaultAvatarUrl(), borderColor: Colors.blue),
          Transform.translate(
            offset: const Offset(0, 13.0),
            child: const Icon(Icons.arrow_forward, color: Colors.orange, size: 18),
          ),
          _buildUserAvatar(_defaultAvatarUrl(), borderColor: Colors.grey),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildUserAvatar(String imageUrl, {Color borderColor = Colors.grey}) {
    return CircleAvatar(
      radius: 22, // Reduced radius
      backgroundColor: borderColor,
      child: CircleAvatar(
        radius: 20, // Reduced radius
        backgroundImage: NetworkImage(imageUrl),
        onBackgroundImageError: (_, __) {
          setState(() {
            imageUrl = _defaultAvatarUrl();
          });
        },
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 20.0), // Reduced vertical padding
      child: Row(
        children: [
          Expanded(
            child: _buildStyledButton(
              label: 'Delete',
              icon: Icons.close,
              backgroundColor: Colors.grey,
              textColor: Colors.white,
              onPressed: isFinalized ? null : () => _confirmDelete(), // Updated to _confirmDelete()
            ),
          ),
          const SizedBox(width: 10), // Reduced spacing
          Expanded(
            child: _buildStyledButton(
              label: 'Edit',
              icon: Icons.check,
              backgroundColor: const Color(0xFFDBB342),
              textColor: Colors.white,
              onPressed: isFinalized ? null : () => _handleEdit(),
            ),
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
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(vertical: 10.0), // Reduced vertical padding
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(icon, color: textColor, size: 18), // Reduced icon size
      label: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 13.0), // Reduced font size
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
      idToSend = data?['take_leave_request_id']?.toString() ?? widget.id;
    } else {
      idToSend = data?['uid']?.toString() ?? widget.id;
    }

    // Debug: Print the data and id before navigating to the edit page
    if (kDebugMode) {
      print('Navigating to Edit Page with data: $data and id: $idToSend');
    }

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
      if (kDebugMode) {
        print('Returned from Edit Page with result: $result');
      }

      // Refresh data after returning from edit page if result is true
      if (result == true) {
        _fetchData();
      }
    });

    setState(() {
      isFinalized = false;
    });
  }

  /// Confirm Delete Action
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close the dialog
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close the dialog
              _handleDelete(); // Proceed with deletion
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
      _showErrorDialog(
          'Authentication Error', 'Token not found. Please log in again.');
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
            _showErrorDialog('Error',
                'Failed to delete leave request: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'car':
          response = await http.delete(
            Uri.parse(
                '$baseUrl/api/office-administration/car_permit/${data?['uid'] ?? id}'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog(
                'Success', 'Car permit deleted successfully.');
          } else {
            _showErrorDialog('Error',
                'Failed to delete car permit: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }
          break;

        case 'meeting':
          response = await http.delete(
            Uri.parse(
                '$baseUrl/api/office-administration/book_meeting_room/${data?['uid'] ?? id}'),
            headers: {
              'Authorization': 'Bearer $tokenValue',
              'Content-Type': 'application/json',
            },
          );
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessDialog('Success', 'Meeting deleted successfully.');
          } else {
            _showErrorDialog('Error',
                'Failed to delete meeting: ${response.reasonPhrase}\nResponse Body: ${response.body}');
          }

          if (kDebugMode) {
            print('Full response body: ${response.body}');
          }

          break;

        default:
          _showErrorDialog('Error', 'Unknown request type.');
      }
    } catch (e) {
      print('Error deleting request: $e');
      _showErrorDialog(
          'Error', 'An unexpected error occurred while deleting the request.');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 360 ? 12.0 : 16.0; // Reduced padding for small screens

    return Scaffold(
      appBar: _buildAppBar(context),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16, color: Colors.red),
          ),
        ),
      )
          : RefreshIndicator(
        onRefresh: _handleRefresh, // Pull down to refresh
        child: data == null
            ? const Center(
          child: Text(
            'No Data Available',
            style:
            TextStyle(fontSize: 16, color: Colors.red),
          ),
        )
            : SingleChildScrollView(
          physics:
          const AlwaysScrollableScrollPhysics(), // To allow pull-to-refresh even when content is less
          child: Center( // Wrapped content in Center widget
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, vertical: 12.0), // Reduced vertical padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 8),
                  _buildRequestorSection(),
                  _buildBlueSection(),
                  const SizedBox(height: 16),
                  _buildDetailsSection(),
                  const SizedBox(height: 16),
                  _buildWorkflowSection(),
                  _buildActionButtons(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
