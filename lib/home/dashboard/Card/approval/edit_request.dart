import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _typesController = TextEditingController(text: widget.item['types'] ?? '');
    _descriptionController = TextEditingController(text: widget.item['take_leave_reason'] ?? '');
    _startDateController = TextEditingController(text: widget.item['take_leave_from'] ?? '');
    _endDateController = TextEditingController(text: widget.item['take_leave_to'] ?? '');
    _daysController = TextEditingController(text: widget.item['days']?.toString() ?? '0.0');
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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = picked.toIso8601String().split('T').first;
      });
    }
  }

  void _incrementDays() {
    setState(() {
      double currentDays = double.tryParse(_daysController.text) ?? 0.0;
      _daysController.text = (currentDays + 1).toStringAsFixed(1);
    });
  }

  void _decrementDays() {
    setState(() {
      double currentDays = double.tryParse(_daysController.text) ?? 0.0;
      if (currentDays > 0) {
        _daysController.text = (currentDays - 1).toStringAsFixed(1);
      }
    });
  }

  Future<void> _updateRequest() async {
    if (_formKey.currentState?.validate() ?? false) {
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

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request updated successfully')),
        );
        Navigator.pop(context, true); // Returning to the previous page
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update request: ${response.reasonPhrase}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(30.10),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField('Type', _typesController, maxLines: 1),
              const SizedBox(height: 40),
              _buildTextField('Description', _descriptionController, maxLines: 3),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField('Start Date', _startDateController),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildDateField('End Date', _endDateController),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _buildDaysField(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: null, // Disable the delete button
                icon: const Icon(Icons.close),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _updateRequest,
                icon: const Icon(Icons.check),
                label: const Text('Update'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107),
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

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Edit Leave Request',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
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
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool readOnly = false, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(vertical: 30, horizontal: 15),
      ),
      style: const TextStyle(fontSize: 16),
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
      onTap: () => _selectDate(context, controller),
      child: AbsorbPointer(
        child: _buildTextField(label, controller),
      ),
    );
  }

  Widget _buildDaysField() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove, color: Colors.redAccent),
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
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter Days';
              }
              return null;
            },
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add, color: Colors.greenAccent),
          onPressed: _incrementDays,
        ),
      ],
    );
  }
}
