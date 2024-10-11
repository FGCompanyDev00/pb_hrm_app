// lib/home/dashboard/Card/approval/meeting_edit_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// This page allows the user to edit a meeting request.
class MeetingEditPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const MeetingEditPage({super.key, required this.item});

  @override
  _MeetingEditPageState createState() => _MeetingEditPageState();
}

class _MeetingEditPageState extends State<MeetingEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionsController;
  late TextEditingController _statusIdController;
  late TextEditingController _fromDateController;
  late TextEditingController _toDateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  bool _isLoading = false;

  // Example status list for demonstration
  List<Map<String, String>> statuses = [
    {'id': '0a8d93f0-1c05-42b2-8e56-984a578ef077', 'name': 'Processing'},
    // Add other statuses as needed
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.item['title'] ?? '');
    _descriptionsController =
        TextEditingController(text: widget.item['description'] ?? '');
    _statusIdController =
        TextEditingController(text: widget.item['status_id'] ?? '');
    _fromDateController = TextEditingController(
        text: widget.item['from_date']?.split(' ')[0] ?? '');
    _toDateController =
        TextEditingController(text: widget.item['to_date']?.split(' ')[0] ?? '');
    _startTimeController =
        TextEditingController(text: widget.item['start_time'] ?? '');
    _endTimeController =
        TextEditingController(text: widget.item['end_time'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionsController.dispose();
    _statusIdController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  /// Opens a date picker and sets the selected date to the controller.
  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text =
        pickedDate.toIso8601String().split('T')[0]; // Format to 'yyyy-MM-dd'
      });
    }
  }

  /// Opens a time picker and sets the selected time to the controller.
  Future<void> _selectTime(
      BuildContext context, TextEditingController controller) async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: controller.text.isNotEmpty
          ? TimeOfDay(
        hour: int.parse(controller.text.split(':')[0]),
        minute: int.parse(controller.text.split(':')[1]),
      )
          : TimeOfDay.now(),
    );

    if (pickedTime != null) {
      setState(() {
        controller.text =
        '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  /// Sends a PUT request to update the meeting.
  Future<void> _updateRequest() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Token is null. Please log in again.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      String meetingId = widget.item['meeting_id'];

      final response = await http.put(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/work-tracking/meeting/update/$meetingId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': _titleController.text,
          'descriptions': _descriptionsController.text,
          'status_id': _statusIdController.text,
          'fromdate': '${_fromDateController.text} ${_startTimeController.text}',
          'todate': '${_toDateController.text} ${_endTimeController.text}',
          'start_time': _startTimeController.text,
          'end_time': _endTimeController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccess('Meeting updated successfully');
      } else {
        _showError('Failed to update meeting: ${response.reasonPhrase}');
      }
    }
  }

  /// Displays a success message and navigates back.
  void _showSuccess(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(true); // Return to previous page
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Displays an error message.
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Builds a text field with the given label and controller.
  Widget _buildTextField(String label, TextEditingController controller,
      {bool readOnly = false, VoidCallback? onTap}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  /// Builds a date field with a date picker.
  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _selectDate(context, controller),
      child: AbsorbPointer(
        child: _buildTextField(label, controller),
      ),
    );
  }

  /// Builds a time field with a time picker.
  Widget _buildTimeField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _selectTime(context, controller),
      child: AbsorbPointer(
        child: _buildTextField(label, controller),
      ),
    );
  }

  /// Shows a bottom sheet to select the status.
  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'Select Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(statuses[index]['name']!),
                    onTap: () {
                      setState(() {
                        _statusIdController.text = statuses[index]['id']!;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds the status field with a picker.
  Widget _buildStatusField() {
    return GestureDetector(
      onTap: _showStatusPicker,
      child: AbsorbPointer(
        child: _buildTextField('Status ID', _statusIdController),
      ),
    );
  }

  /// Builds the UI.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meeting'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image:
              AssetImage('assets/background.png'), // Update path if needed
              fit: BoxFit.cover,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
      body: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Title', _titleController),
              const SizedBox(height: 20),
              _buildTextField('Description', _descriptionsController),
              const SizedBox(height: 20),
              _buildStatusField(),
              const SizedBox(height: 20),
              _buildDateField('From Date', _fromDateController),
              const SizedBox(height: 20),
              _buildDateField('To Date', _toDateController),
              const SizedBox(height: 20),
              _buildTimeField('Start Time', _startTimeController),
              const SizedBox(height: 20),
              _buildTimeField('End Time', _endTimeController),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateRequest,
                icon: _isLoading
                    ? const CircularProgressIndicator(
                    color: Colors.white)
                    : const Icon(Icons.check),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding:
                  const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
