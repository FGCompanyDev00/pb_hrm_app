import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';  // For date formatting

class EditRequestPage extends StatefulWidget {
  final Map<String, dynamic> item;

  const EditRequestPage({super.key, required this.item});

  @override
  _EditRequestPageState createState() => _EditRequestPageState();
}

class _EditRequestPageState extends State<EditRequestPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _typesController;
  late TextEditingController _descriptionController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _daysController;
  bool _isLoading = false;

  List<Map<String, dynamic>> leaveTypes = [
    {'id': '1', 'name': 'Holiday Leave'},
    {'id': '2', 'name': 'Sick Leave'},
    {'id': '3', 'name': 'Unpaid Leave'},
    {'id': '4', 'name': 'Compensation Leave'},
    {'id': '5', 'name': 'Family Leave'},
    {'id': '6', 'name': 'Emergency Leave'},
    {'id': '7', 'name': 'Special Leave'},
  ];

  @override
  void initState() {
    super.initState();
    _typesController = TextEditingController(text: widget.item['take_leave_type_id']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.item['take_leave_reason'] ?? '');
    _startDateController = TextEditingController(text: widget.item['take_leave_from'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    _endDateController = TextEditingController(text: widget.item['take_leave_to'] ?? '');
    _daysController = TextEditingController(text: widget.item['days']?.toString() ?? '1');
    _calculateDays();  // Calculate days based on start and end date at initialization
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _typesController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller, {bool isStart = true}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
        if (isStart) {
          _calculateDays();
        } else {
          _updateDaysFromDates();
        }
      });
    }
  }

  void _calculateDays() {
    if (_startDateController.text.isNotEmpty && _endDateController.text.isNotEmpty) {
      DateTime start = DateTime.parse(_startDateController.text);
      DateTime end = DateTime.parse(_endDateController.text);
      int difference = end.difference(start).inDays + 1;  // Including the end date
      if (difference > 0) {
        setState(() {
          _daysController.text = difference.toString();
        });
      }
    }
  }

  void _updateEndDateFromDays() {
    DateTime start = DateTime.parse(_startDateController.text);
    int days = int.parse(_daysController.text);
    DateTime newEndDate = start.add(Duration(days: days - 1));  // End date calculation
    setState(() {
      _endDateController.text = DateFormat('yyyy-MM-dd').format(newEndDate);
    });
  }

  void _updateDaysFromDates() {
    DateTime start = DateTime.parse(_startDateController.text);
    DateTime end = DateTime.parse(_endDateController.text);
    int difference = end.difference(start).inDays + 1;
    if (difference > 0) {
      setState(() {
        _daysController.text = difference.toString();
      });
    }
  }

  void _incrementDays() {
    setState(() {
      int currentDays = int.parse(_daysController.text);
      _daysController.text = (currentDays + 1).toString();
      _updateEndDateFromDays();
    });
  }

  void _decrementDays() {
    setState(() {
      int currentDays = int.parse(_daysController.text);
      if (currentDays > 1) {
        _daysController.text = (currentDays - 1).toString();
        _updateEndDateFromDays();
      }
    });
  }

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
        return;
      }

      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_request/${widget.item['take_leave_request_id']}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "take_leave_from": _startDateController.text,
          "take_leave_to": _endDateController.text,
          "take_leave_type_id": _typesController.text,
          "take_leave_reason": _descriptionController.text,
          "days": _daysController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      // Handling the response based on the status code range (200-299 = success)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccess('Request updated successfully');
      } else {
        _showError('Failed to update request: ${response.reasonPhrase}');
      }
    }
  }

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
                Navigator.of(context).pop();  // Only close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLeaveTypePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text(
                'Select Leave Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: leaveTypes.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(leaveTypes[index]['name']),
                    onTap: () {
                      setState(() {
                        _typesController.text = leaveTypes[index]['id'];
                        _descriptionController.text = leaveTypes[index]['name'];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Leave Request'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/background.png'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildLeaveTypeField(),  // Leave Type Field
              const SizedBox(height: 20),
              _buildTextField('Reason', _descriptionController),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField('Start Date', _startDateController),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildDateField('End Date', _endDateController),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDaysField(),
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
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.check),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () => _selectDate(context, controller, isStart: label == 'Start Date'),
      child: AbsorbPointer(
        child: _buildTextField(label, controller),
      ),
    );
  }

  Widget _buildDaysField() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: _decrementDays,
        ),
        Expanded(
          child: TextFormField(
            controller: _daysController,
            readOnly: true,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _incrementDays,
        ),
      ],
    );
  }

  Widget _buildLeaveTypeField() {
    return GestureDetector(
      onTap: _showLeaveTypePicker,
      child: AbsorbPointer(
        child: _buildTextField('Type', _typesController),
      ),
    );
  }
}
