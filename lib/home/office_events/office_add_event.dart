// office_add_event.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/office_events/add_member_office_event.dart';
import 'package:intl/intl.dart';

class OfficeAddEventPage extends StatefulWidget {
  const OfficeAddEventPage({Key? key}) : super(key: key);

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
  final _descriptionController = TextEditingController();

  // Loading state
  bool _isLoading = false;

  // Additional fields based on booking type
  String? _projectId;
  String? _statusId;
  String? _roomId;
  String? _roomName;
  String? _employeeTel;
  String? _purpose;
  String? _place;
  String? _employeeId; // Current user's employee ID

  // List of rooms
  List<Map<String, dynamic>> _rooms = [];

  // Lists for Projects and Statuses
  List<Project> _projects = [];

  // Hard-coded list of Statuses as per provided API data
  final List<Status> _statuses = [
    Status(
      id: 1,
      statusId: "87403916-9113-4e2e-9d7d-b5ed269fe20a",
      name: "Error",
    ),
    Status(
      id: 2,
      statusId: "40d2ba5e-a978-47ce-bc48-caceca8668e9",
      name: "Pending",
    ),
    Status(
      id: 3,
      statusId: "0a8d93f0-1c05-42b2-8e56-984a578ef077",
      name: "Processing",
    ),
    Status(
      id: 4,
      statusId: "e35569eb-75e1-4005-9232-bfb57303b8b3",
      name: "Finished",
    ),
  ];

