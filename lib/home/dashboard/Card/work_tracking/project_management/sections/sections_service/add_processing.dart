// add_processing.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing_members.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';

class AddProcessingPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddProcessingPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _AddProcessingPageState createState() => _AddProcessingPageState();
}

class _AddProcessingPageState extends State<AddProcessingPage> {
  final _formKey = GlobalKey<FormState>();

  // Processing Data
  String title = '';
  String description = '';
  String status = 'Processing';
  String statusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? fromDate;
  DateTime? toDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // Members
  List<Map<String, dynamic>> selectedMembers = [];

  // File Uploads
  List<PlatformFile> selectedFiles = [];

  bool _isLoading = false;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  @override
  void initState() {
    super.initState();
    print('[_AddProcessingPageState] Initializing with projectId: ${widget.projectId}, baseUrl: ${widget.baseUrl}');
    // Initialize default dates and times
    fromDate = DateTime.now();
    toDate = DateTime.now();
    startTime = const TimeOfDay(hour: 9, minute: 0);
    endTime = const TimeOfDay(hour: 17, minute: 0);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      case 'Error':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  Future<void> _selectStartDate() async {
    final DateTime initialDate = fromDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        fromDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay initialTime = startTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime initialDate = toDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        toDate = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay initialTime = endTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        selectedFiles.addAll(result.files);
      });
    }
  }

  Future<void> _removeFile(int index) async {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  Future<void> _addProcessingItem() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    // Validate dates and times
    DateTime fromDateTime = DateTime(
      fromDate!.year,
      fromDate!.month,
      fromDate!.day,
      startTime?.hour ?? 0,
      startTime?.minute ?? 0,
    );

    DateTime toDateTime = DateTime(
      toDate!.year,
      toDate!.month,
      toDate!.day,
      endTime?.hour ?? 0,
      endTime?.minute ?? 0,
    );

    if (toDateTime.isBefore(fromDateTime)) {
      _showAlertDialog(
        title: 'Invalid Dates',
        content: 'End date cannot be before start date.',
        isError: true,
      );
      return;
    }

    // Ensure at least one member is selected
    if (selectedMembers.isEmpty) {
      _showAlertDialog(
        title: 'No Members Selected',
        content: 'Please select at least one member.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      var uri = Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/insert');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['project_id'] = widget.projectId;
      request.fields['title'] = title;
      request.fields['descriptions'] = description;
      request.fields['status_id'] = _statusMap[status]!;
      request.fields['fromdate'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(fromDateTime);
      request.fields['todate'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(toDateTime);

      // Add membersDetails
      List<Map<String, String>> membersDetails = selectedMembers.map((member) => {"employee_id": member['employee_id'].toString()}).toList();
      request.fields['membersDetails'] = jsonEncode(membersDetails);

      // Add files
      for (var file in selectedFiles) {
        if (file.path != null) {
          request.files.add(await http.MultipartFile.fromPath(
            'file_name',
            file.path!,
            filename: file.name,
          ));
        }
      }

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Processing item added successfully.',
          isError: false,
          onOk: () {
            Navigator.pop(context, true); // Indicate success to previous page
          },
        );
      } else {
        String errorMessage = 'Failed to add processing item.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showAlertDialog(
          title: 'Error',
          content: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error adding processing item: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }



  void _showAlertDialog({
    required String title,
    required String content,
    required bool isError,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: isError ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!isError && (title.toLowerCase().contains('success') || title.toLowerCase().contains('added'))) {
                  if (onOk != null) {
                    onOk();
                  }
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToSelectMembers() async {
    print('[_AddProcessingPageState] Navigating to SelectProcessingMembersPage with projectId: ${widget.projectId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectProcessingMembersPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
          alreadySelectedMembers: selectedMembers,
        ),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() {
        selectedMembers = result;
      });
      print('[_AddProcessingPageState] Members selected: ${selectedMembers.map((m) => m['employee_id']).toList()}');
    }
  }

  Widget _buildSelectedMembers() {
    if (selectedMembers.isEmpty) return const Text('No members selected.');
    int displayCount = selectedMembers.length > 5 ? 5 : selectedMembers.length;
    List<Widget> avatars = [];
    for (int i = 0; i < displayCount; i++) {
      avatars.add(
        Padding(
          padding: const EdgeInsets.only(right: 4.0),
          child: CircleAvatar(
            backgroundImage: selectedMembers[i]['image_url'] != null && selectedMembers[i]['image_url'].isNotEmpty
                ? NetworkImage(selectedMembers[i]['image_url'])
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
            radius: 20,
            backgroundColor: Colors.grey[200],
          ),
        ),
      );
    }
    if (selectedMembers.length > 5) {
      avatars.add(
        CircleAvatar(
          backgroundColor: Colors.grey[300],
          radius: 20,
          child: Text(
            '+${selectedMembers.length - 5}',
            style: const TextStyle(color: Colors.black),
          ),
        ),
      );
    }
    return Wrap(
      children: avatars,
    );
  }

  Widget _buildFilePicker() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Upload Files (Optional)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _pickFiles,
            icon: const Icon(Icons.attach_file, color: Colors.white),
            label: const Text(
              'Add Files',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3), // Light Blue
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              elevation: 2,
            ),
          ),
          const SizedBox(height: 8),
          selectedFiles.isEmpty
              ? const Text('No files selected.')
              : Wrap(
            spacing: 8.0,
            alignment: WrapAlignment.center,
            children: List.generate(selectedFiles.length, (index) {
              return Chip(
                label: Text(selectedFiles[index].name),
                deleteIcon: const Icon(Icons.close),
                onDeleted: () => _removeFile(index),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return ElevatedButton.icon(
      onPressed: _addProcessingItem,
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'Add',
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFDBB342), // #DBB342
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    // Determine screen size for responsiveness
    final Size screenSize = MediaQuery.of(context).size;

    // Adjust horizontal padding based on screen width
    double horizontalPadding = screenSize.width * 0.05; // 5% of screen width
    horizontalPadding = horizontalPadding < 16.0 ? 16.0 : horizontalPadding;

    return Scaffold(
      appBar: AppBar(
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
          'Add Processing Item',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 'Add' Button Positioned at Top Right
                Align(
                  alignment: Alignment.centerRight,
                  child: _buildAddButton(),
                ),
                const SizedBox(height: 16),
                // Title Input
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required.';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {
                      title = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Description Input
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  onChanged: (value) {
                    setState(() {
                      description = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Status Dropdown
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  icon: Image.asset(
                    'assets/task.png',
                    width: 24,
                    height: 24,
                  ),
                  items: ['Processing', 'Pending', 'Finished', 'Error']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            color: _getStatusColor(value),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(value),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      status = newValue!;
                      statusId = _statusMap[status]!;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Status is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Start Date-Time
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Start Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectStartDate,
                              ),
                            ),
                            validator: (value) {
                              if (fromDate == null) {
                                return 'Start date is required.';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate!) : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectStartTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'Start Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: _selectStartTime,
                              ),
                            ),
                            validator: (value) {
                              if (startTime == null) {
                                return 'Start time is required.';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: startTime != null ? startTime!.format(context) : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // End Date-Time
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndDate,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'End Date',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectEndDate,
                              ),
                            ),
                            validator: (value) {
                              if (toDate == null) {
                                return 'End date is required.';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: toDate != null ? DateFormat('yyyy-MM-dd').format(toDate!) : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _selectEndTime,
                        child: AbsorbPointer(
                          child: TextFormField(
                            decoration: InputDecoration(
                              labelText: 'End Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.access_time),
                                onPressed: _selectEndTime,
                              ),
                            ),
                            validator: (value) {
                              if (endTime == null) {
                                return 'End time is required.';
                              }
                              return null;
                            },
                            controller: TextEditingController(
                              text: endTime != null ? endTime!.format(context) : '',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Members Selection
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selected Members',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _navigateToSelectMembers,
                      icon: const Icon(Icons.person_add, color: Colors.white),
                      label: const Text(
                        'Select Members',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50), // Green
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildSelectedMembers(),
                const SizedBox(height: 20),
                // File Upload
                _buildFilePicker(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
