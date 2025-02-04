// office_booking_event_edit_page.dart

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
  final String type; // 'leave', 'meeting', 'car'

  const OfficeBookingEventEditPage({
    super.key,
    required this.id,
    required this.type,
  });

  @override
  OfficeBookingEventEditPageState createState() => OfficeBookingEventEditPageState();
}

class OfficeBookingEventEditPageState extends State<OfficeBookingEventEditPage> {
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

  final ValueNotifier<DateTime?> _beforeEndDateTime = ValueNotifier<DateTime?>(null);
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
  final TextEditingController _meetingRemarkController = TextEditingController();

  // Controllers for Car
  final TextEditingController _carEmployeeIDController = TextEditingController();
  final TextEditingController _carPurposeController = TextEditingController();
  final TextEditingController _carPlaceController = TextEditingController();
  final TextEditingController _carDateInController = TextEditingController();
  final TextEditingController _carDateOutController = TextEditingController();

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
          url = '$baseUrl/api/office-administration/book_meeting_room/waiting/${widget.id}';
          break;
        case 'car':
          url = '$baseUrl/api/office-administration/car_permit/${widget.id}';
          break;
        default:
          throw Exception('Invalid event type');
      }

      if (kDebugMode) {
        print('Fetching event details from URL: $url');
      }

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
        throw Exception('Failed to load event details: ${response.statusCode}');
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
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(data['take_leave_from']))
          : '';
      _leaveToController.text = data['take_leave_to'] != null
          ? DateFormat('dd-MM-yyyy').format(DateTime.parse(data['take_leave_to']))
          : '';

      _leaveReasonController.text = data['take_leave_reason'] ?? '';
      _leaveDaysController.text = data['days']?.toString() ?? '';
    });
  }

  /// Populates meeting data into controllers
  void _populateMeetingData(Map<String, dynamic> data) {
    setState(() {
      _meetingTitleController.text = data['title'] ?? '';
      _meetingFromController.text = data['from_date_time'] != null ? DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(data['from_date_time'])) : '';
      _meetingToController.text = data['to_date_time'] != null ? DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(data['to_date_time'])) : '';
      _selectedRoomId = data['room_id']?.toString();
      _meetingTelController.text = data['employee_tel'] ?? '';
      _meetingRemarkController.text = data['remark'] ?? '';

      _selectedMembers = List<Map<String, dynamic>>.from(data['members']?.map((member) => {
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
          DateTime dateTimeIn = DateFormat('yyyy-MM-dd HH:mm').parse(dateTimeStr);
          _carDateInController.text = DateFormat('dd-MM-yyyy HH:mm').format(dateTimeIn);  // Only the date part in dd-MM-yyyy format
        } catch (e) {
          // If parsing fails, handle gracefully
          print("Error parsing date_in: $e");
          _carDateInController.text = '';  // Default empty value if parsing fails
        }
      } else {
        _carDateInController.text = '';  // Default empty value if not available
      }

      // Similarly format date_out and time_out
      if (data['date_out'] != null && data['time_out'] != null) {
        String dateTimeStrOut = '${data['date_out']} ${data['time_out']}';
        try {
          // Try parsing with a custom format
          DateTime dateTimeOut = DateFormat('yyyy-MM-dd HH:mm').parse(dateTimeStrOut);
          _carDateOutController.text = DateFormat('dd-MM-yyyy HH:mm').format(dateTimeOut);  // Only the date part in dd-MM-yyyy format
        } catch (e) {
          // If parsing fails, handle gracefully
          print("Error parsing date_out: $e");
          _carDateOutController.text = '';  // Default empty value if parsing fails
        }
      } else {
        _carDateOutController.text = '';  // Default empty value if not available
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
        if (_leaveFromController.text.isEmpty || _leaveToController.text.isEmpty) {
          _showErrorMessage('Please select both From and To dates.');
          return false;
        }
        if (_leaveReasonController.text.isEmpty) {
          _showErrorMessage('Please provide a reason for leave.');
          return false;
        }
        if (_startDateTime != null && _endDateTime != null) {
          if (_endDateTime!.isBefore(_startDateTime!)) {
            _showErrorMessage('End date/time must be after start date/time.');
            return false;
          }
        }
        break;
      case 'meeting':
        if (_meetingTitleController.text.isEmpty) {
          _showErrorMessage('Please enter a title for the meeting.');
          return false;
        }
        if (_meetingFromController.text.isEmpty || _meetingToController.text.isEmpty) {
          _showErrorMessage('Please select both From and To dates.');
          return false;
        }
        if (_selectedRoomId == null) {
          _showErrorMessage('Please select a room.');
          return false;
        }
        if (_meetingTelController.text.isEmpty) {
          _showErrorMessage('Please enter the employee telephone number.');
          return false;
        }
        if (_startDateTime != null && _endDateTime != null) {
          if (_endDateTime!.isBefore(_startDateTime!)) {
            _showErrorMessage('End date/time must be after start date/time.');
            return false;
          }
        }
        break;
      case 'car':
        if (_carPurposeController.text.isEmpty || _carPlaceController.text.isEmpty || _carDateInController.text.isEmpty || _carDateOutController.text.isEmpty) {
          _showErrorMessage('Please fill all required fields for Car Booking.');
          return false;
        }
        if (_startDateTime != null && _endDateTime != null) {
          if (_endDateTime!.isBefore(_startDateTime!)) {
            _showErrorMessage('End date/time must be after start date/time.');
            return false;
          }
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

  /// Builds the leave form
  Widget _buildLeaveForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave Type Label and Dropdown
        Text('${AppLocalizations.of(context)!.leaveType}*'),
        const SizedBox(height: 8.0),
        DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          value: _leaveTypes.any((type) => type['leave_type_id'].toString() == _selectedLeaveTypeId) ? _selectedLeaveTypeId : null, // Ensure value is in the list
          items: _leaveTypes
              .map((leaveType) => DropdownMenuItem<String>(
                    value: leaveType['leave_type_id'].toString(),
                    child: Text(leaveType['name'] ?? AppLocalizations.of(context)!.unknownType),
                  ))
              .toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedLeaveTypeId = newValue;
            });
          },
          validator: (value) => value == null ? AppLocalizations.of(context)!.pleaseSelectLeaveType : null,
        ),
        const SizedBox(height: 16.0),
        // From Date Label and Picker
        Text('${AppLocalizations.of(context)!.fromDateLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _leaveFromController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _leaveFromController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // To Date Label and Picker
        Text('${AppLocalizations.of(context)!.toDateLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _leaveFromController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _leaveFromController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Reason Label and Input
        const Text('Reason*'),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _leaveReasonController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Days Label and Input (Read Only)
        const Text('Days'),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _leaveDaysController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          readOnly: true, // Make editable if days can be manually adjusted
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
        Text('${AppLocalizations.of(context)!.title}*'),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _meetingTitleController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
        const SizedBox(height: 16.0),
        // From Date Label and Picker
        Text('${AppLocalizations.of(context)!.fromDateLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _meetingFromController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _meetingFromController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // To Date Label and Picker
        Text('${AppLocalizations.of(context)!.toDateLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _meetingToController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _meetingToController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Room Label and Dropdown
        Text('${AppLocalizations.of(context)!.room}*'),
        const SizedBox(height: 8.0),
        DropdownButtonFormField<String>(
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          value: _rooms.any((room) => room['room_id'].toString() == _selectedRoomId) ? _selectedRoomId : null, // Ensure _selectedRoomId is valid
          items: _getUniqueRoomItems(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedRoomId = newValue;
            });
          },
          validator: (value) => value == null ? AppLocalizations.of(context)!.pleaseSelectRoomLabel : null,
        ),
        const SizedBox(height: 16.0),
        // Employee Telephone Label and Input
        Text('${AppLocalizations.of(context)!.employeeTelephone}*'),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _meetingTelController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16.0),
        // Remark Label and Input
        Text(AppLocalizations.of(context)!.remarkLabel),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _meetingRemarkController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),

      ],
    );
  }

  List<DropdownMenuItem<String>> _getUniqueRoomItems() {
    final Set<String> uniqueRoomIds = {}; // Set to store unique IDs
    return _rooms.where((room) {
      final roomId = room['room_id'].toString();
      if (uniqueRoomIds.contains(roomId)) {
        return false; // Skip if already added
      } else {
        uniqueRoomIds.add(roomId); // Add to Set if not added
        return true; // Include in the list
      }
    }).map((room) {
      return DropdownMenuItem<String>(
        value: room['room_id'].toString(),
        child: Text(room['room_name']?.isNotEmpty == true ? room['room_name'] : AppLocalizations.of(context)!.unknownRoom),
      );
    }).toList();
  }

  /// Builds the car form
  Widget _buildCarForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppLocalizations.of(context)!.employeeId),
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _carEmployeeIDController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          enabled: false,
        ),
        const SizedBox(height: 12.0),
        // Purpose Label and Input (Corrected)
        Text('${AppLocalizations.of(context)!.purposeLabel}*'),  // Updated label to "Purpose"
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _carPurposeController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16.0),
        // Place Label and Input (Removed redundant label)
        Text('${AppLocalizations.of(context)!.placeLabel}*'),  // Keep label as "Place"
        const SizedBox(height: 8.0),
        TextFormField(
          controller: _carPlaceController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
          ),
        ),
        const SizedBox(height: 16.0),
        // Date In Label and Picker
        Text('${AppLocalizations.of(context)!.dateInLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _carDateInController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _carDateInController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Date Out Label and Picker
        Text('${AppLocalizations.of(context)!.dateOutLabel}*'),
        const SizedBox(height: 8.0),
        GestureDetector(
          onTap: () => _selectDate(context, _carDateOutController, true),
          child: AbsorbPointer(
            child: TextFormField(
              controller: _carDateOutController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 10.0),
                suffixIcon: const Icon(Icons.calendar_today),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
              ),
            ),
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
      default:
        return Center(child: Text(AppLocalizations.of(context)!.unknownEventType));
    }
  }

  /// Builds the edit button
  Widget _buildUpdateButton() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return ElevatedButton(
      onPressed: _isLoading ? null : _submitEdit,
      style: ElevatedButton.styleFrom(
        backgroundColor: isDarkMode ? Colors.orange : const Color(0xFFDBB342),
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.0,
              ),
            )
          : Text(
              AppLocalizations.of(context)!.updateLabel,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 15.0,
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
          if (!_validateDateFormat(_leaveFromController.text, 'yyyy-MM-dd') ||
              !_validateDateFormat(_leaveToController.text, 'yyyy-MM-dd')) {
            _showErrorMessage('Please reselect your Date In and Date Out');
            return;
          }
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
          if (!_validateDateFormat(_meetingFromController.text, 'yyyy-MM-dd HH:mm') ||
              !_validateDateFormat(_meetingToController.text, 'yyyy-MM-dd HH:mm')) {
            _showErrorMessage('Please reselect your Date In and Date Out');
            return;
          }
          url = '$baseUrl/api/office-administration/book_meeting_room/${widget.id}';
          body = {
            "room_id": _selectedRoomId,
            "title": _meetingTitleController.text,
            "from_date_time": _meetingFromController.text,
            "to_date_time": _meetingToController.text,
            "employee_tel": _meetingTelController.text,
            "remark": _meetingRemarkController.text,
            "members": _selectedMembers.isNotEmpty
                ? _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList()
                : [],
          };
          break;
        case 'car':
          if (!_validateDateFormat(_carDateInController.text, 'yyyy-MM-dd HH:mm') ||
              !_validateDateFormat(_carDateOutController.text, 'yyyy-MM-dd HH:mm')) {
            _showErrorMessage('Please reselect your Date In and Date Out');
            return;
          }
          url = '$baseUrl/api/office-administration/car_permit/${widget.id}';
          body = {
            "employee_id": _employeeId,
            "purpose": _carPurposeController.text.isNotEmpty ? _carPurposeController.text : null,
            "place": _carPlaceController.text.isNotEmpty ? _carPlaceController.text : null,
            "date_in": _carDateInController.text.isNotEmpty ? _carDateInController.text : null,
            "date_out": _carDateOutController.text.isNotEmpty ? _carDateOutController.text : null,
            "permit_branch": "0", // Always send "0"
            "members": _selectedMembers.isNotEmpty
                ? _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList()
                : [],
          };
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

      if (response.statusCode == 200 || response.statusCode == 201) {
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

            errorMsg = title.isNotEmpty ? '$title\n$message' : 'Failed to update event: $message';
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

  bool _validateDateFormat(String date, String format) {
    try {
      final parsedDate = DateFormat(format).parseStrict(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Determine form based on type
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context)!.editOfficeEvent,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/ready_bg.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
        ),
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 16.0),
                  ),
                )
              : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  child: _buildUpdateButton(),
                ),
              ),
              const SizedBox(height: 10.0),

              // Form Fields
              Form(
                child: _buildFormFields(),
              ),

              // Edit Members Section
              if (widget.type.toLowerCase() == 'meeting' || widget.type.toLowerCase() == 'car')
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Add People Button
                      Container(
                        width: MediaQuery.of(context).size.width * 0.4,
                        child: ElevatedButton(
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
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Add People'),
                        ),
                      ),

                      const SizedBox(width: 30.0),

                      // Stacked Member Avatars aligned to the right
                      if (_selectedMembers.isNotEmpty)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              height: 40,
                              child: Stack(
                                children: [
                                  for (int i = 0; i < _selectedMembers.take(4).length; i++)
                                    Positioned(
                                      left: i * 25.0,
                                      child: CircleAvatar(
                                        backgroundImage: _selectedMembers[i]['img_name'].isNotEmpty
                                            ? NetworkImage(_selectedMembers[i]['img_name'])
                                            : const AssetImage('assets/avatar_placeholder.png')
                                        as ImageProvider,
                                        radius: 20,
                                      ),
                                    ),
                                  if (_selectedMembers.length > 4)
                                    Positioned(
                                      left: 4 * 25.0,
                                      child: CircleAvatar(
                                        backgroundColor: Colors.grey,
                                        radius: 20,
                                        child: Text(
                                          '+${_selectedMembers.length - 4}',
                                          style: const TextStyle(color: Colors.white),
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
                )
            ],
          ),
        ),
      )
    );
  }

  /// Selects a date and updates the controller
  Future<void> _selectDate(BuildContext context, TextEditingController dateController, bool isStartDate) async {
    final DateTime currentDate = DateTime.now();
    final DateTime initialDate = isStartDate ? (_startDateTime ?? currentDate) : (_endDateTime ?? currentDate);
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
            _beforeEndDateTime.value = _startDateTime!.add(const Duration(hours: 1));
            // Ensure end date/time is after start date/time
            if (_endDateTime != null && _endDateTime!.isBefore(_startDateTime!)) {
              _endDateTime = _startDateTime!.add(const Duration(hours: 1));
              _carDateOutController.text = DateFormat('yyyy-MM-dd HH:mm').format(_endDateTime!);
            }
          } else {
            _endDateTime = pickedDateTime;
          }

          dateController.text = DateFormat('yyyy-MM-dd HH:mm').format(pickedDateTime);
        });
      }
    }
  }

}
