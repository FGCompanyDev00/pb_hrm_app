// add_processing.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_processing_members.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

class AddProcessingPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddProcessingPage({
    Key? key,
    required this.projectId,
    required this.baseUrl,
  }) : super(key: key);

  @override
  State<AddProcessingPage> createState() => _AddProcessingPageState();
}

class _AddProcessingPageState extends State<AddProcessingPage> {
  final _formKey = GlobalKey<FormState>();
  final WorkTrackingService _workTrackingService = WorkTrackingService();

  String _title = '';
  String _description = '';
  String _statusId = '';
  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = TimeOfDay(hour: 17, minute: 0);
  List<File> _selectedFiles = [];
  List<Map<String, dynamic>> _selectedMembers = [];
  final List<Map<String, dynamic>> _statusOptions = [
    {'id': '40d2ba5e-a978-47ce-bc48-caceca8668e9', 'name': 'Pending'},
    {'id': '2d9cda36-8622-4517-94b8-b70dd3d26b64', 'name': 'Processing'},
    {'id': '6e0f9350-d83f-49c8-a10c-1ec5c4b6b4a3', 'name': 'Finished'},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize any necessary data
  }

  Future<void> _selectFromDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _fromDate) {
      setState(() {
        _fromDate = picked;
      });
    }
  }

  Future<void> _selectToDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _toDate) {
      setState(() {
        _toDate = picked;
      });
    }
  }

  Future<void> _selectStartTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null && picked != _startTime) {
      setState(() {
        _startTime = picked;
      });
    }
  }

  Future<void> _selectEndTime() async {
    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null && picked != _endTime) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  Future<void> _selectFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _selectedFiles = result.paths.map((path) => File(path!)).toList();
      });
    }
  }

  Future<void> _selectMembers() async {
    final selectedMembers = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectProcessingMembersPage(projectId: widget.projectId),
      ),
    );

    if (selectedMembers != null) {
      setState(() {
        _selectedMembers = List<Map<String, dynamic>>.from(selectedMembers);
      });
    }
  }

  Future<void> _submitProcessing() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final processingData = {
        'project_id': widget.projectId,
        'title': _title,
        'descriptions': _description,
        'status_id': _statusId,
        'fromdate': DateFormat('yyyy-MM-dd HH:mm:ss').format(_fromDate),
        'todate': DateFormat('yyyy-MM-dd HH:mm:ss').format(_toDate),
        'start_time': _startTime.format(context),
        'end_time': _endTime.format(context),
        'membersDetails': jsonEncode(_selectedMembers),
        'file_name': _selectedFiles, // Handle file upload separately
      };

      try {
        // Add new processing
        final meetingId = await _workTrackingService.addProcessing(processingData);

        if (meetingId != null) {
          // Handle file upload if necessary
          // Handle member addition if necessary

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Processing created successfully')),
          );

          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create processing')),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error submitting processing: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save processing')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
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
          'Add Processing',
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Title
              TextFormField(
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 5,
                validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
                onSaved: (value) => _description = value!,
              ),
              const SizedBox(height: 16),
              // Status
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statusOptions.map((status) {
                  return DropdownMenuItem<String>(
                    value: status['id'],
                    child: Text(status['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusId = value!;
                  });
                },
                validator: (value) => value == null ? 'Please select a status' : null,
              ),
              const SizedBox(height: 16),
              // From Date
              ListTile(
                title: Text('From Date: ${DateFormat('yyyy-MM-dd').format(_fromDate)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectFromDate,
                ),
              ),
              const SizedBox(height: 16),
              // To Date
              ListTile(
                title: Text('To Date: ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _selectToDate,
                ),
              ),
              const SizedBox(height: 16),
              // Start Time
              ListTile(
                title: Text('Start Time: ${_startTime.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: _selectStartTime,
                ),
              ),
              const SizedBox(height: 16),
              // End Time
              ListTile(
                title: Text('End Time: ${_endTime.format(context)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.access_time),
                  onPressed: _selectEndTime,
                ),
              ),
              const SizedBox(height: 16),
              // Members
              ElevatedButton(
                onPressed: _selectMembers,
                child: const Text('Select Members'),
              ),
              const SizedBox(height: 16),
              // Files
              ElevatedButton(
                onPressed: _selectFiles,
                child: const Text('Select Files'),
              ),
              const SizedBox(height: 16),
              // Submit Button
              ElevatedButton(
                onPressed: _submitProcessing,
                child: const Text('Create Processing'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
