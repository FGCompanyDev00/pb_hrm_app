// office_add_event.dart

import 'package:day_night_time_picker/day_night_time_picker.dart';
import 'package:day_night_time_picker/lib/state/time.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pb_hrsystem/home/office_events/add_member_office_event.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

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
  final _nameController = TextEditingController(); // For Booking Car (Optional)

  // Loading state
  bool _isLoading = false;

  // Additional fields based on booking type
  String? _projectId;
  String? _statusId;
  String? _roomId;
  String? _roomName;
  int? _notification; // Notification time in minutes
  String? _location; // For Add Meeting and Meeting Type for Booking Meeting Room
  List<PlatformFile> _selectedFiles = []; // For file uploads (only Type 1)

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

  // Location options for Add Meeting and Meeting Type for Booking Meeting Room
  final List<String> _locationOptions = ["Meeting at Local Office", "Meeting Online", "Deadline"];

  // Notification options
  final List<int> _notificationOptions = [5, 10, 30];

  @override
  void initState() {
    super.initState();
    _fetchEmployeeId();
    _fetchRooms();
    _fetchProjects();
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
      if (kDebugMode) {
        print('Employee ID: $_employeeId');
      } // Debug statement
    });
  }

  /// Fetches the authentication token from shared preferences
  Future<String> _fetchToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    if (kDebugMode) {
      print('Fetched Token: $token');
    } // Debug statement
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
          if (kDebugMode) {
            print('Fetched Rooms: $_rooms');
          } // Debug statement
        });
      } else {
        throw Exception('Failed to load rooms');
      }
    } catch (e) {
      _showErrorMessage('Error fetching rooms: $e');
    }
  }

  /// Fetches the list of projects from the API
  Future<void> _fetchProjects() async {
    try {
      String token = await _fetchToken();

      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/work-tracking/proj/find-My-Project-list'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['result'];
        setState(() {
          _projects = data.map<Project>((item) => Project.fromJson(item)).toList();
          if (kDebugMode) {
            print('Fetched Projects: $_projects');
          } // Debug statement
        });
      } else {
        throw Exception('Failed to load projects');
      }
    } catch (e) {
      _showErrorMessage('Error fetching projects: $e');
    }
  }

  /// Submits the event based on the selected booking type
  Future<void> _submitEvent() async {
    if (_validateFields()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String token = await _fetchToken();

        if (_selectedBookingType == '1. Add Meeting') {
          // Handle Type 1 using MultipartRequest for file upload
          String url = 'https://demo-application-api.flexiflows.co/api/work-tracking/meeting/insert';

          var request = http.MultipartRequest('POST', Uri.parse(url));
          request.headers['Authorization'] = 'Bearer $token';
          // Note: MultipartRequest automatically sets the Content-Type

          // Adding text fields
          request.fields['title'] = _titleController.text;
          request.fields['description'] = _descriptionController.text;
          request.fields['fromdate'] = _startDateTime != null ? DateFormat('yyyy-MM-dd').format(_startDateTime!) : '';
          request.fields['todate'] = _endDateTime != null ? DateFormat('yyyy-MM-dd').format(_endDateTime!) : '';
          request.fields['start_time'] = _startDateTime != null ? DateFormat('HH:mm:ss').format(_startDateTime!) : '';
          request.fields['end_time'] = _endDateTime != null ? DateFormat('HH:mm:ss').format(_endDateTime!) : '';
          request.fields['location'] = _location ?? '';
          request.fields['notification'] = (_notification ?? 5).toString();

          // Adding membersDetails as JSON string
          List<Map<String, dynamic>> members = _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList();
          request.fields['membersDetails'] = jsonEncode(members);

          // Adding files if any
          for (var file in _selectedFiles) {
            if (file.path != null) {
              File f = File(file.path!);
              String fileName = path.basename(f.path);
              request.files.add(await http.MultipartFile.fromPath(
                'file_name', // Ensure this matches the API's expected field name
                f.path,
                filename: fileName,
              ));
            }
          }

          if (kDebugMode) {
            print('Submitting Type 1 Add Meeting with fields: ${request.fields}');
          }
          if (kDebugMode) {
            print('Submitting Type 1 Add Meeting with ${request.files.length} files.');
          }

          // Sending the request
          var streamedResponse = await request.send();

          // Getting the response
          var response = await http.Response.fromStream(streamedResponse);

          // Handle the response
          if (response.statusCode == 200 || response.statusCode == 201) {
            _showSuccessMessage('Event added successfully!');

            // Reset the form after successful submission
            _resetForm();
          } else {
            String errorMsg = 'Failed to add event.';
            if (response.body.isNotEmpty) {
              try {
                final errorResponse = jsonDecode(response.body);
                errorMsg = 'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}';
              } catch (_) {
                // If response is not JSON, keep the default error message
              }
            }
            _showErrorMessage(errorMsg);
          }
        } else {
          // Handle other booking types as before

          String url = '';
          Map<String, dynamic> body = {};

          // Build the request based on the selected booking type
          if (_selectedBookingType == '2. Meeting and Booking Meeting Room') {
            url = 'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room';
            body = {
              "room_id": _roomId,
              "title": _titleController.text,
              "from_date_time": _startDateTime != null ? DateFormat('yyyy-MM-dd').format(_startDateTime!) : "",
              "to_date_time": _endDateTime != null ? DateFormat('yyyy-MM-dd').format(_endDateTime!) : "",
              "start_time": _startDateTime != null ? DateFormat('HH:mm:ss').format(_startDateTime!) : '',
              "end_time": _endDateTime != null ? DateFormat('HH:mm:ss').format(_endDateTime!) : '',
              "employee_tel": _employeeTelController.text,
              "remark": _remarkController.text,
              "notification": _notification ?? 5,
              "members": _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList(),
            };
            if (kDebugMode) {
              print('Submit Book Meeting Room Body: $body');
            } // Debug statement
          } else if (_selectedBookingType == '3. Booking Car') {
            // Handle Type 3 without fetching permit_branch from API
            url = 'https://demo-application-api.flexiflows.co/api/office-administration/car_permit';
            body = {
              "employee_id": _employeeId,
              "place": _placeController.text,
              "date_in": _startDateTime != null ? DateFormat('yyyy-MM-dd').format(_startDateTime!) : "",
              "date_out": _endDateTime != null ? DateFormat('yyyy-MM-dd').format(_endDateTime!) : "",
              "permit_branch": 0, // Default value as per requirement
              "notification": _notification ?? 30,
              "members": _selectedMembers.map((member) => {"employee_id": member['employee_id']}).toList(),
            };
            if (kDebugMode) {
              print('Submit Booking Car Body: $body');
            } // Debug statement
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
            String errorMsg = 'Failed to add event.';
            if (response.body.isNotEmpty) {
              try {
                final errorResponse = jsonDecode(response.body);
                errorMsg = 'Failed to add event: ${errorResponse['message'] ?? 'Please try again.'}';
              } catch (_) {
                // If response is not JSON, keep the default error message
              }
            }
            _showErrorMessage(errorMsg);
          }
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
      _selectedFiles = [];
      _projectId = null;
      _statusId = null;
      _roomId = null;
      _roomName = null;
      _location = null;
      _notification = null;
      _selectedProject = null;
      _selectedStatus = null;
      // Removed _permitBranchId as it's no longer used
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
        if (_selectedProject == null) {
          _showErrorMessage('Please select a project.');
          return false;
        }
        if (_selectedStatus == null) {
          _showErrorMessage('Please select a status.');
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
        // File upload is optional; uncomment if required
        // if (_selectedFiles.isEmpty) {
        //   _showErrorMessage('Please add at least one file.');
        //   return false;
        // }
        break;

      case '2. Meeting and Booking Meeting Room':
        if (_remarkController.text.isEmpty) {
          _showErrorMessage('Please enter a remark.');
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
        break;

      case '3. Booking Car':
        // Name is optional
        if (_placeController.text.isEmpty) {
          _showErrorMessage('Please enter the place.');
          return false;
        }
        if (_purposeController.text.isEmpty) {
          _showErrorMessage('Please enter the purpose.');
          return false;
        }
        // Removed check for _permitBranchId as it's now defaulted to '0'
        if (_notification == null) {
          _showErrorMessage('Please select a notification time.');
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

    if (_selectedMembers.isEmpty) {
      String memberType = _selectedBookingType == '1. Add Meeting' ? 'guest' : 'member';
      _showErrorMessage('Please add at least one $memberType.');
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

  /// Shows date picker for selecting date
  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime initialDate = isStartDate ? (_startDateTime ?? DateTime.now()) : (_endDateTime ?? DateTime.now());
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _startDateTime?.hour ?? 7,
            _startDateTime?.minute ?? 0,
          );
          if (kDebugMode) {
            print('Start DateTime: $_startDateTime');
          } // Debug statement
        } else {
          _endDateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            _endDateTime?.hour ?? 17,
            _endDateTime?.minute ?? 0,
          );
          if (kDebugMode) {
            print('End DateTime: $_endDateTime');
          } // Debug statement
        }
      });
    }
  }

  /// Shows time picker for selecting time
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    double minHours = (isStartTime ? 7 : ((_startDateTime?.hour ?? 0) + 2)).toDouble();
    double minMinutes = (isStartTime ? 7 : _startDateTime?.minute)!.toDouble();
    int? fetchHour = isStartTime
        ? _startDateTime?.hour
        : (_endDateTime!.hour > minHours.toInt())
            ? _endDateTime?.hour
            : minHours.toInt();
    int? fetchMinute = isStartTime
        ? _startDateTime?.minute
        : (_endDateTime!.minute > minMinutes.toInt())
            ? _endDateTime?.minute
            : minMinutes.toInt();
    Time time = Time(
      hour: fetchHour ?? 7,
      minute: fetchMinute ?? 0,
    );
    Navigator.of(context).push(
      showPicker(
        context: context,
        value: time,
        minHour: minHours,
        maxHour: 17,
        duskSpanInMinutes: 120, // optional
        onChange: (e) {
          time = Time(hour: e.hour, minute: e.minute);
          setState(() {
            if (isStartTime) {
              _startDateTime = DateTime(
                _startDateTime?.year ?? DateTime.now().year,
                _startDateTime?.month ?? DateTime.now().month,
                _startDateTime?.day ?? DateTime.now().day,
                e.hour,
                e.minute,
              );
              if (kDebugMode) {
                print('Start Time: $_startDateTime');
              } // Debug statement
            } else {
              _endDateTime = DateTime(
                _endDateTime?.year ?? DateTime.now().year,
                _endDateTime?.month ?? DateTime.now().month,
                _endDateTime?.day ?? DateTime.now().day,
                e.hour,
                e.minute,
              );
              if (kDebugMode) {
                print('End Time: $_endDateTime');
              } // Debug statement
            }
          });
        },
      ),
    );
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
        if (kDebugMode) {
          print('Selected Members: $_selectedMembers');
        } // Debug statement
      });
    }
  }

  /// Allows users to pick files to upload (only for Type 1)
  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.files;
      });
    }
  }

  /// Removes a selected file
  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
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
                    print('Selected Booking Type: $_selectedBookingType'); // Debug
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('2. Meeting and Booking Meeting Room'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '2. Meeting and Booking Meeting Room';
                    if (kDebugMode) {
                      print('Selected Booking Type: $_selectedBookingType');
                    } // Debug
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text('3. Booking Car'),
                onTap: () {
                  setState(() {
                    _selectedBookingType = '3. Booking Car';
                    if (kDebugMode) {
                      print('Selected Booking Type: $_selectedBookingType');
                    } // Debug
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
                          print('Selected Room: $_roomName'); // Debug
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
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
          print('Selected Notification: $_notification'); // Debug
        });
      },
    );
  }

  /// Shows the location or meeting type dropdown based on booking type
  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
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
          print('Selected Location/Meeting Type: $_location'); // Debug
        });
      },
    );
  }

  /// Shows the add files dialog (only for Type 1)
  void _showAddFilesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Files'),
          content: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _pickFiles();
            },
            child: const Text('Choose Files'),
          ),
        );
      },
    );
  }

  /// Builds the file upload section (only for Type 1)
  Widget _buildFileUploadSection() {
    if (_selectedBookingType != '1. Add Meeting' || _selectedFiles.isEmpty) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16.0),
        const Text(
          'Uploaded Files',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        const SizedBox(height: 8.0),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _selectedFiles.length,
          itemBuilder: (context, index) {
            final file = _selectedFiles[index];
            return ListTile(
              leading: Icon(
                _getFileIcon(file.extension),
                color: Colors.blue,
              ),
              title: Text(file.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeFile(index),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Returns appropriate icon based on file extension
  IconData _getFileIcon(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'png':
      case 'jpg':
      case 'jpeg':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }

  /// Builds the UI based on the selected booking type
  Widget _buildAdditionalFields() {
    switch (_selectedBookingType) {
      case '1. Add Meeting':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8.0),
            // Location Dropdown
            const Text(
              'Location*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            _buildLocationDropdown(),
            const SizedBox(height: 16.0),
            // Notification Dropdown
            const Text(
              'Notification*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            _buildNotificationDropdown(),
          ],
        );

      case '2. Meeting and Booking Meeting Room':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6.0),
            // Phone Number Input
            const Text(
              'Tel*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _employeeTelController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Book a Meeting Room Text
            const Text(
              'Book a Meeting Room*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            // Room ID Dropdown
            GestureDetector(
              onTap: _selectRoom,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: Colors.grey),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_roomName ?? 'Select Room'),
                    const Icon(Icons.menu),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Notification Dropdown
            const Text(
              'Notification*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            _buildNotificationDropdown(),
          ],
        );

      case '3. Booking Car':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16.0),
            // Place Input
            const Text(
              'Place*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _placeController,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Purpose Input
            const Text(
              'Purpose*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            TextField(
              controller: _purposeController,
              maxLines: 3,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            // Notification Dropdown
            const Text(
              'Notification*',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            _buildNotificationDropdown(),
          ],
        );

      default:
        return Container();
    }
  }

  /// Builds the UI form fields based on the selected booking type
  Widget _buildFormFields() {
    if (_selectedBookingType == null) return Container();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title input
        const Text(
          'Title*',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
        ),
        const SizedBox(height: 8.0),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        // Description or Remark based on booking type
        if (_selectedBookingType == '1. Add Meeting') ...[
          const Text(
            'Description*',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
        ] else if (_selectedBookingType == '2. Meeting and Booking Meeting Room') ...[
          const Text(
            'Remark*',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _remarkController,
            maxLines: 3,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
        // Additional fields based on booking type
        _buildAdditionalFields(),
        const SizedBox(height: 16.0),
        // Date and time pickers
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _selectDate(context, true),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDateTime == null ? 'Start Date' : DateFormat('yyyy-MM-dd').format(_startDateTime!)),
                          const Icon(Icons.calendar_today),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _selectDate(context, false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endDateTime == null ? 'End Date' : DateFormat('yyyy-MM-dd').format(_endDateTime!)),
                          const Icon(Icons.calendar_today),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _selectTime(context, true),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_startDateTime == null ? 'Start Time' : TimeOfDay.fromDateTime(_startDateTime!).format(context)),
                          const Icon(Icons.access_time),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0)),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _selectTime(context, false),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_endDateTime == null ? 'End Time' : TimeOfDay.fromDateTime(_endDateTime!).format(context)),
                          const Icon(Icons.access_time),
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
        // Add People and Add Files buttons
        Row(
          children: [
            // '+ Add People' button
            Expanded(
              child: ElevatedButton(
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
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 20.0),
            // Show Add Files button only for Type 1
            if (_selectedBookingType == '1. Add Meeting') ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: _showAddFilesDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 12.0),
                  ),
                  child: const Text(
                    '+ Add Files',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16.0),
        // Display selected members
        if (_selectedMembers.isNotEmpty)
          Center(
            child: Wrap(
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
          ),
        // Display selected files (only for Type 1)
        _buildFileUploadSection(),
        const SizedBox(height: 20.0),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Calculate AppBar height

    // Build the UI
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Office Event',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 90,
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
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
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
                        backgroundColor: Color(0xFFE2AD30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 15.0),
                      ),
                      child: const Text(
                        '+ Add',
                        style: TextStyle(color: Colors.black, fontSize: 18.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                  // Booking type selection
                  const Text(
                    'Type of Booking*',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                  ),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _showBookingTypeModal(context),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedBookingType ?? 'Select Booking Type'),
                          const Icon(Icons.menu),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16.0),
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

/// Model class for Project
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

/// Model class for Status
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
