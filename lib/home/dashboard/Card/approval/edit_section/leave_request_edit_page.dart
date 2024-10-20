// leave_request_edit_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LeaveRequestEditPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String id;

  const LeaveRequestEditPage({super.key, required this.id, required this.item});

  @override
  _LeaveRequestEditPageState createState() => _LeaveRequestEditPageState();
}

class _LeaveRequestEditPageState extends State<LeaveRequestEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _typesController;
  late TextEditingController _descriptionController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _daysController;
  bool _isLoading = false;
  bool _isLeaveTypesLoading = false;
  List<Map<String, dynamic>> leaveTypes = [];
  int? _selectedLeaveTypeId;

  @override
  void initState() {
    super.initState();
    _typesController = TextEditingController(text: '');
    _descriptionController =
        TextEditingController(text: widget.item['take_leave_reason'] ?? '');
    _startDateController =
        TextEditingController(text: widget.item['take_leave_from'] ?? '');
    _endDateController =
        TextEditingController(text: widget.item['take_leave_to'] ?? '');
    _daysController =
        TextEditingController(text: widget.item['days']?.toString() ?? '1');
    _calculateDays();
    _fetchLeaveTypes();
  }

  @override
  void dispose() {
    _typesController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveTypes() async {
    setState(() {
      _isLeaveTypesLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Token is null. Please log in again.')),
      );
      setState(() {
        _isLeaveTypesLoading = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave-types'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          leaveTypes = List<Map<String, dynamic>>.from(data['results']);
          // Debug: Print fetched leave types
          print('Fetched Leave Types: $leaveTypes');

          // Find the leave type name based on the leave_type_id from the item
          final matchedLeaveType = leaveTypes.firstWhere(
                  (type) =>
              type['leave_type_id'].toString() ==
                  widget.item['leave_type_id'].toString(),
              orElse: () => {});
          if (matchedLeaveType.isNotEmpty) {
            _selectedLeaveTypeId = matchedLeaveType['leave_type_id'];
            _typesController.text = matchedLeaveType['name'];
          }
          _isLeaveTypesLoading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
              Text('Failed to fetch leave types: ${response.reasonPhrase}')),
        );
        setState(() {
          _isLeaveTypesLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching leave types: $e')),
      );
      setState(() {
        _isLeaveTypesLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller,
      {bool isStart = true}) async {
    DateTime initialDate = DateTime.now();
    if (controller.text.isNotEmpty) {
      try {
        initialDate = DateTime.parse(controller.text);
      } catch (e) {
        // If parsing fails, default to today
        print('Error parsing date: $e');
      }
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
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
    if (_startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty) {
      try {
        DateTime start = DateTime.parse(_startDateController.text);
        DateTime end = DateTime.parse(_endDateController.text);
        int difference = end.difference(start).inDays + 1;
        if (difference > 0) {
          setState(() {
            _daysController.text = difference.toString();
          });
        }
      } catch (e) {
        // Handle invalid date formats
        print('Error calculating days: $e');
      }
    }
  }

  void _updateEndDateFromDays() {
    if (_startDateController.text.isNotEmpty &&
        _daysController.text.isNotEmpty) {
      try {
        DateTime start = DateTime.parse(_startDateController.text);
        int days = int.tryParse(_daysController.text) ?? 1;
        DateTime newEndDate = start.add(Duration(days: days - 1));
        setState(() {
          _endDateController.text = DateFormat('yyyy-MM-dd').format(newEndDate);
        });
      } catch (e) {
        // Handle invalid date formats or parsing errors
        print('Error updating end date from days: $e');
      }
    }
  }

  void _updateDaysFromDates() {
    if (_startDateController.text.isNotEmpty &&
        _endDateController.text.isNotEmpty) {
      try {
        DateTime start = DateTime.parse(_startDateController.text);
        DateTime end = DateTime.parse(_endDateController.text);
        int difference = end.difference(start).inDays + 1;
        if (difference > 0) {
          setState(() {
            _daysController.text = difference.toString();
          });
        }
      } catch (e) {
        // Handle invalid date formats or parsing errors
        print('Error updating days from dates: $e');
      }
    }
  }

  void _incrementDays() {
    setState(() {
      int currentDays = int.tryParse(_daysController.text) ?? 1;
      _daysController.text = (currentDays + 1).toString();
      _updateEndDateFromDays();
    });
  }

  void _decrementDays() {
    setState(() {
      int currentDays = int.tryParse(_daysController.text) ?? 1;
      if (currentDays > 1) {
        _daysController.text = (currentDays - 1).toString();
        _updateEndDateFromDays();
      }
    });
  }

  Future<void> _updateRequest() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedLeaveTypeId == null) {
        _showError('Please select a valid Leave Type.');
        return;
      }

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

      // Use the id passed from the widget
      String leaveRequestId = widget.id;

      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/leave_request/$leaveRequestId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'take_leave_from': _startDateController.text,
          'take_leave_to': _endDateController.text,
          'take_leave_type_id': _selectedLeaveTypeId,
          'take_leave_reason': _descriptionController.text,
          'days': _daysController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccess('Leave request updated successfully');
      } else {
        _showError('Failed to update leave request: ${response.reasonPhrase}');
      }
    }
  }

  Future<void> _showSuccess(String message) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Close dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    Navigator.of(context).pop(true); // Pop edit page with result
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLeaveTypePicker() {
    if (leaveTypes.isEmpty) {
      _showError('No leave types available to select.');
      return;
    }
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
                        _selectedLeaveTypeId =
                        leaveTypes[index]['leave_type_id'];
                        _typesController.text = leaveTypes[index]['name'];
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

  Widget _buildDateField(String label, TextEditingController controller) {
    return GestureDetector(
      onTap: () =>
          _selectDate(context, controller, isStart: label == 'Start Date'),
      child: AbsorbPointer(
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select $label';
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildLeaveTypeField() {
    return GestureDetector(
      onTap: _showLeaveTypePicker,
      child: AbsorbPointer(
        child: TextFormField(
          controller: _typesController,
          decoration: InputDecoration(
            labelText: 'Leave Type',
            filled: true,
            fillColor: Colors.grey.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select Leave Type';
            }
            return null;
          },
        ),
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
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter number of days';
              }
              if (int.tryParse(value) == null || int.parse(value) < 1) {
                return 'Please enter a valid number of days';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _incrementDays,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLeaveTypesLoading) {
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
          toolbarHeight: 100,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
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
        padding:
        const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildLeaveTypeField(),
              const SizedBox(height: 20),
              _buildTextField('Reason', _descriptionController),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child:
                    _buildDateField('Start Date', _startDateController),
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
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
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
}
