import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/add_people_page.dart';

class OfficeAddEventPage extends StatefulWidget {
  const OfficeAddEventPage({super.key});

  @override
  _OfficeAddEventPageState createState() => _OfficeAddEventPageState();
}

class _OfficeAddEventPageState extends State<OfficeAddEventPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime _startDateTime = DateTime.now();
  DateTime _endDateTime = DateTime.now();
  String? _bookingType;
  String? _location;
  String? _notification;
  final _formKey = GlobalKey<FormState>();

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final event = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'startDateTime': _startDateTime,
        'endDateTime': _endDateTime,
        'location': _location,
        'notification': _notification,
      };
      Navigator.pop(context, event);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
    }
  }

  void _navigateToAddPeople() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddPeoplePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        flexibleSpace: Image.asset(
          'assets/background.png',
          fit: BoxFit.cover,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text(
                  '+ Add',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Type of Booking*',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                items: const [
                  DropdownMenuItem(value: 'Add meeting', child: Text('Add meeting')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _bookingType = value;
                  });
                },
                validator: (value) => value == null ? 'Please select a booking type' : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Title*',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _titleController,
                validator: (value) => value == null || value.isEmpty ? 'Please enter a title' : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Start date-Time*',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _startDateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_startDateTime),
                    );
                    if (time != null) {
                      setState(() {
                        _startDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                readOnly: true,
                controller: TextEditingController(
                  text: DateFormat.yMd().add_jm().format(_startDateTime),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please select a start date-time' : null,
              ),
              const SizedBox(height: 16.0),
              const Text(
                'End date-Time*',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextFormField(
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _endDateTime,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(_endDateTime),
                    );
                    if (time != null) {
                      setState(() {
                        _endDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                      });
                    }
                  }
                },
                readOnly: true,
                controller: TextEditingController(
                  text: DateFormat.yMd().add_jm().format(_endDateTime),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please select an end date-time' : null,
              ),
              const SizedBox(height: 16.0),
              const Text(
                'Location*',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              DropdownButtonFormField<String>(
                items: const [
                  DropdownMenuItem(value: 'meeting onsite', child: Text('meeting onsite')),
                  DropdownMenuItem(value: 'meeting online', child: Text('meeting online')),
                ],
                onChanged: (value) {
                  setState(() {
                    _location = value;
                  });
                },
                validator: (value) => value == null ? 'Please select a location' : null,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                items: const [
                  DropdownMenuItem(
                    value: 'Notify me 30 min before meeting',
                    child: Text('Notify me 30 min before meeting'),
                  ),
                  DropdownMenuItem(
                    value: 'Do not notify me',
                    child: Text('Do not notify me'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _notification = value;
                  });
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: _navigateToAddPeople,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text('Add People'),
              ),
              const SizedBox(height: 16.0),
              const Row(
                children: [
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/person1.jpg'),
                  ),
                  SizedBox(width: 8.0),
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/person2.jpg'),
                  ),
                  SizedBox(width: 8.0),
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/person3.jpg'),
                  ),
                  SizedBox(width: 8.0),
                  CircleAvatar(
                    backgroundImage: AssetImage('assets/person4.jpg'),
                  ),
                  SizedBox(width: 8.0),
                  CircleAvatar(
                    child: Text('+3'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
