import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/addpeoplepageworktracking.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TaskModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final Function(Map<String, dynamic>) onSave;
  final bool isEdit;
  final String projectId;
  final String baseUrl;

  static const List<Map<String, dynamic>> statusOptions = [
    {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
    {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
    {'id': 'e35569eb-75e1-4005-9232-bfb57303b8b3', 'name': 'Finished'},
  ];

  const TaskModal({
    this.task,
    required this.onSave,
    this.isEdit = false,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  TaskModalState createState() => TaskModalState();
}

class TaskModalState extends State<TaskModal> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  String _selectedStatus = 'Pending';
  final ImagePicker _picker = ImagePicker();
  final List<File> _files = [];
  List<Map<String, dynamic>> _selectedPeople = [];
  final _formKey = GlobalKey<FormState>();

  final WorkTrackingService _workTrackingService = WorkTrackingService();

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.task?['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.task?['description'] ?? '');

    _selectedStatus = widget.task?['status'] ?? TaskModal.statusOptions.first['id'];

    if (widget.isEdit) {
      _fetchAssignmentMembers();
    }
  }

  Future<void> _fetchAssignmentMembers() async {
    try {
      final members = await _workTrackingService.fetchAssignmentMembers(widget.projectId);
      setState(() {
        _selectedPeople = members;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load assignment members: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'mp4'],
    );

    // If the user picks a file, add it to the _files list
    if (result != null) {
      setState(() {
        _files.addAll(result.paths.map((path) => File(path!)).toList());
      });
    } else {
      // If no file is selected, show a message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected')),
      );
    }
  }

// Function to remove a file from the _files list
  void _removeFile(File file) {
    setState(() {
      _files.remove(file);
    });
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token is null. Please log in again.')),
        );
        return;
      }

      // Prepare task data for both adding and editing
      final taskData = {
        'status_id': _selectedStatus,
        'title': _titleController.text,
        'descriptions': _descriptionController.text,
        'memberDetails': jsonEncode([
          {'employee_id': '12345', 'role': 'Manager'}, // Example memberDetails structure
          {'employee_id': '67890', 'role': 'Developer'}
        ]),
      };

      try {
        // Check if it's an edit action
        if (widget.isEdit && widget.task != null) {
          // Edit Task API (PUT)
          final response = await http.put(
            Uri.parse('${widget.baseUrl}/api/work-tracking/ass/update/${widget.task!['as_id']}'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(taskData),
          );

          if (response.statusCode == 200 || response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task saved successfully')),
            );
            Navigator.pop(context, true);
          } else {
            final responseBody = response.body;
            print('Failed to save task: ${response.statusCode}, Response: $responseBody');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to save task: $responseBody')),
            );
          }
        } else {
          // Add Task API (POST) - Creating a new task
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert'),
          );

          request.headers['Authorization'] = 'Bearer $token';
          request.fields['project_id'] = widget.projectId;
          request.fields['status_id'] = _selectedStatus;
          request.fields['title'] = _titleController.text;
          request.fields['descriptions'] = _descriptionController.text;
          request.fields['memberDetails'] = taskData['memberDetails'] ?? ''; // Fix for nullable String

          // Attach files (if any)
          if (_files.isNotEmpty) {
            for (var file in _files) {
              request.files.add(
                await http.MultipartFile.fromPath(
                  'file_name',
                  file.path,
                ),
              );
            }
          }

          final response = await request.send();

          if (response.statusCode == 201) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Task added successfully')),
            );
            Navigator.pop(context, true);
          } else {
            final errorResponse = await response.stream.bytesToString();
            print('Failed to add task: StatusCode: ${response.statusCode}, Error: $errorResponse');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to add task: $errorResponse')),
            );
          }
        }
      } on SocketException catch (e) {
        print('Network error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Please check your internet connection.')),
        );
      } on FormatException catch (e) {
        print('Response format error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid response format from the server.')),
        );
      } catch (e) {
        print('Unexpected error: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e')),
        );
      }
    }
  }

  void _openAddPeoplePage() async {
    final selectedPeople = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPeoplePageWorkTracking(
          asId: widget.projectId, // Pass the asId (assignment ID)
          projectId: widget.projectId,
          onSelectedPeople: (people) {
            setState(() {
              _selectedPeople = people; // Capture selected people
            });
          },
        ),
      ),
    );

    if (selectedPeople != null) {
      setState(() {
        _selectedPeople = selectedPeople;
      });
    }
  }

@override
Widget build(BuildContext context) {
  Provider.of<ThemeNotifier>(context);

  return AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    titlePadding: EdgeInsets.zero,
    title: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: const BoxDecoration(
        color: Colors.amber,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          const Text(
            'Processing or Detail',
            style: TextStyle(color: Colors.black, fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 48), // To keep the title centered
        ],
      ),
    ),
    content: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Button
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saveTask,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Title Field
              const Text(
                'Title',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Status and Upload Image in the same row
              Row(
                children: [
                  Expanded(
                    flex: 2, // Adjusts width ratio for the status dropdown
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        DropdownButtonFormField<String>(
                          value: TaskModal.statusOptions.any((status) => status['id'] == _selectedStatus)
                              ? _selectedStatus
                              : null,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          ),
                          icon: const Icon(Icons.arrow_downward),
                          style: const TextStyle(color: Colors.black),
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedStatus = newValue!;
                            });
                          },
                          items: TaskModal.statusOptions.map<DropdownMenuItem<String>>((status) {
                            return DropdownMenuItem<String>(
                              value: status['id'],
                              child: Row(
                                children: [
                                  Icon(Icons.circle, color: _getStatusColor(status['name']), size: 12),
                                  const SizedBox(width: 8),
                                  Text(status['name']),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 1, // Adjusts width ratio for the upload button
                    child: ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text('Upload'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 14), // Shorter button
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 15),
              // Only show file upload and member addition for Add Task
              if (!widget.isEdit) ...[
                ElevatedButton.icon(
                  onPressed: _openAddPeoplePage,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add People'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 15),

                Wrap(
                  spacing: 8.0,
                  children: _files.map((file) {
                    return Chip(
                      label: Text(file.path.split('/').last),
                      deleteIcon: const Icon(Icons.cancel, color: Colors.red),
                      onDeleted: () => _removeFile(file),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
              ],

              // Always show selected members for both Add and Edit Task
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _selectedPeople.map((person) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          // Handle tap on avatar function, if needed
                        },
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: person['profile_image'] != null && person['profile_image'].isNotEmpty
                              ? NetworkImage(person['profile_image'])
                              : const AssetImage('assets/default_avatar.png') as ImageProvider,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        person['name'] ?? 'No Name',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
              // Description Field
              const Text(
                'Description',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 5),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


  Color _getStatusColor(String statusName) {
    switch (statusName) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }
}

