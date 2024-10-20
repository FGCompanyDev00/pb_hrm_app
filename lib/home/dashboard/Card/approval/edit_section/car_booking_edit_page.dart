import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CarBookingEditPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String id;

  const CarBookingEditPage(
      {super.key,
        required this.id,
        required this.item});

  @override
  _CarBookingEditPageState createState() => _CarBookingEditPageState();
}

class _CarBookingEditPageState extends State<CarBookingEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _employeeIdController;
  late TextEditingController _purposeController;
  late TextEditingController _placeController;
  late TextEditingController _dateInController;
  late TextEditingController _dateOutController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _employeeIdController = TextEditingController(text: widget.item['employee_id'] ?? '');
    _purposeController = TextEditingController(text: widget.item['purpose'] ?? '');
    _placeController = TextEditingController(text: widget.item['place'] ?? '');
    _dateInController = TextEditingController(text: widget.item['date_in'] ?? '');
    _dateOutController = TextEditingController(text: widget.item['date_out'] ?? '');
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _purposeController.dispose();
    _placeController.dispose();
    _dateInController.dispose();
    _dateOutController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty ? DateTime.parse(controller.text) : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (pickedDate != null) {
      setState(() {
        controller.text = pickedDate.toIso8601String().split('T')[0];
      });
    }
  }

  Future<void> _updateRequest() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        _showError('Token is null. Please log in again.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      String uid = widget.id;

      final response = await http.put(
        Uri.parse('https://demo-application-api.flexiflows.co/api/office-administration/car_permit/$uid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'employee_id': _employeeIdController.text,
          'purpose': _purposeController.text,
          'place': _placeController.text,
          'date_in': _dateInController.text,
          'date_out': _dateOutController.text,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSuccess('Car booking updated successfully');
      } else {
        _showError('Failed to update car booking: ${response.reasonPhrase}');
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
                Navigator.of(context).pop(); // Close the dialog
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

  Widget _buildTextField(String label, TextEditingController controller, {bool readOnly = false, VoidCallback? onTap}) {
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
      onTap: () => _selectDate(context, controller),
      child: AbsorbPointer(
        child: _buildTextField(label, controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Car Booking'),
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Employee ID', _employeeIdController),
              const SizedBox(height: 20),
              _buildTextField('Purpose', _purposeController),
              const SizedBox(height: 20),
              _buildTextField('Place', _placeController),
              const SizedBox(height: 20),
              _buildDateField('Date Out', _dateOutController),
              const SizedBox(height: 20),
              _buildDateField('Date In', _dateInController),
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
                    ? const CircularProgressIndicator(
                    color: Colors.white)
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
