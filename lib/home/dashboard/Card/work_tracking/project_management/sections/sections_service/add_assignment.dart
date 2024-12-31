import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:pb_hrsystem/home/dashboard/Card/work_tracking/project_management/sections/sections_service/add_assignment_members.dart';
import 'package:provider/provider.dart';
import 'package:pb_hrsystem/settings/theme_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddAssignmentPage extends StatefulWidget {
  final String projectId;
  final String baseUrl;

  const AddAssignmentPage({
    super.key,
    required this.projectId,
    required this.baseUrl,
  });

  @override
  AddAssignmentPageState createState() => AddAssignmentPageState();
}

class AddAssignmentPageState extends State<AddAssignmentPage> {
  final _formKey = GlobalKey<FormState>();
  String title = '';
  String description = '';
  String status = 'Processing';
  String statusId = '0a8d93f0-1c05-42b2-8e56-984a578ef077';
  DateTime? fromDate;
  DateTime? toDate;
  TimeOfDay? fromTime;
  TimeOfDay? toTime;

  // Members
  List<Map<String, dynamic>> selectedMembers = [];

  // Image file
  File? _selectedImage;

  // Loading indicator
  bool _isLoading = false;

  // Map for status -> status_id
  final Map<String, String> _statusMap = {
    'Error': '87403916-9113-4e2e-9d7d-b5ed269fe20a',
    'Pending': '40d2ba5e-a978-47ce-bc48-caceca8668e9',
    'Processing': '0a8d93f0-1c05-42b2-8e56-984a578ef077',
    'Finished': 'e35569eb-75e1-4005-9232-bfb57303b8b3',
  };

  @override
  void initState() {
    super.initState();
    debugPrint('[_AddAssignmentPageState] Initializing with projectId: ${widget.projectId}, baseUrl: ${widget.baseUrl}');
    // Initialize fromDate/toDate, fromTime/toTime as null
    fromDate = null;
    toDate = null;
    fromTime = null;
    toTime = null;
  }

  /// For displaying status colors in the dropdown
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.yellow;
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

