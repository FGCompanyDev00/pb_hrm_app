// lib/home/dashboard/Card/approval/meeting_room_booking_edit_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// This page allows the user to edit a meeting room booking request.
/// Members are not displayed or edited as per the requirements.
class MeetingRoomBookingEditPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const MeetingRoomBookingEditPage({super.key, required this.item});

  @override
  _MeetingRoomBookingEditPageState createState() =>
      _MeetingRoomBookingEditPageState();
}

class _MeetingRoomBookingEditPageState
    extends State<MeetingRoomBookingEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _roomIdController;
  late TextEditingController _titleController;
  late TextEditingController _fromDateTimeController;
  late TextEditingController _toDateTimeController;
  late TextEditingController _employeeTelController;
  late TextEditingController _remarkController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _roomIdController =
        TextEditingController(text: widget.item['room_id'] ?? '');
    _titleController =
        TextEditingController(text: widget.item['title'] ?? '');
    _fromDateTimeController =
        TextEditingController(text: widget.item['from_date_time'] ?? '');
    _toDateTimeController =
        TextEditingController(text: widget.item['to_date_time'] ?? '');
    _employeeTelController =
        TextEditingController(text: widget.item['employee_tel'] ?? '');
    _remarkController =
        TextEditingController(text: widget.item['remark'] ?? '');
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _titleController.dispose();
    _fromDateTimeController.dispose();
    _toDateTimeController.dispose();
    _employeeTelController.dispose();
    _remarkController.dispose();
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

  /// Sends a PUT request to update the meeting room booking.
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

      String uid = widget.item['uid'];

      final response = await http.put(
        Uri.parse(
            'https://demo-application-api.flexiflows.co/api/office-administration/book_meeting_room/$uid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'room_id': _roomIdController.text,
          'title': _titleController.text,
          'from_date_time': _fromDateTimeController.text,
          'to_date_time': _toDateTimeController.text,
          'employee_tel': _employeeTelController.text,
          'remark': _remarkController.text,
          // Members are not required
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccess('Meeting room booking updated successfully');
      } else {
        _showError(
            'Failed to update meeting room booking: ${response.reasonPhrase}');
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

  /// Builds the UI.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Meeting Room Booking'),
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
              _buildTextField('Room ID', _roomIdController),
              const SizedBox(height: 20),
              _buildTextField('Title', _titleController),
              const SizedBox(height: 20),
              _buildDateField('From Date', _fromDateTimeController),
              const SizedBox(height: 20),
              _buildDateField('To Date', _toDateTimeController),
              const SizedBox(height: 20),
              _buildTextField('Employee Tel', _employeeTelController),
              const SizedBox(height: 20),
              _buildTextField('Remark', _remarkController),
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
