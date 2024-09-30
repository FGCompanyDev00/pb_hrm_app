import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_members.dart';
import 'package:pb_hrsystem/services/work_tracking_service.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';

class AddAssignmentPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddAssignmentPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  State<AddAssignmentPage> createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  final WorkTrackingService _workTrackingService = WorkTrackingService();

  String _title = '';
  String _description = '';
  String _statusId = '';
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

  Future<void> _submitAssignment() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final assignmentData = {
        'status_id': _statusId,
        'title': _title,
        'descriptions': _description,
        'memberDetails': jsonEncode(_selectedMembers),
        'file_name': _selectedFiles, // Handle file upload separately
      };

      try {
        // Add new assignment
        final asId = await _workTrackingService.addAssignment(
          widget.projectId,
          assignmentData,
        );

        if (asId != null) {
          // Handle file upload
          if (_selectedFiles.isNotEmpty) {
            await _workTrackingService.addFilesToAssignment(asId, _selectedFiles);
          }

          // Handle member addition
          if (_selectedMembers.isNotEmpty) {
            await _workTrackingService.addMembersToAssignment(asId, _selectedMembers);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Assignment created successfully')),
          );

          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create assignment')),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error submitting assignment: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save assignment')),
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
          'Add Assignment',
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
                onPressed: _submitAssignment,
                child: const Text('Create Assignment'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}