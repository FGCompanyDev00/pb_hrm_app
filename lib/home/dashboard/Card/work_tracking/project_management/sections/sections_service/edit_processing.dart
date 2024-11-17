import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class UpdateProcessingPage extends StatefulWidget {
  final String meetingId;
  final String projectId;
  final String baseUrl;

  const UpdateProcessingPage({
    super.key,
    required this.meetingId,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _UpdateProcessingPageState createState() => _UpdateProcessingPageState();
}

class _UpdateProcessingPageState extends State<UpdateProcessingPage> {
  final _formKey = GlobalKey<FormState>();

  // Original Data
  String originalTitle = '';
  String originalDescription = '';
  String originalStatus = 'Processing';
  String originalStatusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? originalFromDate;
  DateTime? originalToDate;
  TimeOfDay? originalStartTime;
  TimeOfDay? originalEndTime;

  // Updated Data
  String? updatedTitle;
  String? updatedDescription;
  String? updatedStatus;
  String? updatedStatusId;
  DateTime? updatedFromDate;
  DateTime? updatedToDate;
  TimeOfDay? updatedStartTime;
  TimeOfDay? updatedEndTime;

  // Flags to track if a field has been edited
  bool isTitleEdited = false;
  bool isDescriptionEdited = false;
  bool isStatusEdited = false;
  bool isFromDateEdited = false;
  bool isToDateEdited = false;
  bool isStartTimeEdited = false;
  bool isEndTimeEdited = false;

  bool _isLoading = false;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  // Controllers to manage text fields and avoid recreating them on each build
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;

  @override
  void initState() {
    super.initState();
    _fetchMeetingDetails();

    // Initialize controllers
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _startDateController = TextEditingController();
    _endDateController = TextEditingController();
    _startTimeController = TextEditingController();
    _endTimeController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose controllers to free resources
    _titleController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      default:
        return Colors.black;
    }
  }

  Future<void> _fetchMeetingDetails() async {
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
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/work-tracking/meeting/get-all-meeting'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final meeting = (data['results'] as List).firstWhere(
              (item) => item['meeting_id'] == widget.meetingId,
          orElse: () => null,
        );
        if (meeting != null) {
          setState(() {
            originalTitle = meeting['title'] ?? '';
            originalDescription = meeting['descriptions'] ?? '';
            originalStatus = meeting['s_name'] ?? 'Processing';
            originalStatusId = _statusMap[originalStatus] ??
                '0a8d93f0-1c05-42b2-8e56-984a578ef077';
            originalFromDate = meeting['fromdate'] != null
                ? DateTime.parse(meeting['fromdate'])
                : null;
            originalToDate = meeting['todate'] != null
                ? DateTime.parse(meeting['todate'])
                : null;
            originalStartTime = meeting['start_time'] != null &&
                meeting['start_time'] != ''
                ? TimeOfDay(
              hour: int.parse(meeting['start_time'].split(':')[0]),
              minute: int.parse(meeting['start_time'].split(':')[1]),
            )
                : null;
            originalEndTime = meeting['end_time'] != null &&
                meeting['end_time'] != ''
                ? TimeOfDay(
              hour: int.parse(meeting['end_time'].split(':')[0]),
              minute: int.parse(meeting['end_time'].split(':')[1]),
            )
                : null;

            // Initialize controllers with original data
            _titleController.text = originalTitle;
            _descriptionController.text = originalDescription;
            _startDateController.text = originalFromDate != null
                ? DateFormat('yyyy-MM-dd').format(originalFromDate!)
                : '';
            _endDateController.text = originalToDate != null
                ? DateFormat('yyyy-MM-dd').format(originalToDate!)
                : '';
            _startTimeController.text = originalStartTime != null
                ? originalStartTime!.format(context)
                : '';
            _endTimeController.text = originalEndTime != null
                ? originalEndTime!.format(context)
                : '';
          });
        } else {
          _showAlertDialog(
            title: 'Error',
            content: 'Meeting not found.',
            isError: true,
          );
        }
      } else {
        _showAlertDialog(
          title: 'Error',
          content: 'Failed to load meeting details.',
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error fetching meeting details: $e',
        isError: true,
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _selectStartDate() async {
    final DateTime initialDate = isFromDateEdited && updatedFromDate != null
        ? updatedFromDate!
        : originalFromDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        updatedFromDate = picked;
        isFromDateEdited = true;
        _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay initialTime = isStartTimeEdited && updatedStartTime != null
        ? updatedStartTime!
        : originalStartTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        updatedStartTime = picked;
        isStartTimeEdited = true;
        _startTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime initialDate = isToDateEdited && updatedToDate != null
        ? updatedToDate!
        : originalToDate ?? DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        updatedToDate = picked;
        isToDateEdited = true;
        _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay initialTime = isEndTimeEdited && updatedEndTime != null
        ? updatedEndTime!
        : originalEndTime ?? TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        updatedEndTime = picked;
        isEndTimeEdited = true;
        _endTimeController.text = picked.format(context);
      });
    }
  }

  Future<void> _updateMeeting() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    // Check if any field has been edited
    if (!isTitleEdited &&
        !isDescriptionEdited &&
        !isStatusEdited &&
        !isFromDateEdited &&
        !isToDateEdited &&
        !isStartTimeEdited &&
        !isEndTimeEdited) {
      _showSnackBar(
        message: 'No fields have been updated.',
        isError: false,
      );
      return;
    }

    // Combine date and time into single DateTime objects
    DateTime fromDateTime = originalFromDate ?? DateTime.now();
    if (isFromDateEdited && updatedFromDate != null) {
      fromDateTime = DateTime(
        updatedFromDate!.year,
        updatedFromDate!.month,
        updatedFromDate!.day,
        updatedStartTime?.hour ?? originalStartTime?.hour ?? 0,
        updatedStartTime?.minute ?? originalStartTime?.minute ?? 0,
      );
    } else if (isStartTimeEdited && updatedStartTime != null) {
      fromDateTime = DateTime(
        fromDateTime.year,
        fromDateTime.month,
        fromDateTime.day,
        updatedStartTime!.hour,
        updatedStartTime!.minute,
      );
    }

    DateTime toDateTime = originalToDate ?? DateTime.now();
    if (isToDateEdited && updatedToDate != null) {
      toDateTime = DateTime(
        updatedToDate!.year,
        updatedToDate!.month,
        updatedToDate!.day,
        updatedEndTime?.hour ?? originalEndTime?.hour ?? 0,
        updatedEndTime?.minute ?? originalEndTime?.minute ?? 0,
      );
    } else if (isEndTimeEdited && updatedEndTime != null) {
      toDateTime = DateTime(
        toDateTime.year,
        toDateTime.month,
        toDateTime.day,
        updatedEndTime!.hour,
        updatedEndTime!.minute,
      );
    }

    // Validate that end date is not before start date
    if (toDateTime.isBefore(fromDateTime)) {
      _showSnackBar(
        message: 'End date cannot be before start date.',
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
      // Prepare the request body with updated or original data
      Map<String, dynamic> body = {
        'title': isTitleEdited ? updatedTitle : originalTitle,
        'descriptions':
        isDescriptionEdited ? updatedDescription : originalDescription,
        'status_id': isStatusEdited ? updatedStatusId : originalStatusId,
        'fromdate': DateFormat('yyyy-MM-dd HH:mm:ss').format(fromDateTime),
        'todate': DateFormat('yyyy-MM-dd HH:mm:ss').format(toDateTime),
        'start_time': isStartTimeEdited && updatedStartTime != null
            ? _formatTime(updatedStartTime!)
            : originalStartTime != null
            ? _formatTime(originalStartTime!)
            : '',
        'end_time': isEndTimeEdited && updatedEndTime != null
            ? _formatTime(updatedEndTime!)
            : originalEndTime != null
            ? _formatTime(originalEndTime!)
            : '',
      };

      final response = await http.put(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/update/${widget.meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          message: 'Meeting updated successfully.',
          isError: false,
        );
        // Optionally, refresh data or navigate back
      } else {
        String errorMessage = 'Failed to update meeting.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showSnackBar(
          message: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: 'Error updating meeting: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _deleteMeeting() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Meeting'),
          content: const Text('Are you sure you want to delete this meeting?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Changed to red for better visibility
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (!confirm) return;

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
      final response = await http.put(
        Uri.parse(
            '${widget.baseUrl}/api/work-tracking/meeting/delete/${widget.meetingId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar(
          message: 'Meeting deleted successfully.',
          isError: false,
        );
        Navigator.pop(context); // Navigate back after deletion
      } else {
        String errorMessage = 'Failed to delete meeting.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showSnackBar(
          message: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar(
        message: 'Error deleting meeting: $e',
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
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title,
              style: TextStyle(
                  color: isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (!isError &&
                    (title.toLowerCase().contains('success') ||
                        title.toLowerCase().contains('deleted'))) {
                  Navigator.of(context).pop(); // Navigate back on success
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar({required String message, required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildEditableField({
    required String label,
    required TextEditingController controller,
    required bool isEditable,
    required Widget suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    VoidCallback? onTap,
    FormFieldValidator<String>? validator,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        absorbing: !isEditable,
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: suffixIcon,
          ),
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

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
          'Edit Processing Item',
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
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delete and Update Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _deleteMeeting,
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Changed to red for better visibility
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _updateMeeting,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Update',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                          const Color(0xFFDBB342), // Hex #DBB342
                          padding: const EdgeInsets.symmetric(
                              vertical: 12.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Title Input
                _buildEditableField(
                  label: 'Title',
                  controller: _titleController,
                  isEditable: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isTitleEdited ? Icons.check : Icons.edit,
                      color: isTitleEdited ? Colors.green : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isTitleEdited = !isTitleEdited;
                      });
                    },
                  ),
                  onTap: () {
                    if (!isTitleEdited) {
                      setState(() {
                        isTitleEdited = true;
                        updatedTitle = originalTitle;
                      });
                    }
                  },
                  validator: (value) {
                    if (isTitleEdited && (value == null || value.isEmpty)) {
                      return 'Title cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Status Dropdown
                DropdownButtonFormField<String>(
                  value: isStatusEdited
                      ? updatedStatus
                      : originalStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  icon: Image.asset(
                    'assets/task.png',
                    width: 24,
                    height: 24,
                  ),
                  items: ['Processing', 'Pending', 'Finished']
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
                  onChanged: _isLoading
                      ? null
                      : (String? newValue) {
                    setState(() {
                      updatedStatus = newValue!;
                      updatedStatusId = _statusMap[updatedStatus!]!;
                      isStatusEdited = true;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a status';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                // Start Date-Time
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableField(
                        label: 'Start Date',
                        controller: _startDateController,
                        isEditable: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _isLoading ? null : _selectStartDate,
                        ),
                        onTap: _isLoading ? null : _selectStartDate,
                        validator: (value) {
                          // Optional field
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEditableField(
                        label: 'Start Time',
                        controller: _startTimeController,
                        isEditable: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _isLoading ? null : _selectStartTime,
                        ),
                        onTap: _isLoading ? null : _selectStartTime,
                        validator: (value) {
                          // Optional field
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // End Date-Time
                Row(
                  children: [
                    Expanded(
                      child: _buildEditableField(
                        label: 'End Date',
                        controller: _endDateController,
                        isEditable: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _isLoading ? null : _selectEndDate,
                        ),
                        onTap: _isLoading ? null : _selectEndDate,
                        validator: (value) {
                          // Optional field
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildEditableField(
                        label: 'End Time',
                        controller: _endTimeController,
                        isEditable: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: _isLoading ? null : _selectEndTime,
                        ),
                        onTap: _isLoading ? null : _selectEndTime,
                        validator: (value) {
                          // Optional field
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Description Input
                _buildEditableField(
                  label: 'Description',
                  controller: _descriptionController,
                  isEditable: true,
                  suffixIcon: IconButton(
                    icon: Icon(
                      isDescriptionEdited ? Icons.check : Icons.edit,
                      color: isDescriptionEdited ? Colors.green : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        isDescriptionEdited = !isDescriptionEdited;
                      });
                    },
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  onTap: () {
                    if (!isDescriptionEdited) {
                      setState(() {
                        isDescriptionEdited = true;
                        updatedDescription = originalDescription;
                      });
                    }
                  },
                  validator: (value) {
                    // Optional field, add validation if necessary
                    return null;
                  },
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
