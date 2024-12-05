// add_assignment.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_assignment_members.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class AddAssignmentPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddAssignmentPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _AddAssignmentPageState createState() => _AddAssignmentPageState();
}

class _AddAssignmentPageState extends State<AddAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _selectedStatus = 'Processing';
  String _statusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  List<Map<String, dynamic>> _selectedMembers = [];
  List<PlatformFile> _newFiles = [];
  bool _isLoading = false;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Finished':
        return Colors.green;
      case 'Error':
        return Colors.red;
      default:
        return Colors.black;
    }
  }

  /// Opens the member selection page and retrieves selected members
  Future<void> _navigateToAddMembers() async {
    final selected = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectAssignmentMembersPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
        ),
      ),
    );
    if (selected != null && selected is List<Map<String, dynamic>>) {
      await _fetchMembersImages(selected);
    }
  }

  Future<void> _fetchMembersImages(List<Map<String, dynamic>> members) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showErrorDialog('Token is null. Please log in again.');
      return;
    }

    List<Map<String, dynamic>> membersWithImages = [];
    for (var member in members) {
      try {
        final response = await http.get(
          Uri.parse('${widget.baseUrl}/api/profile/${member['employee_id']}'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          membersWithImages.add({
            'employee_id': member['employee_id'],
            'name': member['name'] ?? 'Unknown',
            'surname': member['surname'] ?? '',
            'images': data['images'] ?? '',
          });
        } else {
          membersWithImages.add({
            'employee_id': member['employee_id'],
            'name': member['name'] ?? 'Unknown',
            'surname': member['surname'] ?? '',
            'images': '',
          });
        }
      } catch (e) {
        membersWithImages.add({
          'employee_id': member['employee_id'],
          'name': member['name'] ?? 'Unknown',
          'surname': member['surname'] ?? '',
          'images': '',
        });
      }
    }

    setState(() {
      _selectedMembers = membersWithImages;
    });
  }

  /// Opens the file picker for selecting multiple files
  Future<void> _addFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );

    if (result != null) {
      setState(() {
        _newFiles.addAll(result.files);
      });
    }
  }

  /// Handles the assignment creation process
  Future<void> _createAssignment() async {
    if (_formKey.currentState == null) {
      _showErrorDialog('Form is not available.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Please correct the errors in the form.');
      return;
    }

    if (_selectedMembers.isEmpty) {
      _showErrorDialog('Please select at least one member.');
      return;
    }

    _formKey.currentState!.save();

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      _showErrorDialog('Authentication token is missing. Please log in again.');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Validate that all selected members have employee_id
      for (var member in _selectedMembers) {
        if (member['employee_id'] == null || member['employee_id'].isEmpty) {
          throw Exception('Selected member has invalid employee_id.');
        }
      }

      // Prepare memberDetails as JSON string
      List<Map<String, dynamic>> memberDetails = _selectedMembers
          .map((member) => {"employee_id": member['employee_id']})
          .toList();
      String memberDetailsStr = jsonEncode(memberDetails);

      // Validate statusId
      if (!_statusMap.containsKey(_selectedStatus)) {
        throw Exception('Invalid status selected.');
      }

      // Create multipart request
      var uri = Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Add form fields
      request.fields['project_id'] = widget.projectId;
      request.fields['status_id'] = _statusMap[_selectedStatus]!;
      request.fields['title'] = _title;
      request.fields['descriptions'] = _description;
      request.fields['memberDetails'] = memberDetailsStr;

      // Add files if any
      for (var file in _newFiles) {
        if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'file_name',
              file.path!,
              filename: file.name,
            ),
          );
        }
      }

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessDialog('Assignment created successfully.');
        _clearForm();
      } else {
        String errorMessage = 'Failed to create assignment.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showErrorDialog(errorMessage);
      }
    } catch (e) {

    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Clears the form after successful submission
  void _clearForm() {
    setState(() {
      _title = '';
      _description = '';
      _selectedStatus = 'Processing';
      _statusId = _statusMap[_selectedStatus]!;
      _selectedMembers = [];
      _newFiles = [];
    });
    _formKey.currentState!.reset();
  }

  /// Displays an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  /// Displays a success dialog
  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Success'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
            ),
          ],
        );
      },
    );
  }

  /// Launches the file URL in the default browser or file handler
  Future<void> _downloadFile(String url, String originalName) async {
    final Uri fileUri = Uri.parse(url);

    if (await canLaunchUrl(fileUri)) {
      await launchUrl(fileUri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch the file URL')),
      );
    }
  }

  /// Builds the list of selected files with options to download or remove
  Widget _buildFileList() {
    if (_newFiles.isEmpty) {
      return const Center(child: Text('No files selected.'));
    }

    return Column(
      children: _newFiles.map((file) {
        return ListTile(
          leading: const Icon(Icons.attach_file, color: Colors.green),
          title: Text(file.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Remove file
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _newFiles.remove(file);
                  });
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Builds the list of selected members with their avatars
  Widget _buildSelectedMembers() {
    if (_selectedMembers.isEmpty) return const Text('No members selected.');

    return Wrap(
      spacing: 8.0,
      children: _selectedMembers.map((member) {
        return Chip(
          avatar: CircleAvatar(
            backgroundImage: member['images'] != null && member['images'] != ''
                ? NetworkImage(member['images'])
                : const AssetImage('assets/default_avatar.png') as ImageProvider,
          ),
          label: Text('${member['name']} ${member['surname']}'),
          onDeleted: () {
            setState(() {
              _selectedMembers.remove(member);
            });
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(isDarkMode ? 'assets/darkbg.png' : 'assets/background.png'),
              fit: BoxFit.cover,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Add Assignment',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, // Dynamic title color based on theme
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, // Dynamic icon color based on theme
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
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Spacing for the Add button
                    const SizedBox(height: 60),
                    // Title Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter title';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _title = value!;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Description Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter description';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        _description = value!;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      icon: Image.asset(
                        'assets/task.png',
                        width: 24,
                        height: 24,
                      ),
                      items: ['Processing', 'Pending', 'Finished', 'Error']
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
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedStatus = newValue!;
                          _statusId = _statusMap[_selectedStatus]!;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select status';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Member Selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selected Members:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _navigateToAddMembers,
                          icon: const Icon(Icons.person_add, color: Colors.white),
                          label: const Text(
                            'Add Members',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildSelectedMembers(),
                    const SizedBox(height: 24),
                    // File Upload
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Attached Files:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addFiles,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text(
                            'Add Files',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildFileList(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Positioned Add button at top right under AppBar
            Positioned(
              top: 20,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _createAssignment,
                icon: Icon(
                  Icons.add,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white, // Icon color based on theme
                ),
                label: Text(
                  'Add',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white, // Text color based on theme
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFDBB342)
                      : const Color(0xFFDBB342),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
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