  /// Picks an image from Gallery
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        // Validate file size (e.g., max 5MB)
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showAlertDialog(
            title: 'File Too Large',
            content: 'Please select an image smaller than 5MB.',
            isError: true,
          );
          return;
        }

        // Validate file type
        final mimeType = lookupMimeType(image.path);
        if (mimeType == null || !mimeType.startsWith('image/')) {
          _showAlertDialog(
            title: 'Invalid File Type',
            content: 'Please select a valid image file.',
            isError: true,
          );
          return;
        }

        // If all checks pass, set state
        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Image Picker Error',
        content: 'Failed to pick image: $e',
        isError: true,
      );
    }
  }

  /// Sends the form data to the backend
  Future<void> _addAssignmentItem() async {
    // Validate form fields
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      // Build the request
      var uri = Uri.parse('${widget.baseUrl}/api/work-tracking/ass/insert');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Fill the fields
      request.fields['project_id'] = widget.projectId;
      request.fields['title'] = title;
      request.fields['descriptions'] = description;
      request.fields['status_id'] = _statusMap[status]!;

      List<Map<String, String>> membersDetails = selectedMembers.map((member) => {"employee_id": member['employee_id'].toString()}).toList();
      request.fields['memberDetails'] = jsonEncode(membersDetails);

      // If there's an image
      if (_selectedImage != null && await _selectedImage!.exists()) {
        final mimeType = lookupMimeType(_selectedImage!.path) ?? 'application/octet-stream';
        final mimeSplit = mimeType.split('/');
        request.files.add(
          await http.MultipartFile.fromPath(
            'file_name',
            _selectedImage!.path,
            contentType: MediaType(mimeSplit[0], mimeSplit[1]),
          ),
        );
      }

      // Debugging
      debugPrint('Sending request to: $uri');
      debugPrint('Request Fields: ${request.fields}');
      debugPrint('Number of files: ${request.files.length}');

      // Send the request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      debugPrint('Response Status Code: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      // Show success *only* if 200 <= statusCode < 300
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showAlertDialog(
          title: 'Success',
          content: 'Item added successfully.',
          isError: false,
          onOk: () {
            Navigator.pop(context, true);
          },
        );
      } else {
        _showAlertDialog(
          title: 'Error',
          content: 'Failed to add item.\n\nAPI Response:\n${response.body}',
          isError: true,
        );
      }
    } catch (e) {
      _showAlertDialog(
        title: 'Unexpected Error',
        content: 'An error occurred: $e',
        isError: true,
      );
      debugPrint('Unexpected error: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Reusable AlertDialog for error/success
  void _showAlertDialog({
    required String title,
    required String content,
    required bool isError,
    VoidCallback? onOk,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Text(
            title,
            style: TextStyle(
              color: isError ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (!isError && (title.contains('Success') || title.contains('Added'))) {
                  onOk?.call();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  /// Navigates to AddAssignmentMembersPage to pick members
  void _navigateToSelectMembers() async {
    debugPrint('[_AddAssignmentPageState] Navigating to AddAssignmentMembersPage with projectId: ${widget.projectId}');
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssignmentMembersPage(
          projectId: widget.projectId,
          baseUrl: widget.baseUrl,
          alreadySelectedMembers: selectedMembers,
        ),
      ),
    );

    if (result != null && result is List<Map<String, dynamic>>) {
      setState(() {
        selectedMembers = result;
      });
      debugPrint('[_AddAssignmentPageState] Members selected: '
          '${selectedMembers.map((m) => m['employee_id']).toList()}');
    }
  }

  /// Displays an overlapping set of member avatars
  Widget _buildSelectedMembers() {
    if (selectedMembers.isEmpty) return const Text('No members selected.');

    int displayCount = selectedMembers.length > 5 ? 5 : selectedMembers.length;
    List<Widget> avatars = [];

    for (int i = 0; i < displayCount; i++) {
      avatars.add(
        Positioned(
          left: i * 24.0,
          child: CircleAvatar(
            backgroundImage: selectedMembers[i]['image_url'] != null && selectedMembers[i]['image_url'].isNotEmpty ? NetworkImage(selectedMembers[i]['image_url']) : const AssetImage('assets/default_avatar.png') as ImageProvider,
            radius: 18,
            backgroundColor: Colors.white,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 4.0),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    }

    if (selectedMembers.length > 5) {
      avatars.add(
        Positioned(
          left: displayCount * 24.0,
          child: CircleAvatar(
            backgroundColor: Colors.grey[300],
            radius: 16,
            child: Text(
              '+${selectedMembers.length - 5}',
              style: const TextStyle(color: Colors.black, fontSize: 12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 32,
      child: Stack(children: avatars),
    );
  }

  /// Renders the "Add" button
  Widget _buildAddButton(double buttonWidth) {
    double safeWidth = MediaQuery.of(context).size.width * 0.3;
    if (safeWidth < 100) safeWidth = 100;

    return SizedBox(
      width: (buttonWidth < safeWidth) ? buttonWidth : safeWidth,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _addAssignmentItem,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text(
          'Add',
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFDBB342), // #DBB342
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final bool isDarkMode = themeNotifier.isDarkMode;

    final Size screenSize = MediaQuery.of(context).size;
    double horizontalPadding = screenSize.width * 0.04;
    double verticalPadding = screenSize.height * 0.05;

    horizontalPadding = horizontalPadding < 16.0 ? 16.0 : horizontalPadding;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(
                isDarkMode ? 'assets/darkbg.png' : 'assets/background.png',
              ),
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
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
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
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18.0,
                ),
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // + Add Button at Top Right
                          Align(
                            alignment: Alignment.topRight,
                            child: _buildAddButton(160),
                          ),
                          const SizedBox(height: 6),

                          // Title
                          const Text(
                            'Title',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Enter title',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Title is required.';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                title = value;
                              });
                            },
                          ),
                          const SizedBox(height: 18),

                          // Row: Status Dropdown + Upload Image Button
                          Row(
                            children: [
                              // Status
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Status',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    DropdownButtonFormField<String>(
                                      value: status, // "Processing" by default
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(8.0),
                                          ),
                                        ),
                                      ),
                                      items: ['Processing', 'Pending', 'Finished', 'Error'].map<DropdownMenuItem<String>>(
                                        (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.circle,
                                                  color: _getStatusColor(value),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(value),
                                              ],
                                            ),
                                          );
                                        },
                                      ).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          status = newValue!;
                                          statusId = _statusMap[status]!;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Status is required.';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Upload Image
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 25),
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Colors.green, Colors.lightGreen],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(16.0),
                                      ),
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _pickImage,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8.0),
                                          ),
                                          padding: EdgeInsets.symmetric(
                                            vertical: 17.0,
                                            horizontal: MediaQuery.of(context).size.width < 400 ? 40 : 53,
                                          ),
                                        ),
                                        child: Text(
                                          'Upload Image',
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: MediaQuery.of(context).size.width < 400 ? 12 : 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_selectedImage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          'Selected: ${_selectedImage!.path.split('/').last}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Row: Add People Button + Avatars
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SizedBox(
                                width: constraints.maxWidth * 0.45,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _navigateToSelectMembers,
                                  icon: const Icon(Icons.person_add, color: Colors.black),
                                  label: const Text(
                                    'Add People',
                                    style: TextStyle(color: Colors.black),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0,
                                      vertical: 10.0,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                    elevation: 3,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth * 0.5 - 8,
                                child: _buildSelectedMembers(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Enter description',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(8.0)),
                              ),
                            ),
                            maxLines: 7,
                            onChanged: (value) {
                              setState(() {
                                description = value;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
