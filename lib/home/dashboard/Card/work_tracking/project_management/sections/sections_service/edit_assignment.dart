// update_assignment.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/theme/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateAssignmentPage extends StatefulWidget {
  final String assignmentId;
  final String projectId;
  final String baseUrl;

  const UpdateAssignmentPage({
    super.key,
    required this.assignmentId,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  _UpdateAssignmentPageState createState() => _UpdateAssignmentPageState();
}

class _UpdateAssignmentPageState extends State<UpdateAssignmentPage> {
  final _formKey = GlobalKey<FormState>();

  // Original Data
  String originalTitle = '';
  String originalDescription = '';
  String originalStatus = 'Processing';
  String originalStatusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';

  // Updated Data
  String? updatedTitle;
  String? updatedDescription;
  String? updatedStatus;
  String? updatedStatusId;

  // Flags to track if a field has been edited
  bool isTitleEdited = false;
  bool isDescriptionEdited = false;
  bool isStatusEdited = false;

  // File Handling
  List<Map<String, dynamic>> _existingFiles = [];
  List<Map<String, dynamic>> _filesToDelete = [];
  List<PlatformFile> _newFiles = [];

  bool _isLoading = false;

  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  @override
  void initState() {
    super.initState();
    _fetchAssignmentDetails();
  }

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

  Future<void> _fetchAssignmentDetails() async {
    setState(() {
      _isLoading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      final response = await http.get(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/get-assignment/${widget.assignmentId}'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          originalTitle = data['title'] ?? '';
          originalDescription = data['descriptions'] ?? '';
          originalStatus = data['s_name'] ?? 'Processing';
          originalStatusId = _statusMap[originalStatus] ??
              '0a8d93f0-1c05-42b2-8e56-984a578ef077';
          _existingFiles = List<Map<String, dynamic>>.from(data['files'] ?? []);
          _isLoading = false;
        });
      } else {
        _showAlertDialog(
          title: 'Error',
          content: 'Failed to load assignment details.',
          isError: true,
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error fetching assignment details: $e',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

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

  Future<void> _uploadNewFiles() async {
    if (_newFiles.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      return;
    }

    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/add-files/${widget.assignmentId}'),
      );
      request.headers['Authorization'] = 'Bearer $token';

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

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Files uploaded successfully.',
          isError: false,
        );
        setState(() {
          _newFiles.clear();
          _fetchAssignmentDetails();
        });
      } else {
        String errorMessage = 'Failed to upload files.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showAlertDialog(
          title: 'Error',
          content: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error uploading files: $e',
        isError: true,
      );
    }
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/delete-file/${widget.assignmentId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'file_id': file['file_id'], // Assuming 'file_id' is the identifier
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _existingFiles.remove(file);
          _filesToDelete.remove(file);
        });
        _showAlertDialog(
          title: 'Success',
          content: 'File deleted successfully.',
          isError: false,
        );
      } else {
        String errorMessage = 'Failed to delete file.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        _showAlertDialog(
          title: 'Error',
          content: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Error',
        content: 'Error deleting file: $e',
        isError: true,
      );
    }
  }

  Future<void> _updateAssignment() async {
    // Check if any field has been edited or files have been marked for deletion
    if (!isTitleEdited &&
        !isDescriptionEdited &&
        !isStatusEdited &&
        _filesToDelete.isEmpty &&
        _newFiles.isEmpty) {
      await _showAlertDialog(
        title: 'No Changes',
        content: 'No fields have been updated.',
        isError: false,
      );
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      await _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Prepare the request body with updated or original data
      Map<String, dynamic> body = {
        "status_id": isStatusEdited
            ? (_statusMap[updatedStatus!] ?? originalStatusId)
            : originalStatusId,
        "title": isTitleEdited ? (updatedTitle ?? originalTitle) : originalTitle,
        "descriptions": isDescriptionEdited
            ? (updatedDescription ?? originalDescription)
            : originalDescription,
      };

      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/update/${widget.assignmentId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Upload new files if any
        if (_newFiles.isNotEmpty) {
          await _uploadNewFiles();
        }

        // Delete files if any
        if (_filesToDelete.isNotEmpty) {
          for (var file in _filesToDelete) {
            await _deleteFile(file);
          }
        }

        // Refresh assignment details
        await _fetchAssignmentDetails();

        // Show success dialog without navigating back
        await _showAlertDialog(
          title: 'Success',
          content: 'Assignment updated successfully.',
          isError: false,
        );
      } else {
        String errorMessage = 'Failed to update assignment.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        await _showAlertDialog(
          title: 'Error',
          content: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      await _showAlertDialog(
        title: 'Error',
        content: 'Error updating assignment: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _deleteAssignment() async {
    bool confirm = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Assignment'),
          content: const Text('Are you sure you want to delete this assignment?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey, // Grey button as per request
              ),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (!confirm) return;

    setState(() {
      _isLoading = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      await _showAlertDialog(
        title: 'Authentication Error',
        content: 'Token is null. Please log in again.',
        isError: true,
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('${widget.baseUrl}/api/work-tracking/ass/delete/${widget.assignmentId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Show success dialog without navigating back
        await _showAlertDialog(
          title: 'Success',
          content: 'Assignment deleted successfully.',
          isError: false,
        );

        // Optionally, navigate back or to another page
        Navigator.of(context).pop(); // Navigate back after deletion
      } else {
        String errorMessage = 'Failed to delete assignment.';
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (_) {}
        await _showAlertDialog(
          title: 'Error',
          content: errorMessage,
          isError: true,
        );
      }
    } catch (e) {
      await _showAlertDialog(
        title: 'Error',
        content: 'Error deleting assignment: $e',
        isError: true,
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showAlertDialog({
    required String title,
    required String content,
    required bool isError,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title,
              style: TextStyle(
                  color: isError ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold)),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the AlertDialog
                // No further navigation
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

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

  Widget _buildFileList() {
    if (_existingFiles.isEmpty && _newFiles.isEmpty) {
      return const Center(child: Text('No files attached.'));
    }

    return Column(
      children: [
        // Existing Files
        ..._existingFiles.map((file) {
          final fileUrl = file['images'] != null &&
              file['images'] is List &&
              file['images'].isNotEmpty
              ? file['images'][0]
              : null;
          final originalName = file['originalname'] ?? 'No Name';
          final fileId = file['file_id'] ?? '';

          final isMarkedForDeletion = _filesToDelete.contains(file);

          return Opacity(
            opacity: isMarkedForDeletion ? 0.5 : 1.0,
            child: ListTile(
              leading: const Icon(Icons.attach_file, color: Colors.green),
              title: Text(originalName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.download,
                      color: fileUrl != null ? Colors.blue : Colors.grey,
                    ),
                    onPressed: fileUrl != null
                        ? () => _downloadFile(fileUrl, originalName)
                        : null,
                  ),
                  IconButton(
                    icon: Icon(
                      isMarkedForDeletion ? Icons.undo : Icons.delete,
                      color: isMarkedForDeletion ? Colors.orange : Colors.red,
                    ),
                    onPressed: () {
                      setState(() {
                        if (isMarkedForDeletion) {
                          _filesToDelete.remove(file);
                        } else {
                          _filesToDelete.add(file);
                        }
                      });
                    },
                  ),
                ],
              ),
              tileColor:
              isMarkedForDeletion ? Colors.red.withOpacity(0.1) : null,
            ),
          );
        }).toList(),
        // New Files
        ..._newFiles.map((file) {
          return ListTile(
            leading: const Icon(Icons.attach_file, color: Colors.green),
            title: Text(file.name),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () {
                setState(() {
                  _newFiles.remove(file);
                });
              },
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    return Scaffold(
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
          'Update Assignment',
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Stack(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Delete and Update Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _deleteAssignment,
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey, // Grey button as per request
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _updateAssignment,
                            icon: const Icon(Icons.check, color: Colors.black),
                            label: const Text(
                              'Update',
                              style: TextStyle(color: Colors.black),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              const Color(0xFFDBB342), // Hex #DBB342
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12.0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Title Input
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Title cannot be empty';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          updatedTitle = value;
                          isTitleEdited = true;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: isStatusEdited
                          ? updatedStatus
                          : originalStatus,
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
                        if (newValue != null) {
                          setState(() {
                            updatedStatus = newValue;
                            updatedStatusId = _statusMap[newValue] ?? originalStatusId;
                            isStatusEdited = true;
                          });
                        }
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a status';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Description Input
                    TextFormField(
                      initialValue: isDescriptionEdited
                          ? updatedDescription
                          : originalDescription,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Description cannot be empty';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          updatedDescription = value;
                          isDescriptionEdited = true;
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Files Section
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
                                vertical: 8.0, horizontal: 12.0),
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
              // Positioned Delete and Update Buttons to handle opacity overlay if needed
            ],
          ),
        ),
      ),
      // floatingActionButton: _isLoading
      //     ? null
      //     : null, // You can add FABs here if needed in the future
    );
  }
}