  // Selected Project and Status
  Project? _selectedProject;
  Status? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeId();
    _fetchRooms();
    _fetchProjects();
    // No need to fetch statuses as they are hard-coded
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Fetch the current user's employee ID from shared preferences
  Future<void> _fetchEmployeeId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getString('employee_id') ?? '';
      print('Employee ID: $_employeeId'); // Debug statement
    });
  }

  // Fetch the authentication token from shared preferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    print('Fetched Token: $token'); // Debug statement
    return token;
  }

  // Fetch the list of rooms from the API
  Future<void> _fetchRooms() async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/office-administration/rooms'),
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
          print('Fetched Rooms: $_rooms'); // Debug statement
        });
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      _showErrorMessage('Error fetching rooms: $e');
    }
  }

  // Fetch the list of projects from the API
  Future<void> _fetchProjects() async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/work-tracking/proj/find-My-Project-list'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['result'];
        setState(() {
          _projects = data
              .map<Project>((item) => Project.fromJson(item))
              .toList();
          print('Fetched Projects: $_projects'); // Debug statement
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } catch (e) {
      _showErrorMessage('Error fetching projects: $e');
    }
  }

  // Submit the event based on the selected booking type
  Future<void> _submitEvent() async {
    if (_validateFields()) {
      setState(() {
        _isLoading = true;
      });

      String url = '';
      Map<String, dynamic> body = {};

      try {
        String token = await _fetchToken();

        // Build the request based on the selected booking type
        if (_selectedBookingType == '1. Add meeting') {
          url =
          'https://demo-application-api.flexiflows.co/api/work-tracking/meeting/insert';
          body = {
            "projects_id": _projectId, // Use the selected project's ID
            "title": _titleController.text,
            "description": _descriptionController.text,
            "status_id": _statusId, // Use the selected status's ID
            "from_date": _startDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDateTime!)
                : "",
            "to_date": _endDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDateTime!)
                : "",
            "start_time": _startDateTime != null
                ? DateFormat('HH:mm:ss').format(_startDateTime!)
                : "",
            "end_time": _endDateTime != null
                ? DateFormat('HH:mm:ss').format(_endDateTime!)
                : "",
            "file_name": "", // Handle file upload if needed
            "membersDetails": _selectedMembers
                .map((member) => {"employee_id": member['employee_id']})
                .toList(),
          };
          print('Submit Add Meeting Body: $body'); // Debug statement
        } else if (_selectedBookingType ==
            '2. Meeting and Booking meeting room') {
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room';
          body = {
            "room_id": _roomId,
            "title": _titleController.text,
            "from_date_time": _startDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDateTime!)
                : "",
            "to_date_time": _endDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDateTime!)
                : "",
            "employee_tel": _employeeTel,
            "remark": _descriptionController.text,
            "members": _selectedMembers
                .map((member) => {"employee_id": member['employee_id']})
                .toList(),
          };
          print('Submit Book Meeting Room Body: $body'); // Debug statement
        } else if (_selectedBookingType == '3. Booking car') {
          url =
          'https://demo-application-api.flexiflows.co/api/office-administration/car_permit';
          body = {
            "employee_id": _employeeId,
            "purpose": _purpose,
            "place": _place,
            "date_in": _startDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDateTime!)
                : "",
            "date_out": _endDateTime != null
                ? DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDateTime!)
                : "",
            "permit_branch": "3", // Ensure this is the correct value as per API
            "members": _selectedMembers
                .map((member) => {"employee_id": member['employee_id']})
                .toList(),
          };
          print('Submit Booking Car Body: $body'); // Debug statement
        } else {
          _showErrorMessage('Invalid booking type selected.');
          return;
        }

        // Send the POST request
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

          // Reset the form after successful submission
          _resetForm();
        } else {
          final errorResponse = jsonDecode(response.body);
          _showErrorMessage(
              'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}');
        }
      } catch (e) {
        _showErrorMessage('Error: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Reset the form fields to default values
  void _resetForm() {
    setState(() {
      _selectedBookingType = null;
      _titleController.clear();
      _descriptionController.clear();
      _startDateTime = null;
      _endDateTime = null;
      _selectedMembers = [];
      _projectId = null;
      _statusId = null;
      _roomId = null;
      _roomName = null;
      _employeeTel = null;
      _purpose = null;
      _place = null;
      _selectedProject = null;
      _selectedStatus = null;
    });
  }

  // Validate the input fields
  bool _validateFields() {
    if (_selectedBookingType == null) {
      _showErrorMessage('Please select a booking type.');
      return false;
    }
    if (_titleController.text.isEmpty) {
      _showErrorMessage('Please enter a title.');
      return false;
    }
    if (_startDateTime == null || _endDateTime == null) {
      _showErrorMessage('Please select start and end dates.');
      return false;
    }
    if (_selectedMembers.isEmpty) {
      _showErrorMessage('Please add at least one member.');
      return false;
    }
    if (_selectedBookingType == '1. Add meeting') {
      if (_projectId == null || _projectId!.isEmpty) {
        _showErrorMessage('Please select a project.');
        return false;
      }
      if (_statusId == null || _statusId!.isEmpty) {
        _showErrorMessage('Please select a status.');
        return false;
      }
    }
    if (_selectedBookingType == '2. Meeting and Booking meeting room') {
      if (_roomId == null || _roomId!.isEmpty) {
        _showErrorMessage('Please select a room.');
        return false;
      }
      if (_employeeTel == null || _employeeTel!.isEmpty) {
        _showErrorMessage('Please enter your phone number.');
        return false;
      }
    }
    if (_selectedBookingType == '3. Booking car') {
      if (_purpose == null || _purpose!.isEmpty) {
        _showErrorMessage('Please enter the purpose.');
        return false;
      }
      if (_place == null || _place!.isEmpty) {
        _showErrorMessage('Please enter the place.');
        return false;
      }
    }
    // Additional validation to ensure start date is before end date
    if (_startDateTime != null &&
        _endDateTime != null &&
        _startDateTime!.isAfter(_endDateTime!)) {
      _showErrorMessage('Start date must be before end date.');
      return false;
    }
    return true;
  }

  // Show error message using SnackBar
  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Show success message using SnackBar
  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
        Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show date picker for selecting date
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initialDate = isStartDate
        ? (_startDateTime ?? DateTime.now())
        : (_endDateTime ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      final TimeOfDay initialTime = TimeOfDay.fromDateTime(
          isStartDate ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now()));
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );
      if (time != null) {
        setState(() {
          final selectedDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
          if (isStartDate) {
            _startDateTime = selectedDateTime;
            print('Start DateTime: $_startDateTime'); // Debug statement
          } else {
            _endDateTime = selectedDateTime;
            print('End DateTime: $_endDateTime'); // Debug statement
          }
        });
      }
    }
  }

  // Show time picker for selecting time
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay initialTime = TimeOfDay.fromDateTime(
        isStartTime ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now()));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startDateTime = DateTime(
            _startDateTime?.year ?? DateTime.now().year,
            _startDateTime?.month ?? DateTime.now().month,
            _startDateTime?.day ?? DateTime.now().day,
            picked.hour,
            picked.minute,
          );
          print('Start Time: $_startDateTime'); // Debug statement
        } else {
          _endDateTime = DateTime(
            _endDateTime?.year ?? DateTime.now().year,
            _endDateTime?.month ?? DateTime.now().month,
            _endDateTime?.day ?? DateTime.now().day,
            picked.hour,
            picked.minute,
          );
          print('End Time: $_endDateTime'); // Debug statement
        }
      });
    }
  }

  // Show the Add Member page and get the selected members
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
        print('Selected Members: $_selectedMembers'); // Debug statement
      });
    }
  }

  // Show the booking type modal
  void _showBookingTypeModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) {
        return Container(
          padding:
          const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('1. Add meeting'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '1. Add meeting';
                    print('Selected Booking Type: $_selectedBookingType'); // Debug statement
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text(
                    '2. Meeting and Booking meeting room'),
                onTap: () {
                  setState(() {
                    _selectedBookingType =
                    '2. Meeting and Booking meeting room';
                    print('Selected Booking Type: $_selectedBookingType'); // Debug statement
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('3. Booking car'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '3. Booking car';
                    print('Selected Booking Type: $_selectedBookingType'); // Debug statement
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

  // Select a room (for booking type 2)
  Future<void> _selectRoom() async {
    if (_rooms.isEmpty) {
      _showErrorMessage('No rooms available');
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          height: 400,
          child: Column(
            children: [
              Padding(
                padding:
                const EdgeInsets.all(16.0),
                child: Text(
                  'Select a Room',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold),
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
                          print('Selected Room: $_roomName'); // Debug statement
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

  // Fetch profile image for a given employee ID
  Future<String> _fetchProfileImage(
      String employeeId) async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/profile/$employeeId'),
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

  @override
  Widget build(BuildContext context) {
    // Build the UI
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              // Header section with background image and title
              Stack(
                children: [
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image:
                        AssetImage('assets/background.png'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft:
                        Radius.circular(30.0),
                        bottomRight:
                        Radius.circular(30.0),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 70.0,
                    left: 16.0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.black),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  const Positioned(
                    top: 80.0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'Office',
                        style: TextStyle(
                          fontSize: 24.0,
                          fontWeight:
                          FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 30.0,
                      vertical: 20.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // Booking type selection
                        const Text(
                          'Type of Booking*',
                          style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 16.0),
                        ),
                        const SizedBox(height: 8.0),
                        GestureDetector(
                          onTap: () =>
                              _showBookingTypeModal(
                                  context),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(
                                  10.0),
                              border: Border.all(
                                  color: Colors.grey),
                            ),
                            padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16.0),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,
                              children: [
                                Text(_selectedBookingType ??
                                    'Select Booking Type'),
                                const Icon(Icons.menu),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        // Title input
                        const Text(
                          'Title*',
                          style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 16.0),
                        ),
                        const SizedBox(height: 8.0),
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16.0),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  10.0),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        // Description input (optional)
                        const Text(
                          'Description (Optional)',
                          style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                              fontSize: 16.0),
                        ),
                        const SizedBox(height: 8.0),
                        TextField(
                          controller:
                          _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 12.0,
                                vertical: 16.0),
                            border: OutlineInputBorder(
                              borderRadius:
                              BorderRadius.circular(
                                  10.0),
                            ),
                          ),
                        ),
                        // Additional fields based on booking type
                        if (_selectedBookingType ==
                            '1. Add meeting') ...[
                          const SizedBox(height: 16.0),
                          // Project Dropdown
                          const Text(
                            'Project*',
                            style: TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 16.0),
                          ),
                          const SizedBox(height: 8.0),
                          DropdownButtonFormField<Project>(
                            decoration: InputDecoration(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                              ),
                            ),
                            hint: const Text('Select Project'),
                            value: _selectedProject,
                            items: _projects
                                .map((project) => DropdownMenuItem<Project>(
                              value: project,
                              child: Text(project.pName),
                            ))
                                .toList(),
                            onChanged: (Project? newValue) {
                              setState(() {
                                _selectedProject = newValue;
                                _projectId = newValue?.projectId;
                                print('Selected Project ID: $_projectId'); // Debug statement
                              });
                            },
                          ),
                          const SizedBox(height: 16.0),
                          // Status Dropdown
                          const Text(
                            'Status*',
                            style: TextStyle(
                                fontWeight:
                                FontWeight.bold,
                                fontSize: 16.0),
                          ),
                          const SizedBox(height: 8.0),
                          DropdownButtonFormField<Status>(
                            decoration: InputDecoration(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                              ),
                            ),
                            hint: const Text('Select Status'),
                            value: _selectedStatus,
                            items: _statuses
                                .map((status) => DropdownMenuItem<Status>(
                              value: status,
                              child: Text(status.name),
                            ))
                                .toList(),
                            onChanged: (Status? newValue) {
                              setState(() {
                                _selectedStatus = newValue;
                                _statusId = newValue?.statusId;
                                print('Selected Status ID: $_statusId'); // Debug statement
                              });
                            },
                          ),
                        ],
                        if (_selectedBookingType ==
                            '2. Meeting and Booking meeting room') ...[
                          const SizedBox(height: 16.0),
                          const Text('Room*',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16.0)),
                          const SizedBox(height: 8.0),
                          GestureDetector(
                            onTap: _selectRoom,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                                border: Border.all(
                                    color: Colors.grey),
                              ),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Text(_roomName ??
                                      'Select Room'),
                                  const Icon(Icons.menu),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          const Text('Your Phone Number*',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16.0)),
                          const SizedBox(height: 8.0),
                          TextField(
                            onChanged: (value) =>
                            _employeeTel = value,
                            keyboardType:
                            TextInputType.phone,
                            decoration: InputDecoration(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                              ),
                            ),
                          ),
                        ],
                        if (_selectedBookingType ==
                            '3. Booking car') ...[
                          const SizedBox(height: 16.0),
                          const Text('Purpose*',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16.0)),
                          const SizedBox(height: 8.0),
                          TextField(
                            onChanged: (value) =>
                            _purpose = value,
                            decoration: InputDecoration(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16.0),
                          const Text('Place*',
                              style: TextStyle(
                                  fontWeight:
                                  FontWeight.bold,
                                  fontSize: 16.0)),
                          const SizedBox(height: 8.0),
                          TextField(
                            onChanged: (value) =>
                            _place = value,
                            decoration: InputDecoration(
                              contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: 12.0,
                                  vertical: 16.0),
                              border: OutlineInputBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    10.0),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16.0),
                        // Date and time pickers
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  const Text('Start Date',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize:
                                          16.0)),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: () =>
                                        _selectDate(
                                            context,
                                            true),
                                    child: Container(
                                      decoration:
                                      BoxDecoration(
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            10.0),
                                        border: Border.all(
                                            color:
                                            Colors.grey),
                                      ),
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                          12.0,
                                          vertical:
                                          16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(_startDateTime ==
                                              null
                                              ? 'Start Date'
                                              : DateFormat(
                                              'yyyy-MM-dd')
                                              .format(
                                              _startDateTime!)),
                                          const Icon(
                                              Icons
                                                  .calendar_today),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  const Text('Start Time',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize:
                                          16.0)),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: () =>
                                        _selectTime(
                                            context,
                                            true),
                                    child: Container(
                                      decoration:
                                      BoxDecoration(
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            10.0),
                                        border: Border.all(
                                            color:
                                            Colors.grey),
                                      ),
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                          12.0,
                                          vertical:
                                          16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(_startDateTime ==
                                              null
                                              ? 'Start Time'
                                              : TimeOfDay.fromDateTime(
                                              _startDateTime!)
                                              .format(
                                              context)),
                                          const Icon(
                                              Icons
                                                  .access_time),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26.0),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  const Text('End Date',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize:
                                          16.0)),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: () =>
                                        _selectDate(
                                            context,
                                            false),
                                    child: Container(
                                      decoration:
                                      BoxDecoration(
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            10.0),
                                        border: Border.all(
                                            color:
                                            Colors.grey),
                                      ),
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                          12.0,
                                          vertical:
                                          16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(_endDateTime ==
                                              null
                                              ? 'End Date'
                                              : DateFormat(
                                              'yyyy-MM-dd')
                                              .format(
                                              _endDateTime!)),
                                          const Icon(
                                              Icons
                                                  .calendar_today),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20.0),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  const Text('End Time',
                                      style: TextStyle(
                                          fontWeight:
                                          FontWeight
                                              .bold,
                                          fontSize:
                                          16.0)),
                                  const SizedBox(height: 8.0),
                                  GestureDetector(
                                    onTap: () =>
                                        _selectTime(
                                            context,
                                            false),
                                    child: Container(
                                      decoration:
                                      BoxDecoration(
                                        borderRadius:
                                        BorderRadius
                                            .circular(
                                            10.0),
                                        border: Border.all(
                                            color:
                                            Colors.grey),
                                      ),
                                      padding:
                                      const EdgeInsets
                                          .symmetric(
                                          horizontal:
                                          12.0,
                                          vertical:
                                          16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                        MainAxisAlignment
                                            .spaceBetween,
                                        children: [
                                          Text(_endDateTime ==
                                              null
                                              ? 'End Time'
                                              : TimeOfDay.fromDateTime(
                                              _endDateTime!)
                                              .format(
                                              context)),
                                          const Icon(
                                              Icons
                                                  .access_time),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16.0),
                        // Add People button
                        Center(
                          child: ElevatedButton(
                            onPressed: _showAddPeoplePage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    20.0),
                              ),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 32.0,
                                  vertical: 12.0),
                            ),
                            child: const Text(
                              '+ Add People',
                              style: TextStyle(
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        // Display selected members
                        if (_selectedMembers.isNotEmpty)
                          Center(
                            child: Wrap(
                              spacing: 8.0,
                              children:
                              _selectedMembers.map((member) {
                                return FutureBuilder<String>(
                                  future: _fetchProfileImage(
                                      member['employee_id']),
                                  builder:
                                      (context, snapshot) {
                                    if (snapshot.connectionState ==
                                        ConnectionState
                                            .waiting) {
                                      return const CircleAvatar(
                                        radius: 24.0,
                                        child:
                                        CircularProgressIndicator(),
                                      );
                                    } else if (snapshot.hasError) {
                                      return const CircleAvatar(
                                        radius: 24.0,
                                        child:
                                        Icon(Icons.error),
                                      );
                                    } else if (snapshot.hasData &&
                                        snapshot.data != null &&
                                        snapshot.data!.isNotEmpty) {
                                      return CircleAvatar(
                                        backgroundImage:
                                        NetworkImage(
                                            snapshot.data!),
                                        radius: 24.0,
                                      );
                                    } else {
                                      return const CircleAvatar(
                                        radius: 24.0,
                                        child:
                                        Icon(Icons.person),
                                      );
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                          ),
                        const SizedBox(height: 20.0),
                        // Submit Button
                        Center(
                          child: ElevatedButton(
                            onPressed: _submitEvent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              Colors.yellow[700],
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(
                                    20.0),
                              ),
                              padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 40.0,
                                  vertical: 15.0),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(
                                color: Colors.black)
                                : const Text(
                              '+ Add',
                              style: TextStyle(
                                  color: Colors.black),
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
}

// Model class for Project
class Project {
  final int id;
  final String pName;
  final String projectId;

  Project({
    required this.id,
    required this.pName,
    required this.projectId,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      pName: json['p_name'],
      projectId: json['project_id'],
    );
  }

  @override
  String toString() {
    return 'Project(id: $id, pName: $pName, projectId: $projectId)';
  }
}

// Model class for Status
class Status {
  final int id;
  final String statusId;
  final String name;

  Status({
    required this.id,
    required this.statusId,
    required this.name,
  });

  @override
  String toString() {
    return 'Status(id: $id, statusId: $statusId, name: $name)';
  }
}
