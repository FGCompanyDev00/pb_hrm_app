// office_booking_event_edit_page.dart

// ignore_for_file: unused_field, unused_element, use_build_context_synchronously, deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'history_edit_event_members.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class OfficeBookingEventEditPage extends StatefulWidget {
  final String id;
  final String type; // 'leave', 'meeting', 'car', 'minutes_of_meeting'

  const OfficeBookingEventEditPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  OfficeBookingEventEditPageState createState() =>
      OfficeBookingEventEditPageState();
}

class OfficeBookingEventEditPageState
    extends State<OfficeBookingEventEditPage> {
  // Loading and Error States
  bool _isLoading = false;
  String? _errorMessage;

  // Employee ID
  String? _employeeId;

  // Selected Members for Meeting or Car
  List<Map<String, dynamic>> _selectedMembers = [];

  // Leave Types
  List<Map<String, dynamic>> _leaveTypes = [];
  String? _selectedLeaveTypeId;

  // Rooms for Meeting
  List<Map<String, dynamic>> _rooms = [];
  String? _selectedRoomId;

  final ValueNotifier<DateTime?> _beforeEndDateTime =
      ValueNotifier<DateTime?>(null);
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  // Controllers for Leave
  final TextEditingController _leaveFromController = TextEditingController();
  final TextEditingController _leaveToController = TextEditingController();
  final TextEditingController _leaveReasonController = TextEditingController();
  final TextEditingController _leaveDaysController = TextEditingController();

  // Controllers for Meeting
  final TextEditingController _meetingTitleController = TextEditingController();
  final TextEditingController _meetingFromController = TextEditingController();
  final TextEditingController _meetingToController = TextEditingController();
  final TextEditingController _meetingTelController = TextEditingController();
  final TextEditingController _meetingRemarkController =
      TextEditingController();

  // Controllers for Car
  final TextEditingController _carEmployeeIDController =
      TextEditingController();
  final TextEditingController _carPurposeController = TextEditingController();
  final TextEditingController _carPlaceController = TextEditingController();
  final TextEditingController _carDateInController = TextEditingController();
  final TextEditingController _carDateOutController = TextEditingController();

  // Controllers for Minutes of Meeting
  final TextEditingController _minutesOfMeetingTitleController =
      TextEditingController();
  final TextEditingController _minutesOfMeetingFromController =
      TextEditingController();
  final TextEditingController _minutesOfMeetingToController =
      TextEditingController();
  final TextEditingController _minutesOfMeetingDescriptionController =
      TextEditingController();
  final TextEditingController _minutesOfMeetingLocationController =
      TextEditingController();
  final String _minutesOfMeetingStatus = 'public'; // Default status

  // BaseUrl ENV initialization for debug and production
  String baseUrl = dotenv.env['BASE_URL'] ?? 'https://fallback-url.com';

  @override
  void initState() {
    super.initState();
    _fetchEmployeeId();
    _fetchLeaveTypes();
    _fetchEventDetails();
    if (widget.type.toLowerCase() == 'meeting') {
      _fetchRooms();
    }
  }

  @override
  void dispose() {
    // Leave Controllers
    _leaveFromController.dispose();
    _leaveToController.dispose();
    _leaveReasonController.dispose();
    _leaveDaysController.dispose();

    // Meeting Controllers
    _meetingTitleController.dispose();
    _meetingFromController.dispose();
    _meetingToController.dispose();
    _meetingTelController.dispose();
    _meetingRemarkController.dispose();

    // Car Controllers
    _carEmployeeIDController.dispose();
    _carPurposeController.dispose();
    _carPlaceController.dispose();
    _carDateInController.dispose();
    _carDateOutController.dispose();

    // Minutes of Meeting Controllers
    _minutesOfMeetingTitleController.dispose();
    _minutesOfMeetingFromController.dispose();
    _minutesOfMeetingToController.dispose();
    _minutesOfMeetingDescriptionController.dispose();
    _minutesOfMeetingLocationController.dispose();

    super.dispose();
  }

  /// Fetches the current user's employee ID from shared preferences
  Future<void> _fetchEmployeeId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getString('employee_id') ?? '';
    });
  }

  String formatDate(String? dateString) {
    // Check if the date is valid
    if (dateString == null || dateString == '0000-0-00' || dateString.isEmpty) {
      return ''; // Return an empty string for invalid dates
    }
    try {
      // Try parsing the date and formatting it
      DateTime parsedDate = DateTime.parse(dateString);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      // If there's an error parsing, return an empty string
      return '';
    }
  }

  /// Fetches leave types from the API
  Future<void> _fetchLeaveTypes() async {
    try {
      String token = await _fetchToken();
      String url = '$baseUrl/api/leave-types';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Fetching Leave Types from URL: $url');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] is List) {
          setState(() {
            _leaveTypes = List<Map<String, dynamic>>.from(data['results']);
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
      if (kDebugMode) {
        print('Error fetching leave types: $e');
      }
    }
  }

  /// Fetches rooms from the API for meeting booking
  Future<void> _fetchRooms() async {
    try {
      String token = await _fetchToken();
      String url = '$baseUrl/api/office-administration/rooms';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('Fetching Rooms from URL: $url');
        print('Response Status Code: ${response.statusCode}');
        print('Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['statusCode'] == 200 && data['results'] is List) {
          setState(() {
            _rooms = data['results']
                .map<Map<String, dynamic>>((item) => {
                      'room_id': item['uid'],
                      'room_name': item['room_name'],
                    })
                .toList();
          });
        } else {
          throw Exception('Failed to fetch rooms');
        }
      } else {
        throw Exception('Failed to fetch rooms: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching rooms: $e';
      });
      if (kDebugMode) {
        print('Error fetching rooms: $e');
      }
    }
  }

  /// Fetches event details based on type and id
  Future<void> _fetchEventDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String token = await _fetchToken();
      String url = '';

      switch (widget.type.toLowerCase()) {
        case 'leave':
          url = '$baseUrl/api/leave_request/${widget.id}';
          break;
        case 'meeting':
          url =
              '$baseUrl/api/office-administration/book_meeting_room/waiting/${widget.id}';
          break;
        case 'car':
          url = '$baseUrl/api/office-administration/car_permit/${widget.id}';
          break;
        case 'minutes_of_meeting':
          url = '$baseUrl/api/app/users/history/pending/${widget.id}';
          break;
        default:
          throw Exception('Invalid event type');
      }

      if (kDebugMode) {
        print('Fetching event details from URL: $url');
      }

      // For minutes of meeting, we need to use a POST request with type and status in the body
      if (widget.type.toLowerCase() == 'minutes_of_meeting') {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'types': 'minutes of meeting',
            'status': 'Public', // Default status
          }),
        );

        if (kDebugMode) {
          print('Response Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
        }

        if (response.statusCode == 200 ||
            response.statusCode == 201 ||
            response.statusCode == 202) {
          final data = jsonDecode(response.body);
          if (data['statusCode'] == 200 && data['results'] != null) {
            _populateMinutesOfMeetingData(data['results']);
          } else {
            throw Exception('Invalid response format');
          }
        } else {
          throw Exception('Failed to load minutes of meeting details');
        }
      } else {
        // Existing code for other types
        final response = await http.get(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (kDebugMode) {
          print('Response Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
        }

        if (response.statusCode == 200 || response.statusCode == 201) {
          final rawData = jsonDecode(response.body)['results'];

          // Handle if 'results' is a List or Map
          if (rawData is List && rawData.isNotEmpty) {
            final responseData = rawData[0];
            if (widget.type.toLowerCase() == 'leave') {
              _populateLeaveData(responseData);
            } else if (widget.type.toLowerCase() == 'meeting') {
              _populateMeetingData(responseData);
            } else if (widget.type.toLowerCase() == 'car') {
              _populateCarData(responseData);
            }
          } else if (rawData is Map<String, dynamic>) {
            final responseData = rawData;
            if (widget.type.toLowerCase() == 'leave') {
              _populateLeaveData(responseData);
            } else if (widget.type.toLowerCase() == 'meeting') {
              _populateMeetingData(responseData);
            } else if (widget.type.toLowerCase() == 'car') {
              _populateCarData(responseData);
            }
          } else {
            throw Exception('Unexpected data format received from API.');
          }
        } else {
          throw Exception('Failed to load event details');
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching event details: $e';
      });
      if (kDebugMode) {
        print('Error fetching event details: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Fetches the authentication token from shared preferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    if (kDebugMode) {
      print('Fetched Token: $token');
    }
    return token;
  }

  /// Populates leave request data into controllers
  void _populateLeaveData(Map<String, dynamic> data) {
    setState(() {
      _selectedLeaveTypeId = data['take_leave_type_id']?.toString() ??
          (_leaveTypes.isNotEmpty
              ? _leaveTypes.first['leave_type_id'].toString()
              : null);

      // Format take_leave_from and take_leave_to to 'dd-MM-yyyy'
      _leaveFromController.text = data['take_leave_from'] != null
          ? DateFormat('dd-MM-yyyy')
              .format(DateTime.parse(data['take_leave_from']))
          : '';
      _leaveToController.text = data['take_leave_to'] != null
          ? DateFormat('dd-MM-yyyy')
              .format(DateTime.parse(data['take_leave_to']))
          : '';

      _leaveReasonController.text = data['take_leave_reason'] ?? '';
      _leaveDaysController.text = data['days']?.toString() ?? '';
    });
  }

  /// Populates meeting data into controllers
  void _populateMeetingData(Map<String, dynamic> data) {
    setState(() {
      _meetingTitleController.text = data['title'] ?? '';
      _meetingFromController.text = data['from_date_time'] != null
          ? DateFormat('dd-MM-yyyy HH:mm')
              .format(DateTime.parse(data['from_date_time']))
          : '';
      _meetingToController.text = data['to_date_time'] != null
          ? DateFormat('dd-MM-yyyy HH:mm')
              .format(DateTime.parse(data['to_date_time']))
          : '';
      _selectedRoomId = data['room_id']?.toString();
      _meetingTelController.text = data['employee_tel'] ?? '';
      _meetingRemarkController.text = data['remark'] ?? '';

      _selectedMembers =
          List<Map<String, dynamic>>.from(data['members']?.map((member) => {
                    'employee_id': member['employee_id'],
                    'employee_name': member['employee_name'],
                    'img_name': member['img_name'],
                  }) ??
              []);
    });
  }

  /// Populates car booking data into controllers
  void _populateCarData(Map<String, dynamic> data) {
    setState(() {
      _carEmployeeIDController.text = data['employee_id'] ?? 'No Employee ID';
      _carPurposeController.text = data['purpose'] ?? '';
      _carPlaceController.text = data['place'] ?? '';

      // Format the date_in and time_in fields
      if (data['date_in'] != null && data['time_in'] != null) {
        String dateTimeStr = '${data['date_in']} ${data['time_in']}';
        try {
          // Try parsing with a custom format
          DateTime dateTimeIn =
              DateFormat('yyyy-MM-dd HH:mm').parse(dateTimeStr);
          _carDateInController.text = DateFormat('dd-MM-yyyy HH:mm')
              .format(dateTimeIn); // Only the date part in dd-MM-yyyy format
        } catch (e) {
          // If parsing fails, handle gracefully
          if (kDebugMode) {
            print("Error parsing date_in: $e");
          }
          _carDateInController.text =
              ''; // Default empty value if parsing fails
        }
      } else {
        _carDateInController.text = ''; // Default empty value if not available
      }

      // Similarly format date_out and time_out
      if (data['date_out'] != null && data['time_out'] != null) {
        String dateTimeStrOut = '${data['date_out']} ${data['time_out']}';
        try {
          // Try parsing with a custom format
          DateTime dateTimeOut =
              DateFormat('yyyy-MM-dd HH:mm').parse(dateTimeStrOut);
          _carDateOutController.text = DateFormat('dd-MM-yyyy HH:mm')
              .format(dateTimeOut); // Only the date part in dd-MM-yyyy format
        } catch (e) {
          // If parsing fails, handle gracefully
          if (kDebugMode) {
            print("Error parsing date_out: $e");
          }
          _carDateOutController.text =
              ''; // Default empty value if parsing fails
        }
      } else {
        _carDateOutController.text = ''; // Default empty value if not available
      }
    });
  }

  /// Populates minutes of meeting data into controllers
  void _populateMinutesOfMeetingData(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('Populating minutes of meeting data: $data');
    }

    setState(() {
      _minutesOfMeetingTitleController.text = data['title'] ?? '';

      // Convert fromdate and todate to display format
      if (data['fromdate'] != null) {
        try {
          DateTime fromDate = DateTime.parse(data['fromdate']);
          _minutesOfMeetingFromController.text =
              DateFormat('dd-MM-yyyy').format(fromDate);
        } catch (e) {
          _minutesOfMeetingFromController.text = data['fromdate'] ?? '';
        }
      }

      if (data['todate'] != null) {
        try {
          DateTime toDate = DateTime.parse(data['todate']);
          _minutesOfMeetingToController.text =
              DateFormat('dd-MM-yyyy').format(toDate);
        } catch (e) {
          _minutesOfMeetingToController.text = data['todate'] ?? '';
        }
      }

      _minutesOfMeetingDescriptionController.text = data['description'] ?? '';
      _minutesOfMeetingLocationController.text = data['location'] ?? '';

      // Load meeting guests if available
      if (data['guests'] != null && data['guests'] is List) {
        List<dynamic> guests = data['guests'];

        if (kDebugMode) {
          print('Guest data received: $guests');
        }

        _selectedMembers = guests.map<Map<String, dynamic>>((guest) {
          // Handle different formats of guest data
          if (guest is Map) {
            return {
              'employee_id': guest['value'] ?? guest['employee_id'] ?? '',
              'employee_name':
                  guest['name'] ?? guest['employee_name'] ?? 'Unknown',
              'img_name': guest['img_name'] ?? guest['img'] ?? '',
            };
          } else {
            return {
              'employee_id': '',
              'employee_name': 'Unknown Format',
              'img_name': '',
            };
          }
        }).toList();

        if (kDebugMode) {
          print('Formatted members: $_selectedMembers');
        }
      } else {
        _selectedMembers = [];
      }
    });
  }

  /// Validates the input fields based on the event type
  bool _validateFields() {
    switch (widget.type.toLowerCase()) {
      case 'leave':
        if (_selectedLeaveTypeId == null) {
          _showErrorMessage('Please select a leave type.');
          return false;
        }
        break;
      case 'meeting':
        if (_meetingTitleController.text.isEmpty) {
          _showErrorMessage('Please enter a title for the meeting.');
          return false;
        }
        if (_selectedRoomId == null) {
          _showErrorMessage('Please select a room.');
          return false;
        }
        break;
      case 'car':
        // No required validations for car
        break;
      case 'minutes_of_meeting':
        if (_minutesOfMeetingTitleController.text.isEmpty) {
          _showErrorMessage('Please enter a title for the meeting.');
          return false;
        }
        break;
      default:
        _showErrorMessage('Invalid event type selected.');
        return false;
    }

    return true;
  }

  /// Shows error message using SnackBar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Shows success message using SnackBar
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// A reusable input field with consistent styling
  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isRequired = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: screenSize.width * 0.035,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            if (isRequired)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: screenSize.width * 0.035,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
          ],
        ),
        SizedBox(height: screenSize.height * 0.008),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          maxLines: maxLines,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontSize: screenSize.width * 0.033,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDarkMode ? Colors.grey[400] : Colors.grey[500],
              fontSize: screenSize.width * 0.033,
            ),
            contentPadding: EdgeInsets.symmetric(
              vertical: screenSize.height * 0.015,
              horizontal: screenSize.width * 0.04,
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenSize.width * 0.025),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenSize.width * 0.025),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(screenSize.width * 0.025),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.amber[700]! : Colors.amber,
                width: 1.5,
              ),
            ),
            prefixIcon: prefixIcon != null
                ? Icon(
                    prefixIcon,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    size: screenSize.width * 0.045,
                  )
                : null,
            suffixIcon: suffixIcon,
          ),
        ),
        SizedBox(height: screenSize.height * 0.015),
      ],
    );
  }

  /// Builds the leave form
  Widget _buildLeaveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave Type Label and Dropdown
        _buildStyledTextField(
          controller: _leaveFromController,
          label: AppLocalizations.of(context)!.leaveType,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // From Date Label and Picker
        _buildStyledTextField(
          controller: _leaveFromController,
          label: AppLocalizations.of(context)!.fromDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // To Date Label and Picker
        _buildStyledTextField(
          controller: _leaveFromController,
          label: AppLocalizations.of(context)!.toDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // Reason Label and Input
        _buildStyledTextField(
          controller: _leaveReasonController,
          label: 'Reason',
          isRequired: true,
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Days Label and Input (Read Only)
        _buildStyledTextField(
          controller: _leaveDaysController,
          label: AppLocalizations.of(context)!.days,
          readOnly: true,
        ),
      ],
    );
  }

  /// Builds the meeting form
  Widget _buildMeetingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Label and Input
        _buildStyledTextField(
          controller: _meetingTitleController,
          label: AppLocalizations.of(context)!.title,
          isRequired: true,
        ),
        const SizedBox(height: 16.0),
        // From Date Label and Picker
        _buildStyledTextField(
          controller: _meetingFromController,
          label: AppLocalizations.of(context)!.fromDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // To Date Label and Picker
        _buildStyledTextField(
          controller: _meetingToController,
          label: AppLocalizations.of(context)!.toDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // Room Label and Dropdown
        _buildStyledTextField(
          controller: TextEditingController(text: _getSelectedRoomName()),
          label: AppLocalizations.of(context)!.room,
          isRequired: true,
          prefixIcon: Icons.room,
          readOnly: true,
          onTap: () => _showRoomPicker(),
        ),
        const SizedBox(height: 16.0),
        // Employee Telephone Label and Input
        _buildStyledTextField(
          controller: _meetingTelController,
          label: AppLocalizations.of(context)!.employeeTelephone,
          isRequired: true,
          prefixIcon: Icons.phone,
        ),
        const SizedBox(height: 16.0),
        // Remark Label and Input
        _buildStyledTextField(
          controller: _meetingRemarkController,
          label: AppLocalizations.of(context)!.remarkLabel,
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  /// Builds the car form
  Widget _buildCarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStyledTextField(
          controller: _carEmployeeIDController,
          label: AppLocalizations.of(context)!.employeeId,
          readOnly: true,
        ),
        const SizedBox(height: 12.0),
        // Purpose Label and Input (Corrected)
        _buildStyledTextField(
          controller: _carPurposeController,
          label: AppLocalizations.of(context)!.purposeLabel,
          isRequired: true,
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Place Label and Input (Removed redundant label)
        _buildStyledTextField(
          controller: _carPlaceController,
          label: AppLocalizations.of(context)!.placeLabel,
          isRequired: true,
        ),
        const SizedBox(height: 16.0),
        // Date In Label and Picker
        _buildStyledTextField(
          controller: _carDateInController,
          label: AppLocalizations.of(context)!.dateInLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),
        // Date Out Label and Picker
        _buildStyledTextField(
          controller: _carDateOutController,
          label: AppLocalizations.of(context)!.dateOutLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
      ],
    );
  }

  /// Builds the minutes of meeting form
  Widget _buildMinutesOfMeetingForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Label and Input
        _buildStyledTextField(
          controller: _minutesOfMeetingTitleController,
          label: AppLocalizations.of(context)!.title,
          isRequired: true,
        ),
        const SizedBox(height: 16.0),

        // From Date Label and Picker
        _buildStyledTextField(
          controller: _minutesOfMeetingFromController,
          label: AppLocalizations.of(context)!.fromDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),

        // To Date Label and Picker
        _buildStyledTextField(
          controller: _minutesOfMeetingToController,
          label: AppLocalizations.of(context)!.toDateLabel,
          isRequired: true,
          prefixIcon: Icons.calendar_today,
        ),
        const SizedBox(height: 16.0),

        // Description Label and Input
        _buildStyledTextField(
          controller: _minutesOfMeetingDescriptionController,
          label: AppLocalizations.of(context)!.description,
          maxLines: 3,
        ),
        const SizedBox(height: 20.0),

        // Meeting Members Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Meeting Members',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.0,
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditEventMembersPage(
                      id: widget.id,
                      type: widget.type,
                    ),
                  ),
                );

                if (result != null && result is List<Map<String, dynamic>>) {
                  setState(() {
                    _selectedMembers = result;
                  });
                }
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Members'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10.0),

        // Display current members
        if (_selectedMembers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No members added yet'),
          )
        else
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: _selectedMembers.map((member) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundImage: member['img_name'] != null &&
                                    member['img_name'].isNotEmpty
                                ? NetworkImage(member['img_name'])
                                : const AssetImage(
                                        'assets/avatar_placeholder.png')
                                    as ImageProvider,
                          ),
                          const SizedBox(width: 8.0),
                          Flexible(
                            child: Text(
                              member['employee_name'] ?? 'Unknown',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.0),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Builds the form fields based on event type
  Widget _buildFormFields() {
    switch (widget.type.toLowerCase()) {
      case 'leave':
        return _buildLeaveForm();
      case 'meeting':
        return _buildMeetingForm();
      case 'car':
        return _buildCarForm();
      case 'minutes_of_meeting':
        return _buildMinutesOfMeetingForm();
      default:
        return Center(
            child: Text(AppLocalizations.of(context)!.unknownEventType));
    }
  }

  /// Builds the edit button
  Widget _buildUpdateButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    return SizedBox(
      width: screenSize.width * 0.6, // 60% of screen width
      height: screenSize.height * 0.05, // 5% of screen height

      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitEdit,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDarkMode ? Colors.orange : const Color(0xFFDBB342),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: screenSize.height * 0.012,
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Updating...',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: screenSize.width * 0.035,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.save,
                    color: Colors.white,
                    size: screenSize.width * 0.05,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.updateLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: screenSize.width * 0.035,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Submits the edited event
  Future<void> _submitEdit() async {
    if (!_validateFields()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String token = await _fetchToken();
      String url = '';
      Map<String, dynamic> body = {};

      switch (widget.type.toLowerCase()) {
        case 'leave':
          url = '$baseUrl/api/leave_request/${widget.id}';
          body = {
            "take_leave_type_id": _selectedLeaveTypeId,
            "take_leave_from": _leaveFromController.text,
            "take_leave_to": _leaveToController.text,
            "take_leave_reason": _leaveReasonController.text,
            "days": _leaveDaysController.text,
          };
          break;
        case 'meeting':
          url =
              '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';
          body = {
            "room_id": _selectedRoomId,
            "title": _meetingTitleController.text,
            "from_date_time": _meetingFromController.text,
            "to_date_time": _meetingToController.text,
            "employee_tel": _meetingTelController.text,
            "remark": _meetingRemarkController.text,
            "members": _selectedMembers.isNotEmpty
                ? _selectedMembers
                    .map((member) => {"employee_id": member['employee_id']})
                    .toList()
                : [],
          };
          break;
        case 'car':
          url = '$baseUrl/api/office-administration/car_permit/${widget.id}';
          body = {
            "employee_id": _employeeId,
            "purpose": _carPurposeController.text.isNotEmpty
                ? _carPurposeController.text
                : null,
            "place": _carPlaceController.text.isNotEmpty
                ? _carPlaceController.text
                : null,
            "date_in": _carDateInController.text.isNotEmpty
                ? _carDateInController.text
                : null,
            "date_out": _carDateOutController.text.isNotEmpty
                ? _carDateOutController.text
                : null,
            "permit_branch": "0", // Always send "0"
            "members": _selectedMembers.isNotEmpty
                ? _selectedMembers
                    .map((member) => {"employee_id": member['employee_id']})
                    .toList()
                : [],
          };
          break;
        case 'minutes_of_meeting':
          url = '$baseUrl/api/work-tracking/out-meeting/update/${widget.id}';

          // Format dates to API format (yyyy-MM-dd)
          String fromDateFormatted;
          String toDateFormatted;
          try {
            // Parse from display format to DateTime
            DateTime fromDate = DateFormat('dd-MM-yyyy')
                .parse(_minutesOfMeetingFromController.text);
            DateTime toDate = DateFormat('dd-MM-yyyy')
                .parse(_minutesOfMeetingToController.text);

            // Format to API format
            fromDateFormatted = DateFormat('yyyy-MM-dd').format(fromDate);
            toDateFormatted = DateFormat('yyyy-MM-dd').format(toDate);
          } catch (e) {
            // If dates can't be parsed, just use the text as is
            fromDateFormatted = _minutesOfMeetingFromController.text;
            toDateFormatted = _minutesOfMeetingToController.text;
          }

          // Debug the selectedMembers list
          if (kDebugMode) {
            print('Selected members for MoM submission: $_selectedMembers');
          }

          // Format guests data for minutes of meeting
          final List<Map<String, dynamic>> formattedGuests =
              _selectedMembers.map((member) {
            return {
              "value": member['employee_id'],
              "name": member['employee_name'] ?? member['name'] ?? 'Unknown',
              "img_name": member['img_name'] ?? member['img'] ?? ''
            };
          }).toList();

          body = {
            "title": _minutesOfMeetingTitleController.text,
            "description": _minutesOfMeetingDescriptionController.text,
            "fromdate": fromDateFormatted,
            "todate": toDateFormatted,
            "status": "public", // Use default public status
            "guests": formattedGuests
          };

          if (kDebugMode) {
            print('Formatted guests data: $formattedGuests');
          }
          break;
        default:
          throw Exception('Invalid event type');
      }

      // Remove null values to prevent sending unchanged data
      body.removeWhere((key, value) => value == null);

      if (kDebugMode) {
        print('Submitting Edit with URL: $url');
        print('Edit Body: $body');
      }

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('Edit Response Status Code: ${response.statusCode}');
        print('Edit Response Body: ${response.body}');
      }

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202) {
        _showSuccessMessage('Event updated successfully!');
        Navigator.pop(context, true); // Indicate success
      } else {
        String errorMsg = 'Failed to update event.';
        if (response.body.isNotEmpty) {
          try {
            final errorResponse = jsonDecode(response.body);

            // Include 'title' in the error message if present
            final title = errorResponse['title'] ?? '';
            final message = errorResponse['message'] ?? 'Please try again.';

            errorMsg = title.isNotEmpty
                ? '$title\n$message'
                : 'Failed to update event: $message';
          } catch (_) {
            // If response is not JSON, keep the default error message
          }
        }
        _showErrorMessage(errorMsg);
      }
    } catch (e) {
      _showErrorMessage('Error: $e');
      if (kDebugMode) {
        print('Error submitting edit: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Returns a display name for the event type
  String _getEventTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'meeting':
        return 'Meeting Room Booking';
      case 'leave':
        return 'Leave Request';
      case 'car':
        return 'Car Booking';
      case 'minutes_of_meeting':
        return 'Minutes of Meeting';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;

    // Determine form based on type
    return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.editOfficeEvent,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: screenSize.width * 0.05,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: screenSize.height * 0.1,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                    isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30.0),
                bottomRight: Radius.circular(30.0),
              ),
            ),
          ),
          iconTheme:
              IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
        ),
        body: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Saving changes...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 16.0),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenSize.width * 0.04,
                        vertical: screenSize.height * 0.02,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Event Type Badge
                          Center(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: screenSize.width * 0.04,
                                vertical: screenSize.height * 0.01,
                              ),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.blue[900]
                                    : Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _getEventTypeDisplay(widget.type),
                                style: TextStyle(
                                  fontSize: screenSize.width * 0.035,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.blue[800],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: screenSize.height * 0.02),

                          // Update Button - Top position for easier access
                          Align(
                            alignment: Alignment.center,
                            child: _buildUpdateButton(),
                          ),

                          SizedBox(height: screenSize.height * 0.02),

                          // Form content in a card for better visual
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: isDarkMode ? Colors.grey[850] : Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(screenSize.width * 0.04),
                              child: Form(
                                child: _buildFormFields(),
                              ),
                            ),
                          ),

                          // Bottom padding
                          SizedBox(height: screenSize.height * 0.05),
                        ],
                      ),
                    ),
                  ));
  }

  /// Selects a date and updates the controller
  Future<void> _selectDate(BuildContext context,
      TextEditingController dateController, bool isStartDate) async {
    final DateTime currentDate = DateTime.now();
    final DateTime initialDate = isStartDate
        ? (_startDateTime ?? currentDate)
        : (_endDateTime ?? currentDate);
    final DateTime firstDate = currentDate.subtract(const Duration(days: 365));
    final DateTime lastDate = currentDate.add(const Duration(days: 365 * 5));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
      );

      if (pickedTime != null) {
        final DateTime pickedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          pickedTime.hour,
          pickedTime.minute,
        );

        setState(() {
          if (isStartDate) {
            _startDateTime = pickedDateTime;
            _beforeEndDateTime.value =
                _startDateTime!.add(const Duration(hours: 1));
            // Ensure end date/time is after start date/time
            if (_endDateTime != null &&
                _endDateTime!.isBefore(_startDateTime!)) {
              _endDateTime = _startDateTime!.add(const Duration(hours: 1));
              _carDateOutController.text =
                  DateFormat('yyyy-MM-dd HH:mm').format(_endDateTime!);
            }
          } else {
            _endDateTime = pickedDateTime;
          }

          dateController.text =
              DateFormat('yyyy-MM-dd HH:mm').format(pickedDateTime);
        });
      }
    }
  }

  /// Select date-only picker for minutes of meeting (no time needed)
  Future<void> _selectDateOnly(
      BuildContext context, TextEditingController dateController) async {
    final DateTime currentDate = DateTime.now();
    DateTime initialDate;

    // Try to parse the existing date
    try {
      initialDate = DateFormat('dd-MM-yyyy').parse(dateController.text);
    } catch (e) {
      initialDate = currentDate;
    }

    final DateTime firstDate = currentDate.subtract(const Duration(days: 365));
    final DateTime lastDate = currentDate.add(const Duration(days: 365 * 5));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (pickedDate != null) {
      setState(() {
        // Format for display (dd-MM-yyyy)
        dateController.text = DateFormat('dd-MM-yyyy').format(pickedDate);
      });
    }
  }

  /// Gets the name of the selected room
  String _getSelectedRoomName() {
    if (_selectedRoomId == null) return '';

    final selectedRoom = _rooms.firstWhere(
      (room) => room['room_id'].toString() == _selectedRoomId,
      orElse: () => {'room_name': ''},
    );

    return selectedRoom['room_name'] ?? '';
  }

  /// Shows a dialog to pick a room
  void _showRoomPicker() {
    final Set<String> uniqueRoomIds = {}; // Set to store unique IDs
    final uniqueRooms = _rooms.where((room) {
      final roomId = room['room_id'].toString();
      if (uniqueRoomIds.contains(roomId)) {
        return false; // Skip if already added
      } else {
        uniqueRoomIds.add(roomId); // Add to Set if not added
        return true; // Include in the list
      }
    }).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.room),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: uniqueRooms.length,
            itemBuilder: (context, index) {
              final room = uniqueRooms[index];
              return ListTile(
                title: Text(room['room_name']?.isNotEmpty == true
                    ? room['room_name']
                    : AppLocalizations.of(context)!.unknownRoom),
                onTap: () {
                  setState(() {
                    _selectedRoomId = room['room_id'].toString();
                  });
                  Navigator.pop(context);
                },
                selected: _selectedRoomId == room['room_id'].toString(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
        ],
      ),
    );
  }
}
