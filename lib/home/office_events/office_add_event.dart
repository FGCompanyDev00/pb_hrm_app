// office_add_event.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'add_member_office_event.dart';
import 'package:intl/intl.dart';

class OfficeAddEventPage extends StatefulWidget {
  const OfficeAddEventPage({super.key});

  @override
  _OfficeAddEventPageState createState() => _OfficeAddEventPageState();
}

class _OfficeAddEventPageState extends State<OfficeAddEventPage> {
  // Booking type selected by the user
  String? _selectedBookingType;

  // Date and time variables
  DateTime? _startDateTime;
  DateTime? _endDateTime;

  // List of selected members
  List<Map<String, dynamic>> _selectedMembers = [];

  // Controllers for text fields
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController(); // For Type 1
  final _remarkController = TextEditingController(); // For Type 2
  final _employeeTelController = TextEditingController();
  final _purposeController = TextEditingController();
  final _placeController = TextEditingController();
  final _nameController = TextEditingController(); // For Booking Car

  // Loading state
  bool _isLoading = false;

  // Additional fields based on booking type
  String? _roomId;
  String? _roomName;
  int? _notification; // Notification time in minutes
  String? _location; // For Add Meeting and Meeting Type for Booking Meeting Room

  String? _employeeId; // Current user's employee ID

  // List of rooms
  List<Map<String, dynamic>> _rooms = [];

  // Location options for Add Meeting and Meeting Type for Booking Meeting Room
  final List<String> _locationOptions = ["Meeting at Local Office", "Meeting Online", "Deadline"];

  // Notification options
  final List<int> _notificationOptions = [5, 10, 30];

  @override
  void initState() {
    super.initState();
    _fetchEmployeeId();
    _fetchRooms();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _remarkController.dispose();
    _employeeTelController.dispose();
    _purposeController.dispose();
    _placeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Fetches the current user's employee ID from shared preferences
  Future<void> _fetchEmployeeId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getString('employee_id') ?? '';
    });
  }

  /// Fetches the authentication token from shared preferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    return token;
  }

  /// Fetches the list of rooms from the API
  Future<void> _fetchRooms() async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/office-administration/rooms'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['results'];
        setState(() {
          _rooms = data
              .map<Map<String, dynamic>>((item) => {
            'room_id': item['uid'],
            'room_name': item['room_name'],
          })
              .toList();
        });
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      _showErrorMessage('Error fetching rooms: $e');
    }
  }

  // Submits the event based on the selected booking type
  Future<void> _submitEvent() async {
    // Validate the fields before proceeding
    if (!_validateFields()) {
      return; // If validation fails, exit the function
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String token = await _fetchToken();
      String url = '';
      Map<String, dynamic> body = {};

      // Handle different booking types (type 1,2 and 3)
      if (_selectedBookingType == '1. Add Meeting') {
        // URL for Type 1
        url = 'https://demo-application-api.flexiflows.co/api/work-tracking/out-meeting/insert';

        // Determine status based on the presence of members
        String status = _selectedMembers.isEmpty ? 'private' : 'public';

        // Request body
        body = {
          "title": _titleController.text.trim(),
          "description": _descriptionController.text.trim(),
          "fromdate": formatDateTime(_startDateTime),
          "todate": formatDateTime(_endDateTime),
          "location": _location ?? '',
          "status": status,
          "notification": _notification ?? 5,
          "guests": _selectedMembers.map((member) {
            Map<String, dynamic> guest = {"value": member['employee_id']};
            if (member['employee_name'] != null) {
              guest['name'] = member['employee_name'];
            }
            return guest;
          }).toList(),
        };

        // Sending the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        // Handle the response
        if (response.statusCode == 200 || response.statusCode == 201) {
          _showSuccessMessage('Event added successfully!');
          _resetForm(); // Reset the form after successful submission
        } else {
          String errorMsg = 'Failed to add event.';
          if (response.body.isNotEmpty) {
            print('Error response body: ${response.body}');
            try {
              final errorResponse = jsonDecode(response.body);
              errorMsg = 'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}';
            } catch (e) {
              errorMsg = 'Failed to add event: Unable to parse error message.';
            }
          }
          _showErrorMessage(errorMsg);
        }
      } else if (_selectedBookingType == '2. Meeting and Booking Meeting Room') {
        // URL for Type 2
        url = 'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room';
        // Building the request body
        body = {
          "room_id": _roomId,
          "title": _titleController.text.trim(),
          "from_date_time": formatDateTime(_startDateTime),
          "to_date_time": formatDateTime(_endDateTime),
          "employee_tel": _employeeTelController.text.trim(),
          "remark": _remarkController.text.trim(),
          "meeting_type": _location ?? '',
          "notification": _notification ?? 5,
          "members": _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList(),
        };

        // Sending the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        // Handle the response
        if (response.statusCode == 200 || response.statusCode == 201) {
          _showSuccessMessage('Event added successfully!');
          _resetForm(); // Reset the form after successful submission
        } else {
          String errorMsg = 'Failed to add event.';
          if (response.body.isNotEmpty) {
            try {
              final errorResponse = jsonDecode(response.body);
              errorMsg = 'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}';
            } catch (_) {}
          }
          _showErrorMessage(errorMsg);
        }
      } else if (_selectedBookingType == '3. Booking Car') {
        // URL for Type 3
        url = 'https://demo-application-api.flexiflows.co/api/office-administration/car_permit';
        // Building the request body
        body = {
          "employee_id": _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
          "place": _placeController.text.trim(),
          "purpose": _purposeController.text.trim(),
          "date_in": formatDateTime(_startDateTime),
          "date_out": formatDateTime(_endDateTime),
          "notification": _notification ?? 5,
          "members": _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList(),
        };

        // Sending the POST request
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        );

        // Handle the response
        if (response.statusCode == 200 || response.statusCode == 201) {
          _showSuccessMessage('Event added successfully!');
          _resetForm(); // Reset the form after successful submission
        } else {
          String errorMsg = 'Failed to add event.';
          if (response.body.isNotEmpty) {
            try {
              final errorResponse = jsonDecode(response.body);
              errorMsg = 'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}';
            } catch (_) {}
          }
          _showErrorMessage(errorMsg);
        }
      } else {
        _showErrorMessage('Invalid booking type selected.');
      }
    } catch (e) {
      _showErrorMessage('An error occurred while submitting the event. Please try again.');
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  /// Formats DateTime to 'yyyy-MM-dd HH:mm:ss'
  String formatDateTime(DateTime? dateTime) {
    return dateTime != null ? DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime) : '';
  }

  /// Resets the form fields to default values
  void _resetForm() {
    setState(() {
      _selectedBookingType = null;
      _titleController.clear();
      _descriptionController.clear();
      _remarkController.clear();
      _employeeTelController.clear();
      _purposeController.clear();
      _placeController.clear();
      _nameController.clear();
      _startDateTime = null;
      _endDateTime = null;
      _selectedMembers = [];
      _roomId = null;
      _roomName = null;
      _location = null;
      _notification = null;
    });
  }

  /// Validates the input fields based on the selected booking type
  bool _validateFields() {
    if (_selectedBookingType == null) {
      _showErrorMessage('Please select a booking type.');
      return false;
    }
    if (_titleController.text.isEmpty) {
      _showErrorMessage('Please enter a title.');
      return false;
    }

    // Validation based on booking type
    switch (_selectedBookingType) {
      case '1. Add Meeting':
        if (_descriptionController.text.isEmpty) {
          _showErrorMessage('Please enter a description.');
          return false;
        }
        if (_location == null) {
          _showErrorMessage('Please select a location.');
          return false;
        }
        if (_notification == null) {
          _showErrorMessage('Please select a notification time.');
          return false;
        }
        // For Type 1, selecting members is optional
        break;

      case '2. Meeting and Booking Meeting Room':
        if (_remarkController.text.isEmpty) {
          _showErrorMessage('Please enter a description.');
          return false;
        }
        if (_roomId == null) {
          _showErrorMessage('Please select a meeting room.');
          return false;
        }
        if (_employeeTelController.text.isEmpty) {
          _showErrorMessage('Please enter your phone number.');
          return false;
        }
        if (_location == null) {
          _showErrorMessage('Please select a meeting type.');
          return false;
        }
        if (_notification == null) {
          _showErrorMessage('Please select a notification time.');
          return false;
        }
        // For Type 2, at least one member must be selected
        if (_selectedMembers.isEmpty) {
          _showErrorMessage('Please add at least one member.');
          return false;
        }
        break;

      case '3. Booking Car':
        if (_nameController.text.isEmpty) {
          _showErrorMessage('Please enter the name.');
          return false;
        }
        if (_placeController.text.isEmpty) {
          _showErrorMessage('Please enter the place.');
          return false;
        }
        if (_purposeController.text.isEmpty) {
          _showErrorMessage('Please enter the purpose.');
          return false;
        }
        if (_notification == null) {
          _showErrorMessage('Please select a notification time.');
          return false;
        }
        // For Type 3, at least one member must be selected
        if (_selectedMembers.isEmpty) {
          _showErrorMessage('Please add at least one member.');
          return false;
        }
        break;

      default:
        _showErrorMessage('Invalid booking type selected.');
        return false;
    }

    // Start and End Dates are required for all types
    if (_startDateTime == null || _endDateTime == null) {
      _showErrorMessage('Please select start and end dates.');
      return false;
    }

    // Additional validation to ensure start date is before end date
    if (_startDateTime != null && _endDateTime != null && _startDateTime!.isAfter(_endDateTime!)) {
      _showErrorMessage('Start date must be before end date.');
      return false;
    }

    return true; // All validations passed
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

  /// Shows date and time picker for selecting date and time
  Future<void> _selectDateTime(BuildContext context, bool isStartDateTime) async {
    final DateTime initialDate = isStartDateTime ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now());
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (pickedDate != null) {
      final TimeOfDay initialTime = TimeOfDay.fromDateTime(initialDate);
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (pickedTime != null) {
        setState(() {
          final DateTime pickedDateTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          if (isStartDateTime) {
            _startDateTime = pickedDateTime;
          } else {
            _endDateTime = pickedDateTime;
          }
        });
      }
    }
  }

  /// Shows the Add People page and gets the selected members
  Future<void> _showAddPeoplePage() async {
    final selectedMembers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddMemberPage(),
      ),
    );

    if (selectedMembers != null && selectedMembers.isNotEmpty) {
      setState(() {
        _selectedMembers = selectedMembers;
      });
    }
  }

  /// Shows the booking type modal
  void _showBookingTypeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1. Add Meeting'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '1. Add Meeting';
                    // Set default values for Type 1
                    _location = "Meeting at Local Office";
                    _notification = 5;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('2. Meeting and Booking Meeting Room'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '2. Meeting and Booking Meeting Room';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('3. Booking Car'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '3. Booking Car';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Selects a room (for booking type 2)
  Future<void> _selectRoom() async {
    if (_rooms.isEmpty) {
      _showErrorMessage('No rooms available');
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return SizedBox(
          height: 400,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select a Room',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return ListTile(
                      title: Text(room['room_name']),
                      onTap: () {
                        setState(() {
                          _roomId = room['room_id'];
                          _roomName = room['room_name'];
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows the notification time dropdown based on booking type
  Widget _buildNotificationDropdown() {
    return DropdownButtonFormField<int>(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      hint: const Text('Select Notification Time'),
      value: _notification,
      items: _notificationOptions
          .map((minutes) => DropdownMenuItem<int>(
        value: minutes,
        child: Text('Notify me $minutes min before'),
      ))
          .toList(),
      onChanged: (int? newValue) {
        setState(() {
          _notification = newValue;
        });
      },
    );
  }

  /// Shows the location or meeting type dropdown based on booking type
  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
        ),
      ),
      hint: const Text('Select Location / Meeting Type'),
      value: _location,
      items: _locationOptions
          .map((loc) => DropdownMenuItem<String>(
        value: loc,
        child: Text(loc),
      ))
          .toList(),
      onChanged: (String? newValue) {
        setState(() {
          _location = newValue;
        });
      },
    );
  }

  /// Builds the UI form fields based on the selected booking type
  Widget _buildFormFields() {
    if (_selectedBookingType == null) return Container();

    switch (_selectedBookingType) {
      case '1. Add Meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            const Text(
              'Title*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Description input
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Start and End Date & Time labels in same row
            const Row(
              children: [
                Expanded(
                  child: Text('Start Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Text('End Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            // Start and End Date & Time inputs in same row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, true),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_startDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_endDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Type of meeting text
            const Text(
              'Type of meeting*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 6.0),
            // Location dropdown
            _buildLocationDropdown(),
            const SizedBox(height: 12.0),
            _buildNotificationDropdown(),
            const SizedBox(height: 20.0),
            // Add People button
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _showAddPeoplePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  ),
                  child: const Text(
                    '+ Add People',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Display selected members
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: _selectedMembers.map((member) {
                  return FutureBuilder<String?>(
                    future: _fetchProfileImage(member['employee_id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: CircularProgressIndicator(),
                        );
                      } else if (snapshot.hasError) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.error),
                        );
                      } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(snapshot.data!),
                          radius: 24.0,
                        );
                      } else {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.person),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 20.0),
          ],
        );

      case '2. Meeting and Booking Meeting Room':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title input
            const Text(
              'Title*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Description input
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _remarkController,
              maxLines: 3,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Start and End Date & Time labels in same row
            const Row(
              children: [
                Expanded(
                  child: Text('Start Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Text('End Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            // Start and End Date & Time inputs in same row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, true),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_startDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_endDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Type of meeting text
            const Text(
              'Type of meeting*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            // Meeting type dropdown
            _buildLocationDropdown(),
            const SizedBox(height: 6.0),
            // Room ID Dropdown
            GestureDetector(
              onTap: _selectRoom,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_roomName ?? 'Select Room'),
                    const Icon(Icons.menu),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6.0),
            _buildNotificationDropdown(),
            const SizedBox(height: 20.0),
            // Add People button
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _showAddPeoplePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  ),
                  child: const Text(
                    '+ Add People',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Display selected members
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: _selectedMembers.map((member) {
                  return FutureBuilder<String?>(
                    future: _fetchProfileImage(member['employee_id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: CircularProgressIndicator(),
                        );
                      } else if (snapshot.hasError) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.error),
                        );
                      } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(snapshot.data!),
                          radius: 24.0,
                        );
                      } else {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.person),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 20.0),
          ],
        );

      case '3. Booking Car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name input
            const Text(
              'Name*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Place input
            const Text(
              'Place*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _placeController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Purpose input
            const Text(
              'Purpose*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
            ),
            const SizedBox(height: 4.0),
            TextField(
              controller: _purposeController,
              maxLines: 3,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 12.0),
            // Start and End Date & Time labels in same row
            const Row(
              children: [
                Expanded(
                  child: Text('Start Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
                SizedBox(width: 12.0),
                Expanded(
                  child: Text('End Date & Time*', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0)),
                ),
              ],
            ),
            const SizedBox(height: 4.0),
            // Start and End Date & Time inputs in same row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, true),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_startDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12.0),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _selectDateTime(context, false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endDateTime == null
                              ? 'dd/mm/yy'
                              : DateFormat('dd/MM/yy - HH:mm').format(_endDateTime!)),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            _buildNotificationDropdown(),
            const SizedBox(height: 20.0),
            // Add People button
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _showAddPeoplePage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  ),
                  child: const Text(
                    '+ Add People',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12.0),
            // Display selected members
            if (_selectedMembers.isNotEmpty)
              Wrap(
                spacing: 8.0,
                children: _selectedMembers.map((member) {
                  return FutureBuilder<String?>(
                    future: _fetchProfileImage(member['employee_id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: CircularProgressIndicator(),
                        );
                      } else if (snapshot.hasError) {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.error),
                        );
                      } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                        return CircleAvatar(
                          backgroundImage: NetworkImage(snapshot.data!),
                          radius: 24.0,
                        );
                      } else {
                        return const CircleAvatar(
                          radius: 24.0,
                          child: Icon(Icons.person),
                        );
                      }
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 20.0),
          ],
        );

      default:
        return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adjust padding based on screen size
    final double horizontalPadding = MediaQuery.of(context).size.width < 360 ? 16.0 : 14.0;
    final double verticalPadding = MediaQuery.of(context).size.height < 600 ? 10.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Office Event',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30.0),
              bottomRight: Radius.circular(30.0),
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
      ),
      body: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // '+' Add Button positioned at the top right
                  Align(
                    alignment: Alignment.topRight,
                    child: ElevatedButton(
                      onPressed: _submitEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE2AD30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 12.0),
                        elevation: 2.0,
                        shadowColor: Colors.grey.withOpacity(0.5),
                      ),
                      child: const Text(
                        '+ Add',
                        style: TextStyle(color: Colors.black, fontSize: 16.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Booking type selection
                  const Text(
                    'Type of Booking*',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.0),
                  ),
                  const SizedBox(height: 4.0),
                  GestureDetector(
                    onTap: () => _showBookingTypeModal(context),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedBookingType ?? 'Select Booking Type'),
                          const Icon(Icons.menu),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  // Display additional fields based on booking type
                  _buildFormFields(),
                ],
              ),
            ),
          ),
          // Loading indicator overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  /// Fetches profile image URL for a given employee ID
  Future<String?> _fetchProfileImage(String employeeId) async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['results']['images'] ?? '';
      } else {
        throw Exception('Failed to load profile image');
      }
    } catch (e) {
      throw Exception('Error fetching profile image: $e');
    }
  }
}
